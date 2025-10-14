`timescale 1ns / 1ps

module serial_arbiter_tb
  import bus_pkg::*;
();

  logic       clk;
  logic       rst_n;
  logic [1:0] req;
  logic [1:0] gnt;
  logic       frame_active;
  logic       msel;
  logic       split_pending;
  logic [1:0] split_owner;

  int         test_pass_count = 0;
  int         test_fail_count = 0;

  serial_arbiter dut (
      .clk_i(clk),
      .rst_ni(rst_n),
      .req_i(req),
      .gnt_o(gnt),
      .frame_active_i(frame_active),
      .msel_o(msel),
      .split_pending_o(split_pending),
      .split_owner_o(split_owner)
  );

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  task automatic wait_cycles(input int cycles);
    repeat (cycles) @(posedge clk);
  endtask

  task automatic check_grant(input logic [1:0] expected_gnt, input logic expected_msel,
                             input string test_name);
    #1;  // Small delay to let combinational logic settle after clock edge
    if (gnt !== expected_gnt) begin
      $display("  FAIL: %s - gnt mismatch (expected=0b%02b, got=0b%02b)", test_name, expected_gnt,
               gnt);
      test_fail_count++;
    end else if (msel !== expected_msel) begin
      $display("  FAIL: %s - msel mismatch (expected=%b, got=%b)", test_name, expected_msel, msel);
      test_fail_count++;
    end else begin
      $display("  PASS: %s", test_name);
      test_pass_count++;
    end
  endtask

  task automatic test_single_master0();
    $display("\nTest 1: Single master 0 request");
    req = 2'b00;
    frame_active = 1'b0;
    wait_cycles(2);

    req = 2'b01;
    wait_cycles(1);
    check_grant(2'b01, 1'b0, "Master 0 gets grant");

    frame_active = 1'b1;
    wait_cycles(3);
    check_grant(2'b01, 1'b0, "Master 0 keeps grant during frame");

    frame_active = 1'b0;
    wait_cycles(1);
    check_grant(2'b01, 1'b0, "Master 0 keeps grant after frame (req still high)");

    req = 2'b00;
    wait_cycles(1);
    check_grant(2'b00, 1'b0, "Grant released when req goes low");
  endtask

  task automatic test_single_master1();
    $display("\nTest 2: Single master 1 request");
    req = 2'b00;
    frame_active = 1'b0;
    wait_cycles(2);

    req = 2'b10;
    wait_cycles(1);
    check_grant(2'b10, 1'b1, "Master 1 gets grant");

    frame_active = 1'b1;
    wait_cycles(3);
    check_grant(2'b10, 1'b1, "Master 1 keeps grant during frame");

    frame_active = 1'b0;
    wait_cycles(1);
    check_grant(2'b10, 1'b1, "Master 1 keeps grant after frame (req still high)");

    req = 2'b00;
    wait_cycles(1);
    check_grant(2'b00, 1'b0, "Grant released when req goes low");
  endtask

  task automatic test_priority();
    $display("\nTest 3: Priority arbitration (both masters request)");
    req = 2'b00;
    frame_active = 1'b0;
    wait_cycles(2);

    req = 2'b11;
    wait_cycles(1);
    check_grant(2'b01, 1'b0, "Master 0 wins (higher priority)");

    frame_active = 1'b1;
    wait_cycles(3);
    check_grant(2'b01, 1'b0, "Master 0 keeps grant during frame");

    frame_active = 1'b0;
    wait_cycles(1);
    check_grant(2'b01, 1'b0, "Master 0 still has grant");

    req = 2'b10;
    wait_cycles(2);  // Need 2 cycles: MASTER0->IDLE->MASTER1
    check_grant(2'b10, 1'b1, "Master 1 gets grant after Master 0 releases");

    req = 2'b00;
    wait_cycles(1);
  endtask

  task automatic test_frame_atomic();
    $display("\nTest 4: Frame-atomic arbitration");
    req = 2'b00;
    frame_active = 1'b0;
    wait_cycles(2);

    req = 2'b01;
    wait_cycles(1);
    check_grant(2'b01, 1'b0, "Master 0 gets grant");

    frame_active = 1'b1;
    wait_cycles(1);

    req = 2'b11;
    wait_cycles(3);
    check_grant(2'b01, 1'b0, "Master 0 keeps grant even though Master 1 requests");

    frame_active = 1'b0;
    wait_cycles(1);

    req = 2'b10;
    wait_cycles(1);
    check_grant(2'b10, 1'b1, "Master 1 gets grant after frame completes");

    req = 2'b00;
    wait_cycles(1);
  endtask

  task automatic test_back_to_back();
    $display("\nTest 5: Back-to-back transactions");
    req = 2'b00;
    frame_active = 1'b0;
    wait_cycles(2);

    req = 2'b01;
    wait_cycles(1);
    check_grant(2'b01, 1'b0, "Master 0 first transaction");

    frame_active = 1'b1;
    wait_cycles(2);
    frame_active = 1'b0;
    wait_cycles(1);

    frame_active = 1'b1;
    wait_cycles(2);
    check_grant(2'b01, 1'b0, "Master 0 second transaction (back-to-back)");
    frame_active = 1'b0;
    wait_cycles(1);

    req = 2'b00;
    wait_cycles(1);
    check_grant(2'b00, 1'b0, "All grants released");
  endtask

  task automatic test_alternating();
    $display("\nTest 6: Alternating master access");
    req = 2'b00;
    frame_active = 1'b0;
    wait_cycles(2);

    req = 2'b01;
    wait_cycles(1);
    frame_active = 1'b1;
    wait_cycles(2);
    frame_active = 1'b0;
    req = 2'b00;
    wait_cycles(1);
    check_grant(2'b00, 1'b0, "Master 0 transaction complete");

    req = 2'b10;
    wait_cycles(1);
    frame_active = 1'b1;
    wait_cycles(2);
    frame_active = 1'b0;
    req = 2'b00;
    wait_cycles(1);
    check_grant(2'b00, 1'b0, "Master 1 transaction complete");

    req = 2'b01;
    wait_cycles(1);
    check_grant(2'b01, 1'b0, "Master 0 gets access again");

    req = 2'b00;
    wait_cycles(1);
  endtask

  initial begin
    $dumpfile("build/waves/serial_arbiter_tb.fst");
    $dumpvars(0, serial_arbiter_tb);

    rst_n = 0;
    req = 2'b00;
    frame_active = 0;

    repeat (5) @(posedge clk);
    rst_n = 1;
    repeat (2) @(posedge clk);

    $display("\n=== Serial Arbiter Testbench ===");

    test_single_master0();
    test_single_master1();
    test_priority();
    test_frame_atomic();
    test_back_to_back();
    test_alternating();

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
