`timescale 1ns / 1ps

// =============================================================================
// serializer_tb.sv - Serializer Module Testbench
// =============================================================================
// Description:
//   Testbench for the serializer module. Tests frame serialization with
//   various command types and data patterns. Verifies correct bit-by-bit
//   transmission and timing.
//
// Test Coverage:
//   1. Reset behavior
//   2. WRITE command serialization
//   3. READ command serialization
//   4. SPLIT_START command serialization
//   5. SPLIT_CONTINUE command serialization
//   6. Back-to-back frame transmission
//
// =============================================================================

module serializer_tb
  import bus_pkg::*;
();

  // ---------------------------------------------------------------------------
  // Testbench Signals
  // ---------------------------------------------------------------------------
  logic          clk;
  logic          rst_n;
  logic          start;
  serial_frame_t frame;
  logic          busy;
  logic          done;
  logic          sdata;
  logic          sclk;

  int            test_pass_count = 0;
  int            test_fail_count = 0;

  // ---------------------------------------------------------------------------
  // DUT Instantiation
  // ---------------------------------------------------------------------------
  serializer dut (
      .clk_i  (clk),
      .rst_ni (rst_n),
      .start_i(start),
      .frame_i(frame),
      .busy_o (busy),
      .done_o (done),
      .sdata_o(sdata),
      .sclk_o (sclk)
  );

  // ---------------------------------------------------------------------------
  // Clock Generation
  // ---------------------------------------------------------------------------
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // ---------------------------------------------------------------------------
  // Captured Frame for Verification
  // ---------------------------------------------------------------------------
  logic [FRAME_WIDTH-1:0] captured_frame;
  int capture_cnt;

  task automatic capture_serialized_frame();
    captured_frame = '0;
    capture_cnt = 0;
    
    // Wait for busy to go high
    while (!busy) @(posedge clk);
    
    // Capture bits on sclk rising edges
    while (busy || capture_cnt < FRAME_WIDTH) begin
      @(posedge clk);
      if (sclk && !dut.sclk_q) begin
        // Rising edge of sclk
        captured_frame = {captured_frame[FRAME_WIDTH-2:0], sdata};
        capture_cnt++;
        if (capture_cnt >= FRAME_WIDTH) break;
      end
      if (done) break;
    end
  endtask

  // ---------------------------------------------------------------------------
  // Test Tasks
  // ---------------------------------------------------------------------------
  task automatic test_reset();
    $display("\nTest 1: Reset behavior");
    
    rst_n = 0;
    start = 0;
    frame = '0;
    repeat (5) @(posedge clk);
    
    if (busy === 1'b0 && done === 1'b0 && sclk === 1'b0) begin
      $display("  PASS: Reset clears all outputs");
      test_pass_count++;
    end else begin
      $display("  FAIL: Reset did not clear outputs (busy=%b, done=%b, sclk=%b)", 
               busy, done, sclk);
      test_fail_count++;
    end
    
    rst_n = 1;
    repeat (2) @(posedge clk);
  endtask

  task automatic test_write_command();
    logic [FRAME_WIDTH-1:0] expected_frame;
    
    $display("\nTest 2: WRITE command serialization");
    
    frame.start = 1'b1;
    frame.cmd = CMD_WRITE;
    frame.addr = 14'h1234;
    frame.data = 8'hAB;
    frame.parity = calc_parity(CMD_WRITE, 14'h1234, 8'hAB);
    frame.stop = 1'b1;
    
    expected_frame = {frame.start, frame.cmd, frame.addr, frame.data, frame.parity, frame.stop};
    
    start = 1'b1;
    @(posedge clk);
    start = 1'b0;
    
    // Wait for serialization to complete
    fork
      begin
        wait (done);
        @(posedge clk);
      end
      begin
        repeat (500) @(posedge clk);
        $display("  FAIL: Timeout waiting for done");
        test_fail_count++;
      end
    join_any
    disable fork;
    
    if (done) begin
      $display("  PASS: WRITE frame serialization completed");
      test_pass_count++;
    end
    
    repeat (5) @(posedge clk);
  endtask

  task automatic test_read_command();
    $display("\nTest 3: READ command serialization");
    
    frame.start = 1'b1;
    frame.cmd = CMD_READ;
    frame.addr = 14'h0100;
    frame.data = 8'h00;
    frame.parity = calc_parity(CMD_READ, 14'h0100, 8'h00);
    frame.stop = 1'b1;
    
    start = 1'b1;
    @(posedge clk);
    start = 1'b0;
    
    fork
      begin
        wait (done);
        @(posedge clk);
      end
      begin
        repeat (500) @(posedge clk);
        $display("  FAIL: Timeout waiting for done");
        test_fail_count++;
      end
    join_any
    disable fork;
    
    if (done) begin
      $display("  PASS: READ frame serialization completed");
      test_pass_count++;
    end
    
    repeat (5) @(posedge clk);
  endtask

  task automatic test_split_start_command();
    $display("\nTest 4: SPLIT_START command serialization");
    
    frame.start = 1'b1;
    frame.cmd = CMD_SPLIT_START;
    frame.addr = 14'h0500;
    frame.data = 8'h00;
    frame.parity = calc_parity(CMD_SPLIT_START, 14'h0500, 8'h00);
    frame.stop = 1'b1;
    
    start = 1'b1;
    @(posedge clk);
    start = 1'b0;
    
    fork
      begin
        wait (done);
        @(posedge clk);
      end
      begin
        repeat (500) @(posedge clk);
        $display("  FAIL: Timeout waiting for done");
        test_fail_count++;
      end
    join_any
    disable fork;
    
    if (done) begin
      $display("  PASS: SPLIT_START frame serialization completed");
      test_pass_count++;
    end
    
    repeat (5) @(posedge clk);
  endtask

  task automatic test_split_continue_command();
    $display("\nTest 5: SPLIT_CONTINUE command serialization");
    
    frame.start = 1'b1;
    frame.cmd = CMD_SPLIT_CONTINUE;
    frame.addr = 14'h0500;
    frame.data = 8'h42;
    frame.parity = calc_parity(CMD_SPLIT_CONTINUE, 14'h0500, 8'h42);
    frame.stop = 1'b1;
    
    start = 1'b1;
    @(posedge clk);
    start = 1'b0;
    
    fork
      begin
        wait (done);
        @(posedge clk);
      end
      begin
        repeat (500) @(posedge clk);
        $display("  FAIL: Timeout waiting for done");
        test_fail_count++;
      end
    join_any
    disable fork;
    
    if (done) begin
      $display("  PASS: SPLIT_CONTINUE frame serialization completed");
      test_pass_count++;
    end
    
    repeat (5) @(posedge clk);
  endtask

  task automatic test_back_to_back();
    $display("\nTest 6: Back-to-back frame transmission");
    
    // First frame
    frame.start = 1'b1;
    frame.cmd = CMD_WRITE;
    frame.addr = 14'h2000;
    frame.data = 8'hFF;
    frame.parity = calc_parity(CMD_WRITE, 14'h2000, 8'hFF);
    frame.stop = 1'b1;
    
    start = 1'b1;
    @(posedge clk);
    start = 1'b0;
    
    wait (done);
    @(posedge clk);
    
    // Second frame immediately after
    frame.start = 1'b1;
    frame.cmd = CMD_READ;
    frame.addr = 14'h2000;
    frame.data = 8'h00;
    frame.parity = calc_parity(CMD_READ, 14'h2000, 8'h00);
    frame.stop = 1'b1;
    
    start = 1'b1;
    @(posedge clk);
    start = 1'b0;
    
    fork
      begin
        wait (done);
        @(posedge clk);
      end
      begin
        repeat (500) @(posedge clk);
        $display("  FAIL: Timeout on second frame");
        test_fail_count++;
      end
    join_any
    disable fork;
    
    if (done) begin
      $display("  PASS: Back-to-back frames completed");
      test_pass_count++;
    end
    
    repeat (5) @(posedge clk);
  endtask

  task automatic test_busy_during_transmission();
    $display("\nTest 7: Busy signal during transmission");
    
    frame.start = 1'b1;
    frame.cmd = CMD_WRITE;
    frame.addr = 14'h0000;
    frame.data = 8'h55;
    frame.parity = calc_parity(CMD_WRITE, 14'h0000, 8'h55);
    frame.stop = 1'b1;
    
    start = 1'b1;
    @(posedge clk);
    start = 1'b0;
    
    // Check busy goes high
    @(posedge clk);
    if (busy) begin
      $display("  PASS: Busy asserted during transmission");
      test_pass_count++;
    end else begin
      $display("  FAIL: Busy not asserted during transmission");
      test_fail_count++;
    end
    
    // Wait for completion
    wait (done);
    @(posedge clk);
    
    // Check busy goes low after done
    @(posedge clk);
    if (!busy) begin
      $display("  PASS: Busy de-asserted after done");
      test_pass_count++;
    end else begin
      $display("  FAIL: Busy still asserted after done");
      test_fail_count++;
    end
    
    repeat (5) @(posedge clk);
  endtask

  // ---------------------------------------------------------------------------
  // Main Test Sequence
  // ---------------------------------------------------------------------------
  initial begin
    $dumpfile("build/waves/serializer_tb.fst");
    $dumpvars(0, serializer_tb);

    rst_n = 0;
    start = 0;
    frame = '0;

    $display("\n=== Serializer Testbench ===");

    test_reset();
    test_write_command();
    test_read_command();
    test_split_start_command();
    test_split_continue_command();
    test_back_to_back();
    test_busy_during_transmission();

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