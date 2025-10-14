`timescale 1ns / 1ps

module parallel_to_serial
  import bus_pkg::*;
(
    input logic clk_i,
    input logic rst_ni,

    input  logic                  valid_i,
    input  logic [ADDR_WIDTH-1:0] addr_i,
    input  logic [DATA_WIDTH-1:0] wdata_i,
    input  logic                  we_i,
    output logic                  ready_o,
    output logic [DATA_WIDTH-1:0] rdata_o,
    output logic                  err_o,

    output logic sdata_o,
    output logic sclk_o,
    output logic svalid_o,
    input  logic sready_i,
    input  logic sdata_i,
    input  logic sclk_resp_i,
    input  logic svalid_resp_i
);

  logic          ser_start;
  serial_frame_t ser_frame;
  logic          ser_busy;
  logic          ser_done;

  logic          deser_frame_valid;
  serial_frame_t deser_frame;
  logic          deser_parity_err;

  logic          waiting_response_q;
  logic          is_read_q;
  logic          tx_ready;
  logic          trans_complete;
  logic          response_received;

  // Pulse when response is received for a READ
  assign response_received = waiting_response_q && deser_frame_valid;

  // Transaction complete when:
  // - WRITE: serialization done (ser_done pulse)
  // - READ: response received (deser_frame_valid pulse while waiting)
  // Use waiting_response_q instead of is_read_q to avoid timing issue where
  // is_read_q is cleared in same cycle as response arrives
  assign trans_complete = waiting_response_q ? response_received : ser_done;

  always @(posedge clk_i) begin
    if (trans_complete) begin
      $display(
          "[%0t] P2S: TRANS_COMPLETE - waiting_response_q=%b, response_received=%b, ser_done=%b",
          $time, waiting_response_q, response_received, ser_done);
    end
  end

  tx_controller i_tx_ctrl (
      .clk_i           (clk_i),
      .rst_ni          (rst_ni),
      .valid_i         (valid_i),
      .addr_i          (addr_i),
      .wdata_i         (wdata_i),
      .we_i            (we_i),
      .ready_o         (tx_ready),
      .ser_start_o     (ser_start),
      .ser_frame_o     (ser_frame),
      .ser_busy_i      (ser_busy),
      .ser_done_i      (ser_done),
      .trans_complete_i(trans_complete)
  );

  serializer i_serializer (
      .clk_i  (clk_i),
      .rst_ni (rst_ni),
      .start_i(ser_start),
      .frame_i(ser_frame),
      .busy_o (ser_busy),
      .done_o (ser_done),
      .sdata_o(sdata_o),
      .sclk_o (sclk_o)
  );

  deserializer i_deserializer (
      .clk_i        (clk_i),
      .rst_ni       (rst_ni),
      .sdata_i      (sdata_i),
      .sclk_i       (sclk_resp_i),
      .svalid_i     (svalid_resp_i),
      .frame_valid_o(deser_frame_valid),
      .frame_o      (deser_frame),
      .parity_err_o (deser_parity_err)
  );

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      waiting_response_q <= 1'b0;
      is_read_q <= 1'b0;
      rdata_o <= '0;
      err_o <= 1'b0;
    end else begin
      if (ser_start && !we_i) begin
        waiting_response_q <= 1'b1;
        is_read_q <= 1'b1;
        $display("[%0t] P2S: START READ - waiting_response_q set to 1", $time);
      end

      if (waiting_response_q && deser_frame_valid) begin
        rdata_o <= deser_frame.data;
        // Error if: parity error OR response cmd indicates error (CMD_WRITE instead of CMD_READ)
        err_o <= deser_parity_err || (deser_frame.cmd == CMD_WRITE);
        waiting_response_q <= 1'b0;
        is_read_q <= 1'b0;
        $display(
            "[%0t] P2S: RESPONSE RECEIVED - rdata=0x%02x, cmd=%b, parity_err=%b, cmd_is_write=%b, final_err=%b",
            $time, deser_frame.data, deser_frame.cmd, deser_parity_err,
            (deser_frame.cmd == CMD_WRITE), deser_parity_err || (deser_frame.cmd == CMD_WRITE));
      end

      // Clear waiting_response when valid_i goes low (abort/timeout)
      if (waiting_response_q && !valid_i) begin
        waiting_response_q <= 1'b0;
        is_read_q <= 1'b0;
        $display("[%0t] P2S: READ ABORTED - waiting_response_q cleared by valid_i=0", $time);
      end

      // Clear err_o only when transaction completes (valid_i goes low)
      if (!valid_i) begin
        err_o <= 1'b0;
      end
    end
  end

  // For reads, wait for response before asserting ready
  // For writes, use tx_ready directly
  assign ready_o = tx_ready && !waiting_response_q;

  // Debug ready_o changes
  always @(posedge clk_i) begin
    if (ready_o && valid_i && !we_i) begin
      $display("[%0t] P2S: READY_O asserted for READ (tx_ready=%b, waiting_response_q=%b)", $time,
               tx_ready, waiting_response_q);
    end
  end

  assign svalid_o = ser_busy;

  // Debug: Monitor response path
  always @(posedge clk_i) begin
    if (waiting_response_q) begin
      $display("[P2S DEBUG %t] Waiting for response: svalid_resp_i=%b, deser_frame_valid=%b",
               $time, svalid_resp_i, deser_frame_valid);
    end
    if (deser_frame_valid) begin
      $display("[P2S DEBUG %t] Response received! data=0x%h, parity_err=%b", $time,
               deser_frame.data, deser_parity_err);
    end
  end

endmodule
