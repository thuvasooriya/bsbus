# Block Diagrams - Bit-Serial Bus System

This document provides architectural block diagrams showing the structure and interconnections of the bit-serial bus system.

## 1. Top-Level System Architecture

### 1.1 Complete System Block Diagram

```
┌──────────────────────────────────────────────────────────────────────────┐
│                       BITSERIAL_TOP (Top-Level)                          │
│                                                                          │
│  ┌────────────────┐      ┌────────────────┐                              │
│  │   Master 0     │      │   Master 1     │                              │
│  │  (Parallel IF) │      │  (Parallel IF) │                              │
│  └───────┬────────┘      └───────┬────────┘                              │
│          │ req[0]                │ req[1]                                │
│          │ addr[13:0]            │ addr[13:0]                            │
│          │ wdata[7:0]            │ wdata[7:0]                            │
│          │ we                    │ we                                    │
│          │ gnt                   │ gnt                                   │
│          │ rdata[7:0]            │ rdata[7:0]                            │
│          │ err                   │ err                                   │
│          │                       │                                       │
│          ▼                       ▼                                       │
│  ┌──────────────────────────────────────────┐                            │
│  │    PARALLEL_TO_SERIAL (Master Adapter)   │                            │
│  │  - Request buffering                     │                            │
│  │  - Serializer (27-bit shift register)    │                            │
│  │  - TX controller FSM                     │                            │
│  │  - Parity generator                      │                            │
│  └──────────────────┬───────────────────────┘                            │
│                     │ sdata_m[1:0]                                       │
│                     │ svalid_m[1:0]                                      │
│                     │ sready_m[1:0]                                      │
│                     ▼                                                    │
│  ┌──────────────────────────────────────────┐                            │
│  │       SERIAL_ARBITER                     │                            │
│  │  - Priority arbitration (M0 > M1)        │                            │
│  │  - Frame-atomic grants                   │                            │
│  │  - Split transaction tracking            │                            │
│  └──────────────────┬───────────────────────┘                            │
│                     │ sdata (single serial bus)                          │
│                     │ sclk  (serial clock)                               │
│                     │ svalid                                             │
│                     │ sready                                             │
│                     │ msel (master select)                               │
│                     ▼                                                    │
│  ┌──────────────────────────────────────────┐                            │
│  │    SERIAL_TO_PARALLEL (Slave Adapter)    │                            │
│  │  - Deserializer (27-bit shift register)  │                            │
│  │  - Frame decoder FSM                     │                            │
│  │  - Parity checker                        │                            │
│  │  - Address decoder                       │                            │
│  └──────┬──────────────┬────────────┬───────┘                            │
│         │ slave_sel[0] │ slave_sel[1]│ slave_sel[2]                      │
│         │ addr[13:0]   │ addr[13:0]  │ addr[13:0]                        │
│         │ wdata[7:0]   │ wdata[7:0]  │ wdata[7:0]                        │
│         │ we           │ we          │ we                                │
│         │ rdata[7:0]   │ rdata[7:0]  │ rdata[7:0]                        │
│         │ ready        │ ready       │ ready                             │
│         ▼              ▼             ▼                                   │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐                              │
│  │ SLAVE 0  │   │ SLAVE 1  │   │ SLAVE 2  │                              │
│  │  4KB     │   │  4KB     │   │  2KB     │                              │
│  │ (split)  │   │ (normal) │   │ (normal) │                              │
│  │ 0x0000-  │   │ 0x1000-  │   │ 0x2000-  │                              │
│  │  0x0FFF  │   │  0x1FFF  │   │  0x27FF  │                              │
│  └──────────┘   └──────────┘   └──────────┘                              │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐    │
│  │            Optional: INTERBOARD_LINK                             │    │
│  │  - CDC synchronizers (2-FF)                                      │    │
│  │  - Handshake controller                                          │    │
│  │  - TX/RX FIFOs (optional)                                        │    │
│  └───────────────────┬──────────────────────────────────────────────┘    │
│                      │ GPIO[7:0] (to/from other board)                   │
│                      ▼                                                   │
│  ┌─────────────────────────────────────────────────────────────┐         │
│  │  Physical I/O Pins (DE0-Nano GPIO_0 Bank)                  │         │
│  │  - gpio_tx_data, gpio_tx_clk, gpio_tx_valid, gpio_rx_ready │         │
│  │  - gpio_rx_data, gpio_rx_clk, gpio_rx_valid, gpio_tx_ready │         │
│  └─────────────────────────────────────────────────────────────┘         │
│                                                                          │
│  Clock Generation:  clk_i (50 MHz) → sclk (12.5 MHz, CLK/4 divider)     │
│  Reset:  rst_ni (active-low, async)                                     │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Serial Bus Interface Signals

### 2.1 4-Wire Serial Bus

```
Master Side                     Serial Bus (4 wires)              Slave Side
────────────────────────────────────────────────────────────────────────────

