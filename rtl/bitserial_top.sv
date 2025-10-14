module bitserial_top
  import bus_pkg::*;
(
    input logic clk_i,
    input logic rst_ni,

    input  logic [           1:0] m_req_i,
    input  logic [ADDR_WIDTH-1:0] m_addr_i [NUM_MASTERS],
    input  logic [DATA_WIDTH-1:0] m_wdata_i[NUM_MASTERS],
    input  logic [           1:0] m_we_i,
    output logic [           1:0] m_gnt_o,
    output logic [           1:0] m_ready_o,
    output logic [DATA_WIDTH-1:0] m_rdata_o[NUM_MASTERS],
    output logic [           1:0] m_err_o
);

  logic                  serial_sdata;
  logic                  serial_sclk;
  logic                  serial_svalid;
  logic                  serial_sready;
  logic                  serial_resp_data;
  logic                  serial_resp_clk;
  logic                  serial_resp_valid;

  logic [           1:0] master_sdata;
  logic [           1:0] master_sclk;
  logic [           1:0] master_svalid;

  logic                  master_sel;
  logic                  frame_active;

  logic                  slave_valid;
  logic [ADDR_WIDTH-1:0] slave_addr;
  logic [DATA_WIDTH-1:0] slave_wdata;
  logic                  slave_we;
  logic                  slave_ready;
  logic [DATA_WIDTH-1:0] slave_rdata;
  logic                  slave_err;

  logic [NUM_SLAVES-1:0] slave_sel;
  logic [NUM_SLAVES-1:0] slave_valid_dec;
  logic [ADDR_WIDTH-1:0] slave_addr_dec;
  logic [DATA_WIDTH-1:0] slave_wdata_dec;
  logic                  slave_we_dec;
  logic [NUM_SLAVES-1:0] slave_ready_arr;
  logic [DATA_WIDTH-1:0] slave_rdata_arr   [NUM_SLAVES];
  logic [NUM_SLAVES-1:0] slave_err_arr;

  logic                  split_pending;
  logic [           1:0] split_owner;

  assign frame_active = master_svalid[0] | master_svalid[1];

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

  serial_arbiter i_arbiter (
      .clk_i          (clk_i),
      .rst_ni         (rst_ni),
      .req_i          (m_req_i),
      .gnt_o          (m_gnt_o),
      .frame_active_i (frame_active),
      .msel_o         (master_sel),
      .split_pending_o(split_pending),
      .split_owner_o  (split_owner)
  );

  assign serial_sdata  = master_sel ? master_sdata[1] : master_sdata[0];
  assign serial_sclk   = master_sel ? master_sclk[1] : master_sclk[0];
  assign serial_svalid = master_sel ? master_svalid[1] : master_svalid[0];

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

  slave_mem #(
      .MEM_SIZE(SLAVE0_SIZE)
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
      .split_start_i(1'b0),
      .split_ready_o()
  );

  slave_mem #(
      .MEM_SIZE(SLAVE1_SIZE)
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
      .split_ready_o()
  );

  slave_mem #(
      .MEM_SIZE(SLAVE2_SIZE)
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
      .split_ready_o()
  );

  // Debug: Monitor response wire signals
  always @(posedge clk_i) begin
    if (serial_resp_valid) begin
      $display("[TOP WIRE %t] serial_resp_valid=1, serial_resp_data=%b, serial_resp_clk=%b", $time,
               serial_resp_data, serial_resp_clk);
    end
  end

endmodule
