module serial_arbiter
  import bus_pkg::*;
(
    input logic clk_i,
    input logic rst_ni,

    input  logic [1:0] req_i,
    output logic [1:0] gnt_o,

    input logic frame_active_i,

    output logic       msel_o,
    output logic       split_pending_o,
    output logic [1:0] split_owner_o
);

  typedef enum logic [1:0] {
    ARB_IDLE,
    ARB_MASTER0,
    ARB_MASTER1,
    ARB_SPLIT
  } arb_state_e;

  arb_state_e state_d, state_q;
  logic [1:0] split_owner_d, split_owner_q;
  logic split_pending_d, split_pending_q;

  always_comb begin
    state_d = state_q;
    split_owner_d = split_owner_q;
    split_pending_d = split_pending_q;
    gnt_o = 2'b00;
    msel_o = 1'b0;

    if (split_pending_q) begin
      state_d = ARB_SPLIT;
    end

    case (state_q)
      ARB_IDLE: begin
        if (split_pending_q) begin
          state_d = ARB_SPLIT;
        end else if (req_i[0]) begin
          state_d = ARB_MASTER0;
        end else if (req_i[1]) begin
          state_d = ARB_MASTER1;
        end
      end

      ARB_MASTER0: begin
        if (!frame_active_i) begin
          if (!req_i[0]) begin
            state_d = ARB_IDLE;
          end
        end
      end

      ARB_MASTER1: begin
        if (!frame_active_i) begin
          if (!req_i[1]) begin
            state_d = ARB_IDLE;
          end
        end
      end

      ARB_SPLIT: begin
        if (!split_pending_q && !frame_active_i) begin
          state_d = ARB_IDLE;
        end
      end

      default: begin
        state_d = ARB_IDLE;
      end
    endcase

    // Generate gnt_o and msel_o from NEXT state for 0-cycle grant latency
    case (state_d)
      ARB_MASTER0: begin
        gnt_o  = 2'b01;
        msel_o = 1'b0;
      end

      ARB_MASTER1: begin
        gnt_o  = 2'b10;
        msel_o = 1'b1;
      end

      ARB_SPLIT: begin
        if (split_owner_q[0]) begin
          gnt_o  = 2'b01;
          msel_o = 1'b0;
        end else if (split_owner_q[1]) begin
          gnt_o  = 2'b10;
          msel_o = 1'b1;
        end
      end

      default: begin
        gnt_o  = 2'b00;
        msel_o = 1'b0;
      end
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= ARB_IDLE;
      split_owner_q <= 2'b00;
      split_pending_q <= 1'b0;
    end else begin
      state_q <= state_d;
      split_owner_q <= split_owner_d;
      split_pending_q <= split_pending_d;

      if (state_d != state_q) begin
        $display("[%0t] ARBITER: State %0d -> %0d (req=%b, gnt=%b, frame_active=%b)", $time,
                 state_q, state_d, req_i, gnt_o, frame_active_i);
      end
    end
  end

  assign split_pending_o = split_pending_q;
  assign split_owner_o   = split_owner_q;

endmodule
