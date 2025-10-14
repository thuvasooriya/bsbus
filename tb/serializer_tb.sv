module serializer_tb
  import bus_pkg::*;
();

  logic          clk;
  logic          rst_n;
  logic          start;
  serial_frame_t frame;
  logic          busy;
  logic          done;
  logic          sdata;
  logic          sclk;

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

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin
    rst_n = 0;
    start = 0;
    frame = '0;

    repeat (5) @(posedge clk);
    rst_n = 1;
    @(posedge clk);

    $display("[%0t] Starting serializer test", $time);

    frame.start = 1'b1;
    frame.cmd = CMD_WRITE;
    frame.addr = 14'h1234;
    frame.data = 8'hAB;
    frame.parity = calc_parity(CMD_WRITE, 14'h1234, 8'hAB);
    frame.stop = 1'b1;

    start = 1'b1;
    @(posedge clk);
    start = 1'b0;

    $display("[%0t] Frame loaded: START=%b CMD=%b ADDR=%h DATA=%h PARITY=%b STOP=%b", $time,
             frame.start, frame.cmd, frame.addr, frame.data, frame.parity, frame.stop);

    wait (done);
    @(posedge clk);
    $display("[%0t] Serialization complete", $time);

    repeat (10) @(posedge clk);

    frame.start = 1'b1;
    frame.cmd = CMD_READ;
    frame.addr = 14'h0100;
    frame.data = 8'h00;
    frame.parity = calc_parity(CMD_READ, 14'h0100, 8'h00);
    frame.stop = 1'b1;

    start = 1'b1;
    @(posedge clk);
    start = 1'b0;

    $display("[%0t] Frame loaded: START=%b CMD=%b ADDR=%h DATA=%h PARITY=%b STOP=%b", $time,
             frame.start, frame.cmd, frame.addr, frame.data, frame.parity, frame.stop);

    wait (done);
    @(posedge clk);
    $display("[%0t] Serialization complete", $time);

    repeat (10) @(posedge clk);
    $display("[%0t] Test completed successfully", $time);
    $finish;
  end

  initial begin
    $dumpfile("build/waves/serializer_tb.fst");
    $dumpvars(0, serializer_tb);
  end

endmodule
