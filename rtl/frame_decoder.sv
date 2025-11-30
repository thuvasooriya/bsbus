module frame_decoder
  import bus_pkg::*;
(
    input logic clk_i,
    input logic rst_ni,

    input logic          frame_valid_i,
    input serial_frame_t frame_i,
    input logic          parity_err_i,

    output logic                  valid_o,
    output logic [ADDR_WIDTH-1:0] addr_o,
    output logic [DATA_WIDTH-1:0] wdata_o,
    output logic                  we_o,
    output logic                  err_o
);

  typedef enum logic [1:0] {
    DEC_IDLE,
    DEC_DECODE
  } decoder_state_e;

  decoder_state_e state_d, state_q;
  logic [ADDR_WIDTH-1:0] addr_d, addr_q;
  logic [DATA_WIDTH-1:0] wdata_d, wdata_q;
  logic we_d, we_q;
  logic err_d, err_q;
  logic valid_d, valid_q;

  always_comb begin
    state_d = state_q;
    addr_d = addr_q;
    wdata_d = wdata_q;
    we_d = we_q;
    err_d = err_q;
    valid_d = 1'b0;

    case (state_q)
      DEC_IDLE: begin
        if (frame_valid_i) begin
          // Check frame validity immediately when frame arrives
          if (parity_err_i || frame_i.start != 1'b1 || frame_i.stop != 1'b1) begin
            err_d   = 1'b1;
            valid_d = 1'b0;
            $display("[%0t] FRAME_DEC: ERROR detected (parity_err=%b start=%b stop=%b)", $time,
                     parity_err_i, frame_i.start, frame_i.stop);
          end else begin
            // Valid frame - decode and output for one cycle
            addr_d = frame_i.addr;
            wdata_d = frame_i.data;
            we_d = (frame_i.cmd == CMD_WRITE) || (frame_i.cmd == CMD_SPLIT_START);
            err_d = 1'b0;
            valid_d = 1'b1;
            $display("[%0t] FRAME_DEC: Decoded frame - cmd=%b addr=0x%04x data=0x%02x we=%b",
                     $time, frame_i.cmd, frame_i.addr, frame_i.data, we_d);
          end
          state_d = DEC_DECODE;
        end
      end

      DEC_DECODE: begin
        // Return to IDLE after one cycle
        state_d = DEC_IDLE;
      end

      default: begin
        state_d = DEC_IDLE;
      end
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= DEC_IDLE;
      addr_q <= '0;
      wdata_q <= '0;
      we_q <= 1'b0;
      err_q <= 1'b0;
      valid_q <= 1'b0;
    end else begin
      state_q <= state_d;
      addr_q <= addr_d;
      wdata_q <= wdata_d;
      we_q <= we_d;
      err_q <= err_d;
      valid_q <= valid_d;

      // synthesis translate_off
      if (state_q != state_d) begin
        $display("[%0t] FRAME_DEC: State %0d -> %0d (frame_valid_i=%b, valid_o=%b)", $time,
                 state_q, state_d, frame_valid_i, valid_q);
      end
      // synthesis translate_on
    end
  end

  assign addr_o = addr_q;
  assign wdata_o = wdata_q;
  assign we_o = we_q;
  assign err_o = err_q;
  assign valid_o = valid_q;

endmodule
