# Bit-Serial Bus System - Technical Specification

## Project Overview

This document specifies the design of a **bit-serial bus interconnect system** that connects 2 masters and 3 slaves with inter-board communication capability. The design follows the assignment requirements and enables two DE0-Nano FPGA boards to transfer data via serial communication.

### Key Objectives

- Design a **bit-serial bus** (data transferred one bit at a time)
- Support **2 masters** and **3 slaves** (4KB split-capable, 4KB, 2KB)
- Implement **priority-based arbitration** with **split transaction** support
- Enable **inter-board communication** between two DE0-Nano FPGAs
- Meet FPGA resource constraints on DE0-Nano (Cyclone IV E)
- Demonstrate functional operation with other team's board

---

## System Architecture

### 1. Serial Bus Protocol

Unlike the parallel bus (14-bit address + 8-bit data simultaneously), the bit-serial bus transmits data sequentially:

#### Serial Frame Format

```
┌─────────────────────────────────────────────────────────────────┐
│ START │ CMD │ ADDR[13:0] │ DATA[7:0] │ PARITY │ STOP │
│  1b   │ 2b  │   14 bits  │  8 bits   │  1b    │  1b  │
└─────────────────────────────────────────────────────────────────┘
    Total: 27 bits per transaction
```

**Field Definitions:**

- **START** (1 bit): Transaction start delimiter (always `1`)
- **CMD** (2 bits): Command type
  - `00`: READ
  - `01`: WRITE
  - `10`: SPLIT_START (slave not ready)
  - `11`: SPLIT_CONTINUE (slave data ready)
- **ADDR** (14 bits): Address field (MSB first)
- **DATA** (8 bits): Write data or read response (MSB first)
- **PARITY** (1 bit): Even parity over CMD+ADDR+DATA
- **STOP** (1 bit): Transaction end delimiter (always `1`)

#### Timing Characteristics

```
Serial Clock (SCLK): Derived from system clock
  - Default: System_CLK / 4 (12.5 MHz for 50 MHz system)
  - Configurable divider for inter-board communication

Bit Period: 4 system clock cycles
  - Sample on rising edge of SCLK
  - Stable on falling edge of SCLK
```

---

### 2. System Block Diagram

```
┌────────────────────────────────────────────────────────────────────┐
│                      BIT-SERIAL BUS SYSTEM                         │
│                                                                    │
│  ┌─────────┐  ┌─────────┐                                          │
│  │ Master0 │  │ Master1 │  (Parallel Interface)                    │
│  └────┬────┘  └────┬────┘                                          │
│       │            │                                               │
│  ┌────▼────────────▼──────────────┐                                │
│  │   Parallel-to-Serial Adapter   │  ← Master Port                 │
│  │  (Request Buffering, Ser/Des)  │                                │
│  └────────────┬───────────────────┘                                │
│               │ serial_bus (4-wire)                                │
│               │ - sdata (serial data)                              │
│               │ - sclk  (serial clock)                             │
│               │ - svalid (transaction valid)                       │
│               │ - sready (slave ready)                             │
│  ┌────────────▼────────────────────┐                               │
│  │         Bus Arbiter             │                               │
│  │   (Priority + Split Support)    │                               │
│  └────────────┬────────────────────┘                               │
│               │                                                    │
│  ┌────────────▼────────────────────┐                               │
│  │   Serial-to-Parallel Adapter    │                               │
│  │   (Frame Decoder, Addr Decode)  │                               │
│  └────┬──────────┬──────────┬──────┘                               │
│       │          │          │                                      │
│  ┌────▼───┐ ┌───▼────┐ ┌───▼────┐  (Parallel Interface)            │
│  │ Slave0 │ │ Slave1 │ │ Slave2 │                                  │
│  │  4KB   │ │  4KB   │ │  2KB   │                                  │
│  │ (split)│ │        │ │        │                                  │
│  └────────┘ └────────┘ └────────┘                                  │
│                                                                    │
│  ┌──────────────────────────────────────────┐                      │
│  │    Inter-Board Serial Link (Optional)    │                      │
│  │  - TX/RX differential pair or LVDS       │                      │
│  │  - Handshake protocol for sync           │                      │
│  └──────────────────────────────────────────┘                      │
└────────────────────────────────────────────────────────────────────┘
```

---

### 3. Address Map

Follows same mapping as parallel bus for compatibility:

| Slave | Address Range   | Size | Features         |
| ----- | --------------- | ---- | ---------------- |
| 0     | 0x0000 - 0x0FFF | 4KB  | Split-capable    |
| 1     | 0x1000 - 0x1FFF | 4KB  | Normal operation |
| 2     | 0x2000 - 0x27FF | 2KB  | Normal operation |

