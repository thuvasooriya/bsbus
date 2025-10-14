`timescale 1ns / 1ps

module tx_controller
  import bus_pkg::*;
(
    input logic clk_i,
    input logic rst_ni,

    input  logic                  valid_i,
    input  logic [ADDR_WIDTH-1:0] addr_i,
    input  logic [DATA_WIDTH-1:0] wdata_i,
    input  logic                  we_i,
    output logic                  ready_o,

    output logic          ser_start_o,
    output serial_frame_t ser_frame_o,
    input  logic          ser_busy_i,
    input  logic          ser_done_i,
    input  logic          trans_complete_i
);

  typedef enum logic [1:0] {
    TX_IDLE,
    TX_BUILD,
    TX_SEND,
    TX_WAIT
  } tx_state_e;

  tx_state_e state_d, state_q;
  serial_frame_t frame_d, frame_q;
  logic valid_latched_d, valid_latched_q;
  logic complete_hold_d, complete_hold_q;

  always_comb begin
    state_d = state_q;
    frame_d = frame_q;
    valid_latched_d = valid_latched_q;
    complete_hold_d = complete_hold_q;
    ready_o = 1'b0;
    ser_start_o = 1'b0;

    case (state_q)
      TX_IDLE: begin
        // Assert ready when in IDLE AND latch is clear (ready for new transaction)
        // If latch is still set, master must de-assert valid_i first to clear it
        // ALSO assert ready if we're in the completion hold cycle
        ready_o = !valid_latched_q || complete_hold_q;

        // Clear completion hold after one cycle
        if (complete_hold_q) begin
          complete_hold_d = 1'b0;
        end

        // Only trigger on NEW valid_i assertion (not latched yet)
        // AND ensure we've seen valid_i LOW first (to prevent re-triggering)
        if (valid_i && !valid_latched_q) begin
          valid_latched_d = 1'b1;
          ready_o = 1'b0;  // De-assert ready when starting new transaction
          state_d = TX_BUILD;
        end else if (!valid_i && valid_latched_q) begin
          // valid_i went LOW after transaction completed - clear latch
          valid_latched_d = 1'b0;
        end
      end

      TX_BUILD: begin
        frame_d.start = 1'b1;
        frame_d.cmd = we_i ? CMD_WRITE : CMD_READ;
        frame_d.addr = addr_i;
        frame_d.data = wdata_i;
        frame_d.parity = calc_parity(frame_d.cmd, addr_i, wdata_i);
        frame_d.stop = 1'b1;
        $display("[%0t] TX_CTRL BUILD: cmd=%s addr=0x%04x data=0x%02x we=%b", $time,
                 we_i ? "WRITE" : "READ", addr_i, wdata_i, we_i);
        state_d = TX_SEND;
      end

      TX_SEND: begin
        ser_start_o = 1'b1;
        if (ser_busy_i) begin
          state_d = TX_WAIT;
        end
      end

      TX_WAIT: begin
        if (trans_complete_i) begin
          ready_o = 1'b1;
          $display("[%0t] TX_CTRL: COMPLETE - asserting ready_o", $time);
          complete_hold_d = 1'b1;
          state_d = TX_IDLE;
        end else if (!valid_i && valid_latched_q) begin
          $display("[%0t] TX_CTRL: ABORT - valid_i de-asserted during wait", $time);
          ready_o = 1'b1;
          complete_hold_d = 1'b1;
          valid_latched_d = 1'b0;
          state_d = TX_IDLE;
        end
      end

      default: begin
        state_d = TX_IDLE;
        valid_latched_d = 1'b0;
        complete_hold_d = 1'b0;
      end
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= TX_IDLE;
      frame_q <= '0;
      valid_latched_q <= 1'b0;
      complete_hold_q <= 1'b0;
    end else begin
      state_q <= state_d;
      frame_q <= frame_d;
      valid_latched_q <= valid_latched_d;
      complete_hold_q <= complete_hold_d;

      // Debug: print state transitions
      if (state_d != state_q) begin
        $display("[%0t] TX_CTRL: State %0d -> %0d (valid_i=%b, valid_latched_q=%b->%b)", $time,
                 state_q, state_d, valid_i, valid_latched_q, valid_latched_d);
      end
    end
  end

  assign ser_frame_o = frame_q;

endmodule
