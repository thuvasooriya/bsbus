# Agent Roles and Responsibilities - Bit-Serial Bus System

## Agent Overview

This document defines the specialized agent roles for implementing the bit-serial bus system. Each agent has specific responsibilities and expertise areas.

1. **Architecture Agent** - System design and serial protocol definition
2. **RTL Agent** - Hardware implementation in SystemVerilog
3. **Verification Agent** - Testbench and validation
4. **Integration Agent** - FPGA flows and board integration
5. **Documentation Agent** - Technical writing and reporting

---

## 1. Architecture Agent

**Role**: Define bit-serial bus architecture and inter-board protocol

**Responsibilities**:

- Design 27-bit serial frame format (START/CMD/ADDR/DATA/PARITY/STOP)
- Define 4-wire serial bus interface (sdata, sclk, svalid, sready)
- Specify timing for serial clock generation (CLK/4)
- Design inter-board handshake protocol
- Define address mapping (4KB split-capable, 4KB, 2KB)
- Create block diagrams for serial system
- Specify CDC strategy for GPIO pins

**Key Deliverables**:

- Serial protocol specification document
- Inter-board connection diagram
- Timing diagrams for serial transactions
- Block diagram with serial adapters
- DE0-Nano pin assignment plan

**Design Principles**:

- Reuse parallel bus components where possible
- Add serializer/deserializer adapters as bridges
- Ensure frame-atomic arbitration
- Design for reliable inter-board communication
- Consider DE0-Nano resource constraints

---

## 2. RTL Agent

**Role**: Implement bit-serial hardware in SystemVerilog

**Responsibilities**:

- Implement `parallel_to_serial.sv` (master adapter)
  - Frame builder with START/STOP delimiters
  - Shift register serializer
  - Parity generator (even parity)
  - TX controller FSM
- Implement `serial_to_parallel.sv` (slave adapter)
  - Shift register deserializer
  - Frame parser FSM
  - Parity checker with error detection
  - Response frame generator
- Modify `serial_arbiter.sv` for frame-atomic grants
- Implement `interboard_link.sv` for board-to-board
  - 2-FF synchronizers for CDC
  - Handshake controller
  - Optional FIFOs for buffering
- Reuse from parallel bus: `slave_mem.sv`, `addr_decoder.sv`
- Follow lowRISC Verilog style guide
- Ensure synthesizable, FPGA-optimized code

**Key Deliverables**:

- `rtl/bitserial_top.sv` - Top-level integration
- `rtl/parallel_to_serial.sv` + sub-modules
- `rtl/serial_to_parallel.sv` + sub-modules
- `rtl/serial_arbiter.sv`
- `rtl/interboard_link.sv` + CDC modules
- `rtl/bus_pkg.sv` - Parameters and types

**Coding Standards**:

- Follow `refs/VerilogCodingStyle.md`
- Async reset (active-low), posedge clocks
- Proper signal naming (snake_case)
- Commented I/O definitions
- No latches or combinational loops
- Use `timescale 1ns/1ps` in all modules

---

## 3. Verification Agent

**Role**: Verify serial bus and inter-board communication

**Responsibilities**:

- Create module testbenches:
  - `serializer_tb.sv` - Frame generation, parity
  - `deserializer_tb.sv` - Frame parsing, error detection
  - `parallel_to_serial_tb.sv` - Master adapter end-to-end
  - `serial_to_parallel_tb.sv` - Slave adapter end-to-end
  - `serial_arbiter_tb.sv` - Frame-atomic arbitration
  - `addr_decoder_tb.sv` - Address decoding
  - `interboard_link_tb.sv` - CDC, handshake protocol
- Create system testbench:
  - `bitserial_top_tb.sv` - End-to-end serial transactions
- Implement test scenarios:
  1. Reset test
  2. Single master write (all slaves)
  3. Single master read (all slaves)
  4. Arbitration (both masters request)
  5. Split transaction (Slave 0)
  6. Back-to-back transactions
  7. Address decode error
  8. Parity error injection
  9. Inter-board loopback
  10. Dual-board simulation
- Generate waveforms for documentation
- Follow lowRISC DV coding style

**Key Deliverables**:

- Module-level testbenches
- System testbench (`bitserial_top_tb.sv`)
- FST waveforms for all tests
- Test result summary document

**Verification Standards**:

