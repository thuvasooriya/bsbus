// =============================================================================
// serial_arbiter.sv - Priority-Based Frame-Atomic Bus Arbiter
// =============================================================================
// Description:
//   Priority-based arbiter for the bit-serial bus system. Grants bus access
//   to one of two masters with Master 0 having higher priority. Supports
//   frame-atomic arbitration (no switching during active frame) and split
//   transactions where a slave can indicate it needs more time.
//
// Features:
//   - Priority arbitration: Master 0 > Master 1
//   - Frame-atomic grants: No master switching during frame transmission
//   - Split transaction support: Maintains owner across split operations
//
// I/O Definitions:
//   Inputs:
//     clk_i           - System clock (posedge triggered)
//     rst_ni          - Asynchronous reset (active low)
//     req_i[1:0]      - Master request signals (bit 0 = M0, bit 1 = M1)
//     frame_active_i  - Indicates frame transmission in progress
//     split_start_i   - Slave indicates split transaction start
//     split_done_i    - Slave indicates split transaction complete
//
//   Outputs:
//     gnt_o[1:0]      - Grant signals (bit 0 = M0, bit 1 = M1)
//     msel_o          - Master select (0 = M0, 1 = M1)
//     split_pending_o - Split transaction in progress
//     split_owner_o   - Master that initiated split (one-hot)
//
// State Machine:
//   ARB_IDLE   -> ARB_MASTER0 (if req_i[0])
//              -> ARB_MASTER1 (if req_i[1] and !req_i[0])
//              -> ARB_SPLIT   (if split_pending)
//   ARB_MASTER0 -> ARB_IDLE   (when !frame_active and !req_i[0])
//               -> ARB_SPLIT  (when split_start)
//   ARB_MASTER1 -> ARB_IDLE   (when !frame_active and !req_i[1])
//               -> ARB_SPLIT  (when split_start)
//   ARB_SPLIT  -> ARB_IDLE    (when split_done and !frame_active)
//
// =============================================================================

module serial_arbiter
  import bus_pkg::*;
(
    // Clock and Reset
    input logic clk_i,          // System clock
    input logic rst_ni,         // Asynchronous reset (active low)

    // Master Request/Grant Interface
    input  logic [1:0] req_i,   // Master request signals [1:0]
    output logic [1:0] gnt_o,   // Master grant signals [1:0]

    // Frame Control
    input logic frame_active_i, // Frame transmission in progress

    // Split Transaction Interface
    input  logic       split_start_i,    // Slave starts split transaction
    input  logic       split_done_i,     // Slave completes split transaction
    output logic       msel_o,           // Master select (0=M0, 1=M1)
    output logic       split_pending_o,  // Split transaction pending
    output logic [1:0] split_owner_o     // Master that owns split (one-hot)
);

  // ---------------------------------------------------------------------------
  // State Machine Definition
  // ---------------------------------------------------------------------------
  typedef enum logic [1:0] {
    ARB_IDLE,     // No active grant
    ARB_MASTER0,  // Master 0 has bus
    ARB_MASTER1,  // Master 1 has bus
    ARB_SPLIT     // Split transaction in progress
  } arb_state_e;

  arb_state_e state_d, state_q;
  logic [1:0] split_owner_d, split_owner_q;
  logic split_pending_d, split_pending_q;

  // ---------------------------------------------------------------------------
  // Combinational Logic
  // ---------------------------------------------------------------------------
  always_comb begin
    // Default: hold current state
    state_d = state_q;
    split_owner_d = split_owner_q;
    split_pending_d = split_pending_q;
    gnt_o = 2'b00;
    msel_o = 1'b0;

    // State machine
    case (state_q)
      ARB_IDLE: begin
        // Check if split is pending - split owner gets priority
        if (split_pending_q) begin
          state_d = ARB_SPLIT;
        end else if (req_i[0]) begin
          // Master 0 has priority
          state_d = ARB_MASTER0;
        end else if (req_i[1]) begin
          state_d = ARB_MASTER1;
        end
      end

      ARB_MASTER0: begin
        // Check for split start
        if (split_start_i && !split_pending_q) begin
          split_pending_d = 1'b1;
          split_owner_d = 2'b01;
          state_d = ARB_SPLIT;
        end else if (!frame_active_i && !req_i[0]) begin
          // Master 0 released request and no frame active
          state_d = ARB_IDLE;
        end
        // Otherwise stay in MASTER0 state
      end

      ARB_MASTER1: begin
        // Check for split start
        if (split_start_i && !split_pending_q) begin
          split_pending_d = 1'b1;
          split_owner_d = 2'b10;
          state_d = ARB_SPLIT;
        end else if (!frame_active_i && !req_i[1]) begin
          // Master 1 released request and no frame active
          state_d = ARB_IDLE;
        end
        // Otherwise stay in MASTER1 state
      end

      ARB_SPLIT: begin
        // Handle split done - clear pending and owner
        if (split_done_i) begin
          split_pending_d = 1'b0;
          split_owner_d = 2'b00;
          // Immediately transition to IDLE when split done and no frame active
          if (!frame_active_i) begin
            state_d = ARB_IDLE;
          end
        end else if (!split_pending_q && !frame_active_i) begin
          // Not pending and no frame - go to IDLE
          state_d = ARB_IDLE;
        end
      end

      default: begin
        state_d = ARB_IDLE;
        split_pending_d = 1'b0;
        split_owner_d = 2'b00;
      end
    endcase

    // Generate gnt_o and msel_o based on NEXT state for 0-cycle grant latency
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
        // In split state, grant to split owner
        if (split_owner_d[0] || split_owner_q[0]) begin
          gnt_o  = 2'b01;
          msel_o = 1'b0;
        end else if (split_owner_d[1] || split_owner_q[1]) begin
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

  // ---------------------------------------------------------------------------
  // Sequential Logic
  // ---------------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= ARB_IDLE;
      split_owner_q <= 2'b00;
      split_pending_q <= 1'b0;
    end else begin
      state_q <= state_d;
      split_owner_q <= split_owner_d;
      split_pending_q <= split_pending_d;
    end
  end

  // ---------------------------------------------------------------------------
  // Output Assignments
  // ---------------------------------------------------------------------------
  assign split_pending_o = split_pending_q;
  assign split_owner_o   = split_owner_q;

endmodule
