`timescale 1ns / 1ps

module deserializer
  import bus_pkg::*;
(
    input logic clk_i,
    input logic rst_ni,

    input logic sdata_i,
    input logic sclk_i,
    input logic svalid_i,

    output logic          frame_valid_o,
    output serial_frame_t frame_o,
    output logic          parity_err_o
);

  logic [FRAME_WIDTH-1:0] shift_reg_d, shift_reg_q;
  logic [4:0] bit_cnt_d, bit_cnt_q;
  logic sclk_q, sclk_qq;
  logic receiving_d, receiving_q;
  logic frame_done_d, frame_done_q;

  wire sclk_posedge = sclk_q && !sclk_qq;

  always_comb begin
    shift_reg_d = shift_reg_q;
    bit_cnt_d = bit_cnt_q;
    receiving_d = receiving_q;
    frame_done_d = 1'b0;

    if (svalid_i) begin
      if (!receiving_q && sdata_i) begin
        receiving_d = 1'b1;
        bit_cnt_d   = 5'd0;
        shift_reg_d = '0;
      end

      if (receiving_q && sclk_posedge) begin
        shift_reg_d = {shift_reg_q[FRAME_WIDTH-2:0], sdata_i};
        bit_cnt_d   = bit_cnt_q + 5'd1;

        if (bit_cnt_q == 5'd26) begin
          receiving_d = 1'b0;
          frame_done_d = 1'b1;
          bit_cnt_d = 5'd0;
        end
      end
    end else begin
      receiving_d = 1'b0;
      bit_cnt_d   = 5'd0;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      shift_reg_q <= '0;
      bit_cnt_q <= '0;
      sclk_q <= 1'b0;
      sclk_qq <= 1'b0;
      receiving_q <= 1'b0;
      frame_done_q <= 1'b0;
    end else begin
      shift_reg_q <= shift_reg_d;
      bit_cnt_q <= bit_cnt_d;
      sclk_q <= sclk_i;
      sclk_qq <= sclk_q;
      receiving_q <= receiving_d;
      frame_done_q <= frame_done_d;

      // Debug: print received frame when done
      if (frame_done_d) begin
        $display("[%0t] DESER RECEIVED: shift_reg=0x%07x", $time, shift_reg_d);
      end
    end
  end

  serial_frame_t frame_unpacked;
  logic expected_parity;

  assign frame_unpacked.start = shift_reg_q[FRAME_WIDTH-1];
  assign frame_unpacked.cmd = cmd_e'(shift_reg_q[FRAME_WIDTH-2:FRAME_WIDTH-3]);
  assign frame_unpacked.addr = shift_reg_q[FRAME_WIDTH-4:FRAME_WIDTH-17];
  assign frame_unpacked.data = shift_reg_q[FRAME_WIDTH-18:FRAME_WIDTH-25];
  assign frame_unpacked.parity = shift_reg_q[1];
  assign frame_unpacked.stop = shift_reg_q[0];

  assign expected_parity = calc_parity(
      frame_unpacked.cmd, frame_unpacked.addr, frame_unpacked.data
  );

  assign frame_o = frame_unpacked;
  assign frame_valid_o = frame_done_q;
  assign parity_err_o = frame_done_q && (frame_unpacked.parity != expected_parity);

  // Debug: print unpacked frame
  always @(posedge clk_i) begin
    if (frame_valid_o) begin
      $display("[%0t] DESER UNPACKED: start=%b cmd=%b addr=0x%04x data=0x%02x parity=%b stop=%b",
               $time, frame_unpacked.start, frame_unpacked.cmd, frame_unpacked.addr,
               frame_unpacked.data, frame_unpacked.parity, frame_unpacked.stop);
      $display("[%0t] DESER PARITY CHECK: received=%b expected=%b parity_err_o=%b", $time,
               frame_unpacked.parity, expected_parity, parity_err_o);
    end
  end

endmodule