parallel_to_serial              ┌─────────────┐         serial_to_parallel
                                │             │
  sdata_o  ────────────────────►│   sdata    ├────────────────────► sdata_i
                                │             │
  sclk_o   ────────────────────►│   sclk     ├────────────────────► sclk_i
                                │             │
  svalid_o ────────────────────►│   svalid   ├────────────────────► svalid_i
                                │             │
  sready_i ◄────────────────────┤   sready   │◄──────────────────── sready_o
                                │             │
                                └─────────────┘

Signal Descriptions:
─────────────────────────────────────────────────────────────────────────────

sdata   - Serial data (1 bit transmitted per sclk cycle)
          Direction: Master → Slave for requests
                     Slave → Master for responses
          MSB transmitted first

sclk    - Serial clock (derived from system clock, CLK/4 = 12.5 MHz)
          Direction: Master → Slave (master generates clock)
          Frequency: 12.5 MHz (80ns period)

svalid  - Transaction valid indicator
          Direction: Master → Slave during request
                     Slave → Master during response
          High for entire 27-bit frame duration

sready  - Ready to accept transaction
          Direction: Slave → Master (slave can accept request)
                     Master → Slave (master can accept response)
          Low during frame processing
```

---

## 3. Module Hierarchy

### 3.1 RTL Module Tree

```
bitserial_top.sv
│
├─ bus_pkg.sv                          [Package: Types, parameters, functions]
│  ├─ ADDR_WIDTH = 14
│  ├─ DATA_WIDTH = 8
│  ├─ FRAME_WIDTH = 27
│  ├─ cmd_e {READ, WRITE, SPLIT_START, SPLIT_CONTINUE}
│  ├─ serial_frame_t struct
│  └─ calc_parity() function
│
├─ parallel_to_serial.sv               [Master-side adapter]
│  ├─ serializer.sv                    [Parallel → Serial converter]
│  │  └─ 27-bit shift register
│  │     - Loads: {START, CMD, ADDR, DATA, PARITY, STOP}
│  │     - Shifts: MSB first on sclk edges
│  │
│  └─ tx_controller.sv                 [TX control FSM]
│     ├─ States: IDLE, LOAD, SHIFT, WAIT_RESP, DONE
│     ├─ Frame builder logic
│     └─ Parity generator
│
├─ serial_arbiter.sv                   [Bus arbitration]
│  ├─ Priority logic (M0 > M1)
│  ├─ Frame-atomic grant logic
│  ├─ Split transaction tracker
│  └─ Master select mux (msel)
│
├─ serial_to_parallel.sv               [Slave-side adapter]
│  ├─ deserializer.sv                  [Serial → Parallel converter]
│  │  └─ 27-bit shift register
│  │     - Shifts in: sdata on sclk edges
│  │     - Outputs: {START, CMD, ADDR, DATA, PARITY, STOP}
│  │
│  ├─ frame_decoder.sv                 [RX control FSM]
│  │  ├─ States: IDLE, SHIFT, PARSE, EXEC, RESPOND
│  │  ├─ Frame parser logic
│  │  └─ Parity checker
│  │
│  └─ addr_decoder.sv                  [Address decode logic]
│     ├─ Slave 0: 0x0000-0x0FFF (4KB, split-capable)
│     ├─ Slave 1: 0x1000-0x1FFF (4KB, normal)
│     ├─ Slave 2: 0x2000-0x27FF (2KB, normal)
│     └─ Decode error: addr >= 0x2800
│
├─ slave_mem.sv (×3 instances)         [Memory slaves]
│  ├─ slave_mem_0 (4KB, split support)
│  ├─ slave_mem_1 (4KB, normal)
│  └─ slave_mem_2 (2KB, normal)
│
└─ interboard_link.sv                  [Optional: Board-to-board interface]
   ├─ cdc_sync.sv (×4 instances)       [2-FF synchronizers]
   │  ├─ sync_rx_data
   │  ├─ sync_rx_clk
   │  ├─ sync_rx_valid
   │  └─ sync_tx_ready
   │
   └─ (Optional) TX/RX FIFOs
      ├─ tx_fifo (for rate buffering)
      └─ rx_fifo (for rate buffering)
