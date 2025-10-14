`timescale 1ns / 1ps

/* verilator lint_off WIDTHTRUNC */

module bitserial_top_tb
  import bus_pkg::*;
();

  logic                  clk;
  logic                  rst_n;
  logic [           1:0] m_req;
  logic [ADDR_WIDTH-1:0] m_addr                 [NUM_MASTERS];
  logic [DATA_WIDTH-1:0] m_wdata                [NUM_MASTERS];
  logic [           1:0] m_we;
  logic [           1:0] m_gnt;
  logic [           1:0] m_ready;
  logic [DATA_WIDTH-1:0] m_rdata                [NUM_MASTERS];
  logic [           1:0] m_err;

  int                    test_pass_count = 0;
  int                    test_fail_count = 0;
  int                    timeout_cycles = 10000;

  bitserial_top dut (
      .clk_i    (clk),
      .rst_ni   (rst_n),
      .m_req_i  (m_req),
      .m_addr_i (m_addr),
      .m_wdata_i(m_wdata),
      .m_we_i   (m_we),
      .m_gnt_o  (m_gnt),
      .m_ready_o(m_ready),
      .m_rdata_o(m_rdata),
      .m_err_o  (m_err)
  );

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin
    $dumpfile("build/waves/bitserial_top_tb.fst");
    $dumpvars(0, bitserial_top_tb);
  end

  // Debug monitor for slave signals
  always @(posedge clk) begin
    if (dut.slave_valid && dut.slave_we) begin
      $display("  [DEBUG] WRITE: addr=0x%04x, wdata=0x%02x, valid_dec=%03b, we=%b", dut.slave_addr,
               dut.slave_wdata, dut.slave_valid_dec, dut.slave_we_dec);
    end
    if (dut.slave_valid && !dut.slave_we) begin
      $display("  [DEBUG] READ:  addr=0x%04x, valid_dec=%03b, we=%b, rdata=0x%02x", dut.slave_addr,
               dut.slave_valid_dec, dut.slave_we_dec, dut.slave_rdata);
    end

    // Monitor individual slave writes
    if (dut.i_slave_0.valid_i && dut.i_slave_0.we_i) begin
      $display(
          "  [DEBUG] Slave 0 WRITE: addr=0x%04x (local=0x%03x), wdata=0x%02x, ready=%b, addr_valid=%b, split_pend=%b",
          dut.slave_addr_dec, dut.i_slave_0.local_addr, dut.slave_wdata_dec, dut.i_slave_0.ready_o,
          dut.i_slave_0.addr_valid, dut.i_slave_0.split_pending_q);
    end
    if (dut.i_slave_1.valid_i && dut.i_slave_1.we_i) begin
      $display(
          "  [DEBUG] Slave 1 WRITE: addr=0x%04x (local=0x%03x), wdata=0x%02x, ready=%b, addr_valid=%b",
          dut.slave_addr_dec, dut.i_slave_1.local_addr, dut.slave_wdata_dec, dut.i_slave_1.ready_o,
          dut.i_slave_1.addr_valid);
    end
    if (dut.i_slave_2.valid_i && dut.i_slave_2.we_i) begin
      $display(
          "  [DEBUG] Slave 2 WRITE: addr=0x%04x (local=0x%03x), wdata=0x%02x, ready=%b, addr_valid=%b",
          dut.slave_addr_dec, dut.i_slave_2.local_addr, dut.slave_wdata_dec, dut.i_slave_2.ready_o,
          dut.i_slave_2.addr_valid);
    end

    // Monitor individual slave reads
    if (dut.i_slave_0.valid_i && !dut.i_slave_0.we_i) begin
      $display(
          "  [DEBUG] Slave 0 READ: local=0x%03x, rdata=0x%02x (mem=0x%02x), ready=%b, addr_valid=%b, split_start=%b",
          dut.i_slave_0.local_addr, dut.i_slave_0.rdata_o,
          dut.i_slave_0.mem[dut.i_slave_0.local_addr], dut.i_slave_0.ready_o,
          dut.i_slave_0.addr_valid, dut.i_slave_0.split_start_i);
    end

    // Monitor response frame generation
    if (dut.i_s2p.resp_start) begin
      $display("  [DEBUG] RESPONSE START: resp_state=%0d, ready_i=%b, resp_busy=%b, rdata=0x%02x",
               dut.i_s2p.resp_state_q, dut.i_s2p.ready_i, dut.i_s2p.resp_busy, dut.i_s2p.rdata_i);
    end
    if (dut.i_s2p.resp_busy) begin
      $display("  [DEBUG] RESP STATUS: busy=%b, state=%0d, done=%b", dut.i_s2p.resp_busy,
               dut.i_s2p.resp_state_q, dut.i_s2p.resp_done);
    end
    if (dut.i_slave_1.valid_i && !dut.i_slave_1.we_i) begin
      $display("  [DEBUG] Slave 1 READ: local=0x%03x, rdata=0x%02x (mem=0x%02x), ready=%b",
               dut.i_slave_1.local_addr, dut.i_slave_1.rdata_o,
               dut.i_slave_1.mem[dut.i_slave_1.local_addr], dut.i_slave_1.ready_o);
    end
    if (dut.i_slave_2.valid_i && !dut.i_slave_2.we_i) begin
      $display("  [DEBUG] Slave 2 READ: local=0x%03x, rdata=0x%02x (mem=0x%02x), ready=%b",
               dut.i_slave_2.local_addr, dut.i_slave_2.rdata_o,
               dut.i_slave_2.mem[dut.i_slave_2.local_addr], dut.i_slave_2.ready_o);
    end
  end

  always @(posedge clk) begin
    if (dut.serial_resp_valid) begin
      $display("  [DEBUG] @%0t RESPONSE ON BUS: sdata=%b, sclk=%b, svalid=%b", $time,
               dut.serial_resp_data, dut.serial_resp_clk, dut.serial_resp_valid);
    end
    if (dut.i_p2s_0.waiting_response_q) begin
      $display(
          "  [DEBUG] @%0t M0 WAITING: deser_valid=%b, sclk_resp_in=%b, svalid_resp_in=%b, deser_receiving=%b, deser_bit_cnt=%0d",
          $time, dut.i_p2s_0.deser_frame_valid, dut.i_p2s_0.sclk_resp_i, dut.i_p2s_0.svalid_resp_i,
          dut.i_p2s_0.i_deserializer.receiving_q, dut.i_p2s_0.i_deserializer.bit_cnt_q);
    end
  end

  task automatic wait_cycles(input int cycles);
    repeat (cycles) @(posedge clk);
  endtask

  task automatic master_write(input int master_id, input logic [ADDR_WIDTH-1:0] addr,
                              input logic [DATA_WIDTH-1:0] wdata);
    int timeout_count;
    timeout_count = 0;

    $display("  [DEBUG] master_write: M%0d addr=0x%04x wdata=0x%04x", master_id, addr, wdata);
    m_req[master_id] = 1'b1;
    m_addr[master_id] = addr;
    m_wdata[master_id] = wdata;
    m_we[master_id] = 1'b1;

    @(posedge clk);

    // If ready is already high (no grant yet), wait for it to go low first
    if (m_ready[master_id]) begin
      while (m_ready[master_id]) begin
        @(posedge clk);
        timeout_count++;
        if (timeout_count > timeout_cycles) begin
          $display("  ERROR: Timeout waiting for ready to de-assert (master %0d, addr=0x%04x)",
                   master_id, addr);
          $finish;
        end
      end
      timeout_count = 0;  // Reset counter for next phase
    end

    // Now wait for ready to go high (transaction complete)
    while (!m_ready[master_id]) begin
      @(posedge clk);
      timeout_count++;
      if (timeout_count > timeout_cycles) begin
        $display("  ERROR: Timeout waiting for write ready (master %0d, addr=0x%04x)", master_id,
                 addr);
        $finish;
      end
    end

    $display("  [DEBUG] master_write DONE: M%0d ready after %0d cycles", master_id, timeout_count);
    m_req[master_id] = 1'b0;

    // Wait for ready to de-assert, then re-assert (latch clear cycle)
    timeout_count = 0;
    @(posedge clk);
    while (m_ready[master_id]) begin
      @(posedge clk);
      timeout_count++;
      if (timeout_count > 10) break;  // Short timeout for de-assert
    end

    timeout_count = 0;
    while (!m_ready[master_id]) begin
      @(posedge clk);
      timeout_count++;
      if (timeout_count > 10) begin
        $display("  ERROR: Timeout waiting for ready re-assertion after latch clear (master %0d)",
                 master_id);
        $finish;
      end
    end
  endtask

  task automatic master_read(input int master_id, input logic [ADDR_WIDTH-1:0] addr,
                             output logic [DATA_WIDTH-1:0] rdata);
    int timeout_count;
    timeout_count = 0;

    // Debug: check memory before read
    if (addr < 16'h1000) begin
      $display("  [DEBUG] PRE-READ Slave 0 mem[0x%03x] = 0x%02x", addr[11:0],
               dut.i_slave_0.mem[addr[11:0]]);
    end else if (addr < 16'h2000) begin
      $display("  [DEBUG] PRE-READ Slave 1 mem[0x%03x] = 0x%02x", addr[11:0],
               dut.i_slave_1.mem[addr[11:0]]);
    end else begin
      $display("  [DEBUG] PRE-READ Slave 2 mem[0x%03x] = 0x%02x", addr[10:0],
               dut.i_slave_2.mem[addr[10:0]]);
    end

    m_req[master_id]  = 1'b1;
    m_addr[master_id] = addr;
    m_we[master_id]   = 1'b0;

    @(posedge clk);

    // If ready is already high (no grant yet), wait for it to go low first
    if (m_ready[master_id]) begin
      while (m_ready[master_id]) begin
        @(posedge clk);
        timeout_count++;
        if (timeout_count > timeout_cycles) begin
          $display("  ERROR: Timeout waiting for ready to de-assert (master %0d, addr=0x%04x)",
                   master_id, addr);
          $finish;
        end
      end
      timeout_count = 0;  // Reset counter for next phase
    end

    // Now wait for ready to go high (transaction complete)
    while (!m_ready[master_id]) begin
      @(posedge clk);
      timeout_count++;
      if (timeout_count > timeout_cycles) begin
        $display("  ERROR: Timeout waiting for read ready (master %0d, addr=0x%04x)", master_id,
                 addr);
        $finish;
      end
    end

    rdata = m_rdata[master_id];
    m_req[master_id] = 1'b0;

    // Wait for ready to de-assert, then re-assert (latch clear cycle)
    timeout_count = 0;
    @(posedge clk);
    while (m_ready[master_id]) begin
      @(posedge clk);
      timeout_count++;
      if (timeout_count > 10) break;  // Short timeout for de-assert
    end

    timeout_count = 0;
    while (!m_ready[master_id]) begin
      @(posedge clk);
      timeout_count++;
      if (timeout_count > 10) begin
        $display("  ERROR: Timeout waiting for ready re-assertion after latch clear (master %0d)",
                 master_id);
        $finish;
      end
    end
  endtask

  task automatic check_value(input logic [DATA_WIDTH-1:0] expected,
                             input logic [DATA_WIDTH-1:0] actual, input string test_name);
    #1;
    if (actual !== expected) begin
      $display("  FAIL: %s - value mismatch (expected=0x%04x, got=0x%04x)", test_name, expected,
               actual);
      test_fail_count++;
    end else begin
      $display("  PASS: %s", test_name);
      test_pass_count++;
    end
  endtask

  task automatic check_error(input int master_id, input logic expected_err, input string test_name);
    #1;
    if (m_err[master_id] !== expected_err) begin
      $display("  FAIL: %s - error flag mismatch (expected=%b, got=%b)", test_name, expected_err,
               m_err[master_id]);
      test_fail_count++;
    end else begin
      $display("  PASS: %s", test_name);
      test_pass_count++;
    end
  endtask

  task automatic test_reset();
    $display("\nTest 1: Reset behavior");

    rst_n = 1'b0;
    m_req = 2'b00;
    m_we  = 2'b00;
    wait_cycles(5);

    rst_n = 1'b1;
    wait_cycles(2);

    #1;
    // After reset, masters should be idle (ready=1) and no grants (gnt=0)
    if (m_gnt === 2'b00 && m_ready === 2'b11) begin
      $display("  PASS: System properly reset (idle and ready)");
      test_pass_count++;
    end else begin
      $display("  FAIL: System not properly reset (gnt=%b, ready=%b)", m_gnt, m_ready);
      test_fail_count++;
    end
  endtask

  task automatic test_master0_write_all_slaves();
    logic [DATA_WIDTH-1:0] rdata;

    $display("\nTest 2: Master 0 write to all slaves");

    master_write(0, SLAVE0_BASE, 8'hAA);
    $display("  INFO: Wrote 0xAA to Slave 0 (0x%04x)", SLAVE0_BASE);
    test_pass_count++;

    master_write(0, SLAVE1_BASE, 8'hBB);
    $display("  INFO: Wrote 0xBB to Slave 1 (0x%04x)", SLAVE1_BASE);
    test_pass_count++;

    master_write(0, SLAVE2_BASE, 8'hCC);
    $display("  INFO: Wrote 0xCC to Slave 2 (0x%04x)", SLAVE2_BASE);
    test_pass_count++;

    wait_cycles(10);

    master_read(0, SLAVE0_BASE, rdata);
    $display("  INFO: Read 0x%02x from Slave 0", rdata);
    check_value(8'hAA, rdata, "Read back from Slave 0");

    master_read(0, SLAVE1_BASE, rdata);
    $display("  INFO: Read 0x%02x from Slave 1", rdata);
    check_value(8'hBB, rdata, "Read back from Slave 1");

    master_read(0, SLAVE2_BASE, rdata);
    $display("  INFO: Read 0x%02x from Slave 2", rdata);
    check_value(8'hCC, rdata, "Read back from Slave 2");
  endtask

  task automatic test_master0_read_all_slaves();
    logic [DATA_WIDTH-1:0] rdata;

    $display("\nTest 3: Master 0 read from all slaves");

    master_write(0, SLAVE0_BASE + 4, 16'hDEAD);
    master_write(0, SLAVE1_BASE + 4, 16'hBEEF);
    master_write(0, SLAVE2_BASE + 4, 16'hCAFE);
    wait_cycles(5);

    master_read(0, SLAVE0_BASE + 4, rdata);
    check_value(16'hDEAD, rdata, "Master 0 read from Slave 0");

    master_read(0, SLAVE1_BASE + 4, rdata);
    check_value(16'hBEEF, rdata, "Master 0 read from Slave 1");

    master_read(0, SLAVE2_BASE + 4, rdata);
    check_value(16'hCAFE, rdata, "Master 0 read from Slave 2");
  endtask

  task automatic test_arbitration();
    logic [DATA_WIDTH-1:0] rdata0, rdata1;

    $display("\nTest 4: Arbitration between both masters");

    fork
      begin
        master_write(0, SLAVE0_BASE + 8, 16'h0000);
        wait_cycles(2);
        master_write(0, SLAVE0_BASE + 12, 16'h1111);
      end
      begin
        wait_cycles(1);
        master_write(1, SLAVE1_BASE + 8, 16'hAAAA);
        wait_cycles(2);
        master_write(1, SLAVE1_BASE + 12, 16'hBBBB);
      end
    join

    $display("  PASS: Both masters completed transactions");
    test_pass_count++;

    wait_cycles(5);

    master_read(0, SLAVE0_BASE + 8, rdata0);
    check_value(16'h0000, rdata0, "Master 0 write verified");

    master_read(1, SLAVE1_BASE + 8, rdata1);
    check_value(16'hAAAA, rdata1, "Master 1 write verified");
  endtask

  task automatic test_back_to_back();
    logic [DATA_WIDTH-1:0] rdata;

    $display("\nTest 5: Back-to-back transactions");

    master_write(0, SLAVE0_BASE + 16, 16'h1111);
    master_write(0, SLAVE0_BASE + 20, 16'h2222);
    master_write(0, SLAVE0_BASE + 24, 16'h3333);

    $display("  PASS: Three back-to-back writes completed");
    test_pass_count++;

    wait_cycles(5);

    master_read(0, SLAVE0_BASE + 16, rdata);
    check_value(16'h1111, rdata, "First back-to-back write");

    master_read(0, SLAVE0_BASE + 20, rdata);
    check_value(16'h2222, rdata, "Second back-to-back write");

    master_read(0, SLAVE0_BASE + 24, rdata);
    check_value(16'h3333, rdata, "Third back-to-back write");
  endtask

  task automatic test_address_decode_error();
    logic [DATA_WIDTH-1:0] rdata;
    int timeout_count;

    $display("\nTest 6: Address decode error");

    m_req[0] = 1'b1;
    m_addr[0] = 16'h3000;
    m_we[0] = 1'b0;

    timeout_count = 0;
    @(posedge clk);
    while (!m_ready[0] && timeout_count < timeout_cycles) begin
      @(posedge clk);
      timeout_count++;
    end

    check_error(0, 1'b1, "Invalid address generates error");

    m_req[0] = 1'b0;
    wait_cycles(2);
  endtask

  task automatic test_different_slaves();
    logic [DATA_WIDTH-1:0] rdata;

    $display("\nTest 7: Access different slaves in sequence");

    master_write(0, SLAVE0_BASE + 28, 16'hAAAA);
    master_write(0, SLAVE1_BASE + 28, 16'hBBBB);
    master_write(0, SLAVE2_BASE + 28, 16'hCCCC);
    master_write(0, SLAVE0_BASE + 32, 16'hDDDD);

    $display("  PASS: Sequential access to different slaves");
    test_pass_count++;

    wait_cycles(5);

    master_read(0, SLAVE0_BASE + 28, rdata);
    check_value(16'hAAAA, rdata, "Slave 0 sequential access");

    master_read(0, SLAVE1_BASE + 28, rdata);
    check_value(16'hBBBB, rdata, "Slave 1 sequential access");

    master_read(0, SLAVE2_BASE + 28, rdata);
    check_value(16'hCCCC, rdata, "Slave 2 sequential access");
  endtask

  task automatic test_boundary_addresses();
    logic [DATA_WIDTH-1:0] rdata;

    $display("\nTest 8: Boundary address access");

    master_write(0, SLAVE0_BASE, 16'h0001);
    master_write(0, SLAVE0_BASE + SLAVE0_SIZE - 2, 16'h0002);
    master_write(0, SLAVE1_BASE, 16'h0003);
    master_write(0, SLAVE1_BASE + SLAVE1_SIZE - 2, 16'h0004);

    $display("  PASS: Boundary address writes completed");
    test_pass_count++;

    wait_cycles(5);

    master_read(0, SLAVE0_BASE, rdata);
    check_value(16'h0001, rdata, "Slave 0 base address");

    master_read(0, SLAVE0_BASE + SLAVE0_SIZE - 2, rdata);
    check_value(16'h0002, rdata, "Slave 0 top address");

    master_read(0, SLAVE1_BASE, rdata);
    check_value(16'h0003, rdata, "Slave 1 base address");

    master_read(0, SLAVE1_BASE + SLAVE1_SIZE - 2, rdata);
    check_value(16'h0004, rdata, "Slave 1 top address");
  endtask

  task automatic test_alternating_masters();
    logic [DATA_WIDTH-1:0] rdata0, rdata1;

    $display("\nTest 9: Alternating master access");

    master_write(0, SLAVE0_BASE + 36, 16'h1000);
    master_write(1, SLAVE1_BASE + 36, 16'h2000);
    master_write(0, SLAVE0_BASE + 40, 16'h3000);
    master_write(1, SLAVE1_BASE + 40, 16'h4000);

    $display("  PASS: Alternating master writes completed");
    test_pass_count++;

    wait_cycles(5);

    master_read(0, SLAVE0_BASE + 36, rdata0);
    check_value(16'h1000, rdata0, "Master 0 first write");

    master_read(1, SLAVE1_BASE + 36, rdata1);
    check_value(16'h2000, rdata1, "Master 1 first write");

    master_read(0, SLAVE0_BASE + 40, rdata0);
    check_value(16'h3000, rdata0, "Master 0 second write");

    master_read(1, SLAVE1_BASE + 40, rdata1);
    check_value(16'h4000, rdata1, "Master 1 second write");
  endtask

  task automatic test_read_write_mix();
    logic [DATA_WIDTH-1:0] rdata;

    $display("\nTest 10: Mixed read/write operations");

    master_write(0, SLAVE1_BASE + 44, 16'hFACE);
    master_read(0, SLAVE1_BASE + 44, rdata);
    check_value(16'hFACE, rdata, "Immediate read after write");

    master_write(0, SLAVE1_BASE + 48, 16'hFEED);
    wait_cycles(3);
    master_read(0, SLAVE1_BASE + 48, rdata);
    check_value(16'hFEED, rdata, "Delayed read after write");

    master_read(0, SLAVE1_BASE + 44, rdata);
    master_write(0, SLAVE1_BASE + 44, 16'hC0DE);
    master_read(0, SLAVE1_BASE + 44, rdata);
    check_value(16'hC0DE, rdata, "Read-write-read sequence");
  endtask

  initial begin
    rst_n = 0;
    m_req = 2'b00;
    m_we = 2'b00;
    m_addr[0] = '0;
    m_addr[1] = '0;
    m_wdata[0] = '0;
    m_wdata[1] = '0;

    wait_cycles(5);

    $display("\n=== Bit-Serial Bus System Testbench ===");

    test_reset();
    test_master0_write_all_slaves();
    test_master0_read_all_slaves();
    test_arbitration();
    test_back_to_back();
    test_address_decode_error();
    test_different_slaves();
    test_boundary_addresses();
    test_alternating_masters();
    test_read_write_mix();

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