**Decode Error**: Addresses ≥ 0x2800 return error frame

---

### 4. Inter-Board Communication

#### Physical Interface

**Option 1: GPIO-based (Simple)**

- Use 4 GPIO pins per board:
  - `TX_DATA`, `TX_CLK`, `TX_VALID`, `RX_READY`
  - `RX_DATA`, `RX_CLK`, `RX_VALID`, `TX_READY`
- Direct connection between DE0-Nano boards
- 3.3V LVTTL signaling

**Option 2: LVDS (High-Speed)**

- Use differential pairs for noise immunity
- Higher data rates possible
- Requires LVDS-capable I/O pins on DE0-Nano

#### Board-to-Board Protocol

```
Board A (Master)          Serial Bus          Board B (Slave)
─────────────────────────────────────────────────────────────
    Master0/1        →  Parallel-to-Serial  →  TX Interface
    Local Bus        →  Arbiter + Serializer →
                                              ↓
                                           GPIO/LVDS Pins
                                              ↓
                                     Physical Connection
                                              ↓
                                           GPIO/LVDS Pins
                                              ↓
    Slave0/1/2       ←  Serial-to-Parallel  ← RX Interface
    Local Bus        ←  Decoder + Deserializer
```

**Synchronization:**

- Clock domain crossing (CDC) for TX/RX
- Handshake signals ensure data integrity
- Optional FIFOs for rate matching

---

## Module Specifications

### 5. RTL Module Hierarchy

```
bitserial_top.sv
├── bus_pkg.sv                    (Parameters and types)
├── master_parallel.sv            (Parallel master interface - reuse from parallel design)
├── parallel_to_serial.sv         (Master-side adapter) ★ NEW
│   ├── serializer.sv             (Parallel → Serial converter)
│   └── tx_controller.sv          (Frame builder, parity)
├── serial_arbiter.sv             (Arbitration on serial bus) ★ MODIFIED
├── serial_to_parallel.sv         (Slave-side adapter) ★ NEW
│   ├── deserializer.sv           (Serial → Parallel converter)
│   ├── frame_decoder.sv          (Frame parser, parity check)
│   └── addr_decoder.sv           (Address decode - reuse)
├── slave_port.sv                 (Parallel slave interface - reuse)
├── slave_mem.sv                  (Memory slave - reuse)
└── interboard_link.sv            (TX/RX for board-to-board) ★ NEW
    ├── cdc_sync.sv               (Clock domain crossing)
    └── handshake_ctrl.sv         (Flow control)
```

**Legend:**

- ★ NEW: New modules for serial bus
- MODIFIED: Adapted from parallel bus
- Reuse: Unchanged from parallel bus design

---

### 6. Module Descriptions

#### 6.1 `parallel_to_serial.sv` - Master Adapter

**Purpose**: Convert parallel master requests into serial frames

**Interface:**

```systemverilog
module parallel_to_serial
  import bus_pkg::*;
(
  input  logic                  clk_i,
  input  logic                  rst_ni,

  // Parallel master interface (from master_port.sv)
  input  logic                  valid_i,
  input  logic [ADDR_WIDTH-1:0] addr_i,
  input  logic [DATA_WIDTH-1:0] wdata_i,
  input  logic                  we_i,
  output logic                  ready_o,
  output logic [DATA_WIDTH-1:0] rdata_o,
  output logic                  err_o,

  // Serial bus interface
  output logic                  sdata_o,      // Serial data out
  output logic                  sclk_o,       // Serial clock out
  output logic                  svalid_o,     // Frame valid
  input  logic                  sready_i,     // Slave ready
  input  logic                  sdata_i       // Serial data in (for read responses)
);
```

**Functionality:**

1. Buffer parallel request (addr, wdata, we)
2. Build 27-bit serial frame
3. Calculate parity
4. Serialize frame bit-by-bit on `sclk_o` edges
5. Receive response for reads
6. Assert `ready_o` when complete

---

#### 6.2 `serial_arbiter.sv` - Modified Arbiter

**Purpose**: Arbitrate between multiple masters on serial bus

**Key Differences from Parallel Arbiter:**

- Grant extends for entire serial frame duration (27 clocks)
- Must not preempt mid-frame
- Split transaction tracking uses frame command field

**Interface:**

