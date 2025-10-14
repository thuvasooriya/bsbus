`timescale 1ns / 1ps

module serial_to_parallel_tb
  import bus_pkg::*;
();

  logic                  clk;
  logic                  rst_n;
  logic                  sdata;
  logic                  sclk;
  logic                  svalid;
  logic                  sready;
  logic                  sdata_out;
  logic                  sclk_resp;
  logic                  svalid_resp;
  logic                  valid;
  logic [ADDR_WIDTH-1:0] addr;
  logic [DATA_WIDTH-1:0] wdata;
  logic                  we;
  logic                  ready;
  logic [DATA_WIDTH-1:0] rdata;
  logic                  err;

  int                    test_pass_count = 0;
  int                    test_fail_count = 0;

  serial_to_parallel dut (
      .clk_i(clk),
      .rst_ni(rst_n),
      .sdata_i(sdata),
      .sclk_i(sclk),
      .svalid_i(svalid),
      .sready_o(sready),
      .sdata_o(sdata_out),
      .sclk_resp_o(sclk_resp),
      .svalid_resp_o(svalid_resp),
      .valid_o(valid),
      .addr_o(addr),
      .wdata_o(wdata),
      .we_o(we),
      .ready_i(ready),
      .rdata_i(rdata),
      .err_i(err)
  );

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin
    sclk = 0;
    forever #20 sclk = ~sclk;
  end

  task automatic send_serial_frame(input cmd_e cmd, input logic [ADDR_WIDTH-1:0] frame_addr,
                                   input logic [DATA_WIDTH-1:0] frame_data,
                                   input logic corrupt_parity = 1'b0);
    serial_frame_t frame;
    logic [FRAME_WIDTH-1:0] frame_bits;
    int i;
    int timeout_counter;

    frame.start = 1'b1;
    frame.cmd = cmd;
    frame.addr = frame_addr;
    frame.data = frame_data;
    frame.parity = calc_parity(cmd, frame_addr, frame_data);
    if (corrupt_parity) begin
      frame.parity = ~frame.parity;
    end
    frame.stop = 1'b1;

    frame_bits = {frame.start, frame.cmd, frame.addr, frame.data, frame.parity, frame.stop};

    @(posedge clk);
    svalid = 1'b1;
    timeout_counter = 0;

    for (i = FRAME_WIDTH - 1; i >= 0; i--) begin
      @(negedge sclk);
      sdata = frame_bits[i];
      timeout_counter++;
      if (timeout_counter > 1000) begin
        $error("TIMEOUT in send_serial_frame");
        return;
      end
    end

    @(negedge sclk);
    svalid = 1'b0;
    sdata  = 1'b0;

    repeat (5) @(posedge clk);
  endtask

  task automatic check_parallel_write(input logic [ADDR_WIDTH-1:0] expected_addr,
                                      input logic [DATA_WIDTH-1:0] expected_wdata,
                                      input string test_name);
    int timeout_counter;

    timeout_counter = 0;
    while (!valid && timeout_counter < 1000) begin
      @(posedge clk);
      timeout_counter++;
    end

    if (timeout_counter >= 1000) begin
      $display("  FAIL: %s - Timeout waiting for valid", test_name);
      test_fail_count++;
      return;
    end

    if (addr !== expected_addr) begin
      $display("  FAIL: %s - Address mismatch (expected=0x%0h, got=0x%0h)", test_name,
               expected_addr, addr);
      test_fail_count++;
      return;
    end

    if (wdata !== expected_wdata) begin
      $display("  FAIL: %s - Write data mismatch (expected=0x%0h, got=0x%0h)", test_name,
               expected_wdata, wdata);
      test_fail_count++;
      return;
    end

    if (we !== 1'b1) begin
      $display("  FAIL: %s - we should be high for WRITE", test_name);
      test_fail_count++;
      return;
    end

    $display("  PASS: %s", test_name);
    test_pass_count++;

    @(posedge clk);
    ready = 1'b1;
    @(posedge clk);
    ready = 1'b0;

    repeat (5) @(posedge clk);
  endtask

  task automatic check_parallel_read(input logic [ADDR_WIDTH-1:0] expected_addr,
                                     input logic [DATA_WIDTH-1:0] read_data_to_return,
                                     input string test_name);
    int timeout_counter;

    timeout_counter = 0;
    while (!valid && timeout_counter < 1000) begin
      @(posedge clk);
      timeout_counter++;
    end

    if (timeout_counter >= 1000) begin
      $display("  FAIL: %s - Timeout waiting for valid", test_name);
      test_fail_count++;
      return;
    end

    if (addr !== expected_addr) begin
      $display("  FAIL: %s - Address mismatch (expected=0x%0h, got=0x%0h)", test_name,
               expected_addr, addr);
      test_fail_count++;
      return;
    end

    if (we !== 1'b0) begin
      $display("  FAIL: %s - we should be low for READ", test_name);
      test_fail_count++;
      return;
    end

    $display("  PASS: %s", test_name);
    test_pass_count++;

    @(posedge clk);
    ready = 1'b1;
    rdata = read_data_to_return;
    @(posedge clk);
    ready = 1'b0;
    rdata = 8'h00;

    repeat (5) @(posedge clk);
  endtask

  initial begin
    $dumpfile("build/waves/serial_to_parallel_tb.fst");
    $dumpvars(0, serial_to_parallel_tb);

    rst_n = 0;
    sdata = 0;
    svalid = 0;
    ready = 0;
    rdata = '0;
    err = 0;

    repeat (5) @(posedge clk);
    rst_n = 1;
    repeat (5) @(posedge clk);

    $display("\n=== Serial-to-Parallel Testbench ===\n");

    $display("Test 1: WRITE frame reception (addr=0x1000, data=0x42)");
    fork
      send_serial_frame(CMD_WRITE, 14'h1000, 8'h42);
    join_none
    check_parallel_write(14'h1000, 8'h42, "WRITE to 0x1000");

    $display("\nTest 2: WRITE frame reception (addr=0x2500, data=0xAB)");
    fork
      send_serial_frame(CMD_WRITE, 14'h2500, 8'hAB);
    join_none
    check_parallel_write(14'h2500, 8'hAB, "WRITE to 0x2500");

    $display("\nTest 3: READ frame reception (addr=0x1800)");
    fork
      send_serial_frame(CMD_READ, 14'h1800, 8'h00);
    join_none
    check_parallel_read(14'h1800, 8'h55, "READ from 0x1800");

    $display("\nTest 4: Parity error detection");
    begin
      logic valid_asserted = 1'b0;
      int   check_cycles = 0;

      fork
        send_serial_frame(CMD_WRITE, 14'h3000, 8'hFF, 1'b1);
      join_none

      for (check_cycles = 0; check_cycles < 300; check_cycles++) begin
        @(posedge clk);
        if (valid) begin
          valid_asserted = 1'b1;
        end
      end

      if (valid_asserted) begin
        $display("  FAIL: Parity error - valid asserted with bad parity");
        test_fail_count++;
      end else begin
        $display("  PASS: Parity error - frame rejected (no parallel transaction)");
        test_pass_count++;
      end
    end

    repeat (10) @(posedge clk);

    $display("\nTest 5: SPLIT_START frame reception (addr=0x0800, data=0x77)");
    fork
      send_serial_frame(CMD_SPLIT_START, 14'h0800, 8'h77);
    join_none
    check_parallel_write(14'h0800, 8'h77, "SPLIT_START to 0x0800");

    repeat (20) @(posedge clk);

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
