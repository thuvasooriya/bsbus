# Timing Diagrams - Bit-Serial Bus System

This document provides detailed timing diagrams for the bit-serial bus system, illustrating serial frame structure, transaction timing, arbitration, and inter-board communication.

## 1. Serial Frame Structure

### 1.1 Complete Frame Format

```
┌─────────────────────────────────────────────────────────────────┐
│ START │ CMD │ ADDR[13:0] │ DATA[7:0] │ PARITY │ STOP │
│  1b   │ 2b  │   14 bits  │  8 bits   │  1b    │  1b  │
└─────────────────────────────────────────────────────────────────┘
    Total: 27 bits per transaction
```

**Bit-by-Bit Transmission Order** (MSB first):
```
Bit  0: START (always 1)
Bit  1: CMD[1]
Bit  2: CMD[0]
Bit  3: ADDR[13]
Bit  4: ADDR[12]
...
Bit 16: ADDR[0]
Bit 17: DATA[7]
Bit 18: DATA[6]
...
Bit 24: DATA[0]
Bit 25: PARITY (even parity over CMD+ADDR+DATA)
Bit 26: STOP (always 1)
```

### 1.2 Frame Field Definitions

| Field  | Bits | Position | Description                          |
|--------|------|----------|--------------------------------------|
| START  | 1    | 0        | Frame delimiter (always 1)           |
| CMD    | 2    | 1-2      | Command: 00=READ, 01=WRITE, 10/11=SPLIT |
| ADDR   | 14   | 3-16     | Address (MSB first)                  |
| DATA   | 8    | 17-24    | Write data or read response          |
| PARITY | 1    | 25       | Even parity over CMD+ADDR+DATA       |
| STOP   | 1    | 26       | Frame delimiter (always 1)           |

**Parity Calculation:**
```
parity = ^{CMD[1:0], ADDR[13:0], DATA[7:0]}  // XOR reduction (even parity)
```

---

## 2. Clock Generation

### 2.1 Serial Clock Derivation

```
System Clock (50 MHz)
    ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐
    │ │ │ │ │ │ │ │ │ │ │ │ │ │ │ │ │ │ │ │ │ │ │ │ │ │ │ │ │ │ │ │
────┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └───
    20ns period

Serial Clock (12.5 MHz = CLK/4)
    ┌───────┐       ┌───────┐       ┌───────┐       ┌───────┐
    │       │       │       │       │       │       │       │
────┘       └───────┘       └───────┘       └───────┘       └───────────
    80ns period (4 system clocks)
    
    ◄──────►
     4 clks  = 80ns bit period
```

**Clock Characteristics:**
- System clock: 50 MHz (20ns period)
- Serial clock (sclk): 12.5 MHz (80ns period)
- Clock divider: SERIAL_CLK_DIV = 4
- Data sampled on: Rising edge of sclk
- Data stable on: Falling edge of sclk

---

## 3. WRITE Transaction Timing

### 3.1 Single WRITE Transaction

```
Master writes 0x42 to address 0x1234

System Clock (50 MHz)
    ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐
clk │ │ │ │ │ │ │ │ │ │ │ │ │ │ │ │ │ │ │ │ │ │ │ │
────┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └───

Serial Clock (12.5 MHz)
     ┌───────┐       ┌───────┐       ┌───────┐
sclk │       │       │       │       │       │
─────┘       └───────┘       └───────┘       └───────────
     ◄──────►◄──────►◄──────►
       BIT0    BIT1    BIT2    (continues for 27 bits)

Serial Data
sdata ──╥──────X───────X───────X─────  (continues)
        ║START │ CMD1  │ CMD0  │ ADDR13...
        ╙──1───┴───0───┴───1───┴──────  (WRITE = 01)

Serial Valid
svalid ────────────────────────────────  (high during frame)
       ┌─────────────────────────────┐
       │                             │
───────┘                             └──────

Serial Ready
sready ────────────────────────────────  (slave ready)
       ┌─────────────────────────────┐
       │                             │
───────┘                             └──────
```