```

---

## 4. Parallel-to-Serial Adapter

### 4.1 Master Adapter Internal Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│                   PARALLEL_TO_SERIAL Module                            │
│                                                                        │
│  Parallel Master Interface (Input)                                    │
│  ┌──────────────────────────────────────────────────────────────┐     │
│  │  valid_i, addr_i[13:0], wdata_i[7:0], we_i                   │     │
│  └─────────────────────────┬────────────────────────────────────┘     │
│                            ▼                                           │
│  ┌──────────────────────────────────────────────────────────────┐     │
│  │  Request Buffer Registers                                    │     │
│  │  - addr_reg[13:0]                                            │     │
│  │  - wdata_reg[7:0]                                            │     │
│  │  - we_reg                                                    │     │
│  │  (Captures parallel request on valid_i & ready_o handshake)  │     │
│  └─────────────────────────┬────────────────────────────────────┘     │
│                            ▼                                           │
│  ┌──────────────────────────────────────────────────────────────┐     │
│  │  TX_CONTROLLER (FSM)                                         │     │
│  │                                                              │     │
│  │  States:                                                     │     │
│  │    IDLE  ──► LOAD ──► SHIFT ──► WAIT_RESP ──► DONE ──► IDLE │     │
│  │                                                              │     │
│  │  Actions:                                                    │     │
│  │  - IDLE:      Wait for valid_i, assert ready_o              │     │
│  │  - LOAD:      Build frame, calculate parity                 │     │
│  │  - SHIFT:     Serialize 27 bits, assert svalid_o            │     │
│  │  - WAIT_RESP: For READ, receive response frame              │     │
│  │  - DONE:      Assert ready_o, output rdata/err              │     │
│  └─────────────────────────┬────────────────────────────────────┘     │
│                            │ load, shift_en, done                     │
│                            ▼                                           │
│  ┌──────────────────────────────────────────────────────────────┐     │
│  │  SERIALIZER (27-bit Shift Register)                         │     │
│  │                                                              │     │
│  │  Parallel Load:  ┌─────────────────────────────────────┐    │     │
│  │                  │ START │ CMD │ ADDR │ DATA │ PAR │ STOP│   │     │
│  │                  │   1   │ 2b  │ 14b  │  8b  │ 1b  │  1  │   │     │
│  │                  └─────────────────────────────────────┘    │     │
│  │                                                              │     │
│  │  Serial Shift:   [26][25][24]...[2][1][0] ──► sdata_o      │     │
│  │                   MSB ──────────────────► LSB                │     │
│  │                   (Shift left, output MSB first)             │     │
│  └─────────────────────────┬────────────────────────────────────┘     │
│                            ▼                                           │
│  ┌──────────────────────────────────────────────────────────────┐     │
│  │  Parity Generator                                            │     │
│  │  parity = ^{cmd[1:0], addr_reg[13:0], wdata_reg[7:0]}       │     │
│  │  (Even parity: XOR reduction of CMD+ADDR+DATA fields)        │     │
│  └──────────────────────────────────────────────────────────────┘     │
│                                                                        │
│  Serial Bus Interface (Output)                                        │
│  ┌──────────────────────────────────────────────────────────────┐     │
│  │  sdata_o, sclk_o, svalid_o  (to arbiter/bus)                │     │
│  │  sready_i, sdata_i  (from slave for READ responses)          │     │
│  └──────────────────────────────────────────────────────────────┘     │
│                                                                        │
│  Parallel Master Interface (Output)                                   │
│  ┌──────────────────────────────────────────────────────────────┐     │
│  │  ready_o, rdata_o[7:0], err_o  (back to master)             │     │
│  └──────────────────────────────────────────────────────────────┘     │
└────────────────────────────────────────────────────────────────────────┘
```

### 4.2 TX Controller State Machine

```
                         ┌──────────────────┐
                         │      IDLE        │
                         │  ready_o = 1     │
                         │  svalid_o = 0    │
                         └─────────┬────────┘
                                   │
                       valid_i = 1 │
                                   ▼
                         ┌──────────────────┐
                         │      LOAD        │
                         │  Capture request │
                         │  Build frame     │
                         │  Calculate parity│
                         └─────────┬────────┘
                                   │
                                   │ 1 cycle
                                   ▼
                         ┌──────────────────┐
                         │      SHIFT       │◄────────────┐
                         │  shift_en = 1    │             │
                         │  svalid_o = 1    │             │
                         │  Output sdata_o  │             │
                         └─────────┬────────┘             │
                                   │                      │
                      bit_count < 27│                     │ Repeat
                                   │                      │ 27 times
                                   └──────────────────────┘
                                   │
                    bit_count == 27│
                                   ▼
                         ┌──────────────────┐
                  ┌──────┤   WAIT_RESP?     ├──────┐
                  │      │  (if READ)       │      │
                  │      └──────────────────┘      │
                  │                                │
          we_reg=1│ (WRITE)              we_reg=0 │ (READ)
                  │                                │
                  ▼                                ▼
        ┌──────────────────┐           ┌──────────────────┐
        │      DONE        │           │    WAIT_RESP     │
        │  ready_o = 1     │           │  Receive 27 bits │
        │  Transaction OK  │           │  from slave      │
        └─────────┬────────┘           └─────────┬────────┘
                  │                              │
                  │                              │ resp_done
                  │                              ▼
                  │                    ┌──────────────────┐
                  │                    │      DONE        │
                  │                    │  ready_o = 1     │
                  │                    │  rdata_o = resp  │
                  │                    │  err_o = parity? │
                  │                    └─────────┬────────┘
                  │                              │
                  └──────────────┬───────────────┘
                                 │
                                 │ 1 cycle
                                 ▼
                       Back to IDLE (loop)
```

---

## 5. Serial-to-Parallel Adapter

