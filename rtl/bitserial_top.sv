// =============================================================================
// bitserial_top.sv - Bit-Serial Bus System Top Level
// =============================================================================
// Description:
//   Top-level integration module for the bit-serial bus system. Connects two
//   masters to three slaves through a serial bus with priority arbitration,
//   address decoding, and split transaction support.
//
// System Architecture:
//   +--------+    +--------+
//   |Master 0|    |Master 1|
//   +---+----+    +----+---+
//       |              |
//   +---v----+    +----v---+
//   |  P2S 0 |    |  P2S 1 |  (parallel_to_serial)
//   +---+----+    +----+---+
//       |              |
//       v              v
//   +---------------------+
//   |   Serial Arbiter    |  (priority: M0 > M1, split support)
//   +----------+----------+
//              |
//              v
//   +---------------------+
//   | Serial-to-Parallel  |  (frame decode, response gen)
//   +----------+----------+
//              |
//              v
//   +---------------------+
//   |   Address Decoder   |  (routes to slaves)
//   +---+-------+-----+---+
//       |       |     |
//       v       v     v
//   +------+ +------+ +------+
//   |Slave0| |Slave1| |Slave2|
//   | 4KB  | | 4KB  | | 2KB  |
//   |split | |      | |      |
//   +------+ +------+ +------+
//
// I/O Definitions:
//   Inputs:
//     clk_i             - System clock (50 MHz typical)
//     rst_ni            - Asynchronous reset (active low)
//     m_req_i[1:0]      - Master request signals
//     m_addr_i[1:0]     - Master address arrays [13:0]
//     m_wdata_i[1:0]    - Master write data arrays [7:0]
//     m_we_i[1:0]       - Master write enable signals
//
//   Outputs:
//     m_gnt_o[1:0]      - Master grant signals
//     m_ready_o[1:0]    - Master transaction complete signals
//     m_rdata_o[1:0]    - Master read data arrays [7:0]
//     m_err_o[1:0]      - Master error signals
//
// Split Transaction Support:
//   Slave 0 is configured with SPLIT_CAPABLE=1. When a split transaction
//   occurs, the arbiter tracks which master initiated it and ensures that
//   master receives the response when the slave is ready.
//
// =============================================================================

module bitserial_top
  import bus_pkg::*;