**Timing Parameters:**
- Frame duration: 27 bits × 80ns = 2.16 μs
- Setup time: Data stable 10ns before sclk rising edge
- Hold time: Data held 10ns after sclk rising edge

### 3.2 WRITE Transaction Complete Frame

```
Bit:   0    1 2   3  4  5  6  7  8  9 10 11 12 13 14 15 16   17 18 19 20 21 22 23 24   25   26
Field: ST   CMD   ADDR[13:0]                                  DATA[7:0]                 PAR  STP
Value: 1    01    00010010001101 (0x1234)                     01000010 (0x42)           P    1
                  │              │                            │                         │
                  └──MSB first───┘                            └───MSB first─────────────┘

Complete bit stream (27 bits):
1 01 00010010001101 01000010 P 1
│ └──WRITE          └──0x42
└──START
```

**Example WRITE 0x42 to 0x1234:**
1. START = 1
2. CMD = 01 (WRITE)
3. ADDR = 00010010001101 (0x1234)
4. DATA = 01000010 (0x42)
5. PARITY = ^{01,00010010001101,01000010} = 0
6. STOP = 1

Full frame: `1_01_00010010001101_01000010_0_1`

---

## 4. READ Transaction Timing

### 4.1 READ Request and Response

```
Master reads from address 0x0100, slave returns 0xAB

REQUEST FRAME (Master → Slave)
────────────────────────────────────────────────────────────────

Serial Clock
     ┌───┐   ┌───┐   ┌───┐   ┌───┐     ...     ┌───┐   ┌───┐
sclk │   │   │   │   │   │   │   │             │   │   │   │
─────┘   └───┘   └───┘   └───┘   └─────────────┘   └───┘   └───

Serial Data (Master TX)
sdata_mosi ─╥───X───X───X───X─────────────X───X─
            ║ST │CMD│CMD│A13│  ...  │A0 │D7 │...│D0 │PAR│STP│
            ╙─1─┴─0─┴─0─┴─0─┴───────┴───┴───┴───────┴─P─┴─1─┘
                   └──READ (00)      └──Don't care for READ

Valid/Ready Handshake
svalid_mosi ┌─────────────────────────────────────────────┐
            │          REQUEST PHASE                      │
────────────┘                                             └────

sready_slave┌─────────────────────────────────────────────┐
            │          Slave accepts request              │
────────────┘                                             └────


RESPONSE FRAME (Slave → Master)
────────────────────────────────────────────────────────────────

Serial Data (Slave TX)
sdata_miso  ─╥───X───X───X───X─────────────X───X─
            ║ST │CMD│CMD│A13│  ...  │A0 │D7 │...│D0 │PAR│STP│
            ╙─1─┴─0─┴─0─┴─0─┴───────┴───┴─1─┴─0─┴─1─┴─0─┴─1─┘
                   └──READ (00)      └──0xAB response data

Valid/Ready Handshake
svalid_miso ┌─────────────────────────────────────────────┐
            │          RESPONSE PHASE                     │
────────────┘                                             └────

sready_master┌────────────────────────────────────────────┐
             │          Master accepts response           │
─────────────┘                                            └────
```

**READ Transaction Phases:**
1. **Request Phase (27 bits, 2.16 μs)**
   - Master sends: START + READ cmd + address + 0x00 + parity + STOP
   - DATA field is don't care (typically 0x00)
   
2. **Response Phase (27 bits, 2.16 μs)**
   - Slave sends: START + READ cmd + same address + read data + parity + STOP
   - DATA field contains actual read data from memory

**Total READ latency:** ~4.32 μs (54 serial clock cycles)

### 4.2 READ Transaction Example

**Request frame (Read from 0x0100):**
```
Bit stream: 1_00_00000100000000_00000000_P_1
            │ └─READ  └───0x0100  └──0x00
            └─START                (don't care)
```

