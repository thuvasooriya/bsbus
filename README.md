# bsbus

Bit-serial bus system for DE0-Nano FPGA with 2 masters, 3 slaves, and split transaction support.

## Overview

- **27-bit serial frame**: START[1] CMD[2] ADDR[14] DATA[8] PARITY[1] STOP[1]
- **2 Masters**: Priority-based arbitration (M0 > M1)
- **3 Slaves**: 4KB (split-capable), 4KB, 2KB
- **113 tests passing** on Verilator and Vivado xsim

## Directory Structure

```
bsbus/
├── rtl/                    # 11 RTL modules
├── tb/                     # 7 testbenches
├── fpga/                   # FPGA projects (quartus/, vivado/)
├── report/                 # Typst report and diagrams
├── docs/                   # Technical documentation
└── justfile                # Build automation
```

## Memory Map

| Slave | Address Range     | Size | Notes         |
|-------|-------------------|------|---------------|
| 0     | 0x0000 - 0x0FFF   | 4KB  | Split-capable |
| 1     | 0x1000 - 0x1FFF   | 4KB  |               |
| 2     | 0x2000 - 0x27FF   | 2KB  |               |

## Quick Start

```bash
just setup              # Create build directories
just sim-all            # Run all Verilator tests (113 tests)
just lint               # Check code style
just report             # Compile typst report to PDF
just clean              # Remove build artifacts
```

## Simulation

### Verilator (Mac/Linux)

```bash
just sim-serializer
just sim-deserializer
just sim-parallel-to-serial
just sim-serial-to-parallel
just sim-addr-decoder
just sim-serial-arbiter
just sim-bitserial-top
just sim-all
```

### Vivado xsim (Linux via orb)

```bash
orb run bash -c "cd $(pwd) && source ~/Xilinx/Vivado/2024.1/settings64.sh && ..."
```

## Test Results

| Module | Tests | Status |
|--------|-------|--------|
| serializer_tb | 8 | PASS |
| deserializer_tb | 5 | PASS |
| parallel_to_serial_tb | 3 | PASS |
| serial_to_parallel_tb | 5 | PASS |
| addr_decoder_tb | 18 | PASS |
| serial_arbiter_tb | 39 | PASS |
| bitserial_top_tb | 35 | PASS |
| **Total** | **113** | **ALL PASS** |

## Report

```bash
just report             # Compile report/main.typ to PDF
just report-watch       # Watch mode for live updates
just report-diagrams    # Regenerate timing diagrams
```

Output: `report/main.pdf` (77 pages with full RTL code)

## Deferred Tasks

1. FPGA synthesis and programming (Intel Quartus, DE0-Nano)
2. Inter-board transmission demo with another group
3. Demo preparation for Dec 3rd

## Technical Specs

- System clock: 50 MHz
- Serial clock: 12.5 MHz (CLK/4)
- Frame duration: 108 system clocks
- Target: Cyclone IV EP4CE22F17C6 (DE0-Nano)

## References

- [DE0-Nano User Manual](https://www.terasic.com.tw/cgi-bin/page/archive.pl?No=593)
- [lowRISC Verilog Style Guide](refs/VerilogCodingStyle.md)