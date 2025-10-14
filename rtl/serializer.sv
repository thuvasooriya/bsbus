`timescale 1ns / 1ps

module serializer
  import bus_pkg::*;
(
    input logic clk_i,
    input logic rst_ni,

    input  logic          start_i,
    input  serial_frame_t frame_i,
    output logic          busy_o,
    output logic          done_o,

    output logic sdata_o,
    output logic sclk_o
);

  logic [FRAME_WIDTH-1:0] shift_reg_d, shift_reg_q;
  logic [4:0] bit_cnt_d, bit_cnt_q;
  logic [1:0] clk_div_d, clk_div_q;
  logic active_d, active_q;
  logic sclk_d, sclk_q;
  logic done_d, done_q;

  always_comb begin
    shift_reg_d = shift_reg_q;
    bit_cnt_d = bit_cnt_q;
    clk_div_d = clk_div_q;
    active_d = active_q;
    sclk_d = sclk_q;
    done_d = 1'b0;

    if (active_q) begin
      clk_div_d = clk_div_q + 2'd1;

      if (clk_div_q == 2'd1) begin
        sclk_d = 1'b1;
      end else if (clk_div_q == 2'd3) begin
        sclk_d = 1'b0;
      end

      if (clk_div_q == 2'd3) begin
        shift_reg_d = {shift_reg_q[FRAME_WIDTH-2:0], 1'b0};
        bit_cnt_d   = bit_cnt_q + 5'd1;

        if (bit_cnt_q == 5'd26) begin
          active_d = 1'b0;
          done_d = 1'b1;
          bit_cnt_d = 5'd0;
          clk_div_d = 2'd0;
        end
      end
    end else if (start_i) begin
      shift_reg_d = {
        frame_i.start, frame_i.cmd, frame_i.addr, frame_i.data, frame_i.parity, frame_i.stop
      };
      active_d = 1'b1;
      bit_cnt_d = 5'd0;
      clk_div_d = 2'd0;
      sclk_d = 1'b0;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      shift_reg_q <= '0;
      bit_cnt_q <= '0;
      clk_div_q <= '0;
      active_q <= 1'b0;
      sclk_q <= 1'b0;
      done_q <= 1'b0;
    end else begin
      shift_reg_q <= shift_reg_d;
      bit_cnt_q <= bit_cnt_d;
      clk_div_q <= clk_div_d;
      active_q <= active_d;
      sclk_q <= sclk_d;
      done_q <= done_d;
    end
  end

  assign sdata_o = shift_reg_q[FRAME_WIDTH-1];
  assign sclk_o  = sclk_q;
  assign busy_o  = active_q;
  assign done_o  = done_q;

endmodule