```systemverilog
module serial_arbiter
  import bus_pkg::*;
(
  input  logic       clk_i,
  input  logic       rst_ni,

  // Master requests
  input  logic [1:0] req_i,      // Master 0, Master 1 request
  output logic [1:0] gnt_o,      // Master grants

  // Serial frame monitoring
  input  logic       frame_active_i,  // Frame in progress (don't switch)
  input  logic       split_pending_i, // Split transaction active
  input  logic [1:0] split_owner_i,   // Which master owns split

  output logic       msel_o      // Master select (0 = M0, 1 = M1)
);
```

---

#### 6.3 `serial_to_parallel.sv` - Slave Adapter

**Purpose**: Deserialize frames and convert to parallel slave accesses

**Interface:**

```systemverilog
module serial_to_parallel
  import bus_pkg::*;
(
  input  logic                  clk_i,
  input  logic                  rst_ni,

  // Serial bus interface
  input  logic                  sdata_i,      // Serial data in
  input  logic                  sclk_i,       // Serial clock in
  input  logic                  svalid_i,     // Frame valid
  output logic                  sready_o,     // Ready for next frame
  output logic                  sdata_o,      // Serial data out (responses)

  // Parallel slave interface (to addr_decoder + slave_port)
  output logic                  valid_o,
  output logic [ADDR_WIDTH-1:0] addr_o,
  output logic [DATA_WIDTH-1:0] wdata_o,
  output logic                  we_o,
  input  logic                  ready_i,
  input  logic [DATA_WIDTH-1:0] rdata_i,
  input  logic                  err_i
);
```

**Functionality:**

1. Deserialize incoming frame bit-by-bit
2. Detect START bit
3. Parse CMD, ADDR, DATA fields
4. Verify parity
5. Drive parallel slave transaction
6. Serialize response for reads
7. Assert `sready_o` when complete

---

#### 6.4 `interboard_link.sv` - Board-to-Board Interface

**Purpose**: Enable communication between two DE0-Nano boards

**Interface:**

```systemverilog
module interboard_link
  import bus_pkg::*;
(
  // Local clock domain
  input  logic       clk_local_i,
  input  logic       rst_local_ni,

  // Remote clock domain (if different)
  input  logic       clk_remote_i,
  input  logic       rst_remote_ni,

  // Local serial bus (from local masters)
  input  logic       tx_sdata_i,
  input  logic       tx_svalid_i,
  output logic       tx_sready_o,

  // Remote serial bus (to local slaves)
  output logic       rx_sdata_o,
  output logic       rx_svalid_o,
  input  logic       rx_sready_i,

  // Physical I/O pins
  output logic       gpio_tx_data_o,
  output logic       gpio_tx_clk_o,
  output logic       gpio_tx_valid_o,
  input  logic       gpio_rx_ready_i,

  input  logic       gpio_rx_data_i,
  input  logic       gpio_rx_clk_i,
  input  logic       gpio_rx_valid_i,
  output logic       gpio_tx_ready_o
);
```

**Key Features:**

- Clock domain crossing using 2-FF synchronizers
- Optional TX/RX FIFOs for buffering
- Handshake protocol for flow control
- Error detection (missing clock, framing errors)

---

## Pin Assignments (DE0-Nano)

### 7. DE0-Nano Pin Mapping

#### 7.1 System Pins

| Signal   | Pin | Description        |
| -------- | --- | ------------------ |
| `clk_i`  | R8  | 50 MHz clock input |
| `rst_ni` | J15 | KEY0 (active low)  |

#### 7.2 Local Master Interface (Demo)

| Signal       | Pin    | Description                |
| ------------ | ------ | -------------------------- |
| `m0_req`     | M1     | SW0 (request bus)          |
| `m0_gnt`     | A15    | LED0 (grant indicator)     |
| `m0_we`      | M15    | SW1 (write enable)         |
| `addr[3:0]`  | T8-B9  | SW3-SW2 (address low bits) |
| `rdata[7:0]` | A8-B10 | LED7-LED1 (read data)      |

#### 7.3 Inter-Board Serial Link

| Signal          | Pin | Description                  |
| --------------- | --- | ---------------------------- |
| `gpio_tx_data`  | D3  | GPIO_0[0] - Serial data out  |
| `gpio_tx_clk`   | C3  | GPIO_0[1] - Serial clock out |
| `gpio_tx_valid` | A2  | GPIO_0[2] - Frame valid out  |
| `gpio_rx_ready` | A3  | GPIO_0[3] - Ready in         |
| `gpio_rx_data`  | B3  | GPIO_0[4] - Serial data in   |
| `gpio_rx_clk`   | B4  | GPIO_0[5] - Serial clock in  |
| `gpio_rx_valid` | A4  | GPIO_0[6] - Frame valid in   |
| `gpio_tx_ready` | B5  | GPIO_0[7] - Ready out        |