### 5.1 Slave Adapter Internal Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│                   SERIAL_TO_PARALLEL Module                            │
│                                                                        │
│  Serial Bus Interface (Input)                                         │
│  ┌──────────────────────────────────────────────────────────────┐     │
│  │  sdata_i, sclk_i, svalid_i  (from arbiter/bus)               │     │
│  └─────────────────────────┬────────────────────────────────────┘     │
│                            ▼                                           │
│  ┌──────────────────────────────────────────────────────────────┐     │
│  │  DESERIALIZER (27-bit Shift Register)                       │     │
│  │                                                              │     │
│  │  Serial Input:   sdata_i ──► [0][1][2]...[25][26]          │     │
│  │                              MSB first ──► LSB               │     │
│  │                              (Shift right, capture on sclk)  │     │
│  │                                                              │     │
│  │  Parallel Output:  ┌─────────────────────────────────────┐  │     │
│  │                    │ START │ CMD │ ADDR │ DATA │ PAR │ STOP│ │     │
│  │                    │  [26] │[25:24]│[23:10]│[9:2]│[1]│[0]│ │     │
│  │                    └─────────────────────────────────────┘  │     │
│  └─────────────────────────┬────────────────────────────────────┘     │
│                            ▼                                           │
│  ┌──────────────────────────────────────────────────────────────┐     │
│  │  FRAME_DECODER (FSM)                                         │     │
│  │                                                              │     │
│  │  States:                                                     │     │
│  │    IDLE ──► SHIFT ──► PARSE ──► EXEC ──► RESPOND ──► IDLE   │     │
│  │                                                              │     │
│  │  Actions:                                                    │     │
│  │  - IDLE:    Wait for svalid_i, assert sready_o              │     │
│  │  - SHIFT:   Deserialize 27 bits from sdata_i                │     │
│  │  - PARSE:   Extract fields, check START/STOP/PARITY         │     │
│  │  - EXEC:    Drive parallel slave transaction                │     │
│  │  - RESPOND: Build response frame (if READ)                  │     │
│  └─────────────────────────┬────────────────────────────────────┘     │
│                            │ cmd, addr, data, parity_ok               │
│                            ▼                                           │
│  ┌──────────────────────────────────────────────────────────────┐     │
│  │  Parity Checker                                              │     │
│  │  calc_parity = ^{cmd[1:0], addr[13:0], data[7:0]}           │     │
│  │  parity_ok = (calc_parity == received_parity)               │     │
│  │  err_o = !parity_ok                                          │     │
│  └─────────────────────────┬────────────────────────────────────┘     │
│                            ▼                                           │
│  ┌──────────────────────────────────────────────────────────────┐     │
│  │  ADDR_DECODER (Combinational Logic)                         │     │
│  │                                                              │     │
│  │  Input: addr[13:0]                                           │     │
│  │                                                              │     │
│  │  Output: slave_sel[2:0] (one-hot encoding)                  │     │
│  │    slave_sel[0] = (addr >= 0x0000) & (addr <= 0x0FFF)       │     │
│  │    slave_sel[1] = (addr >= 0x1000) & (addr <= 0x1FFF)       │     │
│  │    slave_sel[2] = (addr >= 0x2000) & (addr <= 0x27FF)       │     │
│  │                                                              │     │
│  │  Output: decode_err = (addr >= 0x2800)                      │     │
│  └─────────────────────────┬────────────────────────────────────┘     │
│                            ▼                                           │
│  Parallel Slave Interface (Output)                                    │
│  ┌──────────────────────────────────────────────────────────────┐     │
│  │  valid_o, addr_o[13:0], wdata_o[7:0], we_o  (to slaves)     │     │
│  │  ready_i, rdata_i[7:0], err_i  (from selected slave)        │     │
│  └──────────────────────────────────────────────────────────────┘     │
│                                                                        │
│  Serial Bus Interface (Output)                                        │
│  ┌──────────────────────────────────────────────────────────────┐     │
│  │  sready_o, sdata_o  (response frame to master)               │     │
│  └──────────────────────────────────────────────────────────────┘     │
└────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Frame Decoder State Machine

```
                         ┌──────────────────┐
                         │      IDLE        │
                         │  sready_o = 1    │
                         │  Wait for frame  │
                         └─────────┬────────┘
                                   │
                      svalid_i = 1 │
                                   ▼
                         ┌──────────────────┐
                         │      SHIFT       │◄────────────┐
                         │  Shift in sdata_i│             │
                         │  on sclk rising  │             │
                         │  edge            │             │
                         └─────────┬────────┘             │
                                   │                      │
                      bit_count < 27│                     │ Repeat
                                   │                      │ 27 times
                                   └──────────────────────┘
                                   │
                    bit_count == 27│
                                   ▼
                         ┌──────────────────┐
                         │      PARSE       │
                         │  Check START=1   │
                         │  Check STOP=1    │
                         │  Verify parity   │
                         │  Extract fields  │
                         └─────────┬────────┘
                                   │
                   Frame valid?    │
                      ┌────────────┴────────────┐
                      │                         │
                  YES │                         │ NO (error)
                      ▼                         ▼
            ┌──────────────────┐      ┌──────────────────┐
            │      EXEC        │      │   RESPOND (ERR)  │
            │  Drive parallel  │      │  err_o = 1       │
            │  slave access    │      │  rdata = 0xFF    │
            │  valid_o = 1     │      └─────────┬────────┘
            └─────────┬────────┘                │
                      │                         │
          wait ready_i│                         │
                      ▼                         │
            ┌──────────────────┐                │
            │    RESPOND       │                │
            │  Build response  │                │
            │  frame (if READ) │                │
            │  Serialize back  │                │
            └─────────┬────────┘                │
                      │                         │
                      └────────┬────────────────┘
                               │
                               │ 1 cycle
                               ▼
                     Back to IDLE (loop)
```

