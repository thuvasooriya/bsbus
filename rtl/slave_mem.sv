/* verilator lint_off WIDTHTRUNC */

// =============================================================================
// slave_mem.sv - Memory Slave with Split Transaction Support
// =============================================================================
// Description:
//   Parameterized memory slave module for the bit-serial bus system. Provides
//   single-cycle read/write access to internal memory. Slave 0 (4KB) supports
//   split transactions where the slave can delay its response.
//
// Split Transaction Operation:
//   1. Master sends READ request to Slave 0
//   2. If split_start_i is asserted, slave enters split mode
//   3. Slave asserts split_busy_o (ready_o stays low)
//   4. After SPLIT_DELAY_CYCLES, slave provides data and asserts split_ready_o
//   5. Master completes transaction with split_continue
//
// I/O Definitions:
//   Inputs:
//     clk_i           - System clock (posedge triggered)
//     rst_ni          - Asynchronous reset (active low)
//     valid_i         - Transaction valid from address decoder
//     addr_i[13:0]    - Local address (offset within this slave)
//     wdata_i[7:0]    - Write data
//     we_i            - Write enable (1=write, 0=read)
//     split_start_i   - Initiate split transaction (Slave 0 only)
//
//   Outputs:
//     ready_o         - Transaction complete (data valid for reads)
//     rdata_o[7:0]    - Read data
//     err_o           - Error (address out of range)
//     split_busy_o    - Split transaction in progress
//     split_ready_o   - Split transaction data ready
//
// Parameters:
//     MEM_SIZE        - Memory size in bytes (default 4096)
//     SPLIT_CAPABLE   - Enable split transaction support (default 0)
//
// Timing:
//   Write: Single cycle (valid_i + we_i -> ready_o next cycle)
//   Read:  Single cycle (valid_i + !we_i -> ready_o + rdata_o next cycle)
//   Split: SPLIT_DELAY_CYCLES after split_start_i
//
// =============================================================================

module slave_mem
  import bus_pkg::*;
#(
    parameter int unsigned MEM_SIZE = 4096,
    parameter bit SPLIT_CAPABLE = 0
) (
    // Clock and Reset
    input logic clk_i,              // System clock
    input logic rst_ni,             // Asynchronous reset (active low)

    // Transaction Interface
    input  logic                  valid_i,       // Transaction valid
    input  logic [ADDR_WIDTH-1:0] addr_i,        // Local address
    input  logic [DATA_WIDTH-1:0] wdata_i,       // Write data
    input  logic                  we_i,          // Write enable
    output logic                  ready_o,       // Transaction ready
    output logic [DATA_WIDTH-1:0] rdata_o,       // Read data
    output logic                  err_o,         // Address error

    // Split Transaction Interface
    input  logic split_start_i,     // Start split transaction
    output logic split_busy_o,      // Split in progress
    output logic split_ready_o      // Split data ready
);

  // ---------------------------------------------------------------------------
  // Local Parameters
  // ---------------------------------------------------------------------------
  localparam int unsigned MEM_DEPTH = MEM_SIZE;
  localparam int unsigned ADDR_BITS = $clog2(MEM_DEPTH);

  // ---------------------------------------------------------------------------
  // Memory Array
  // ---------------------------------------------------------------------------
  logic [DATA_WIDTH-1:0] mem [MEM_DEPTH];

  // ---------------------------------------------------------------------------
  // Internal Signals
  // ---------------------------------------------------------------------------
  logic [ADDR_BITS-1:0] local_addr;
  logic                 addr_valid;

  // Split transaction state
  logic                 split_pending_q;
  logic [ADDR_BITS-1:0] split_addr_q;
  logic [2:0]           split_delay_q;

  // ---------------------------------------------------------------------------
  // Address Validation
  // ---------------------------------------------------------------------------
  assign local_addr = addr_i[ADDR_BITS-1:0];
  assign addr_valid = (addr_i < MEM_SIZE);

  // ---------------------------------------------------------------------------
  // Split Busy Signal
  // ---------------------------------------------------------------------------
  assign split_busy_o = split_pending_q;

  // ---------------------------------------------------------------------------
  // Main Sequential Logic
  // ---------------------------------------------------------------------------
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
      // Default: clear single-cycle outputs
      ready_o       <= 1'b0;
      err_o         <= 1'b0;
      split_ready_o <= 1'b0;

      // Split transaction handling (only if SPLIT_CAPABLE)
      if (SPLIT_CAPABLE && split_pending_q) begin
        // Count down split delay
        if (split_delay_q > 0) begin
          split_delay_q <= split_delay_q - 1;
          $display("[%0t] SLAVE_MEM: Split delay countdown: %0d", $time, split_delay_q - 1);
        end else begin
          // Split complete: provide data
          rdata_o         <= mem[split_addr_q];
          split_ready_o   <= 1'b1;
          ready_o         <= 1'b1;
          split_pending_q <= 1'b0;
          $display("[%0t] SLAVE_MEM: Split complete, returning data 0x%02x from addr 0x%03x",
                   $time, mem[split_addr_q], split_addr_q);
        end
      end else if (valid_i) begin
        // Normal transaction handling
        if (!addr_valid) begin
          // Address out of range: error response
          err_o   <= 1'b1;
          ready_o <= 1'b1;
          $display("[%0t] SLAVE_MEM: Address error - 0x%04x out of range", $time, addr_i);
        end else if (we_i) begin
          // Write transaction
          mem[local_addr] <= wdata_i;
          ready_o         <= 1'b1;
          $display("[%0t] SLAVE_MEM: Write 0x%02x to addr 0x%03x", $time, wdata_i, local_addr);
        end else begin
          // Read transaction
          if (SPLIT_CAPABLE && split_start_i) begin
            // Split read: defer response
            split_pending_q <= 1'b1;
            split_addr_q    <= local_addr;
            split_delay_q   <= 3'(SPLIT_DELAY_CYCLES);
            ready_o         <= 1'b0;  // Not ready yet
            $display("[%0t] SLAVE_MEM: Split transaction started for addr 0x%03x, delay=%0d",
                     $time, local_addr, SPLIT_DELAY_CYCLES);
          end else begin
            // Normal read: immediate response
            rdata_o <= mem[local_addr];
            ready_o <= 1'b1;
            $display("[%0t] SLAVE_MEM: Read 0x%02x from addr 0x%03x", $time, mem[local_addr],
                     local_addr);
          end
        end
      end
    end
  end

endmodule