**Note**: GPIO_0 bank provides adjacent pins for clean inter-board wiring

---

## Verification Strategy

### 8. Testbench Requirements

#### 8.1 Module-Level Tests

**`parallel_to_serial_tb.sv`**

- Test frame generation (START, CMD, ADDR, DATA, PARITY, STOP)
- Verify parity calculation
- Test read response deserialization
- Back-to-back transaction handling

**`serial_to_parallel_tb.sv`**

- Test frame parsing
- Verify parity checking (detect errors)
- Test CMD decode (READ/WRITE/SPLIT)
- Response frame generation

**`serial_arbiter_tb.sv`**

- Priority arbitration (Master 0 > Master 1)
- Frame-atomic grants (no mid-frame switching)
- Split transaction ownership
- Two masters simultaneous requests

**`interboard_link_tb.sv`**

- Clock domain crossing correctness
- Handshake protocol verification
- Error injection (missing clock, bad frames)

#### 8.2 System-Level Tests

**`bitserial_top_tb.sv`**

1. **Reset Test**: All modules initialize correctly
2. **Single Master Write**: Master 0 writes to each slave
3. **Single Master Read**: Master 0 reads from each slave
4. **Arbitration**: Both masters request simultaneously
5. **Split Transaction**: Write to Slave 0, observe split behavior
6. **Back-to-Back**: Multiple transactions in sequence
7. **Address Decode**: Verify all slaves and decode error
8. **Parity Error**: Inject bad parity, verify error handling
9. **Inter-Board Loopback**: TX → RX on same board
10. **Inter-Board Dual-Board**: Simulate two boards communicating

#### 8.3 Inter-Board Integration Tests

**Physical Test Scenarios** (Two DE0-Nano boards):

1. **Board A Master → Board B Slaves**: Board A writes data to Board B's memories
2. **Board B Master → Board A Slaves**: Board B reads data from Board A
3. **Bidirectional**: Simultaneous transactions both directions
4. **Arbitration Across Boards**: Multiple masters on both boards
5. **Error Cases**: Disconnect cable, verify timeout/recovery

---

## FPGA Implementation

### 9. Resource Estimates (DE0-Nano EP4CE22F17C6)

| Resource Type        | Estimated Usage | Available | % Used |
| -------------------- | --------------- | --------- | ------ |
| Logic Elements (LEs) | 2500-3500       | 22,320    | 11-16% |
| Registers            | 800-1200        | 22,320    | 4-5%   |
| M9K Memory Blocks    | 3 (10KB)        | 66 (594K) | 5%     |
| PLLs                 | 0-1             | 4         | 0-25%  |
| GPIO Pins            | 20              | 154       | 13%    |

**Notes:**

- Serial logic adds ~1000 LEs vs. parallel bus
- Serializers/deserializers are shift registers
- CDC logic requires careful timing constraints
- Memory blocks same as parallel design (M9K inference)

---

### 10. Timing Constraints

#### 10.1 Primary Clock Domain

```tcl
# 50 MHz system clock
create_clock -name clk_sys -period 20.0 [get_ports clk_i]

# Input delays (from switches, buttons)
set_input_delay -clock clk_sys -max 5.0 [get_ports {m0_req m0_we addr[*]}]
set_input_delay -clock clk_sys -min 2.0 [get_ports {m0_req m0_we addr[*]}]

# Output delays (to LEDs)
set_output_delay -clock clk_sys -max 5.0 [get_ports {m0_gnt rdata[*]}]
set_output_delay -clock clk_sys -min 0.0 [get_ports {m0_gnt rdata[*]}]
```

#### 10.2 Serial Clock Domain

```tcl
# Derived serial clock (12.5 MHz - CLK/4)
create_generated_clock -name sclk \
    -source [get_pins clk_divider/clk_i] \
    -divide_by 4 \
    [get_pins clk_divider/sclk_o]

# Serial data paths
set_multicycle_path -setup 2 -from [get_clocks sclk] -to [get_clocks sclk]
set_multicycle_path -hold 1 -from [get_clocks sclk] -to [get_clocks sclk]
```

#### 10.3 Inter-Board Timing

```tcl
# GPIO constraints for board-to-board
set_output_delay -clock sclk -max 3.0 [get_ports gpio_tx_*]
set_output_delay -clock sclk -min 0.5 [get_ports gpio_tx_*]

set_input_delay -clock sclk -max 3.0 [get_ports gpio_rx_*]
set_input_delay -clock sclk -min 0.5 [get_ports gpio_rx_*]

# False paths for async resets
set_false_path -from [get_ports rst_ni]
```