---

## 6. Serial Arbiter

### 6.1 Arbiter Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│                        SERIAL_ARBITER Module                           │
│                                                                        │
│  Master Request Inputs                                                │
│  ┌──────────────────────────────────────────────────────────────┐     │
│  │  req[0] (Master 0 request)                                   │     │
│  │  req[1] (Master 1 request)                                   │     │
│  └─────────────────────────┬────────────────────────────────────┘     │
│                            ▼                                           │
│  ┌──────────────────────────────────────────────────────────────┐     │
│  │  Priority Logic (Combinational)                              │     │
│  │                                                              │     │
│  │  if (req[0])                priority_grant = 2'b01 (M0)     │     │
│  │  else if (req[1])           priority_grant = 2'b10 (M1)     │     │
│  │  else                       priority_grant = 2'b00 (none)   │     │
│  │                                                              │     │
│  │  (Master 0 has higher priority than Master 1)               │     │
│  └─────────────────────────┬────────────────────────────────────┘     │
│                            ▼                                           │
│  ┌──────────────────────────────────────────────────────────────┐     │
│  │  Grant Control FSM                                           │     │
│  │                                                              │     │
│  │  States:                                                     │     │
│  │    IDLE ──► GRANT_M0 ──► HOLD ──► IDLE                      │     │
│  │           └► GRANT_M1 ──► HOLD ──► IDLE                      │     │
│  │                                                              │     │
│  │  Logic:                                                      │     │
│  │  - IDLE:     gnt = 2'b00, wait for req                      │     │
│  │  - GRANT_Mx: Assert gnt[x], latch msel                      │     │
│  │  - HOLD:     Hold grant for frame_active duration           │     │
│  │              (27 serial clock cycles)                        │     │
│  │              Prevents preemption mid-frame                   │     │
│  └─────────────────────────┬────────────────────────────────────┘     │
│                            │ gnt[1:0], msel                           │
│                            ▼                                           │
│  ┌──────────────────────────────────────────────────────────────┐     │
│  │  Frame Monitor                                               │     │
│  │  frame_active = svalid & sready                              │     │
│  │  (Tracks when a frame is in flight on the bus)              │     │
│  └─────────────────────────┬────────────────────────────────────┘     │
│                            ▼                                           │
│  ┌──────────────────────────────────────────────────────────────┐     │
│  │  Split Transaction Tracker                                   │     │
│  │                                                              │     │
│  │  if (cmd == SPLIT_START):                                    │     │
│  │    split_pending = 1                                         │     │
│  │    split_owner = current_master_id                           │     │
│  │                                                              │     │
│  │  if (cmd == SPLIT_CONTINUE):                                 │     │
│  │    split_pending = 0                                         │     │
│  │                                                              │     │
│  │  Priority boost: if split_pending, grant split_owner first  │     │
│  └─────────────────────────┬────────────────────────────────────┘     │
│                            ▼                                           │
│  ┌──────────────────────────────────────────────────────────────┐     │
│  │  Serial Bus Multiplexer                                      │     │
│  │                                                              │     │
│  │  if (msel == 0):  // Master 0 granted                       │     │
│  │    sdata  = sdata_m0                                         │     │
│  │    svalid = svalid_m0                                        │     │
│  │  else:            // Master 1 granted                       │     │
│  │    sdata  = sdata_m1                                         │     │
│  │    svalid = svalid_m1                                        │     │
│  └─────────────────────────┬────────────────────────────────────┘     │
│                            ▼                                           │
│  Grant Outputs                                                        │
│  ┌──────────────────────────────────────────────────────────────┐     │
│  │  gnt[1:0]  (to masters: indicates grant status)             │     │
│  │  msel      (to bus mux: selects active master)              │     │
│  └──────────────────────────────────────────────────────────────┘     │
│                                                                        │
│  Serial Bus Outputs                                                   │
│  ┌──────────────────────────────────────────────────────────────┐     │
│  │  sdata, svalid  (multiplexed from granted master)            │     │
│  │  sready  (from slave side, broadcast to all masters)         │     │
│  └──────────────────────────────────────────────────────────────┘     │
└────────────────────────────────────────────────────────────────────────┘
```

### 6.2 Arbitration Example (Both Masters Request)

```
Timeline:
─────────────────────────────────────────────────────────────────────────

Request Signals:
req[0] ────────┐                                   ┌───────────
(Master 0)     │         REQUESTING                │
               └───────────────────────────────────┘

req[1] ────────┐                                   ┌───────────
(Master 1)     │         REQUESTING                │
               └───────────────────────────────────┘


Arbiter Decision:
Priority check: req[0] = 1 → Grant Master 0 (higher priority)

Grant Signals:
gnt[0] ────────┐                                   ┌───────────
               │         GRANTED                   │
               └───────────────────────────────────┘

