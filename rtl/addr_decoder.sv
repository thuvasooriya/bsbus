module addr_decoder
  import bus_pkg::*;
(
    input  logic                  valid_i,
    input  logic [ADDR_WIDTH-1:0] addr_i,
    input  logic [DATA_WIDTH-1:0] wdata_i,
    input  logic                  we_i,
    output logic                  ready_o,
    output logic [DATA_WIDTH-1:0] rdata_o,
    output logic                  err_o,

    output logic [NUM_SLAVES-1:0] slave_sel_o,
    output logic [NUM_SLAVES-1:0] slave_valid_o,
    output logic [ADDR_WIDTH-1:0] slave_addr_o,
    output logic [DATA_WIDTH-1:0] slave_wdata_o,
    output logic                  slave_we_o,
    input  logic [NUM_SLAVES-1:0] slave_ready_i,
    input  logic [DATA_WIDTH-1:0] slave_rdata_i[NUM_SLAVES],
    input  logic [NUM_SLAVES-1:0] slave_err_i
);

  logic [NUM_SLAVES-1:0] addr_match;
  logic addr_valid;
  logic [1:0] selected_slave;
  logic [ADDR_WIDTH-1:0] local_addr;

  always_comb begin
    /* verilator lint_off WIDTHEXPAND */
    addr_match[0] = (addr_i < (SLAVE0_BASE + SLAVE0_SIZE));
    addr_match[1] = (addr_i >= SLAVE1_BASE) && (addr_i < (SLAVE1_BASE + SLAVE1_SIZE));
    addr_match[2] = (addr_i >= SLAVE2_BASE) && (addr_i < (SLAVE2_BASE + SLAVE2_SIZE));
    /* verilator lint_on WIDTHEXPAND */

    addr_valid = |addr_match;

    selected_slave = 2'd0;
    if (addr_match[0]) selected_slave = 2'd0;
    else if (addr_match[1]) selected_slave = 2'd1;
    else if (addr_match[2]) selected_slave = 2'd2;

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
      local_addr = addr_i;
    end
    /* verilator lint_on WIDTHEXPAND */
    /* verilator lint_on WIDTHTRUNC */

    slave_sel_o = addr_match;
    slave_valid_o = valid_i ? addr_match : '0;
    slave_addr_o = local_addr;
    slave_wdata_o = wdata_i;
    slave_we_o = we_i;

    if (valid_i && !addr_valid) begin
      ready_o = 1'b1;
      rdata_o = '0;
      err_o   = 1'b1;
      $display("[%0t] ADDR_DEC: Invalid address 0x%04x - setting err_o=1", $time, addr_i);
    end else begin
      ready_o = slave_ready_i[selected_slave];
      rdata_o = slave_rdata_i[selected_slave];
      err_o   = slave_err_i[selected_slave];
    end
  end

endmodule