**Response frame (Data = 0xAB):**
```
Bit stream: 1_00_00000100000000_10101011_P_1
            │ └─READ  └───0x0100  └──0xAB
            └─START                (actual data)
```

---

## 5. Split Transaction Timing

### 5.1 SPLIT Transaction Sequence

```
Master writes to Slave 0 (split-capable), slave not ready

INITIAL WRITE REQUEST
─────────────────────────────────────────────────────────────

sclk        ┌───┐   ┌───┐   ┌───┐         ┌───┐   ┌───┐
            │   │   │   │   │   │   ...   │   │   │   │
────────────┘   └───┘   └───┘   └─────────┘   └───┘   └─────

sdata       ─╥───X───X───X───────────X───X─
            ║ST │CMD│CMD│ADDR...    │DATA...│PAR│STP│
            ╙─1─┴─0─┴─1─┴───────────┴───────┴─P─┴─1─┘
                   └─WRITE (01)

svalid      ┌─────────────────────────────────────┐
            │         REQUEST                     │
────────────┘                                     └──────────

sready      ┐                                     ┌──────────
(slave)     │         NOT READY                   │
            └─────────────────────────────────────┘


SPLIT_START RESPONSE (Slave indicates not ready)
─────────────────────────────────────────────────────────────

sdata       ─╥───X───X───X───────────X───X─
(slave)     ║ST │CMD│CMD│ADDR...    │DATA...│PAR│STP│
            ╙─1─┴─1─┴─0─┴───────────┴───────┴─P─┴─1─┘
                   └─SPLIT_START (10)

svalid      ┌─────────────────────────────────────┐
(slave)     │       SPLIT NOTIFICATION            │
────────────┘                                     └──────────


MASTER POLLS OR WAITS...
─────────────────────────────────────────────────────────────

(Delay period: slave processes transaction in background)


SPLIT_CONTINUE RESPONSE (Slave now ready with data)
─────────────────────────────────────────────────────────────

sdata       ─╥───X───X───X───────────X───X─
(slave)     ║ST │CMD│CMD│ADDR...    │DATA...│PAR│STP│
            ╙─1─┴─1─┴─1─┴───────────┴───────┴─P─┴─1─┘
                   └─SPLIT_CONTINUE (11)

svalid      ┌─────────────────────────────────────┐
(slave)     │      DATA READY                     │
────────────┘                                     └──────────

sready      ┌─────────────────────────────────────┐
(master)    │      Master accepts data            │
────────────┘                                     └──────────
```

**Split Transaction Timeline:**
```
Time    Event
────────────────────────────────────────────────────────
0 μs    Master sends WRITE request (CMD=01)
2.2 μs  Slave responds with SPLIT_START (CMD=10)
        (Master releases bus, other masters can use)
        
2.2 μs  Slave processes transaction in background
to      (Memory operation, computation, etc.)
X μs    

X μs    Slave asserts split_ready signal
        Master polls or arbiter grants access
        
X μs    Slave sends SPLIT_CONTINUE frame (CMD=11)
        with write acknowledgment or read data
        
X+2.2   Transaction complete
```

**Key Features:**
- Bus freed during split processing (other masters can access)
- Arbiter tracks split owner (master ID)
- Split completion can be polled or interrupt-driven
- Slave 0 only (address range 0x0000-0x0FFF)

---

## 6. Arbitration Timing

### 6.1 Priority Arbitration (Master 0 Wins)