gnt[1] ──────────────────────────────────────────────────────
               DENIED (must wait for M0 frame to complete)

msel   ────────┐
(to mux)       │ = 0 (Master 0 selected)
               └───────────────────────────────────


Frame Activity:
frame_active ──┐                                   ┌───────────
               │  27 bits × 4 clks = 108 cycles    │
               └───────────────────────────────────┘
               ◄─────────────────────────────────►
                     GRANT HELD (frame-atomic)


After M0 frame completes:
gnt[0] ────────┐                                   ┌───────────
               │         GRANTED                   │
               └───────────────────────────────────┘

gnt[1] ───────────────────────────────────────────┐
                                                  │ NOW GRANTED
──────────────────────────────────────────────────┘

msel   ────────┐                                  ┌───────────
               │ = 0 (M0)                         │ = 1 (M1)
               └──────────────────────────────────┘
```

---

## 7. Inter-Board Link

### 7.1 Board-to-Board Connection Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          BOARD A (DE0-Nano #1)                          │
│                                                                         │
│  ┌───────────────────────────────────────────────────────┐              │
│  │  BITSERIAL_TOP (Local System)                        │              │
│  │  - Masters, Arbiter, Serial Bus, Slaves              │              │
│  └────────────────────────┬──────────────────────────────┘              │
│                           │ sdata, svalid, sready                       │
│                           ▼                                             │
│  ┌───────────────────────────────────────────────────────┐              │
│  │  INTERBOARD_LINK (TX Path)                           │              │
│  │  ┌─────────────────────────────────────────────────┐ │              │
│  │  │  TX Logic                                       │ │              │
│  │  │  - Buffer serial data                           │ │              │
│  │  │  - Drive GPIO outputs                           │ │              │
│  │  │  - Clock forwarding                             │ │              │
│  │  └─────────────────────────────────────────────────┘ │              │
│  └────────────────────────┬──────────────────────────────┘              │
│                           │ gpio_tx[3:0]                                │
│                           ▼                                             │
│  ┌───────────────────────────────────────────────────────┐              │
│  │  GPIO_0 Bank (Physical Pins)                         │              │
│  │  PIN D3 - gpio_tx_data  (output)                     │              │
│  │  PIN C3 - gpio_tx_clk   (output)                     │              │
│  │  PIN A2 - gpio_tx_valid (output)                     │              │
│  │  PIN A3 - gpio_rx_ready (input)                      │              │
│  └────────────────────────┬──────────────────────────────┘              │
│                           │                                             │
└───────────────────────────┼─────────────────────────────────────────────┘
                            │
                            │ Physical Cable Connection
                            │ (8 wires: 4 TX, 4 RX, + GND)
                            │ Cable length: < 30 cm recommended
                            │
┌───────────────────────────┼─────────────────────────────────────────────┐
│                           │                                             │
│  ┌────────────────────────┴──────────────────────────────┐              │
│  │  GPIO_0 Bank (Physical Pins)                         │              │
│  │  PIN B3 - gpio_rx_data  (input)                      │              │
│  │  PIN B4 - gpio_rx_clk   (input)                      │              │
│  │  PIN A4 - gpio_rx_valid (input)                      │              │
│  │  PIN B5 - gpio_tx_ready (output)                     │              │
│  └────────────────────────┬──────────────────────────────┘              │
│                           │ gpio_rx[3:0]                                │
│                           ▼                                             │
│  ┌───────────────────────────────────────────────────────┐              │
│  │  INTERBOARD_LINK (RX Path)                           │              │
│  │  ┌─────────────────────────────────────────────────┐ │              │
│  │  │  CDC Synchronizers (2-FF × 4 signals)           │ │              │
│  │  │  - sync_rx_data[1:0]                            │ │              │
│  │  │  - sync_rx_clk[1:0]                             │ │              │
│  │  │  - sync_rx_valid[1:0]                           │ │              │
│  │  │  - sync_tx_ready[1:0]                           │ │              │
│  │  └─────────────────────────────────────────────────┘ │              │
│  │  ┌─────────────────────────────────────────────────┐ │              │
│  │  │  RX Logic                                       │ │              │
│  │  │  - Deserialize GPIO inputs                      │ │              │
│  │  │  - Handshake protocol                           │ │              │
│  │  │  - Drive local serial bus                       │ │              │
│  │  └─────────────────────────────────────────────────┘ │              │
│  └────────────────────────┬──────────────────────────────┘              │
│                           │ sdata, svalid, sready                       │
│                           ▼                                             │
│  ┌───────────────────────────────────────────────────────┐              │
│  │  BITSERIAL_TOP (Local System)                        │              │
│  │  - Masters, Arbiter, Serial Bus, Slaves              │              │
│  └───────────────────────────────────────────────────────┘              │
│                                                                         │
│                          BOARD B (DE0-Nano #2)                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 7.2 CDC Synchronizer Detail

```
┌────────────────────────────────────────────────────────────────────────┐
│                    2-FF Synchronizer (per GPIO signal)                 │
│                                                                        │
│  Async Input                                                           │
│  (from GPIO pin)                                                       │
│       │                                                                │
│       │  gpio_rx_data                                                  │
│       ▼                                                                │
│  ┌────────────┐            ┌────────────┐                              │
│  │  Flip-Flop │  sync[0]   │  Flip-Flop │  sync[1]                     │
│  │     #1     ├───────────►│     #2     ├──────────► Synchronized      │
│  │            │            │            │            Output            │
│  │  (Meta-    │            │  (Stable)  │                              │
│  │   stable   │            │            │                              │
│  │   region)  │            │            │                              │
│  └─────┬──────┘            └─────┬──────┘                              │
│        │                         │                                     │
│    clk_local              clk_local                                    │
│                                                                        │
│  Timing:                                                               │
│  ─────────────────────────────────────────────────────────────────     │
│                                                                        │
│  clk_local  ┌─┐  ┌─┐  ┌─┐  ┌─┐  ┌─┐  ┌─┐                              │
│             │ │  │ │  │ │  │ │  │ │  │ │                              │
│  ───────────┘ └──┘ └──┘ └──┘ └──┘ └──┘ └─────                         │
│                                                                        │
│  gpio_rx_data ───────X═══════════════════════                          │
│  (async)             │  INPUT CHANGES  │                              │
│                      └─────────────────┘                              │
│                                                                        │
│  sync[0]     ────────────X═══════════════════X──                       │
│  (FF1 out)              │  MAY BE METASTABLE │                         │
│                         └────────────────────┘                         │
│                                                                        │
│  sync[1]     ───────────────────X═══════════════════X──                │
│  (FF2 out)                     │  STABLE OUTPUT  │                    │
│  SYNCHRONIZED                  └─────────────────┘                    │
│                                                                        │
│  Latency: 2 clock cycles (40ns @ 50 MHz)                              │
│  MTBF: > 1000 years (with proper FF placement)                        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 8. Address Decode and Memory Map

