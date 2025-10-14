`timescale 1ns / 1ps

package bus_pkg;

  parameter int unsigned ADDR_WIDTH = 14;
  parameter int unsigned DATA_WIDTH = 8;
  parameter int unsigned NUM_MASTERS = 2;
  parameter int unsigned NUM_SLAVES = 3;

  parameter int unsigned SLAVE0_BASE = 'h0000;
  parameter int unsigned SLAVE0_SIZE = 'h1000;
  parameter int unsigned SLAVE1_BASE = 'h1000;
  parameter int unsigned SLAVE1_SIZE = 'h1000;
  parameter int unsigned SLAVE2_BASE = 'h2000;
  parameter int unsigned SLAVE2_SIZE = 'h0800;

  parameter int unsigned FRAME_WIDTH = 27;
  parameter int unsigned CMD_WIDTH = 2;
  parameter int unsigned SERIAL_CLK_DIV = 4;

  typedef enum logic [CMD_WIDTH-1:0] {
    CMD_READ           = 2'b00,
    CMD_WRITE          = 2'b01,
    CMD_SPLIT_START    = 2'b10,
    CMD_SPLIT_CONTINUE = 2'b11
  } cmd_e;

  typedef struct packed {
    logic                  start;
    cmd_e                  cmd;
    logic [ADDR_WIDTH-1:0] addr;
    logic [DATA_WIDTH-1:0] data;
    logic                  parity;
    logic                  stop;
  } serial_frame_t;

  typedef enum logic [2:0] {
    STATE_IDLE,
    STATE_START,
    STATE_CMD,
    STATE_ADDR,
    STATE_DATA,
    STATE_PARITY,
    STATE_STOP,
    STATE_DONE
  } frame_state_e;

  function automatic logic calc_parity(input cmd_e cmd, input logic [ADDR_WIDTH-1:0] addr,
                                       input logic [DATA_WIDTH-1:0] data);
    logic [CMD_WIDTH+ADDR_WIDTH+DATA_WIDTH-1:0] combined;
    logic parity_bit;
    combined   = {cmd, addr, data};
    parity_bit = ^combined;
    return parity_bit;
  endfunction

endpackage