---

## Project Structure

### 11. Directory Layout

```
bitserial-bus/
├── rtl/
│   ├── bus_pkg.sv                   # Parameters, types
│   ├── bitserial_top.sv             # Top-level integration
│   ├── master_parallel.sv           # Parallel master (reused)
│   ├── parallel_to_serial.sv        # Master adapter ★
│   │   ├── serializer.sv
│   │   └── tx_controller.sv
│   ├── serial_arbiter.sv            # Serial arbiter ★
│   ├── serial_to_parallel.sv        # Slave adapter ★
│   │   ├── deserializer.sv
│   │   ├── frame_decoder.sv
│   │   └── addr_decoder.sv          # Reused from parallel
│   ├── slave_port.sv                # Parallel slave (reused)
│   ├── slave_mem.sv                 # Memory slave (reused)
│   └── interboard_link.sv           # Board-to-board ★
│       ├── cdc_sync.sv
│       └── handshake_ctrl.sv
├── tb/
│   ├── tb_utils.svh                 # Testbench utilities
│   ├── parallel_to_serial_tb.sv
│   ├── serial_to_parallel_tb.sv
│   ├── serial_arbiter_tb.sv
│   ├── interboard_link_tb.sv
│   └── bitserial_top_tb.sv          # System-level testbench
├── fpga/
│   └── quartus/
│       ├── bitserial.qpf            # Quartus project
│       ├── bitserial.qsf            # Settings + pins
│       ├── bitserial.sdc            # Timing constraints
│       └── compile.tcl              # Build script
├── sim/
│   └── (generated simulation files)
├── build/
│   ├── logs/
│   └── waves/
├── docs/
│   ├── functional_description.md
│   ├── io_definitions.md
│   ├── timing_diagrams.md
│   ├── block_diagrams.md
│   ├── wavedrom/                    # Timing diagram sources
│   └── diagrams/                    # Architecture diagrams (D2)
├── refs/
│   ├── assignment.md                # Assignment requirements
│   ├── VerilogCodingStyle.md        # lowRISC style guide
│   ├── DVCodingStyle.md             # DV style guide
│   └── ads-system-bus/              # Reference parallel design
├── justfile                         # Build automation
├── AGENTS.md                        # Agent roles
├── STATUS.md                        # Implementation status
└── README.md                        # Project overview
```

---

## Justfile Template

### 12. Build Automation (`justfile`)

