# bsbus

A bit-serial bus interconnect system designed for DE0-Nano FPGA boards, supporting 2 masters and 3 slaves with inter-board communication capability.

## Project Overview

A complete bit-serial bus interconnect system with **162 passing tests** across Verilator and Vivado xsim simulators. The design serializes parallel bus transactions into 27-bit frames transmitted over a 4-wire interface (sdata, sclk, svalid, sready).

### Key Features

- **27-bit serial frame**: START, CMD[1:0], ADDR[13:0], DATA[7:0], PARITY, STOP
- **Dual masters**: Priority-based, frame-atomic arbitration
- **Three slaves**: 4KB split-capable, 4KB, 2KB memory regions
- **Split transactions**: Slave 0 supports delayed responses
- **Error detection**: Even parity with automatic checking

## Directory Structure

```
bsbus/
├── rtl/                         # 9 RTL modules (~1500 lines)
│   ├── bus_pkg.sv              # Parameters, types, functions
│   ├── serializer.sv           # Shift register + clock divider
│   ├── deserializer.sv         # Frame capture + parity check
│   ├── tx_controller.sv        # Frame builder FSM
│   ├── frame_decoder.sv        # Command decoder FSM
│   ├── parallel_to_serial.sv   # Master adapter (parallel→serial)
│   ├── serial_to_parallel.sv   # Slave adapter (serial→parallel)
│   ├── serial_arbiter.sv       # Frame-atomic priority arbiter
│   ├── addr_decoder.sv         # 3-slave address decoder
│   ├── slave_mem.sv            # Memory slave (split-capable)
│   └── bitserial_top.sv        # System integration
├── tb/                         # 7 testbenches (81 tests)
├── fpga/                       # FPGA synthesis projects
│   ├── vivado/                 # Xilinx validation synthesis
│   └── quartus/                # DE0-Nano target synthesis
├── build/                      # Generated outputs
│   ├── logs/                   # Simulation logs
│   ├── waves/                  # Waveform dumps (FST/WDB)
│   └── obj_dir/                # Verilator objects
├── justfile                    # Build automation (35+ recipes)
└── README.md
```

## Serial Frame Format

```
┌─────────────────────────────────────────────────────────────────┐
│ START │ CMD │ ADDR[13:0] │ DATA[7:0] │ PARITY │ STOP │
│  1b   │ 2b  │   14 bits  │  8 bits   │  1b    │  1b  │
└─────────────────────────────────────────────────────────────────┘
    Total: 27 bits per transaction
```

### Command Types

- `00`: READ
- `01`: WRITE
- `10`: SPLIT_START
- `11`: SPLIT_CONTINUE

## Memory Map

| Slave | Address Range   | Size | Features         |
| ----- | --------------- | ---- | ---------------- |
| 0     | 0x0000 - 0x0FFF | 4KB  | Split-capable    |
| 1     | 0x1000 - 0x1FFF | 4KB  | Normal operation |
| 2     | 0x2000 - 0x27FF | 2KB  | Normal operation |

## Quick Start

### Prerequisites

**For Verilator simulation (Mac/Linux)**:

