`timescale 1ns / 1ps

module deserializer_tb
  import bus_pkg::*;
();

  logic          clk;
  logic          rst_n;
  logic          sdata;
  logic          sclk;
  logic          svalid;
  logic          frame_valid;
  serial_frame_t frame;
  logic          parity_err;
  int            test_pass_count = 0;
  int            test_fail_count = 0;

  deserializer dut (
      .clk_i(clk),
      .rst_ni(rst_n),
      .sdata_i(sdata),
      .sclk_i(sclk),
      .svalid_i(svalid),
      .frame_valid_o(frame_valid),
      .frame_o(frame),
      .parity_err_o(parity_err)
  );

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin
    sclk = 0;
    forever #20 sclk = ~sclk;
  end

  task automatic send_frame(input cmd_e cmd, input logic [ADDR_WIDTH-1:0] addr,
                            input logic [DATA_WIDTH-1:0] data, input logic corrupt_parity = 1'b0);
    logic [FRAME_WIDTH-1:0] frame_bits;
    logic parity_bit;
    int i;

    parity_bit = corrupt_parity ? ~calc_parity(cmd, addr, data) : calc_parity(cmd, addr, data);
    frame_bits = {1'b1, cmd, addr, data, parity_bit, 1'b0};

    svalid = 1'b1;

    for (i = FRAME_WIDTH - 1; i >= 0; i--) begin
      @(negedge sclk);
      sdata = frame_bits[i];
    end

    @(negedge sclk);
    svalid = 1'b0;
    sdata  = 1'b0;
  endtask

  task automatic wait_for_frame_valid();
    fork
      begin
        wait (frame_valid);
        @(posedge clk);
      end
      begin
        repeat (500) @(posedge clk);
        $display("    ERROR: Timeout waiting for frame_valid");
        test_fail_count++;
        $finish;
      end
    join_any
    disable fork;
  endtask

  task automatic check_frame(
      input string test_name, input cmd_e expected_cmd, input logic [ADDR_WIDTH-1:0] expected_addr,
      input logic [DATA_WIDTH-1:0] expected_data, input logic expected_parity_err);
    if (frame_valid && 
        frame.cmd == expected_cmd && 
        frame.addr == expected_addr && 
        frame.data == expected_data &&
        parity_err == expected_parity_err) begin
      $display("  PASS: %s", test_name);
      test_pass_count++;
    end else begin
      $display("  FAIL: %s", test_name);
      $display("    Expected: cmd=%b addr=%h data=%h parity_err=%b", expected_cmd, expected_addr,
               expected_data, expected_parity_err);
      $display("    Got:      cmd=%b addr=%h data=%h parity_err=%b frame_valid=%b", frame.cmd,
               frame.addr, frame.data, parity_err, frame_valid);
      test_fail_count++;
    end
  endtask

  initial begin
    $dumpfile("build/waves/deserializer_tb.fst");
    $dumpvars(0, deserializer_tb);

    rst_n  = 0;
    sdata  = 0;
    svalid = 0;

    repeat (5) @(posedge clk);
    rst_n = 1;
    repeat (5) @(posedge clk);

    $display("\n=== Deserializer Testbench ===\n");

    $display("Test 1: WRITE command (addr=0x1234, data=0xAB)");
    send_frame(CMD_WRITE, 14'h1234, 8'hAB);
    wait_for_frame_valid();
    check_frame("WRITE frame", CMD_WRITE, 14'h1234, 8'hAB, 1'b0);
    repeat (10) @(posedge clk);

    $display("\nTest 2: READ command (addr=0x2000, data=0x00)");
    send_frame(CMD_READ, 14'h2000, 8'h00);
    wait_for_frame_valid();
    check_frame("READ frame", CMD_READ, 14'h2000, 8'h00, 1'b0);
    repeat (10) @(posedge clk);

    $display("\nTest 3: Bad parity (addr=0x0100, data=0xFF)");
    send_frame(CMD_WRITE, 14'h0100, 8'hFF, 1'b1);
    wait_for_frame_valid();
    check_frame("Parity error detection", CMD_WRITE, 14'h0100, 8'hFF, 1'b1);
    repeat (10) @(posedge clk);

    $display("\nTest 4: SPLIT_START command (addr=0x0500)");
    send_frame(CMD_SPLIT_START, 14'h0500, 8'h00);
    wait_for_frame_valid();
    check_frame("SPLIT_START frame", CMD_SPLIT_START, 14'h0500, 8'h00, 1'b0);
    repeat (10) @(posedge clk);

    $display("\nTest 5: SPLIT_CONTINUE command (addr=0x0500, data=0x42)");
    send_frame(CMD_SPLIT_CONTINUE, 14'h0500, 8'h42);
    wait_for_frame_valid();
    check_frame("SPLIT_CONTINUE frame", CMD_SPLIT_CONTINUE, 14'h0500, 8'h42, 1'b0);
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