```justfile
set export := true

# =============================================================================
# CONFIGURATION
# =============================================================================

VERILATOR := "/Users/tony/arc/dev/archive/sort/verilator/zig-out/bin/verilator"
VERILATOR_CFLAGS := "-Wno-unused-command-line-argument"
VERILATOR_FLAGS := "-CFLAGS $VERILATOR_CFLAGS --binary -j 0"
VERIBLE_FORMAT := "verible-verilog-format"
WAVE_VIEWER := "surfer"
QUARTUS_BIN := "quartus_sh"

# Directories
RTL_DIR := "rtl"
TB_DIR := "tb"
BUILD_DIR := "build"
FPGA_DIR := "fpga/quartus"

# RTL source files
RTL_COMMON := RTL_DIR + "/bus_pkg.sv"
RTL_SERIAL := RTL_DIR + "/parallel_to_serial.sv " +
              RTL_DIR + "/serializer.sv " +
              RTL_DIR + "/tx_controller.sv " +
              RTL_DIR + "/serial_to_parallel.sv " +
              RTL_DIR + "/deserializer.sv " +
              RTL_DIR + "/frame_decoder.sv"
RTL_BUS := RTL_DIR + "/serial_arbiter.sv " +
           RTL_DIR + "/addr_decoder.sv " +
           RTL_DIR + "/master_parallel.sv " +
           RTL_DIR + "/slave_port.sv " +
           RTL_DIR + "/slave_mem.sv"
RTL_INTERBOARD := RTL_DIR + "/interboard_link.sv " +
                  RTL_DIR + "/cdc_sync.sv " +
                  RTL_DIR + "/handshake_ctrl.sv"
RTL_TOP := RTL_DIR + "/bitserial_top.sv"

RTL_ALL := RTL_COMMON + " " + RTL_SERIAL + " " + RTL_BUS + " " +
           RTL_INTERBOARD + " " + RTL_TOP

# =============================================================================
# DEFAULT TARGET
# =============================================================================

default:
    @just --list

# =============================================================================
# SETUP AND CLEANUP
# =============================================================================

setup:
    mkdir -p {{ BUILD_DIR }}/logs {{ BUILD_DIR }}/waves

clean:
    rm -rf {{ BUILD_DIR }} obj_dir
    rm -rf xsim.dir .Xil *.jou *.log *.pb *.wdb

# =============================================================================
# SIMULATION - MODULE LEVEL
# =============================================================================

sim-serializer: setup
    {{ VERILATOR }} {{ VERILATOR_FLAGS }} \
        --trace --trace-structs \
        -I{{ RTL_DIR }} -I{{ TB_DIR }} \
        {{ RTL_COMMON }} \
        {{ RTL_DIR }}/serializer.sv \
        {{ RTL_DIR }}/tx_controller.sv \
        {{ RTL_DIR }}/parallel_to_serial.sv \
        {{ TB_DIR }}/parallel_to_serial_tb.sv \
        --top-module parallel_to_serial_tb \
        -o ../{{ BUILD_DIR }}/parallel_to_serial_tb
    {{ BUILD_DIR }}/parallel_to_serial_tb

sim-deserializer: setup
    {{ VERILATOR }} {{ VERILATOR_FLAGS }} \
        --trace --trace-structs \
        -I{{ RTL_DIR }} -I{{ TB_DIR }} \
        {{ RTL_COMMON }} \
        {{ RTL_DIR }}/deserializer.sv \
        {{ RTL_DIR }}/frame_decoder.sv \
        {{ RTL_DIR }}/addr_decoder.sv \
        {{ RTL_DIR }}/serial_to_parallel.sv \
        {{ TB_DIR }}/serial_to_parallel_tb.sv \
        --top-module serial_to_parallel_tb \
        -o ../{{ BUILD_DIR }}/serial_to_parallel_tb
    {{ BUILD_DIR }}/serial_to_parallel_tb

sim-arbiter: setup
    {{ VERILATOR }} {{ VERILATOR_FLAGS }} \
        --trace --trace-structs \
        -I{{ RTL_DIR }} -I{{ TB_DIR }} \
        {{ RTL_COMMON }} \
        {{ RTL_DIR }}/serial_arbiter.sv \
        {{ TB_DIR }}/serial_arbiter_tb.sv \
        --top-module serial_arbiter_tb \
        -o ../{{ BUILD_DIR }}/serial_arbiter_tb
    {{ BUILD_DIR }}/serial_arbiter_tb

sim-interboard: setup
    {{ VERILATOR }} {{ VERILATOR_FLAGS }} \
        --trace --trace-structs \
        -I{{ RTL_DIR }} -I{{ TB_DIR }} \
        {{ RTL_COMMON }} \
        {{ RTL_INTERBOARD }} \
        {{ TB_DIR }}/interboard_link_tb.sv \
        --top-module interboard_link_tb \
        -o ../{{ BUILD_DIR }}/interboard_link_tb
    {{ BUILD_DIR }}/interboard_link_tb

# =============================================================================
# SIMULATION - SYSTEM LEVEL
# =============================================================================

sim-top: setup
    {{ VERILATOR }} {{ VERILATOR_FLAGS }} \
        --trace --trace-depth 3 \
        -I{{ RTL_DIR }} -I{{ TB_DIR }} \
        {{ RTL_ALL }} \
        {{ TB_DIR }}/bitserial_top_tb.sv \
        --top-module bitserial_top_tb \
        -o ../{{ BUILD_DIR }}/bitserial_top_tb
    {{ BUILD_DIR }}/bitserial_top_tb

sim-all: sim-serializer sim-deserializer sim-arbiter sim-interboard sim-top

# =============================================================================
# LINTING
# =============================================================================

lint:
    {{ VERILATOR }} --lint-only -Wall \
        -I{{ RTL_DIR }} \
        {{ RTL_ALL }}

# =============================================================================
# WAVEFORM VIEWING
# =============================================================================

waves-serializer:
    {{ WAVE_VIEWER }} {{ BUILD_DIR }}/waves/parallel_to_serial_tb.vcd &

waves-deserializer:
    {{ WAVE_VIEWER }} {{ BUILD_DIR }}/waves/serial_to_parallel_tb.vcd &

waves-arbiter:
    {{ WAVE_VIEWER }} {{ BUILD_DIR }}/waves/serial_arbiter_tb.vcd &

waves-interboard:
    {{ WAVE_VIEWER }} {{ BUILD_DIR }}/waves/interboard_link_tb.vcd &

waves-top:
    {{ WAVE_VIEWER }} {{ BUILD_DIR }}/waves/bitserial_top_tb.vcd &

# =============================================================================
# CODE FORMATTING
# =============================================================================

format:
    {{ VERIBLE_FORMAT }} --inplace {{ RTL_DIR }}/*.sv
    {{ VERIBLE_FORMAT }} --inplace {{ TB_DIR }}/*.sv

format-check:
    {{ VERIBLE_FORMAT }} --verify {{ RTL_DIR }}/*.sv
    {{ VERIBLE_FORMAT }} --verify {{ TB_DIR }}/*.sv

# =============================================================================
# FPGA SYNTHESIS
# =============================================================================

synth-quartus: setup
    cd {{ FPGA_DIR }} && {{ QUARTUS_BIN }} -t compile.tcl

program-quartus:
    cd {{ FPGA_DIR }} && quartus_pgm -c USB-Blaster -m JTAG \
        -o "p;output_files/bitserial.sof"

clean-quartus:
    rm -rf {{ FPGA_DIR }}/output_files {{ FPGA_DIR }}/db \
           {{ FPGA_DIR }}/incremental_db
    rm -f {{ FPGA_DIR }}/*.rpt {{ FPGA_DIR }}/*.summary {{ FPGA_DIR }}/*.qws

# =============================================================================
# DOCUMENTATION GENERATION
# =============================================================================

diagrams-timing:
    #!/bin/bash
    echo "Generating timing diagrams with WaveDrom..."
    cd docs/wavedrom
    for json in *.json; do
        echo "  - $json -> ${json%.json}.svg"
        bunx wavedrom-cli --input "$json" --svg "${json%.json}.svg"
    done

diagrams-arch:
    #!/bin/bash
    echo "Generating architecture diagrams with D2..."
    cd docs/diagrams
    for d2_file in *.d2; do
        echo "  - $d2_file -> ${d2_file%.d2}_d2.svg"
        d2 "$d2_file" "${d2_file%.d2}_d2.svg"
    done

diagrams: diagrams-timing diagrams-arch

# =============================================================================
# CONTINUOUS INTEGRATION
# =============================================================================

ci: lint sim-all
    @echo "✅ All checks passed!"

# =============================================================================
# DEMO TARGETS
# =============================================================================

demo-local: sim-top
    @echo "Running local loopback demo..."
    @echo "TX→RX on single board"

demo-interboard: program-quartus
    @echo "Program both boards and connect GPIO_0 pins"
    @echo "Press KEY0 to reset, use switches for control"
```

