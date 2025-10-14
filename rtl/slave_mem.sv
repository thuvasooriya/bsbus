module slave_mem
  import bus_pkg::*;
#(
    parameter int unsigned MEM_SIZE = 4096
) (
    input logic clk_i,
    input logic rst_ni,

    input  logic                  valid_i,
    input  logic [ADDR_WIDTH-1:0] addr_i,
    input  logic [DATA_WIDTH-1:0] wdata_i,
    input  logic                  we_i,
    output logic                  ready_o,
    output logic [DATA_WIDTH-1:0] rdata_o,
    output logic                  err_o,

    input  logic split_start_i,
    output logic split_ready_o
);

  localparam int unsigned MEM_DEPTH = MEM_SIZE;
  localparam int unsigned ADDR_BITS = $clog2(MEM_DEPTH);

  logic [DATA_WIDTH-1:0] mem             [MEM_DEPTH];

  logic [ ADDR_BITS-1:0] local_addr;
  logic                  addr_valid;
  logic                  split_pending_q;
  logic [ ADDR_BITS-1:0] split_addr_q;
  logic [           2:0] split_delay_q;

  assign local_addr = addr_i[ADDR_BITS-1:0];
  assign addr_valid = (addr_i < MEM_SIZE);

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rdata_o         <= '0;
      ready_o         <= 1'b0;
      err_o           <= 1'b0;
      split_pending_q <= 1'b0;
      split_addr_q    <= '0;
      split_delay_q   <= '0;
      split_ready_o   <= 1'b0;
    end else begin
      ready_o       <= 1'b0;
      err_o         <= 1'b0;
      split_ready_o <= 1'b0;

      if (split_pending_q) begin
        if (split_delay_q > 0) begin
          split_delay_q <= split_delay_q - 1;
        end else begin
          rdata_o         <= mem[split_addr_q];
          split_ready_o   <= 1'b1;
          split_pending_q <= 1'b0;
        end
      end else if (valid_i) begin
        if (!addr_valid) begin
          err_o   <= 1'b1;
          ready_o <= 1'b1;
        end else if (we_i) begin
          mem[local_addr] <= wdata_i;
          ready_o         <= 1'b1;
        end else begin
          if (split_start_i) begin
            split_pending_q <= 1'b1;
            split_addr_q    <= local_addr;
            split_delay_q   <= 3'd5;
            ready_o         <= 1'b0;
          end else begin
            rdata_o <= mem[local_addr];
            ready_o <= 1'b1;
          end
        end
      end
    end
  end

endmodule
