`timescale 1ns / 1ps

// =============================================================================
// serial_arbiter_tb.sv - Serial Arbiter Testbench
// =============================================================================
// Description:
//   Comprehensive testbench for the serial arbiter module. Tests priority
//   arbitration, frame-atomic grants, and split transaction handling.
//
// Test Coverage:
//   1. Reset behavior
//   2. Single master 0 request
//   3. Single master 1 request
//   4. Priority arbitration (M0 > M1)
//   5. Frame-atomic arbitration
//   6. Back-to-back transactions
//   7. Alternating master access
//   8. Split transaction start (M0)
//   9. Split transaction start (M1)
//   10. Split with priority
//
// =============================================================================

module serial_arbiter_tb
  import bus_pkg::*;
();

  // ---------------------------------------------------------------------------
  // Testbench Signals
  // ---------------------------------------------------------------------------
  logic       clk;
  logic       rst_n;
  logic [1:0] req;
  logic [1:0] gnt;
  logic       frame_active;
  logic       split_start;
  logic       split_done;
  logic       msel;
  logic       split_pending;
  logic [1:0] split_owner;

  int         test_pass_count = 0;
  int         test_fail_count = 0;

  // ---------------------------------------------------------------------------
  // DUT Instantiation
  // ---------------------------------------------------------------------------
  serial_arbiter dut (
      .clk_i(clk),
      .rst_ni(rst_n),
      .req_i(req),
      .gnt_o(gnt),
      .frame_active_i(frame_active),
      .split_start_i(split_start),
      .split_done_i(split_done),
      .msel_o(msel),
      .split_pending_o(split_pending),
      .split_owner_o(split_owner)
  );

  // ---------------------------------------------------------------------------
  // Clock Generation
  // ---------------------------------------------------------------------------
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // ---------------------------------------------------------------------------
  // Helper Tasks
  // ---------------------------------------------------------------------------
  task automatic wait_cycles(input int cycles);
    repeat (cycles) @(posedge clk);
  endtask

  task automatic reset_inputs();
    req = 2'b00;
    frame_active = 1'b0;
    split_start = 1'b0;
    split_done = 1'b0;
  endtask

  task automatic do_reset();
    rst_n = 1'b0;
    reset_inputs();
    wait_cycles(5);
    rst_n = 1'b1;
    wait_cycles(2);
  endtask

  task automatic check_grant(input logic [1:0] expected_gnt, input logic expected_msel,
                             input string test_name);
    #1;
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

  task automatic check_split_state(input logic expected_pending, input logic [1:0] expected_owner,
                                   input string test_name);
    #1;
    if (split_pending !== expected_pending) begin
      $display("  FAIL: %s - split_pending mismatch (expected=%b, got=%b)", test_name,
               expected_pending, split_pending);
      test_fail_count++;
    end else if (expected_pending && split_owner !== expected_owner) begin
      $display("  FAIL: %s - split_owner mismatch (expected=0b%02b, got=0b%02b)", test_name,
               expected_owner, split_owner);
      test_fail_count++;
    end else begin
      $display("  PASS: %s", test_name);
      test_pass_count++;
    end
  endtask

  // ---------------------------------------------------------------------------
  // Test Tasks
  // ---------------------------------------------------------------------------
  task automatic test_reset();
    $display("\nTest 0: Reset behavior");

    rst_n = 1'b0;
    reset_inputs();
    wait_cycles(5);

    if (gnt === 2'b00 && msel === 1'b0 && split_pending === 1'b0) begin
      $display("  PASS: Reset clears all outputs");
      test_pass_count++;
    end else begin
      $display("  FAIL: Reset did not clear outputs (gnt=%b, msel=%b, split_pending=%b)",
               gnt, msel, split_pending);
      test_fail_count++;
    end

    rst_n = 1'b1;
    wait_cycles(2);
  endtask

  task automatic test_single_master0();
    $display("\nTest 1: Single master 0 request");
    do_reset();

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
    do_reset();

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
    do_reset();

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
    wait_cycles(2);
    check_grant(2'b10, 1'b1, "Master 1 gets grant after Master 0 releases");

    req = 2'b00;
    wait_cycles(1);
  endtask

  task automatic test_frame_atomic();
    $display("\nTest 4: Frame-atomic arbitration");
    do_reset();

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
    do_reset();

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
    do_reset();

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

  task automatic test_split_transaction_m0();
    $display("\nTest 7: Split transaction initiated by Master 0");
    do_reset();

    // Master 0 requests and gets grant
    req = 2'b01;
    wait_cycles(1);
    check_grant(2'b01, 1'b0, "Master 0 gets grant before split");

    // Start frame transmission
    frame_active = 1'b1;
    wait_cycles(2);

    // Slave indicates split
    split_start = 1'b1;
    wait_cycles(1);
    split_start = 1'b0;
    wait_cycles(1);
    check_split_state(1'b1, 2'b01, "Split pending with M0 as owner");

    // Frame completes, master releases req temporarily
    frame_active = 1'b0;
    wait_cycles(1);

    // Master 0 should still have grant due to split (stays in SPLIT state)
    check_grant(2'b01, 1'b0, "Master 0 keeps grant during split");

    // Slave completes split, master re-requests
    // Hold split_done for 2 cycles to ensure it's captured at posedge
    @(posedge clk);
    split_done = 1'b1;
    @(posedge clk);
    @(posedge clk);
    split_done = 1'b0;
    wait_cycles(1);
    check_split_state(1'b0, 2'b00, "Split complete - pending cleared");

    // Release request to complete
    req = 2'b00;
    wait_cycles(2);
    check_grant(2'b00, 1'b0, "Transaction complete after split");
  endtask

  task automatic test_split_transaction_m1();
    $display("\nTest 8: Split transaction initiated by Master 1");
    do_reset();

    // Master 1 requests and gets grant
    req = 2'b10;
    wait_cycles(1);
    check_grant(2'b10, 1'b1, "Master 1 gets grant before split");

    // Start frame transmission
    frame_active = 1'b1;
    wait_cycles(2);

    // Slave indicates split
    split_start = 1'b1;
    wait_cycles(1);
    split_start = 1'b0;
    wait_cycles(1);
    check_split_state(1'b1, 2'b10, "Split pending with M1 as owner");

    // Frame completes
    frame_active = 1'b0;
    wait_cycles(1);

    // Master 1 should still have grant due to split
    check_grant(2'b10, 1'b1, "Master 1 keeps grant during split");

    // Slave completes split - hold for 2 cycles
    @(posedge clk);
    split_done = 1'b1;
    @(posedge clk);
    @(posedge clk);
    split_done = 1'b0;
    wait_cycles(1);
    check_split_state(1'b0, 2'b00, "Split complete - pending cleared");

    // Release to complete
    req = 2'b00;
    wait_cycles(2);
    check_grant(2'b00, 1'b0, "Transaction complete after split");
  endtask

  task automatic test_split_priority();
    $display("\nTest 9: Split owner has priority over other master");
    do_reset();

    // Master 1 initiates split transaction
    req = 2'b10;
    wait_cycles(1);
    frame_active = 1'b1;
    wait_cycles(1);
    split_start = 1'b1;
    wait_cycles(1);
    split_start = 1'b0;
    frame_active = 1'b0;
    wait_cycles(1);
    check_split_state(1'b1, 2'b10, "Split pending for M1");

    // Both masters request - split owner (M1) should win
    req = 2'b11;
    wait_cycles(1);
    check_grant(2'b10, 1'b1, "Split owner M1 wins over M0");

    // Complete split - hold for 2 cycles
    @(posedge clk);
    split_done = 1'b1;
    @(posedge clk);
    @(posedge clk);
    split_done = 1'b0;
    req = 2'b00;
    wait_cycles(2);

    // Now M0 should win with priority
    req = 2'b11;
    wait_cycles(1);
    check_grant(2'b01, 1'b0, "After split, M0 wins with normal priority");

    req = 2'b00;
    wait_cycles(1);
  endtask

  task automatic test_split_during_m0_with_m1_waiting();
    $display("\nTest 10: Split during M0 transaction with M1 waiting");
    do_reset();

    // M0 starts transaction
    req = 2'b01;
    wait_cycles(1);
    check_grant(2'b01, 1'b0, "M0 gets initial grant");

    // M1 also requests while M0 is active
    req = 2'b11;
    frame_active = 1'b1;
    wait_cycles(1);

    // Split occurs
    split_start = 1'b1;
    wait_cycles(1);
    split_start = 1'b0;
    wait_cycles(1);
    check_split_state(1'b1, 2'b01, "Split owned by M0 even with M1 waiting");

    // Frame ends
    frame_active = 1'b0;
    wait_cycles(1);

    // M0 should keep grant during split (M1 is waiting but split owner takes priority)
    check_grant(2'b01, 1'b0, "M0 keeps grant during split despite M1 waiting");

    // Complete split - hold for 2 cycles
    @(posedge clk);
    split_done = 1'b1;
    @(posedge clk);
    @(posedge clk);
    split_done = 1'b0;

    // M0 releases, only M1 requesting
    req = 2'b10;
    wait_cycles(2);
    check_grant(2'b10, 1'b1, "M1 gets grant after M0 split completes");

    req = 2'b00;
    wait_cycles(1);
  endtask

  // ---------------------------------------------------------------------------
  // Main Test Sequence
  // ---------------------------------------------------------------------------
  initial begin
    $dumpfile("build/waves/serial_arbiter_tb.fst");
    $dumpvars(0, serial_arbiter_tb);

    rst_n = 0;
    reset_inputs();

    $display("\n=== Serial Arbiter Testbench ===");

    test_reset();
    test_single_master0();
    test_single_master1();
    test_priority();
    test_frame_atomic();
    test_back_to_back();
    test_alternating();
    test_split_transaction_m0();
    test_split_transaction_m1();
    test_split_priority();
    test_split_during_m0_with_m1_waiting();

    wait_cycles(10);

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