```
Both masters request bus simultaneously, Master 0 has priority

Request Signals
req[0] ──────────┐                              ┌──────────
(Master 0)       │         GRANTED              │
                 └──────────────────────────────┘

req[1] ──────────┐                              ┌──────────
(Master 1)       │         WAITING              │
                 └──────────────────────────────┘

Grant Signals
gnt[0] ────────────┐                          ┌────────────
(to Master 0)      │      M0 ACTIVE           │
                   └──────────────────────────┘

gnt[1] ────────────────────────────────────────────────────
(to Master 1)                DENIED


Frame Active (from arbiter monitoring)
frame_active ────┐                            ┌────────────
                 │    27-bit frame in flight  │
                 └────────────────────────────┘
                 ◄──────────────────────────►
                         2.16 μs
                   (GRANT HELD FOR FULL FRAME)


Serial Bus
svalid ────────────┐                          ┌────────────
                   │    Master 0 transaction  │
                   └──────────────────────────┘

sdata  ────────────╥──────────────────────────╨────────────
                   ║   Master 0 serial data   ║
                   ╙──────────────────────────┴────────────
```

**Arbitration Rules:**
1. **Priority:** Master 0 > Master 1 (fixed priority)
2. **Frame-Atomic:** Grant held for entire 27-bit frame
3. **No Preemption:** Active frame cannot be interrupted
4. **Fair Queuing:** After frame completes, arbiter re-evaluates

### 6.2 Arbitration State Machine

```
IDLE State
────────────────────────────────────────────────────────────
Condition: No requests pending
Action:    gnt[1:0] = 2'b00
           frame_active = 0


GRANT_M0 State
────────────────────────────────────────────────────────────
Condition: req[0] = 1 (regardless of req[1])
Action:    gnt[1:0] = 2'b01
           frame_active = 1 (when svalid asserts)
Duration:  Until frame completes (svalid deasserts)


GRANT_M1 State
────────────────────────────────────────────────────────────
Condition: req[0] = 0 AND req[1] = 1
Action:    gnt[1:0] = 2'b10
           frame_active = 1 (when svalid asserts)
Duration:  Until frame completes (svalid deasserts)


SPLIT_HOLD State (if applicable)
────────────────────────────────────────────────────────────
Condition: split_pending = 1, split_owner = M0 or M1
Action:    Hold grant for split owner until SPLIT_CONTINUE
Exception: Other masters can still access non-split slaves
```