- Use Verilator-compatible constructs only
- Clear PASS/FAIL reporting
- Waveform dumps for debugging (FST format)
- Coverage: all slaves, all commands, errors
- **CRITICAL: Always use timeouts in testbenches to prevent infinite wait times**
  - Use `wait()` with timeout counters
  - Add watchdog timers for frame completion
  - Example: `repeat(TIMEOUT_CYCLES) @(posedge clk); if (!done) $error("TIMEOUT");`
  - Default timeout: 1000-5000 cycles depending on operation
  - Never use bare `wait()` or `@(posedge signal)` without timeout protection
- **Always run Verilator simulations with 20s timeout** (handled in justfile)
  - Simulations should complete quickly (< 1 second typically)
  - If halted by timeout, indicates infinite loop or timing issue
  - Investigate testbench logic, FSM states, and wait conditions

---

## 4. Integration Agent

**Role**: FPGA synthesis and inter-board demo

**Responsibilities**:

- Verilator simulation setup (Mac)
- Quartus synthesis for DE0-Nano
- Create `bitserial.qsf` with EP4CE22F17C6 settings
- Pin assignments:
  - System clock (PIN_R8)
  - Reset button (PIN_J15)
  - Demo switches/LEDs
  - GPIO_0 bank for inter-board (8 pins)
- Timing constraints (SDC file):
  - 50 MHz system clock
  - 12.5 MHz serial clock (derived)
  - GPIO I/O delays
  - CDC false paths
- Program both DE0-Nano boards
- Validate inter-board communication
- Resource utilization analysis

**Key Deliverables**:

- `fpga/quartus/bitserial.qpf/.qsf` - Quartus project
- `fpga/quartus/bitserial.sdc` - Timing constraints
- `fpga/quartus/compile.tcl` - Build script
- Synthesis reports (resource usage, Fmax)
- FPGA bitstream (.sof file)
- Demo setup guide

**Tool Constraints**:

- Verilator: `/Users/tony/arc/dev/archive/sort/verilator/zig-out/bin/verilator`
- Quartus: Standard installation (20.1 Lite Edition)

**FPGA Target**: Altera DE0-Nano Board

- Device: Cyclone IV E EP4CE22F17C6
- Resources: 22,320 LEs, 66 M9K blocks
- Clock: 50 MHz onboard oscillator
- GPIO: GPIO_0 bank for inter-board link

---

## 5. Documentation Agent

**Role**: Create technical documentation and report

**Responsibilities**:

- Write functional descriptions:
  - Bit-serial protocol overview
  - Frame format and timing
  - Serializer/deserializer operation
  - Inter-board communication protocol
  - Arbiter modifications
- Document I/O definitions for all modules
- Generate timing diagrams:
  - Serial frame structure
  - Read/write transactions
  - Split transactions
  - Inter-board handshake
  - Arbitration scenarios
- Create block diagrams
- Document test results and coverage
- Create demo operation guide
- Compile final report

**Key Deliverables**:

- `docs/functional_description.md`
- `docs/io_definitions.md`
- `docs/timing_diagrams.md`
- `docs/block_diagrams.md`
- `docs/interboard_protocol.md`
- `docs/demo_guide.md`
- `REPORT.pdf` - Final submission

**Report Structure**:

1. Introduction
2. Serial Protocol Specification
3. Functional Descriptions
4. I/O Definitions
5. Timing Diagrams
6. RTL Code
7. Testbench and Results
8. FPGA Implementation
9. Conclusion

---

## Cross-Agent Communication

**Architecture → RTL**:

- Serial frame format specification
- Interface definitions (4-wire bus)
- Timing parameters (clock divider ratio)
- CDC strategy

**RTL → Verification**:

- Module interfaces
- Frame format details
- Expected behavior for error cases
- CDC timing constraints

**RTL → Integration**:

- Complete RTL file list
- Clock generation requirements
- GPIO pin requirements
- Resource estimates

**Verification → Documentation**:

- Test results and pass/fail status
- Waveforms for timing diagrams
- Error cases and handling
- Inter-board test results

**Integration → Documentation**:

- Synthesis reports
- Resource utilization
- Fmax achieved
- Demo setup and results

---

## Implementation Strategy

**Phase 1: Architecture & Planning**

1. Define serial frame format
2. Design 4-wire bus interface
3. Plan inter-board connection
4. Create block diagrams