---

## AGENTS.md Template

### 13. Agent Roles for Bit-Serial Bus

```markdown
# Agent Roles and Responsibilities - Bit-Serial Bus System

## Agent Overview

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
- Define address mapping (same as parallel: 4KB split, 4KB, 2KB)
- Create block diagrams for serial system
- Specify CDC strategy for GPIO pins

**Key Deliverables**:

- Serial protocol specification document
- Inter-board connection diagram
- Timing diagrams for serial transactions
- Block diagram with serial adapters
- DE0-Nano pin assignment plan

**Design Principles**:

- Reuse parallel bus components where possible (memories, decoders)
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
- Reuse from parallel bus: `slave_mem.sv`, `addr_decoder.sv`, `slave_port.sv`
- Follow lowRISC Verilog style guide
- Ensure synthesizable, FPGA-optimized code

**Key Deliverables**:

- `rtl/bitserial_top.sv` - Top-level integration
- `rtl/parallel_to_serial.sv` + sub-modules
- `rtl/serial_to_parallel.sv` + sub-modules
- `rtl/serial_arbiter.sv`
- `rtl/interboard_link.sv` + CDC modules
- `rtl/bus_pkg.sv` - Updated parameters

**Coding Standards**:

- Follow `refs/VerilogCodingStyle.md`
- Use `(* ramstyle = "M9K" *)` for memories
- Async reset (active-low), posedge clocks
- Proper signal naming (snake_case)
- Commented I/O definitions
- No latches or combinational loops

---

## 3. Verification Agent

**Role**: Verify serial bus and inter-board communication

**Responsibilities**:

- Create module testbenches:
  - `parallel_to_serial_tb.sv` - Frame generation, parity
  - `serial_to_parallel_tb.sv` - Frame parsing, error detection
  - `serial_arbiter_tb.sv` - Frame-atomic arbitration
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
  10. Dual-board simulation (two tops)
- Generate waveforms for documentation
- Follow lowRISC DV coding style

**Key Deliverables**:

- Module-level testbenches (4 files)
- System testbench (`bitserial_top_tb.sv`)
- Test utilities in `tb_utils.svh`
- VCD waveforms for all tests
- Test result summary document

**Verification Standards**:

- Use Verilator-compatible constructs
- Clear PASS/FAIL reporting with colors
- Waveform dumps for debugging
- Coverage: all slaves, all commands, errors

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
- Document I/O definitions for all new modules
- Generate timing diagrams:
  - Serial frame structure
  - Read/write transactions
  - Split transactions
  - Inter-board handshake
  - Arbitration scenarios
- Create block diagrams (D2):
  - System architecture with serial adapters
  - Inter-board connection diagram
  - Module hierarchy
- Document test results and coverage
- Create demo operation guide
- Compile final report (20 marks)

**Key Deliverables**:

- `docs/functional_description.md`
- `docs/io_definitions.md`
- `docs/timing_diagrams.md`
- `docs/block_diagrams.md`
- `docs/interboard_protocol.md` (NEW)
- `docs/demo_guide.md` (NEW)
- `REPORT.pdf` - Final submission

**Report Structure**:

1. Introduction
   - Bit-serial bus motivation
   - Design overview
2. Serial Protocol Specification
   - Frame format
   - Timing characteristics
   - Parity and error handling
3. Functional Descriptions
   - Serializer/deserializer
   - Modified arbiter
   - Inter-board link
4. I/O Definitions (all modules)
5. Timing Diagrams
   - Serial transactions
   - Inter-board communication
6. RTL Code (key modules)
7. Testbench and Results
8. FPGA Implementation
   - Resource utilization
   - Timing analysis
   - Inter-board demo results
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
- GPIO pin requirements (8 pins)
- Resource estimates

**Verification → Documentation**:

- Test results and pass/fail status
- Waveforms for timing diagrams
- Error cases and handling
- Inter-board test results

**Integration → Documentation**:

- Synthesis reports
- Resource utilization (actual vs. estimated)
- Fmax achieved
- Demo setup and results
- Inter-board connection photos

---

## Implementation Strategy

**Phase 1: Architecture & Planning (Week 1)**

1. Define serial frame format
2. Design 4-wire bus interface
3. Plan inter-board connection
4. Create block diagrams

**Phase 2: RTL Implementation (Week 2)**

1. Implement serializer + tx_controller
2. Implement deserializer + frame_decoder
3. Modify arbiter for frame-atomic grants
4. Integrate with reused parallel modules
5. Implement interboard_link with CDC

**Phase 3: Verification (Week 3)**

1. Module-level tests (serializer, deserializer, arbiter, interboard)
2. System-level tests (bitserial_top)
3. Loopback test (TX→RX single board)
4. Generate waveforms

**Phase 4: FPGA Integration (Week 4)**

1. Verilator simulation validation
2. Quartus synthesis for DE0-Nano
3. Program single board, test loopback
4. Program two boards, test inter-board
5. Demo with other team's board

**Phase 5: Documentation (Week 5)**

1. Collect all artifacts
2. Generate diagrams (WaveDrom, D2)
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

## Inter-Board Testing Checklist

- [ ] Pin mapping verified (GPIO_0 bank)
- [ ] Cable length < 30 cm (signal integrity)
- [ ] Ground connection between boards
- [ ] Clock domain crossing tested
- [ ] Handshake protocol verified
- [ ] Error recovery tested
- [ ] Data integrity checked (write then read back)
- [ ] Demo script prepared
- [ ] Photos/video of working demo

---

## **CRITICAL RULES**

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
```

---

## Summary

This specification provides a complete blueprint for implementing a **bit-serial bus system** that:

1. **Meets assignment requirements**: 2 masters, 3 slaves, split transactions, DE0-Nano FPGA
2. **Enables inter-board communication**: Two teams can connect boards via GPIO
3. **Reuses proven components**: Leverages parallel bus memories and decoders
4. **Adds serial capability**: New serializer/deserializer adapters
5. **Follows best practices**: lowRISC style, proper verification, thorough documentation

**Key Innovations:**

- 27-bit serial frame with parity checking
- 4-wire bus interface (data, clock, valid, ready)
- Frame-atomic arbitration (no mid-frame switching)
- CDC-safe inter-board link with handshake protocol
- Modular design allows local testing before inter-board integration

**Next Steps:**

1. Review specification with team
2. Set up project structure (directories, justfile)
3. Begin Phase 1: Architecture diagrams
4. Start RTL implementation with serializer module
5. Coordinate with other team for inter-board testing schedule