**Arbiter Inputs:**
- `req[1:0]`: Master request signals
- `frame_active`: Frame in progress (don't switch)
- `split_pending`: Split transaction active
- `split_owner[1:0]`: Which master owns split

**Arbiter Outputs:**
- `gnt[1:0]`: Grant signals to masters
- `msel`: Master select to serial mux (0=M0, 1=M1)

---

## 7. Inter-Board Communication

### 7.1 Board-to-Board Frame Transfer

```
BOARD A (Master Side)                    BOARD B (Slave Side)
═══════════════════════════════════════════════════════════════

Local Serial Clock (12.5 MHz)
sclk_local ┌───┐   ┌───┐   ┌───┐   ┌───┐
           │   │   │   │   │   │   │   │
───────────┘   └───┘   └───┘   └───┘   └────────────


GPIO TX Signals
─────────────────────────────────────────────────────────
gpio_tx_data ──╥───X───X───X───X─────────X───X─
               ║ST │CMD│...│   │   ...   │STP│
               ╙───┴───┴───┴───┴─────────┴───┘

gpio_tx_clk  ┌───┐   ┌───┐   ┌───┐   ┌───┐
             │   │   │   │   │   │   │   │
─────────────┘   └───┘   └───┘   └───┘   └──────────

gpio_tx_valid┌─────────────────────────────────┐
             │         FRAME VALID             │
─────────────┘                                 └──────────

gpio_rx_ready┌─────────────────────────────────┐
             │      Board B ready              │
─────────────┘                                 └──────────


CABLE CONNECTION (Physical GPIO Pins)
═══════════════════════════════════════════════════════════
Board A GPIO_0[0] ────────────────────► Board B GPIO_0[4]  (data)
Board A GPIO_0[1] ────────────────────► Board B GPIO_0[5]  (clk)
Board A GPIO_0[2] ────────────────────► Board B GPIO_0[6]  (valid)
Board A GPIO_0[3] ◄──────────────────── Board B GPIO_0[7]  (ready)
       GND        ◄────────────────────►       GND         (common)


GPIO RX Signals (Board B)
─────────────────────────────────────────────────────────
gpio_rx_data ──╥───X───X───X───X─────────X───X─
               ║ST │CMD│...│   │   ...   │STP│
               ╙───┴───┴───┴───┴─────────┴───┘
               (Same as Board A TX, after CDC)

gpio_rx_clk  ┌───┐   ┌───┐   ┌───┐   ┌───┐
             │   │   │   │   │   │   │   │
─────────────┘   └───┘   └───┘   └───┘   └──────────
             (Synchronized to Board B clock domain)

gpio_rx_valid┌─────────────────────────────────┐
             │         FRAME VALID             │
─────────────┘                                 └──────────

gpio_tx_ready┌─────────────────────────────────┐
             │      Board B ready to accept    │
─────────────┘                                 └──────────


Local Serial Interface (Board B)
─────────────────────────────────────────────────────────
sdata_slave ──╥───X───X───X───X─────────X───X─
              ║ST │CMD│...│   │   ...   │STP│
              ╙───┴───┴───┴───┴─────────┴───┘

sclk_slave  ┌───┐   ┌───┐   ┌───┐   ┌───┐
            │   │   │   │   │   │   │   │
────────────┘   └───┘   └───┘   └───┘   └──────────
            (Reconstructed from gpio_rx_clk)

svalid_slave┌─────────────────────────────────┐
            │         FRAME VALID             │
────────────┘                                 └──────────
```

### 7.2 Clock Domain Crossing (CDC)

```
TRANSMIT PATH (Board A: Local Clock → GPIO)
═══════════════════════════════════════════════════════════

clk_local  ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐
(50 MHz)   │ │ │ │ │ │ │ │ │ │ │ │ │ │ │ │
───────────┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └────────

tx_data_local ─────X═══════════════════X─────
(sync)             │   STABLE DATA     │
                   └───────────────────┘

gpio_tx_data ──────────X═══════════════════X────
(async output)         │   STABLE DATA     │
                       └───────────────────┘
                       (Registered output)


RECEIVE PATH (Board B: GPIO → Local Clock)
═══════════════════════════════════════════════════════════

gpio_rx_data ──────X═══════════════════X────
(async input)      │   INCOMING DATA   │
                   └───────────────────┘

clk_local  ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐
(50 MHz)   │ │ │ │ │ │ │ │ │ │ │ │ │ │ │ │
───────────┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └────────

sync_ff1   ────────────X═══════════════════X───
(1st flop)             │   METASTABLE?     │

sync_ff2   ────────────────X═══════════════════X
(2nd flop)                 │   STABLE DATA │
                           └───────────────┘

rx_data_local ─────────────────X═══════════════════X
(synchronized)                 │   STABLE DATA │
                               └───────────────┘
```

**CDC Implementation:**
```systemverilog
// 2-FF synchronizer for each GPIO input signal
logic [1:0] sync_rx_data;
logic [1:0] sync_rx_valid;

always_ff @(posedge clk_local_i or negedge rst_local_ni) begin
  if (!rst_local_ni) begin
    sync_rx_data  <= 2'b00;
    sync_rx_valid <= 2'b00;
  end else begin
    sync_rx_data  <= {sync_rx_data[0],  gpio_rx_data_i};
    sync_rx_valid <= {sync_rx_valid[0], gpio_rx_valid_i};
  end
end

assign rx_sdata_o  = sync_rx_data[1];   // 2-cycle delay, stable
assign rx_svalid_o = sync_rx_valid[1];
```

**Timing Constraints (SDC):**
```tcl
# Mark async paths as false paths
set_false_path -from [get_ports gpio_rx_*] -to [get_registers sync_*[0]]

# Max delay constraint for metastability settling
set_max_delay 15.0 -from [get_ports gpio_rx_*] -to [get_registers sync_*[0]]
```

### 7.3 Handshake Protocol

```
FOUR-WIRE HANDSHAKE (Request → Acknowledge)
═══════════════════════════════════════════════════════════

Board A (Transmitter)                Board B (Receiver)
─────────────────────────────────────────────────────────

1. Board A asserts TX_VALID
   gpio_tx_valid ────────┐
                         │
   ──────────────────────┘

2. Board B synchronizes RX_VALID
   (After 2-FF sync: 2 clock cycles delay)
   gpio_rx_valid ────────────┐
                             │
   ──────────────────────────┘

3. Board B processes data, asserts TX_READY
   gpio_tx_ready ────────────────┐
   (Board B)                     │
   ──────────────────────────────┘

4. Board A receives RX_READY (synchronized)
   gpio_rx_ready ────────────────────┐
   (Board A)                         │
   ──────────────────────────────────┘

5. Board A deasserts TX_VALID
   gpio_tx_valid ────────┐           ┌─────
                         │           │
   ──────────────────────┘           └─────

6. Board B deasserts TX_READY
   gpio_tx_ready ────────────────┐   ┌─────
   (Board B)                     │   │
   ──────────────────────────────┘   └─────

   Transaction complete, ready for next frame
```

**Handshake Timing:**
```
Event                          Time (approx)
───────────────────────────────────────────────────────
Board A asserts TX_VALID       0 ns
Board B sees RX_VALID          40 ns (2 clocks @ 50 MHz)
Board B processes frame        40-2200 ns (27 bits)
Board B asserts TX_READY       2200 ns
Board A sees RX_READY          2240 ns (2 clocks delay)
Board A deasserts TX_VALID     2240 ns
Board B deasserts TX_READY     2280 ns
Next frame can start           2300 ns

Total inter-board latency: ~2.3 μs per frame
(Additional ~100ns overhead vs. local transfer)
```

---

## 8. Back-to-Back Transactions

### 8.1 Pipelined Transactions

```
Master performs consecutive writes to different slaves

Transaction 1: WRITE 0xAA to Slave 1 (0x1000)
Transaction 2: WRITE 0xBB to Slave 2 (0x2000)
Transaction 3: READ from Slave 0 (0x0500)

═══════════════════════════════════════════════════════════

sclk    ┌─┐ ┌─┐ ┌─┐     ┌─┐ ┌─┐ ┌─┐     ┌─┐ ┌─┐ ┌─┐
        │ │ │ │ │ │ ... │ │ │ │ │ │ ... │ │ │ │ │ │
────────┘ └─┘ └─┘ └─────┘ └─┘ └─┘ └─────┘ └─┘ └─┘ └────

sdata   ────╥═══════════╨─╥═══════════╨─╥═══════════╨───
            ║   TX1      ║ ║   TX2      ║ ║   TX3 REQ  ║
            ╙════════════┘ ╙════════════┘ ╙════════════┘

svalid  ────┐             ┌┐             ┌┐             ┌─
            │             ││             ││             │
            └─────────────┘└─────────────┘└─────────────┘
            ◄────2.16μs───►◄────2.16μs───►◄────2.16μs───►
                 TX1            TX2            TX3 REQ

sready  ────┐             ┌┐             ┌┐             ┌─
            │   Slave1    ││   Slave2    ││   Slave0    │
            └─────────────┘└─────────────┘└─────────────┘


(For TX3 READ, slave responds with data frame)
sdata   ─────────────────────────────────────╥═══════════╨
(slave)                                      ║ TX3 RESP  ║
                                             ╙════════════┘

svalid  ─────────────────────────────────────┐           ┌─
(slave)                                      │           │
                                             └───────────┘
                                             ◄────2.16μs─►
                                                TX3 RESP

Total time: 3 × 2.16μs (req) + 1 × 2.16μs (resp) = 8.64μs
Throughput: ~463 kB/s (4 frames × 8 bits / 8.64μs)
```

**Pipeline Efficiency:**
- **Zero idle cycles** between frames (svalid deasserts for 1 clock)
- **Full bandwidth utilization** when arbiter grants consecutive
- **READ latency:** 2 frames (request + response)
- **WRITE latency:** 1 frame (fire-and-forget)

### 8.2 Inter-Frame Gap

```
Minimum gap between frames (1 serial clock cycle)

Frame N                 Frame N+1
═══════════════════════════════════════════════════════

sclk    ┌───┐   ┌───┐   ┌───┐   ┌───┐   ┌───┐
        │   │   │   │   │   │   │   │   │   │
────────┘   └───┘   └───┘   └───┘   └───┘   └─────
            ▲                       ▲
            │                       │
           BIT26 (STOP)            BIT0 (START)
            │                       │
sdata   ────╨───────────────────────╥───────────────
            1                       1
           (STOP)                  (START)

svalid  ────┐                       ┌───────────────
            │                       │
            └───────────────────────┘
            ◄───►
            80ns gap (1 sclk cycle)

ready_o ────┐                   ┌───────────────────
(master)    │   DONE            │   READY FOR NEXT
            └───────────────────┘
```

**Gap Timing:**
- Minimum: 1 serial clock cycle (80ns @ 12.5 MHz)
- Typical: 1-2 system clock cycles (20-40ns) for FSM transition
- Maximum: Unlimited (master can wait indefinitely)

---

## 9. Error Handling

### 9.1 Parity Error Detection

```
Frame with incorrect parity

Transmitted Frame (parity bit flipped by noise)
═══════════════════════════════════════════════════════════

sdata   ────╥═══╦═══════════════════════════╦═══╦═══╨───
            ║ST ║CMD│ADDR...│DATA...        ║BAD║STP║
            ╙═══╩═══════════════════════════╩═╝═╩═══┘
                │                           │
                └───────────────────────────┘
                      XOR = 1 (odd)
                Expected parity = 0, Received = 1


Deserializer Detection
═══════════════════════════════════════════════════════════

calc_parity = ^{CMD, ADDR, DATA} = 0 (even parity)
recv_parity = 1 (from frame bit 25)

parity_error = (calc_parity != recv_parity) = 1


Error Response
═══════════════════════════════════════════════════════════

err_o ───────────────────────────────────┐
(to master)                              │  ERROR
─────────────────────────────────────────┘

ready_o ─────────────────────────────────┐
(to master)                              │  DONE
─────────────────────────────────────────┘

rdata_o ─────────────────────────────────X──────────
(to master)                              │ 0xFF
─────────────────────────────────────────┴──────────
                                    (Error indicator)
```

**Error Recovery:**
1. Deserializer detects parity mismatch
2. Asserts `err_o` to master
3. Master retries transaction or reports error
4. Optional: Increment error counter for monitoring

### 9.2 Frame Decode Error (Invalid Address)

```
Master attempts access to invalid address 0x3000 (>0x27FF)

═══════════════════════════════════════════════════════════

Address Decoder
───────────────────────────────────────────────────────────
Input:  addr = 14'h3000 (0011_0000_0000_0000)
Check:  addr >= 14'h2800?  YES → DECODE ERROR

slave_sel[2:0] = 3'b000 (no slave selected)
decode_err     = 1


Error Frame Response
───────────────────────────────────────────────────────────

sdata   ────╥═══╦═══════════════════════════╦═══╦═══╨───
(slave)     ║ST ║CMD│ADDR...│DATA...        ║PAR║STP║
            ╙═══╩═══════════════════════════╩═══╩═══┘
                │           └──0xFF (error code)

err_o ───────────────────────────────────┐
(to master)                              │  ADDR ERROR
─────────────────────────────────────────┘

rdata_o ─────────────────────────────────X──────────
                                         │ 0xFF
─────────────────────────────────────────┴──────────
```

**Address Decode Error Handling:**
- Addresses ≥ 0x2800 are invalid (beyond Slave 2 range)
- `addr_decoder` asserts `decode_err`
- Response frame DATA field = 0xFF (error indicator)
- `err_o` signal asserted to master

---

## 10. Performance Analysis

### 10.1 Bandwidth Calculation

**Serial Bus Bandwidth:**
```
Serial clock: 12.5 MHz
Bit time: 80 ns
Frame size: 27 bits
Data payload: 8 bits

Raw bit rate: 12.5 Mbit/s
Effective data rate (WRITE):
  = (8 data bits) / (27 frame bits × 80ns)
  = 8 bits / 2.16 μs
  = 3.7 Mbit/s = 463 kB/s

Effective data rate (READ):
  = (8 data bits) / (2 × 27 frame bits × 80ns)
  = 8 bits / 4.32 μs
  = 1.85 Mbit/s = 231 kB/s

Overhead: 19 bits per 8 data bits = 237% overhead
  (START + CMD + ADDR + PARITY + STOP = 19 bits)
```

**Comparison to Parallel Bus:**
```
Parallel Bus (hypothetical):
  - 1 clock cycle per transaction (@ 50 MHz)
  - 8 bits data per 20ns = 400 Mbit/s = 50 MB/s

Serial Bus:
  - 27 clock cycles per transaction (@ 12.5 MHz)
  - 8 bits data per 2.16μs = 3.7 Mbit/s = 463 kB/s

Bandwidth ratio: Serial / Parallel = 0.9% (~100x slower)

Trade-off: 14 address + 8 data + control = 26 wires reduced to 4 wires
Pin savings: 84% fewer signals
```

### 10.2 Latency Breakdown

```
WRITE Transaction Latency
───────────────────────────────────────────────────────────
Component                          Cycles (50MHz)    Time
───────────────────────────────────────────────────────────
Frame serialization (27 bits)      108 (27×4)        2.16 μs
Master ready assert                1                 20 ns
───────────────────────────────────────────────────────────
Total WRITE latency:               109               2.18 μs


READ Transaction Latency
───────────────────────────────────────────────────────────
Component                          Cycles (50MHz)    Time
───────────────────────────────────────────────────────────
Request frame serialization        108 (27×4)        2.16 μs
Slave memory access                4-10              80-200 ns
Response frame serialization       108 (27×4)        2.16 μs
Master data capture                1                 20 ns
───────────────────────────────────────────────────────────
Total READ latency:                221-227           4.42-4.54 μs


SPLIT Transaction Latency (Worst Case)
───────────────────────────────────────────────────────────
Component                          Cycles (50MHz)    Time
───────────────────────────────────────────────────────────
Initial request frame              108               2.16 μs
SPLIT_START response               108               2.16 μs
Slave processing delay             variable          100μs-1ms
SPLIT_CONTINUE response            108               2.16 μs
───────────────────────────────────────────────────────────
Total SPLIT latency:               324 + delay       6.48μs + delay
```

---

## Summary

This document provides comprehensive timing diagrams for all critical operations in the bit-serial bus system:

1. **Frame Structure:** 27-bit serial frames with START/STOP delimiters and parity
2. **Clock Generation:** 12.5 MHz serial clock derived from 50 MHz system clock
3. **Transactions:** WRITE (1 frame), READ (2 frames), SPLIT (3+ frames)
4. **Arbitration:** Frame-atomic priority-based arbitration
5. **Inter-Board:** 4-wire GPIO interface with CDC and handshake protocol
6. **Error Handling:** Parity check and address decode error detection
7. **Performance:** 463 kB/s WRITE, 231 kB/s READ throughput

**Key Timing Parameters:**
- Bit period: 80 ns (4 system clocks)
- Frame duration: 2.16 μs (27 bits)
- WRITE latency: 2.18 μs
- READ latency: 4.42 μs
- Inter-board overhead: ~100 ns per transfer

All timing diagrams are based on the actual RTL implementation and verified through simulation.