(
    // Clock and Reset
    input logic clk_i,              // System clock
    input logic rst_ni,             // Asynchronous reset (active low)

    // Master 0 Interface
    input  logic [           1:0] m_req_i,       // Master request [1:0]
    input  logic [ADDR_WIDTH-1:0] m_addr_i [NUM_MASTERS],  // Master addresses
    input  logic [DATA_WIDTH-1:0] m_wdata_i[NUM_MASTERS],  // Master write data
    input  logic [           1:0] m_we_i,        // Master write enable [1:0]
    output logic [           1:0] m_gnt_o,       // Master grant [1:0]
    output logic [           1:0] m_ready_o,     // Master ready [1:0]
    output logic [DATA_WIDTH-1:0] m_rdata_o[NUM_MASTERS],  // Master read data
    output logic [           1:0] m_err_o        // Master error [1:0]
);

  // ---------------------------------------------------------------------------
  // Internal Signal Declarations
  // ---------------------------------------------------------------------------

  // Serial bus signals (between arbitrated master and S2P)
  logic                  serial_sdata;
  logic                  serial_sclk;
  logic                  serial_svalid;
  logic                  serial_sready;

  // Response path signals (from S2P back to masters)
  logic                  serial_resp_data;
  logic                  serial_resp_clk;
  logic                  serial_resp_valid;

  // Per-master serial outputs (before arbitration)
  logic [           1:0] master_sdata;
  logic [           1:0] master_sclk;
  logic [           1:0] master_svalid;

  // Arbiter control signals
  logic                  master_sel;
  logic                  frame_active;

  // Split transaction signals
  logic                  split_start;
  logic                  split_done;
  logic                  split_pending;
  logic [           1:0] split_owner;

  // Decoded slave interface (from S2P to address decoder)
  logic                  slave_valid;
  logic [ADDR_WIDTH-1:0] slave_addr;
  logic [DATA_WIDTH-1:0] slave_wdata;
  logic                  slave_we;
  logic                  slave_ready;
  logic [DATA_WIDTH-1:0] slave_rdata;
  logic                  slave_err;

  // Address decoder to slave signals
  logic [NUM_SLAVES-1:0] slave_sel;
  logic [NUM_SLAVES-1:0] slave_valid_dec;
  logic [ADDR_WIDTH-1:0] slave_addr_dec;
  logic [DATA_WIDTH-1:0] slave_wdata_dec;
  logic                  slave_we_dec;

  // Slave response signals
  logic [NUM_SLAVES-1:0] slave_ready_arr;
  logic [DATA_WIDTH-1:0] slave_rdata_arr   [NUM_SLAVES];
  logic [NUM_SLAVES-1:0] slave_err_arr;

  // Slave 0 split transaction signals
  logic                  slave0_split_busy;
  logic                  slave0_split_ready;

  // ---------------------------------------------------------------------------
  // Frame Active Detection
  // ---------------------------------------------------------------------------
  // Frame is active when any master is transmitting
  assign frame_active = master_svalid[0] | master_svalid[1];

  // ---------------------------------------------------------------------------
  // Split Transaction Logic
  // ---------------------------------------------------------------------------
  // Split starts when slave 0 is accessed and it's a read to trigger split
  // For now, split is controlled by detecting slave 0 read with split busy
  assign split_start = slave0_split_busy && !split_pending;
  assign split_done  = slave0_split_ready;

  // ---------------------------------------------------------------------------
  // Master 0 Parallel-to-Serial Adapter
  // ---------------------------------------------------------------------------
  parallel_to_serial i_p2s_0 (
      .clk_i        (clk_i),
      .rst_ni       (rst_ni),
      .valid_i      (m_req_i[0] & m_gnt_o[0]),
      .addr_i       (m_addr_i[0]),
      .wdata_i      (m_wdata_i[0]),
      .we_i         (m_we_i[0]),
      .ready_o      (m_ready_o[0]),
      .rdata_o      (m_rdata_o[0]),
      .err_o        (m_err_o[0]),
      .sdata_o      (master_sdata[0]),
      .sclk_o       (master_sclk[0]),
      .svalid_o     (master_svalid[0]),
      .sready_i     (serial_sready),
      .sdata_i      (serial_resp_data),
      .sclk_resp_i  (serial_resp_clk),
      .svalid_resp_i(serial_resp_valid)
  );

  // ---------------------------------------------------------------------------
  // Master 1 Parallel-to-Serial Adapter
  // ---------------------------------------------------------------------------
  parallel_to_serial i_p2s_1 (
      .clk_i        (clk_i),
      .rst_ni       (rst_ni),
      .valid_i      (m_req_i[1] & m_gnt_o[1]),
      .addr_i       (m_addr_i[1]),
      .wdata_i      (m_wdata_i[1]),
      .we_i         (m_we_i[1]),
      .ready_o      (m_ready_o[1]),
      .rdata_o      (m_rdata_o[1]),
      .err_o        (m_err_o[1]),
      .sdata_o      (master_sdata[1]),
      .sclk_o       (master_sclk[1]),
      .svalid_o     (master_svalid[1]),
      .sready_i     (serial_sready),
      .sdata_i      (serial_resp_data),
      .sclk_resp_i  (serial_resp_clk),
      .svalid_resp_i(serial_resp_valid)
  );

  // ---------------------------------------------------------------------------
  // Serial Arbiter
  // ---------------------------------------------------------------------------
  serial_arbiter i_arbiter (
      .clk_i          (clk_i),
      .rst_ni         (rst_ni),
      .req_i          (m_req_i),
      .gnt_o          (m_gnt_o),
      .frame_active_i (frame_active),
      .split_start_i  (split_start),
      .split_done_i   (split_done),
      .msel_o         (master_sel),
      .split_pending_o(split_pending),
      .split_owner_o  (split_owner)
  );

  // ---------------------------------------------------------------------------
  // Serial Bus Multiplexing
  // ---------------------------------------------------------------------------
  // Select serial signals from granted master
  assign serial_sdata  = master_sel ? master_sdata[1] : master_sdata[0];
  assign serial_sclk   = master_sel ? master_sclk[1] : master_sclk[0];
  assign serial_svalid = master_sel ? master_svalid[1] : master_svalid[0];

  // ---------------------------------------------------------------------------
  // Serial-to-Parallel Adapter
  // ---------------------------------------------------------------------------
  serial_to_parallel i_s2p (
      .clk_i        (clk_i),
      .rst_ni       (rst_ni),
      .sdata_i      (serial_sdata),
      .sclk_i       (serial_sclk),
      .svalid_i     (serial_svalid),
      .sready_o     (serial_sready),
      .sdata_o      (serial_resp_data),
      .sclk_resp_o  (serial_resp_clk),
      .svalid_resp_o(serial_resp_valid),
      .valid_o      (slave_valid),
      .addr_o       (slave_addr),
      .wdata_o      (slave_wdata),
      .we_o         (slave_we),
      .ready_i      (slave_ready),
      .rdata_i      (slave_rdata),
      .err_i        (slave_err)
  );

  // ---------------------------------------------------------------------------
  // Address Decoder
  // ---------------------------------------------------------------------------
  addr_decoder i_addr_dec (
      .valid_i      (slave_valid),
      .addr_i       (slave_addr),
      .wdata_i      (slave_wdata),
      .we_i         (slave_we),
      .ready_o      (slave_ready),
      .rdata_o      (slave_rdata),
      .err_o        (slave_err),
      .slave_sel_o  (slave_sel),
      .slave_valid_o(slave_valid_dec),
      .slave_addr_o (slave_addr_dec),
      .slave_wdata_o(slave_wdata_dec),
      .slave_we_o   (slave_we_dec),
      .slave_ready_i(slave_ready_arr),
      .slave_rdata_i(slave_rdata_arr),
      .slave_err_i  (slave_err_arr)
  );

  // ---------------------------------------------------------------------------
  // Slave 0: 4KB Split-Capable Memory
  // ---------------------------------------------------------------------------
  slave_mem #(
      .MEM_SIZE(SLAVE0_SIZE),
      .SPLIT_CAPABLE(1)
  ) i_slave_0 (
      .clk_i        (clk_i),
      .rst_ni       (rst_ni),
      .valid_i      (slave_valid_dec[0]),
      .addr_i       (slave_addr_dec),
      .wdata_i      (slave_wdata_dec),
      .we_i         (slave_we_dec),
      .ready_o      (slave_ready_arr[0]),
      .rdata_o      (slave_rdata_arr[0]),
      .err_o        (slave_err_arr[0]),
      .split_start_i(1'b0),  // Split triggered externally if needed
      .split_busy_o (slave0_split_busy),
      .split_ready_o(slave0_split_ready)
  );

  // ---------------------------------------------------------------------------
  // Slave 1: 4KB Normal Memory
  // ---------------------------------------------------------------------------
  slave_mem #(
      .MEM_SIZE(SLAVE1_SIZE),
      .SPLIT_CAPABLE(0)
  ) i_slave_1 (
      .clk_i        (clk_i),
      .rst_ni       (rst_ni),
      .valid_i      (slave_valid_dec[1]),
      .addr_i       (slave_addr_dec),
      .wdata_i      (slave_wdata_dec),
      .we_i         (slave_we_dec),
      .ready_o      (slave_ready_arr[1]),
      .rdata_o      (slave_rdata_arr[1]),
      .err_o        (slave_err_arr[1]),
      .split_start_i(1'b0),
      .split_busy_o (),
      .split_ready_o()
  );

  // ---------------------------------------------------------------------------
  // Slave 2: 2KB Normal Memory
  // ---------------------------------------------------------------------------
  slave_mem #(
      .MEM_SIZE(SLAVE2_SIZE),
      .SPLIT_CAPABLE(0)
  ) i_slave_2 (
      .clk_i        (clk_i),
      .rst_ni       (rst_ni),
      .valid_i      (slave_valid_dec[2]),
      .addr_i       (slave_addr_dec),
      .wdata_i      (slave_wdata_dec),
      .we_i         (slave_we_dec),
      .ready_o      (slave_ready_arr[2]),
      .rdata_o      (slave_rdata_arr[2]),
      .err_o        (slave_err_arr[2]),
      .split_start_i(1'b0),
      .split_busy_o (),
      .split_ready_o()
  );

  // ---------------------------------------------------------------------------
  // Debug Monitoring
  // ---------------------------------------------------------------------------
  // Monitor response wire signals
  always @(posedge clk_i) begin
    if (serial_resp_valid) begin
      $display("[TOP WIRE %t] serial_resp_valid=1, serial_resp_data=%b, serial_resp_clk=%b", $time,
               serial_resp_data, serial_resp_clk);
    end
  end

endmodule