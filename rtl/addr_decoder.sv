// =============================================================================
// addr_decoder.sv - Address Decoder for Bit-Serial Bus System
// =============================================================================
// Description:
//   Combinational address decoder that routes transactions from the serial bus
//   to one of three memory slaves based on address. Generates slave select
//   signals and routes read data back to the bus. Detects invalid addresses
//   and generates error responses.
//
// Memory Map:
//   Slave 0: 0x0000 - 0x0FFF (4KB, split-capable)
//   Slave 1: 0x1000 - 0x1FFF (4KB)
//   Slave 2: 0x2000 - 0x27FF (2KB)
//   Invalid: 0x2800 - 0x3FFF (generates error)
//
// I/O Definitions:
//   Inputs:
//     valid_i         - Transaction valid from serial-to-parallel adapter
//     addr_i[13:0]    - Global address from decoded frame
//     wdata_i[7:0]    - Write data from decoded frame
//     we_i            - Write enable (1=write, 0=read)
//     slave_ready_i[2:0] - Ready signals from each slave
//     slave_rdata_i[2:0][7:0] - Read data array from each slave
//     slave_err_i[2:0] - Error signals from each slave
//
//   Outputs:
//     ready_o         - Ready signal to serial-to-parallel adapter
//     rdata_o[7:0]    - Read data to serial-to-parallel adapter
//     err_o           - Error signal (invalid address or slave error)
//     slave_sel_o[2:0]   - Slave select (one-hot)
//     slave_valid_o[2:0] - Valid signal for each slave
//     slave_addr_o[13:0] - Local address (offset within slave)
//     slave_wdata_o[7:0] - Write data to slaves
//     slave_we_o         - Write enable to slaves
//
// Address Translation:
//   Global Address    -> Local Address
//   0x0000 - 0x0FFF   -> 0x000 - 0xFFF (Slave 0)
//   0x1000 - 0x1FFF   -> 0x000 - 0xFFF (Slave 1)
//   0x2000 - 0x27FF   -> 0x000 - 0x7FF (Slave 2)
//
// =============================================================================

module addr_decoder
  import bus_pkg::*;
(
    // Transaction Input Interface (from serial_to_parallel)
    input  logic                  valid_i,       // Transaction valid
    input  logic [ADDR_WIDTH-1:0] addr_i,        // Global address
    input  logic [DATA_WIDTH-1:0] wdata_i,       // Write data
    input  logic                  we_i,          // Write enable

    // Transaction Output Interface (to serial_to_parallel)
    output logic                  ready_o,       // Transaction ready
    output logic [DATA_WIDTH-1:0] rdata_o,       // Read data
    output logic                  err_o,         // Error (invalid addr or slave err)

    // Slave Interface (directly to slave modules)
    output logic [NUM_SLAVES-1:0] slave_sel_o,   // Slave select (one-hot)
    output logic [NUM_SLAVES-1:0] slave_valid_o, // Valid to each slave
    output logic [ADDR_WIDTH-1:0] slave_addr_o,  // Local address (translated)
    output logic [DATA_WIDTH-1:0] slave_wdata_o, // Write data broadcast
    output logic                  slave_we_o,    // Write enable broadcast

    // Slave Response Interface (from slave modules)
    input  logic [NUM_SLAVES-1:0] slave_ready_i,             // Ready from slaves
    input  logic [DATA_WIDTH-1:0] slave_rdata_i[NUM_SLAVES], // Read data array
    input  logic [NUM_SLAVES-1:0] slave_err_i                // Error from slaves
);

  // ---------------------------------------------------------------------------
  // Address Decode Logic
  // ---------------------------------------------------------------------------
  logic [NUM_SLAVES-1:0] addr_match;
  logic addr_valid;
  logic [1:0] selected_slave;
  logic [ADDR_WIDTH-1:0] local_addr;

  always_comb begin
    // Address range matching for each slave
    /* verilator lint_off WIDTHEXPAND */
    addr_match[0] = (addr_i < (SLAVE0_BASE + SLAVE0_SIZE));
    addr_match[1] = (addr_i >= SLAVE1_BASE) && (addr_i < (SLAVE1_BASE + SLAVE1_SIZE));
    addr_match[2] = (addr_i >= SLAVE2_BASE) && (addr_i < (SLAVE2_BASE + SLAVE2_SIZE));
    /* verilator lint_on WIDTHEXPAND */

    // Valid if any slave matches
    addr_valid = |addr_match;

    // Priority encode selected slave (should be one-hot anyway)
    selected_slave = 2'd0;
    if (addr_match[0]) selected_slave = 2'd0;
    else if (addr_match[1]) selected_slave = 2'd1;
    else if (addr_match[2]) selected_slave = 2'd2;

    // ---------------------------------------------------------------------------
    // Address Translation (Global -> Local)
    // ---------------------------------------------------------------------------
    // Convert global address to local offset for selected slave
    /* verilator lint_off WIDTHTRUNC */
    /* verilator lint_off WIDTHEXPAND */
    if (addr_match[0]) begin
      local_addr = addr_i - SLAVE0_BASE;
    end else if (addr_match[1]) begin
      local_addr = addr_i - SLAVE1_BASE;
    end else if (addr_match[2]) begin
      local_addr = addr_i - SLAVE2_BASE;
    end else begin
      local_addr = addr_i;  // Invalid address, pass through
    end
    /* verilator lint_on WIDTHEXPAND */
    /* verilator lint_on WIDTHTRUNC */

    // ---------------------------------------------------------------------------
    // Output Signal Generation
    // ---------------------------------------------------------------------------
    // Slave select and valid signals
    slave_sel_o = addr_match;
    slave_valid_o = valid_i ? addr_match : '0;
    slave_addr_o = local_addr;
    slave_wdata_o = wdata_i;
    slave_we_o = we_i;

    // Response multiplexing
    if (valid_i && !addr_valid) begin
      // Invalid address: generate immediate error response
      ready_o = 1'b1;
      rdata_o = '0;
      err_o   = 1'b1;
      $display("[%0t] ADDR_DEC: Invalid address 0x%04x - setting err_o=1", $time, addr_i);
    end else begin
      // Valid address: route response from selected slave
      ready_o = slave_ready_i[selected_slave];
      rdata_o = slave_rdata_i[selected_slave];
      err_o   = slave_err_i[selected_slave];
    end
  end

endmodule