- [Verilator](https://verilator.org) 5.x
- [Just](https://github.com/casey/just) (command runner)
- [Verible](https://github.com/chipsalliance/verible) (optional, for formatting)

**For Vivado xsim (Linux only)**:

- Xilinx Vivado 2024.1+
- Set `VIVADO_SETTINGS` in justfile (default: `~/Xilinx/Vivado/2024.1/settings64.sh`)

**For Quartus synthesis (Linux only)**:

- Intel Quartus Prime 20.1+ Lite Edition
- See `fpga/quartus/README.md` for detailed setup

### Essential Commands

```bash
just                          # List all available commands
just setup                    # Create build directories
just lint                     # Check code style

# Run all Verilator tests (81 tests, ~5 seconds)
just sim-all

# Run all Vivado tests (requires Linux)
orb -s "just sim-vivado-all"  # Via orb on macOS
just sim-vivado-all           # Direct on Linux

# Synthesis
orb -s "just synth-vivado"    # Xilinx validation
orb -s "just synth-quartus"   # DE0-Nano target

just clean                    # Remove build artifacts
```

### Simulation (81 Tests per Simulator)

#### Verilator (Recommended for development)

```bash
# Individual module tests
just sim-serializer              # Basic serialization
just sim-deserializer            # Frame parsing (5 tests)
just sim-parallel-to-serial      # Master adapter (3 tests)
just sim-serial-to-parallel      # Slave adapter (5 tests)
just sim-addr-decoder            # Address decode (11 tests)
just sim-serial-arbiter          # Arbitration (21 tests)
just sim-bitserial-top           # Full system (35 tests)
```

**Output**: Logs to stdout, waveforms to `build/waves/*.fst` (view with GTKWave/surfer)

#### Vivado xsim (For synthesis validation)

**On macOS** (via orb remote execution):

```bash
orb -s "just sim-vivado-all"     # Run all 81 tests on Linux
```

**On Linux** (direct):

```bash
just sim-vivado-all              # Requires Vivado 2024.1
```

**Output**: Logs to `build/logs/xsim_*.log`, waveforms to `build/waves/*.wdb`

## Implementation Status

### RTL Implementation (Complete)

- **Core modules**: serializer, deserializer, tx_controller, frame_decoder
- **Adapters**: parallel_to_serial (master), serial_to_parallel (slave)
- **Infrastructure**: serial_arbiter, addr_decoder, slave_mem, bitserial_top
- **Total**: 9 synthesizable modules, ~1500 lines of SystemVerilog

### Verification (Complete - 162 Tests Passed)

**Verilator Simulations (Mac)**:

- 81/81 tests PASSED across 7 testbenches
- Waveform dumps: FST format in `build/waves/`

**Vivado xsim Simulations (Linux via orb)**:

- 81/81 tests PASSED across 7 testbenches
- Waveform dumps: WDB format in `build/waves/`

**Test Coverage**:

- Basic serialization/deserialization: PASS
- All command types (READ/WRITE/SPLIT_START/SPLIT_CONTINUE): PASS
- Parity error detection: PASS
- Priority arbitration: PASS
- Address decoding (3 slaves): PASS
- System integration (35 end-to-end scenarios): PASS

### FPGA Synthesis

#### Vivado 2024.1 (Xilinx Kintex-7 xc7k70t - Validation)

**Purpose**: Synthesis validation on Xilinx architecture

**Run**: `orb -s "just synth-vivado"` (on macOS via orb)

**Results**:

- **LUTs**: 3,051 / 41,000 (7.4%)
  - Logic: 491 LUTs
  - Distributed RAM: 2,560 LUTs (10KB memory)
- **Registers**: 514 / 82,000 (0.6%)
- **Block RAM**: 0 (memory uses Distributed RAM)
- **Status**: Synthesis successful, 0 errors

**Note**: Memory infers as Distributed RAM due to single-cycle read requirement. This is functionally correct for small memories (10KB total).

**Reports**: `build/vivado/utilization_synth.rpt`, `build/vivado/timing_synth.rpt`

#### Quartus Prime (Cyclone IV E EP4CE22F17C6 - DE0-Nano Target)

**Purpose**: Production synthesis for DE0-Nano FPGA board

**Setup**:

```bash
cd fpga/quartus
# Review project files
cat bitserial.qsf  # Pin assignments and device settings
cat bitserial.sdc  # Timing constraints
cat README.md      # Detailed setup guide
```

**Run**: `orb -s "just synth-quartus"` (requires Quartus installation)

**Expected Resources** (based on Vivado results):

- **Logic Elements**: ~3,000 / 22,320 (13%)
- **Registers**: ~500 / 82,000 (0.6%)
- **Memory**: Distributed RAM or M9K blocks (vendor-dependent)
- **Fmax Target**: 50 MHz system clock

**Pin Assignments**:

- System clock: PIN_R8 (50 MHz oscillator)
- Reset: PIN_J15 (KEY0 pushbutton)
- Master I/O: Switches and LEDs (see `.qsf` file)
- Inter-board GPIO: Reserved (GPIO_0 pins [7:0])

**Output**: `fpga/quartus/output_files/bitserial.sof` (FPGA programming file)

**Programming**: `orb -s "just quartus-program"` (requires USB Blaster)

See `fpga/quartus/README.md` for comprehensive Quartus setup, pin assignments, and troubleshooting.

### Remaining Work

- [ ] Inter-board link module (CDC, GPIO interface)
- [ ] Physical hardware testing on DE0-Nano
- [ ] Inter-board demo with second team
- [ ] Optional: Add pipelined memory interface for Block RAM inference

## Technical Specifications

- **System Clock**: 50 MHz
- **Serial Clock**: 12.5 MHz (CLK/4)
- **Frame Duration**: 108 system clocks (27 bits × 4 clocks/bit)
- **Target FPGA**: Cyclone IV E (EP4CE22F17C6) - DE0-Nano Board
- **Xilinx Resources** (Kintex-7): 3,051 LUTs, 514 FFs, 0 BRAMs
- **Expected Cyclone IV**: ~3,000 LEs, 514 FFs, 0-3 M9K blocks

## Build System (Just)

The project uses [Just](https://github.com/casey/just) for build automation. Key recipes:

```bash
just setup              # Create build directories
just lint              # Verible linting
just format            # Auto-format RTL files
just clean             # Remove build artifacts

# Verilator simulation
just sim-<module>      # Run specific module test
just waves-<module>    # Open waveform viewer

# Vivado simulation (Linux)
just sim-vivado-<module>     # Vivado xsim simulation
just sim-vivado-all          # All Vivado tests

# FPGA synthesis (Linux)
just synth-vivado            # Xilinx validation
just synth-quartus           # DE0-Nano synthesis
just quartus-gui             # Open Quartus GUI
just quartus-program         # Program FPGA via USB Blaster
just quartus-clean           # Clean Quartus build files
```

Run `just` without arguments to see all available recipes.

## Development Notes

- **Coding Style**: Follows lowRISC Verilog style guide
- **Reset Strategy**: Asynchronous active-low reset (rst_ni)
- **Clock Strategy**: Synchronous design, single clock domain (inter-board CDC pending)
- **Naming**: snake_case for signals, CamelCase for modules
- **Documentation**: All modules have header comments with I/O descriptions

## References

- [DE0-Nano User Manual](https://www.terasic.com.tw/cgi-bin/page/archive.pl?No=593)
- [Cyclone IV Device Handbook](https://www.intel.com/content/www/us/en/programmable/documentation/lit-index.html)
- [lowRISC Verilog Coding Style](refs/VerilogCodingStyle.md)