### 8.1 Address Decoder Logic

```
┌────────────────────────────────────────────────────────────────────────┐
│                         ADDR_DECODER Module                            │
│                                                                        │
│  Input: addr[13:0] (14-bit address)                                   │
│         ▼                                                              │
│  ┌──────────────────────────────────────────────────────────────┐     │
│  │  Range Check Logic (Combinational)                           │     │
│  │                                                              │     │
│  │  Slave 0: 0x0000 - 0x0FFF (4096 bytes)                      │     │
│  │    slave_sel[0] = (addr >= 14'h0000) && (addr <= 14'h0FFF)  │     │
│  │                                                              │     │
│  │  Slave 1: 0x1000 - 0x1FFF (4096 bytes)                      │     │
│  │    slave_sel[1] = (addr >= 14'h1000) && (addr <= 14'h1FFF)  │     │
│  │                                                              │     │
│  │  Slave 2: 0x2000 - 0x27FF (2048 bytes)                      │     │
│  │    slave_sel[2] = (addr >= 14'h2000) && (addr <= 14'h27FF)  │     │
│  │                                                              │     │
│  │  Decode Error: addr >= 0x2800                               │     │
│  │    decode_err = (addr >= 14'h2800)                          │     │
│  └─────────────────────────┬────────────────────────────────────┘     │
│                            ▼                                           │
│  Output: slave_sel[2:0] (one-hot encoding)                            │
│          decode_err                                                   │
└────────────────────────────────────────────────────────────────────────┘
```

### 8.2 Memory Map Visualization

```
Address Space (14-bit address = 16KB range)
───────────────────────────────────────────────────────────────────────────

0x0000  ┌───────────────────────────────────────┐
        │                                       │
        │           SLAVE 0                     │
        │          4KB Memory                   │
        │       (Split-capable)                 │
        │                                       │
        │  - Can assert split_start             │
        │  - Delays response with split_continue│
        │  - Used for slow operations           │
        │                                       │
0x0FFF  ├───────────────────────────────────────┤
0x1000  │                                       │
        │           SLAVE 1                     │
        │          4KB Memory                   │
        │        (Normal operation)             │
        │                                       │
        │  - Immediate response                 │
        │  - Fast read/write                    │
        │                                       │
0x1FFF  ├───────────────────────────────────────┤
0x2000  │                                       │
        │           SLAVE 2                     │
        │          2KB Memory                   │
        │        (Normal operation)             │
        │                                       │
        │  - Immediate response                 │
0x27FF  ├───────────────────────────────────────┤
0x2800  │                                       │
        │       DECODE ERROR REGION             │
        │                                       │
        │  - No slave selected                  │
        │  - Returns decode_err = 1             │
        │  - Response data = 0xFF               │
        │                                       │
0x3FFF  └───────────────────────────────────────┘

Total addressable: 16KB (14 bits)
Total used:        10KB (Slave0 + Slave1 + Slave2)
Unused/Error:      6KB  (0x2800 - 0x3FFF)
```

---

## 9. Signal Flow Summary

### 9.1 WRITE Transaction Data Flow