**Phase 2: RTL Implementation**

1. Implement serializer + tx_controller
2. Implement deserializer + frame_decoder
3. Modify arbiter for frame-atomic grants
4. Integrate with reused parallel modules
5. Implement interboard_link with CDC

**Phase 3: Verification**

1. Module-level tests (serializer, deserializer, arbiter, interboard)
2. System-level tests (bitserial_top)
3. Loopback test (TX→RX single board)
4. Generate waveforms

**Phase 4: FPGA Integration**

1. Verilator simulation validation
2. Quartus synthesis for DE0-Nano
3. Program single board, test loopback
4. Program two boards, test inter-board
5. Demo with other team's board

**Phase 5: Documentation**

1. Collect all artifacts
2. Generate diagrams
3. Write report sections
4. Create demo video/photos
5. Final review and submission

---

## Success Criteria

**RTL Quality**:

- [ ] Synthesizes on DE0-Nano
- [ ] Follows lowRISC style guidelines
- [ ] Clean lint/syntax checks
- [ ] Resource usage < 20% LEs
- [ ] Achieves 50 MHz system clock

**Verification Coverage**:

- [ ] All module tests pass
- [ ] System tests pass (10 scenarios)
- [ ] Parity error detection verified
- [ ] Inter-board loopback works
- [ ] Timing diagrams generated
- [ ] All testbenches have timeout protection

**FPGA Demo**:

- [ ] Single-board loopback functional
- [ ] Two-board communication works
- [ ] Meets timing constraints (50 MHz)
- [ ] Communicates with other team's board
- [ ] Demo-ready with switches/LEDs

**Documentation**:

- [ ] Complete functional descriptions
- [ ] I/O definitions documented
- [ ] Timing diagrams included
- [ ] Block diagrams clear
- [ ] Inter-board protocol documented
- [ ] RTL and testbench code presented
- [ ] Demo guide complete
- [ ] Professional report formatting

---

## Notes

- Reuse as much as possible from parallel bus design
- Focus effort on serial adapters and inter-board link
- Test single-board loopback before inter-board
- Coordinate with other team for inter-board testing
- Keep GPIO connections short for signal integrity
- Document any deviations from original plan

---

## **CRITICAL RULES**

NEVER use emojis in code
NEVER use emojis in docs
NEVER use emojis anywhere
You CAN use symbols if needed

### Git Operations

**NEVER use destructive git commands without explicit user permission:**

- ❌ `git checkout <file>` - Destroys uncommitted changes
- ❌ `git reset --hard` - Destroys uncommitted changes
- ❌ `git clean -f` - Deletes untracked files
- ❌ `git restore <file>` - Destroys uncommitted changes
- ❌ `git reset` (any form that discards work)

**Safe alternatives:**

- ✅ `git stash` - Preserves changes temporarily
- ✅ `git diff` - Review changes before deciding
- ✅ `git status` - Check what will be affected
- ✅ Ask user before any operation that discards work

**If you accidentally destroy work, immediately:**

1. Stop and inform the user
2. Check `git reflog` for recovery options
3. Apologize and help restore from any available source

### Testbench Timeout Requirements

**ALWAYS implement timeout protection in testbenches:**

- Never use bare `wait()` statements without timeout
- Use timeout counters for all blocking operations
- Default timeout: 1000-5000 cycles
- Always report timeout with clear error message
- Verilator simulations have 20s execution timeout (in justfile)

---

## Deferred Tasks

The following tasks are pending and should be completed before the demo (scheduled: Wed, Dec 3rd):

1. **FPGA Synthesis and Programming**
   - Run elaboration and synthesis in Intel Quartus for DE0-Nano (EP4CE22F17C6)
   - Verify timing closure at 50 MHz
   - Program the design to DE0-Nano board
   - Test basic functionality on hardware

2. **Inter-Board Transmission Demo**
   - Coordinate with another group for inter-board communication testing
   - Connect GPIO pins between two DE0-Nano boards
   - Verify serial frame transmission/reception across boards
   - Document any protocol adjustments needed for interoperability

3. **Demo Preparation**
   - Prepare step-by-step demo guide with expected outputs
   - Document switch/LED mappings for demo
   - Create test scenarios to demonstrate during evaluation
   - Prepare backup plan if inter-board demo fails (single-board loopback)
