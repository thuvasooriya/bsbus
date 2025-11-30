`timescale 1ns / 1ps

// =============================================================================
// bus_pkg.sv - Bit-Serial Bus System Package
// =============================================================================
// Description:
//   Package containing parameters, types, and utility functions for the
//   bit-serial bus system. Defines the 27-bit serial frame format, command
//   types, address map constants, and shared state enumerations.
//
// Frame Format (27 bits):
//   | START | CMD  | ADDR[13:0] | DATA[7:0] | PARITY | STOP |
//   |  1b   | 2b   |   14 bits  |  8 bits   |  1b    |  1b  |
//
// Memory Map:
//   Slave 0: 0x0000 - 0x0FFF (4KB, split-capable)
//   Slave 1: 0x1000 - 0x1FFF (4KB)
//   Slave 2: 0x2000 - 0x27FF (2KB)
//
// =============================================================================

package bus_pkg;

  // ---------------------------------------------------------------------------
  // Bus Configuration Parameters
  // ---------------------------------------------------------------------------
  parameter int unsigned ADDR_WIDTH = 14;       // Address bus width (16KB addressable)
  parameter int unsigned DATA_WIDTH = 8;        // Data bus width
  parameter int unsigned NUM_MASTERS = 2;       // Number of bus masters
  parameter int unsigned NUM_SLAVES = 3;        // Number of bus slaves

  // ---------------------------------------------------------------------------
  // Memory Map Constants
  // ---------------------------------------------------------------------------
  // NOTE: Sizes reduced for DE0-Nano fitting (22320 LEs available)
  // Original: 4KB/4KB/2KB = 10KB total, but Slave 0 async read prevents BRAM
  parameter int unsigned SLAVE0_BASE = 'h0000;  // Slave 0 base (split-capable)
  parameter int unsigned SLAVE0_SIZE = 'h0100;  // 256B (reduced from 4KB for fitting)
  parameter int unsigned SLAVE1_BASE = 'h0100;  // Slave 1 base
  parameter int unsigned SLAVE1_SIZE = 'h0100;  // 256B (reduced from 4KB for fitting)
  parameter int unsigned SLAVE2_BASE = 'h0200;  // Slave 2 base
  parameter int unsigned SLAVE2_SIZE = 'h0080;  // 128B (reduced from 2KB for fitting)

  // ---------------------------------------------------------------------------
  // Serial Frame Parameters
  // ---------------------------------------------------------------------------
  parameter int unsigned FRAME_WIDTH = 27;      // Total frame bits
  parameter int unsigned CMD_WIDTH = 2;         // Command field width
  parameter int unsigned SERIAL_CLK_DIV = 4;    // System clock divider for serial clock

  // ---------------------------------------------------------------------------
  // Command Types
  // ---------------------------------------------------------------------------
  // CMD[1:0] encoding for serial frame command field
  typedef enum logic [CMD_WIDTH-1:0] {
    CMD_READ           = 2'b00,  // Read request/response
    CMD_WRITE          = 2'b01,  // Write request
    CMD_SPLIT_START    = 2'b10,  // Split transaction start (slave busy)
    CMD_SPLIT_CONTINUE = 2'b11   // Split transaction continue (slave ready)
  } cmd_e;

  // ---------------------------------------------------------------------------
  // Serial Frame Structure
  // ---------------------------------------------------------------------------
  // Packed structure representing the 27-bit serial frame
  typedef struct packed {
    logic                  start;   // [26]    Start delimiter (always 1)
    cmd_e                  cmd;     // [25:24] Command type
    logic [ADDR_WIDTH-1:0] addr;    // [23:10] Address field
    logic [DATA_WIDTH-1:0] data;    // [9:2]   Data field
    logic                  parity;  // [1]     Even parity (CMD + ADDR + DATA)
    logic                  stop;    // [0]     Stop delimiter (always 1)
  } serial_frame_t;

  // ---------------------------------------------------------------------------
  // Frame State Machine States
  // ---------------------------------------------------------------------------
  // States for frame parsing/building FSMs
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

  // ---------------------------------------------------------------------------
  // Split Transaction Parameters
  // ---------------------------------------------------------------------------
  parameter int unsigned SPLIT_DELAY_CYCLES = 5;  // Default split delay

  // ---------------------------------------------------------------------------
  // Utility Functions
  // ---------------------------------------------------------------------------

  // calc_parity: Calculate even parity over CMD + ADDR + DATA fields
  // Inputs:
  //   cmd  - Command type (2 bits)
  //   addr - Address (14 bits)
  //   data - Data (8 bits)
  // Returns:
  //   1-bit even parity (XOR of all bits)
  function automatic logic calc_parity(input cmd_e cmd, input logic [ADDR_WIDTH-1:0] addr,
                                       input logic [DATA_WIDTH-1:0] data);
    logic [CMD_WIDTH+ADDR_WIDTH+DATA_WIDTH-1:0] combined;
    logic parity_bit;
    combined   = {cmd, addr, data};
    parity_bit = ^combined;
    return parity_bit;
  endfunction

endpackage