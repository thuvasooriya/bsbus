`timescale 1ns / 1ps

/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHTRUNC */

// =============================================================================
// addr_decoder_tb.sv - Address Decoder Testbench
// =============================================================================
// Description:
//   Comprehensive testbench for the address decoder module. Tests address
//   decoding, slave selection, error detection, and read data routing.
//
// Test Coverage:
//   1. Reset behavior
//   2. Slave 0 address decode (0x0000 - 0x0FFF)
//   3. Slave 1 address decode (0x1000 - 0x1FFF)
//   4. Slave 2 address decode (0x2000 - 0x27FF)
//   5. Invalid address detection (>= 0x2800)
//   6. Read data routing from each slave
//   7. Write data forwarding
//   8. Boundary address testing
//   9. Address translation (global to local)
//
// =============================================================================

module addr_decoder_tb
  import bus_pkg::*;
();

  // ---------------------------------------------------------------------------
  // Testbench Signals
  // ---------------------------------------------------------------------------
  logic                  clk;
  logic                  valid;
  logic [ADDR_WIDTH-1:0] addr;
  logic [DATA_WIDTH-1:0] wdata;
  logic                  we;
  logic                  ready;
  logic [DATA_WIDTH-1:0] rdata;
  logic                  err;
  logic [NUM_SLAVES-1:0] slave_sel;
  logic [NUM_SLAVES-1:0] slave_valid;
  logic [ADDR_WIDTH-1:0] slave_addr;
  logic [DATA_WIDTH-1:0] slave_wdata;
  logic                  slave_we;
  logic [NUM_SLAVES-1:0] slave_ready;
  logic [DATA_WIDTH-1:0] slave_rdata         [NUM_SLAVES];
  logic [NUM_SLAVES-1:0] slave_err;

  int                    test_pass_count = 0;
  int                    test_fail_count = 0;

  // ---------------------------------------------------------------------------
  // DUT Instantiation
  // ---------------------------------------------------------------------------
  addr_decoder dut (
      .valid_i(valid),
      .addr_i(addr),
      .wdata_i(wdata),
      .we_i(we),
      .ready_o(ready),
      .rdata_o(rdata),
      .err_o(err),
      .slave_sel_o(slave_sel),
      .slave_valid_o(slave_valid),
      .slave_addr_o(slave_addr),
      .slave_wdata_o(slave_wdata),
      .slave_we_o(slave_we),
      .slave_ready_i(slave_ready),
      .slave_rdata_i(slave_rdata),
      .slave_err_i(slave_err)
  );

  // ---------------------------------------------------------------------------
  // Clock Generation
  // ---------------------------------------------------------------------------
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // ---------------------------------------------------------------------------
  // Test Tasks
  // ---------------------------------------------------------------------------
  
  task automatic test_reset();
    $display("\nTest 0: Reset/Initial state behavior");
    
    // Set all inputs to default state
    valid = 1'b0;
    addr = '0;
    wdata = '0;
    we = 1'b0;
    slave_ready = '0;
    for (int i = 0; i < NUM_SLAVES; i++) begin
      slave_rdata[i] = '0;
    end
    slave_err = '0;
    
    @(posedge clk);
    
    // Check outputs when not valid
    if (slave_valid === 3'b000 && slave_sel === 3'b001) begin
      $display("  PASS: Idle state - no slaves active when valid=0");
      test_pass_count++;
    end else begin
      $display("  FAIL: Idle state - slave_valid=%03b (expected 000)", slave_valid);
      test_fail_count++;
    end
  endtask

  task automatic check_decode(input logic [ADDR_WIDTH-1:0] test_addr,
                              input logic [2:0] expected_sel, input string test_name);
    logic [ADDR_WIDTH-1:0] expected_local_addr;

    @(posedge clk);
    valid = 1'b1;
    addr = test_addr;
    wdata = 8'h42;
    we = 1'b1;
    @(posedge clk);

    // Calculate expected local address based on which slave is selected
    /* verilator lint_off WIDTHEXPAND */
    /* verilator lint_off WIDTHTRUNC */
    if (expected_sel[0]) begin
      expected_local_addr = test_addr - SLAVE0_BASE;
    end else if (expected_sel[1]) begin
      expected_local_addr = test_addr - SLAVE1_BASE;
    end else if (expected_sel[2]) begin
      expected_local_addr = test_addr - SLAVE2_BASE;
    end else begin
      expected_local_addr = test_addr;
    end
    /* verilator lint_on WIDTHTRUNC */
    /* verilator lint_on WIDTHEXPAND */

    if (slave_sel !== expected_sel) begin
      $display("  FAIL: %s - slave_sel mismatch (expected=0b%03b, got=0b%03b)", test_name,
               expected_sel, slave_sel);
      test_fail_count++;
    end else if (slave_valid !== expected_sel) begin
      $display("  FAIL: %s - slave_valid mismatch (expected=0b%03b, got=0b%03b)", test_name,
               expected_sel, slave_valid);
      test_fail_count++;
    end else if (slave_addr !== expected_local_addr) begin
      $display("  FAIL: %s - slave_addr mismatch (expected=0x%0h, got=0x%0h)", test_name,
               expected_local_addr, slave_addr);
      test_fail_count++;
    end else if (slave_wdata !== 8'h42) begin
      $display("  FAIL: %s - slave_wdata mismatch", test_name);
      test_fail_count++;
    end else if (slave_we !== 1'b1) begin
      $display("  FAIL: %s - slave_we should be 1", test_name);
      test_fail_count++;
    end else begin
      $display("  PASS: %s", test_name);
      test_pass_count++;
    end

    valid = 1'b0;
    @(posedge clk);
  endtask

  task automatic check_error(input logic [ADDR_WIDTH-1:0] test_addr, input string test_name);
    @(posedge clk);
    valid = 1'b1;
    addr = test_addr;
    wdata = 8'h55;
    we = 1'b0;
    @(posedge clk);

    if (slave_sel !== 3'b000) begin
      $display("  FAIL: %s - slave_sel should be 0 for invalid address", test_name);
      test_fail_count++;
    end else if (slave_valid !== 3'b000) begin
      $display("  FAIL: %s - slave_valid should be 0 for invalid address", test_name);
      test_fail_count++;
    end else if (!err) begin
      $display("  FAIL: %s - err should be 1 for invalid address", test_name);
      test_fail_count++;
    end else if (!ready) begin
      $display("  FAIL: %s - ready should be 1 for error response", test_name);
      test_fail_count++;
    end else begin
      $display("  PASS: %s", test_name);
      test_pass_count++;
    end

    valid = 1'b0;
    @(posedge clk);
  endtask

  task automatic check_read_routing(input logic [ADDR_WIDTH-1:0] test_addr, input int slave_num,
                                    input logic [DATA_WIDTH-1:0] expected_rdata,
                                    input string test_name);
    int timeout_counter;

    @(posedge clk);
    valid = 1'b1;
    addr = test_addr;
    wdata = 8'h00;
    we = 1'b0;

    timeout_counter = 0;
    while (!slave_valid[slave_num] && timeout_counter < 100) begin
      @(posedge clk);
      timeout_counter++;
    end

    if (timeout_counter >= 100) begin
      $display("  FAIL: %s - Timeout waiting for slave_valid", test_name);
      test_fail_count++;
      valid = 1'b0;
      return;
    end

    slave_ready[slave_num] = 1'b1;
    slave_rdata[slave_num] = expected_rdata;
    @(posedge clk);

    if (rdata !== expected_rdata) begin
      $display("  FAIL: %s - rdata mismatch (expected=0x%0h, got=0x%0h)", test_name,
               expected_rdata, rdata);
      test_fail_count++;
    end else if (!ready) begin
      $display("  FAIL: %s - ready should be 1", test_name);
      test_fail_count++;
    end else begin
      $display("  PASS: %s", test_name);
      test_pass_count++;
    end

    valid = 1'b0;
    slave_ready[slave_num] = 1'b0;
    slave_rdata[slave_num] = 8'h00;
    @(posedge clk);
  endtask

  task automatic check_address_translation(
      input logic [ADDR_WIDTH-1:0] global_addr,
      input logic [ADDR_WIDTH-1:0] expected_local,
      input string test_name);
    
    @(posedge clk);
    valid = 1'b1;
    addr = global_addr;
    wdata = 8'hAA;
    we = 1'b1;
    @(posedge clk);
    
    if (slave_addr !== expected_local) begin
      $display("  FAIL: %s - Local addr mismatch (global=0x%04x, expected_local=0x%04x, got=0x%04x)",
               test_name, global_addr, expected_local, slave_addr);
      test_fail_count++;
    end else begin
      $display("  PASS: %s (global=0x%04x -> local=0x%04x)", test_name, global_addr, slave_addr);
      test_pass_count++;
    end
    
    valid = 1'b0;
    @(posedge clk);
  endtask

  task automatic check_slave_error_propagation(input int slave_num, input string test_name);
    logic [ADDR_WIDTH-1:0] test_addr;
    
    // Select address for the slave
    case (slave_num)
      0: test_addr = 14'(SLAVE0_BASE + 'h100);
      1: test_addr = 14'(SLAVE1_BASE + 'h100);
      2: test_addr = 14'(SLAVE2_BASE + 'h100);
      default: test_addr = 14'(SLAVE0_BASE);
    endcase
    
    @(posedge clk);
    valid = 1'b1;
    addr = test_addr;
    wdata = 8'h00;
    we = 1'b0;
    
    // Simulate slave error
    slave_ready[slave_num] = 1'b1;
    slave_err[slave_num] = 1'b1;
    slave_rdata[slave_num] = 8'hFF;
    
    @(posedge clk);
    
    if (err !== 1'b1) begin
      $display("  FAIL: %s - Slave error not propagated", test_name);
      test_fail_count++;
    end else if (ready !== 1'b1) begin
      $display("  FAIL: %s - Ready not asserted with slave error", test_name);
      test_fail_count++;
    end else begin
      $display("  PASS: %s", test_name);
      test_pass_count++;
    end
    
    valid = 1'b0;
    slave_ready[slave_num] = 1'b0;
    slave_err[slave_num] = 1'b0;
    @(posedge clk);
  endtask

  // ---------------------------------------------------------------------------
  // Main Test Sequence
  // ---------------------------------------------------------------------------
  initial begin
    $dumpfile("build/waves/addr_decoder_tb.fst");
    $dumpvars(0, addr_decoder_tb);

    valid = 0;
    addr = '0;
    wdata = '0;
    we = 0;
    slave_ready = '0;
    for (int i = 0; i < NUM_SLAVES; i++) begin
      slave_rdata[i] = '0;
    end
    slave_err = '0;

    repeat (5) @(posedge clk);

    $display("\n=== Address Decoder Testbench ===");

    // Test reset/initial state
    test_reset();

    // Test Slave 0 decode (0x0000 - 0x0FFF)
    $display("\nTest 1: Decode to Slave 0 (addr=0x0000)");
    check_decode(14'h0000, 3'b001, "Slave 0 base address");

    $display("\nTest 2: Decode to Slave 0 (addr=0x0FFF)");
    check_decode(14'h0FFF, 3'b001, "Slave 0 top address");

    // Test Slave 1 decode (0x1000 - 0x1FFF)
    $display("\nTest 3: Decode to Slave 1 (addr=0x1000)");
    check_decode(14'h1000, 3'b010, "Slave 1 base address");

    $display("\nTest 4: Decode to Slave 1 (addr=0x1FFF)");
    check_decode(14'h1FFF, 3'b010, "Slave 1 top address");

    // Test Slave 2 decode (0x2000 - 0x27FF)
    $display("\nTest 5: Decode to Slave 2 (addr=0x2000)");
    check_decode(14'h2000, 3'b100, "Slave 2 base address");

    $display("\nTest 6: Decode to Slave 2 (addr=0x27FF)");
    check_decode(14'h27FF, 3'b100, "Slave 2 top address");

    // Test invalid addresses
    $display("\nTest 7: Invalid address (addr=0x2800)");
    check_error(14'h2800, "Address just beyond Slave 2");

    $display("\nTest 8: Invalid address (addr=0x3FFF)");
    check_error(14'h3FFF, "High invalid address");

    // Test read data routing
    $display("\nTest 9: Read routing from Slave 0");
    check_read_routing(14'h0500, 0, 8'hAB, "Read from Slave 0 returns correct data");

    $display("\nTest 10: Read routing from Slave 1");
    check_read_routing(14'h1800, 1, 8'hCD, "Read from Slave 1 returns correct data");

    $display("\nTest 11: Read routing from Slave 2");
    check_read_routing(14'h2100, 2, 8'hEF, "Read from Slave 2 returns correct data");

    // Test address translation
    $display("\nTest 12: Address translation Slave 0");
    check_address_translation(14'h0100, 14'h0100, "Slave 0 addr translation");

    $display("\nTest 13: Address translation Slave 1");
    check_address_translation(14'h1100, 14'h0100, "Slave 1 addr translation");

    $display("\nTest 14: Address translation Slave 2");
    check_address_translation(14'h2100, 14'h0100, "Slave 2 addr translation");

    // Test slave error propagation
    $display("\nTest 15: Slave 0 error propagation");
    check_slave_error_propagation(0, "Slave 0 error to decoder");

    $display("\nTest 16: Slave 1 error propagation");
    check_slave_error_propagation(1, "Slave 1 error to decoder");

    $display("\nTest 17: Slave 2 error propagation");
    check_slave_error_propagation(2, "Slave 2 error to decoder");

    repeat (10) @(posedge clk);

    $display("\n=== Test Summary ===");
    $display("PASSED: %0d", test_pass_count);
    $display("FAILED: %0d", test_fail_count);

    if (test_fail_count == 0) begin
      $display("\nAll tests PASSED!");
    end else begin
      $display("\nSome tests FAILED!");
    end

    $finish;
  end

endmodule