```
Master 0 writes 0x42 to address 0x1234 (Slave 1)

┌─────────────────────────────────────────────────────────────────────────┐
│                           DATA FLOW PATH                                │
└─────────────────────────────────────────────────────────────────────────┘

[1] Master 0 Interface
    ──────────────────────────────────────────────────────
    valid_i = 1, addr_i = 0x1234, wdata_i = 0x42, we_i = 1
                            │
                            ▼
[2] PARALLEL_TO_SERIAL
    ──────────────────────────────────────────────────────
    - Captures request in registers
    - Builds frame: START=1, CMD=01, ADDR=0x1234, DATA=0x42
    - Calculates parity
    - Serializes to sdata_m0
                            │
                            ▼
[3] SERIAL_ARBITER
    ──────────────────────────────────────────────────────
    - Checks req[0] = 1
    - Grants M0 (gnt[0] = 1)
    - Sets msel = 0
    - Multiplexes sdata_m0 → sdata
                            │
                            ▼
[4] Serial Bus (27 bits transmitted)
    ──────────────────────────────────────────────────────
    sdata:  1_01_00010010001101_01000010_P_1
    sclk:   12.5 MHz (27 cycles = 2.16 μs)
    svalid: 1 (entire frame)
                            │
                            ▼
[5] SERIAL_TO_PARALLEL
    ──────────────────────────────────────────────────────
    - Deserializes 27 bits
    - Parses fields: CMD=01 (WRITE), ADDR=0x1234, DATA=0x42
    - Checks parity (OK)
    - Drives addr_decoder
                            │
                            ▼
[6] ADDR_DECODER
    ──────────────────────────────────────────────────────
    - Checks addr = 0x1234
    - Range: 0x1000 <= 0x1234 <= 0x1FFF
    - Asserts slave_sel[1] = 1 (Slave 1)
                            │
                            ▼
[7] SLAVE 1 Memory
    ──────────────────────────────────────────────────────
    - Receives valid_o = 1, addr_o = 0x1234, wdata_o = 0x42
    - Writes 0x42 to internal memory[0x234] (local offset)
    - Asserts ready_i = 1
                            │
                            ▼
[8] Response Path (WRITE ack)
    ──────────────────────────────────────────────────────
    - SERIAL_TO_PARALLEL asserts sready_o
    - ARBITER forwards to PARALLEL_TO_SERIAL
    - Master 0 receives ready_o = 1, err_o = 0
    - Transaction complete

Total time: ~2.18 μs
```

### 9.2 READ Transaction Data Flow

```
Master 1 reads from address 0x0100 (Slave 0), data = 0xAB

┌─────────────────────────────────────────────────────────────────────────┐
│                      REQUEST PHASE (Master → Slave)                     │
└─────────────────────────────────────────────────────────────────────────┘

[1] Master 1 Interface → [2] PARALLEL_TO_SERIAL → [3] ARBITER → 
[4] Serial Bus (27 bits: START, READ, 0x0100, 0x00, PAR, STOP) →
[5] SERIAL_TO_PARALLEL → [6] ADDR_DECODER (slave_sel[0]=1) → [7] SLAVE 0

┌─────────────────────────────────────────────────────────────────────────┐
│                      RESPONSE PHASE (Slave → Master)                    │
└─────────────────────────────────────────────────────────────────────────┘

[7] SLAVE 0
    ──────────────────────────────────────────────────────
    - Reads memory[0x100] = 0xAB
    - Asserts rdata_i = 0xAB, ready_i = 1
                            │
                            ▼
[8] SERIAL_TO_PARALLEL (Response Builder)
    ──────────────────────────────────────────────────────
    - Builds response frame: START=1, CMD=00, ADDR=0x0100, DATA=0xAB
    - Calculates parity
    - Serializes to sdata (slave → master)
                            │
                            ▼
[9] Serial Bus (27 bits response)
    ──────────────────────────────────────────────────────
    sdata:  1_00_00000100000000_10101011_P_1
    sclk:   12.5 MHz (27 cycles = 2.16 μs)
    svalid: 1 (entire frame)
                            │
                            ▼
[10] PARALLEL_TO_SERIAL (Response Receiver)
     ──────────────────────────────────────────────────────
     - Deserializes response frame
     - Extracts DATA field = 0xAB
     - Checks parity (OK)
                            │
                            ▼
[11] Master 1 Interface
     ──────────────────────────────────────────────────────
     - Receives ready_o = 1, rdata_o = 0xAB, err_o = 0
     - Transaction complete

Total time: ~4.42 μs (request + response)
```

---

## Summary

This document provides comprehensive block diagrams showing:

1. **Top-Level Architecture:** Complete system with masters, arbiter, adapters, and slaves
2. **Serial Bus Interface:** 4-wire protocol with clear signal definitions
3. **Module Hierarchy:** RTL structure with all components and sub-modules
4. **Adapter Internals:** Detailed views of serializer/deserializer logic
5. **Arbiter Design:** Priority arbitration with frame-atomic grants
6. **Inter-Board Link:** Board-to-board connection with CDC synchronizers
7. **Address Decode:** Memory map and address range checking
8. **Signal Flow:** Complete data flow paths for WRITE and READ transactions

All diagrams are based on the actual RTL implementation and accurately reflect the bit-serial bus system architecture.
