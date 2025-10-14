module serial_to_parallel
  import bus_pkg::*;
(
    input logic clk_i,
    input logic rst_ni,

    input  logic sdata_i,
    input  logic sclk_i,
    input  logic svalid_i,
    output logic sready_o,
    output logic sdata_o,
    output logic sclk_resp_o,
    output logic svalid_resp_o,

    output logic                  valid_o,
    output logic [ADDR_WIDTH-1:0] addr_o,
    output logic [DATA_WIDTH-1:0] wdata_o,
    output logic                  we_o,
    input  logic                  ready_i,
    input  logic [DATA_WIDTH-1:0] rdata_i,
    input  logic                  err_i
);

  logic                           frame_valid;
  serial_frame_t                  frame;
  logic                           parity_err;

  logic                           dec_valid;
  logic          [ADDR_WIDTH-1:0] dec_addr;
  logic          [DATA_WIDTH-1:0] dec_wdata;
  logic                           dec_we;
  logic                           dec_err;

  logic                           resp_start;
  serial_frame_t                  resp_frame;
  logic                           resp_busy;
  logic                           resp_done;
  logic                           resp_sdata;
  logic                           resp_sclk;

  deserializer i_deserializer (
      .clk_i        (clk_i),
      .rst_ni       (rst_ni),
      .sdata_i      (sdata_i),
      .sclk_i       (sclk_i),
      .svalid_i     (svalid_i),
      .frame_valid_o(frame_valid),
      .frame_o      (frame),
      .parity_err_o (parity_err)
  );

  frame_decoder i_frame_decoder (
      .clk_i        (clk_i),
      .rst_ni       (rst_ni),
      .frame_valid_i(frame_valid),
      .frame_i      (frame),
      .parity_err_i (parity_err),
      .valid_o      (dec_valid),
      .addr_o       (dec_addr),
      .wdata_o      (dec_wdata),
      .we_o         (dec_we),
      .err_o        (dec_err)
  );

  serializer i_resp_serializer (
      .clk_i  (clk_i),
      .rst_ni (rst_ni),
      .start_i(resp_start),
      .frame_i(resp_frame),
      .busy_o (resp_busy),
      .done_o (resp_done),
      .sdata_o(resp_sdata),
      .sclk_o (resp_sclk)
  );

  // Response frame generation
  // State machine: IDLE -> WAIT_SLAVE -> SEND_RESP -> IDLE
  typedef enum logic [1:0] {
    RESP_IDLE,
    RESP_WAIT_SLAVE,
    RESP_SENDING
  } resp_state_e;

  resp_state_e resp_state_q;
  logic [ADDR_WIDTH-1:0] read_addr_q;
  logic err_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      resp_start <= 1'b0;
      resp_state_q <= RESP_IDLE;
      read_addr_q <= '0;
      err_q <= 1'b0;
    end else begin
      resp_start <= 1'b0;

      case (resp_state_q)
        RESP_IDLE: begin
          // Detect READ request (dec_valid HIGH for one cycle, dec_we LOW)
          if (dec_valid && !dec_we) begin
            // If ready_i is already high (error case), start response immediately
            if (ready_i && !resp_busy) begin
              resp_start <= 1'b1;
              resp_state_q <= RESP_SENDING;
              read_addr_q <= dec_addr;
              err_q <= err_i;
              $display("[%0t] S2P: Detected READ addr=0x%04x err=%b, ready immediately", $time,
                       dec_addr, err_i);
            end else begin
              resp_state_q <= RESP_WAIT_SLAVE;
              read_addr_q <= dec_addr;
              err_q <= err_i;
              $display("[%0t] S2P: Detected READ addr=0x%04x err=%b, waiting for slave", $time,
                       dec_addr, err_i);
            end
          end
        end

        RESP_WAIT_SLAVE: begin
          // Wait for slave to respond with ready_i HIGH
          if (ready_i && !resp_busy) begin
            resp_start   <= 1'b1;
            resp_state_q <= RESP_SENDING;
            $display("[%0t] S2P: Starting response addr=0x%04x data=0x%02x err=%b", $time,
                     read_addr_q, rdata_i, err_q);
          end
        end

        RESP_SENDING: begin
          // Wait for response transmission to complete
          if (resp_done) begin
            resp_state_q <= RESP_IDLE;
            $display("[%0t] S2P: Response transmission complete", $time);
          end
        end

        default: resp_state_q <= RESP_IDLE;
      endcase
    end
  end

  always_comb begin
    resp_frame.start = 1'b1;
    // Use CMD_WRITE to signal error response, CMD_READ for normal response
    resp_frame.cmd = err_q ? CMD_WRITE : CMD_READ;
    resp_frame.addr = read_addr_q;  // Use saved address
    resp_frame.data = rdata_i;
    resp_frame.parity = ^{resp_frame.cmd, resp_frame.addr, resp_frame.data};
    resp_frame.stop = 1'b1;
  end

  assign valid_o = dec_valid;
  assign addr_o = dec_addr;
  assign wdata_o = dec_wdata;
  assign we_o = dec_we;
  assign sready_o = !svalid_i && !resp_busy;
  assign sdata_o = resp_sdata;
  assign sclk_resp_o = resp_sclk;
  assign svalid_resp_o = resp_busy;

endmodule
