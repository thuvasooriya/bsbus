# Bit-Serial Bus System - Demo Guide

## Overview

This guide provides step-by-step instructions for demonstrating the bit-serial bus system on Altera DE0-Nano FPGA boards. The demo showcases both single-board loopback and inter-board communication capabilities.

**System Summary:**
- **Protocol:** 27-bit serial frames (START/CMD/ADDR/DATA/PARITY/STOP)
- **Interface:** 4-wire serial bus (sdata, sclk, svalid, sready)
- **Clock:** 50 MHz system, 12.5 MHz serial (CLK/4)
- **Performance:** 463 kB/s WRITE, 231 kB/s READ throughput
- **Target:** Cyclone IV E EP4CE22F17C6 on DE0-Nano

---

## Hardware Requirements

### Equipment Needed

**For Single-Board Demo:**
- 1x Altera DE0-Nano board
- 1x USB Blaster cable (included with DE0-Nano)
- 1x USB cable for power
- PC with Quartus Programmer

**For Inter-Board Demo:**
- 2x Altera DE0-Nano boards
- 2x USB Blaster cables
- 8x female-to-female jumper wires (for GPIO connections)
- 2x USB cables for power
- PC with Quartus Programmer

### DE0-Nano Board Specifications

- **Device:** Cyclone IV E EP4CE22F17C6
- **Logic Elements:** 22,320 LEs
- **Memory:** 66 M9K blocks (594 Kbits)
- **Clock:** 50 MHz onboard oscillator
- **GPIO:** 2x 40-pin expansion headers (GPIO_0, GPIO_1)
- **User I/O:** 8 LEDs, 2 push-buttons, 4 DIP switches

---

## Pin Assignments

### System Pins

| Signal | Pin | Location | Description |
|--------|-----|----------|-------------|
| clk | R8 | Clock input | 50 MHz oscillator |
| rst_n | J15 | KEY0 | Active-low reset button |

### Demo Interface Pins

| Signal | Pin | Location | Description |
|--------|-----|----------|-------------|
| SW[0] | M1 | DIP switch 0 | Master 0 request trigger |
| SW[1] | T8 | DIP switch 1 | Master 1 request trigger |
| SW[2] | B9 | DIP switch 2 | Command select (0=WRITE, 1=READ) |
| SW[3] | M15 | DIP switch 3 | Address bit for slave select |
| LED[0] | A15 | LED 0 | Master 0 busy indicator |
| LED[1] | A13 | LED 1 | Master 1 busy indicator |
| LED[2] | B13 | LED 2 | Slave 0 response ready |
| LED[3] | A11 | LED 3 | Slave 1 response ready |
| LED[4] | D1 | LED 4 | Slave 2 response ready |
| LED[5] | F3 | LED 5 | Error indicator (parity/decode) |
| LED[6] | B1 | LED 6 | Serial bus active |
| LED[7] | L3 | LED 7 | Inter-board link active |

### Inter-Board GPIO Connections (GPIO_0 Bank)

**Outbound Signals (Board A → Board B):**

| Signal | Pin | GPIO_0 Pin | Description |
|--------|-----|------------|-------------|
| sdata_out | A8 | GPIO_0[0] | Serial data output |
| sclk_out | D3 | GPIO_0[1] | Serial clock output |
| svalid_out | B8 | GPIO_0[2] | Serial valid output |
| sready_in | C3 | GPIO_0[3] | Serial ready input |

**Inbound Signals (Board B → Board A):**

| Signal | Pin | GPIO_0 Pin | Description |
|--------|-----|------------|-------------|
| sdata_in | A2 | GPIO_0[4] | Serial data input |
| sclk_in | A3 | GPIO_0[5] | Serial clock input |
| svalid_in | B3 | GPIO_0[6] | Serial valid input |
| sready_out | B4 | GPIO_0[7] | Serial ready output |

**Note:** All GPIO pins are configured as 3.3V LVTTL with 8mA drive strength.

---

## Setup Procedure

### Step 1: Program the FPGA

**Prerequisites:**
- Quartus Programmer installed
- Bitstream file: `fpga/quartus/output_files/bitserial.sof`
- USB Blaster driver installed

**Programming Steps:**

1. **Connect Hardware:**
   - Connect USB Blaster to DE0-Nano JTAG header
   - Connect USB cable to DE0-Nano for power
   - Power on the board

2. **Launch Quartus Programmer:**
   ```bash
   quartus_pgm
   ```

3. **Configure Programmer:**
   - Click "Hardware Setup"
   - Select USB Blaster device
   - Click "Auto Detect" to find EP4CE22
   - Right-click device → "Change File"
   - Select `bitserial.sof`
   - Check "Program/Configure"

4. **Program Device:**
   - Click "Start" button
   - Wait for "100% Successful" message
   - LEDs should light up in test pattern

5. **Verify Programming:**
   - Press KEY0 (reset button)
   - All LEDs should turn off briefly, then resume
   - System is now ready

**Alternative: Command-Line Programming:**
```bash
cd fpga/quartus
quartus_pgm -c USB-Blaster -m JTAG -o "p;output_files/bitserial.sof@1"
```

### Step 2: Initial System Check

**Power-On State:**
- All LEDs should be OFF after reset
- No switches should be active
- System is idle

**Reset Test:**
1. Press and hold KEY0 (rst_n)
2. All LEDs should turn OFF
3. Release KEY0
4. LEDs remain OFF (idle state)
5. System ready for operation

---

## Demo 1: Single-Board Loopback

This demo verifies the serializer and deserializer work correctly by looping TX back to RX on the same board.

### Configuration

**Internal Loopback Mode:**
- RTL parameter `LOOPBACK_MODE = 1` in `bitserial_top.sv`
- TX output directly feeds RX input
- No external GPIO connections needed

### Demo Procedure

#### Test 1: Master 0 WRITE Transaction

**Setup:**
1. Reset system (press KEY0)
2. Set SW[3:0] = 4'b0000 (Master 0, WRITE, Slave 0)

**Execute:**
1. Toggle SW[0] HIGH → LOW (Master 0 request)
2. **Observe:**
   - LED[0] turns ON (Master 0 busy)
   - LED[6] turns ON (serial bus active)
   - After ~27 serial clock cycles:
     - LED[2] turns ON (Slave 0 response)
     - LED[0] turns OFF (Master 0 done)
     - LED[6] turns OFF (bus idle)

**Expected Timing:**
- Serial transaction: 27 bits × 80 ns = 2.16 µs
- Total latency: ~3 µs (includes arbitration)

#### Test 2: Master 0 READ Transaction

**Setup:**
1. Reset system
2. Set SW[3:0] = 4'b0100 (Master 0, READ, Slave 0)

**Execute:**
1. Toggle SW[0] HIGH → LOW
2. **Observe:**
   - LED[0] turns ON (Master 0 busy)
   - LED[6] turns ON (serial bus active)
   - After ~54 serial clock cycles:
     - LED[2] turns ON (Slave 0 response with data)
     - LED[0] turns OFF (Master 0 done)
     - LED[6] turns OFF (bus idle)

**Expected Timing:**
- Command frame: 27 bits
- Response frame: 27 bits
- Total: 54 bits × 80 ns = 4.32 µs

#### Test 3: Master 1 WRITE Transaction

**Setup:**
1. Reset system
2. Set SW[3:0] = 4'b0010 (Master 1, WRITE, Slave 1)

**Execute:**
1. Toggle SW[1] HIGH → LOW (Master 1 request)
2. **Observe:**
   - LED[1] turns ON (Master 1 busy)
   - LED[6] turns ON (serial bus active)
   - LED[3] turns ON (Slave 1 response)
   - LED[1] turns OFF (Master 1 done)

#### Test 4: Arbitration - Both Masters Request

**Setup:**
1. Reset system
2. Set SW[3:0] = 4'b0011 (both masters ready, WRITE)

**Execute:**
1. Toggle SW[0] and SW[1] LOW simultaneously
2. **Observe:**
   - LED[0] turns ON first (Master 0 has priority)
   - LED[6] turns ON (bus active)
   - LED[0] turns OFF (Master 0 completes)
   - LED[1] turns ON (Master 1 gets bus)
   - LED[1] turns OFF (Master 1 completes)

**Verification:**
- Master 0 always wins arbitration
- Master 1 waits until bus is free
- Frame-atomic arbitration (no interruption)

#### Test 5: Split Transaction (Slave 0 Only)

**Setup:**
1. Reset system
2. Set SW[3:0] = 4'b0100 (Master 0, READ, Slave 0)

**Execute:**
1. Toggle SW[0] HIGH → LOW
2. **Observe:**
   - LED[0] turns ON (Master 0 busy)
   - LED[6] turns ON (bus active)
   - LED[2] blinks briefly (Slave 0 WAIT response)
   - LED[0] remains ON (Master 0 waiting)
   - After ~10 cycles (Slave 0 latency):
     - LED[2] turns ON solid (Slave 0 data ready)
     - LED[0] turns OFF (Master 0 done)

**Expected Timing:**
- Initial READ: 27 bits
- WAIT response: 27 bits
- Retry READ: 27 bits
- Data response: 27 bits
- Total: ~108 bits = 8.64 µs

#### Test 6: Error Injection (Parity Error)

**Note:** Requires RTL modification to inject parity error.

**Setup:**
1. Modify `serializer.sv` to invert parity bit:
   ```systemverilog
   assign parity_bit = ~(^frame_reg[23:0]); // Inverted for error test
   ```
2. Recompile and reprogram FPGA
3. Reset system
4. Set SW[3:0] = 4'b0000 (Master 0, WRITE)

**Execute:**
1. Toggle SW[0] HIGH → LOW
2. **Observe:**
   - LED[5] turns ON (error indicator)
   - LED[6] turns ON briefly (bus active)
   - Transaction aborted
   - LED[0] turns OFF (Master 0 done)

**Restore:**
- Revert parity bit to normal: `assign parity_bit = ^frame_reg[23:0];`
- Recompile and reprogram

### Loopback Demo Success Criteria

- [ ] All WRITE transactions complete successfully
- [ ] All READ transactions return data
- [ ] Arbitration gives priority to Master 0
- [ ] Split transactions work on Slave 0
- [ ] Parity error detection functional
- [ ] Timing matches expected values (±10%)
- [ ] No LED glitches or stuck states

---

## Demo 2: Inter-Board Communication

This demo shows two DE0-Nano boards communicating over the serial bus via GPIO connections.

### Hardware Setup

#### Board A (Master Board)

**Configuration:**
- Programmed with `bitserial.sof`
- `LOOPBACK_MODE = 0` (external mode)
- Acts as bus master (initiates transactions)

#### Board B (Slave Board)

**Configuration:**
- Programmed with `bitserial.sof`
- `LOOPBACK_MODE = 0` (external mode)
- Acts as bus slave (responds to requests)

### GPIO Wiring

**Critical:** All connections must be short (< 6 inches) for signal integrity at 12.5 MHz.

**Connection Table:**

| Board A (Master) | Wire Color | Board B (Slave) | Signal |
|------------------|------------|-----------------|--------|
| GPIO_0[0] (A8) | Red | GPIO_0[4] (A2) | sdata (A→B) |
| GPIO_0[1] (D3) | Orange | GPIO_0[5] (A3) | sclk (A→B) |
| GPIO_0[2] (B8) | Yellow | GPIO_0[6] (B3) | svalid (A→B) |
| GPIO_0[3] (C3) | Green | GPIO_0[7] (B4) | sready (B→A) |
| GPIO_0[4] (A2) | Blue | GPIO_0[0] (A8) | sdata (B→A) |
| GPIO_0[5] (A3) | Purple | GPIO_0[1] (D3) | sclk (B→A) |
| GPIO_0[6] (B3) | Gray | GPIO_0[2] (B8) | svalid (B→A) |
| GPIO_0[7] (B4) | White | GPIO_0[3] (C3) | sready (A→B) |
| GND | Black | GND | Common ground |

**Pinout Diagram (GPIO_0 Header):**

```
Board A GPIO_0:              Board B GPIO_0:
┌─────────────┐              ┌─────────────┐
│  1  3  5  7 │              │  1  3  5  7 │
│  0  2  4  6 │              │  0  2  4  6 │
└─────────────┘              └─────────────┘
  │  │  │  │                    │  │  │  │
  │  │  │  └─────────────────────┘  │  │  │
  │  │  └────────────────────────────┘  │  │
  │  └───────────────────────────────────┘  │
  └──────────────────────────────────────────┘
```

**Wiring Checklist:**
- [ ] All 8 signal wires connected
- [ ] GND connected between boards
- [ ] No crossed connections
- [ ] Wire length < 6 inches
- [ ] Secure connections (no loose wires)
- [ ] Both boards powered via USB

### Demo Procedure

#### Test 1: Inter-Board WRITE

**Board A Setup (Master):**
1. Reset (press KEY0)
2. Set SW[3:0] = 4'b0000 (Master 0, WRITE, Slave 0)

**Board B Setup (Slave):**
1. Reset (press KEY0)
2. Set switches to idle (all OFF)

**Execute:**
1. On Board A: Toggle SW[0] HIGH → LOW
2. **Observe Board A:**
   - LED[0] turns ON (Master 0 busy)
   - LED[6] turns ON (bus active)
   - LED[7] turns ON (inter-board link active)
3. **Observe Board B:**
   - LED[7] turns ON (inter-board link active)
   - LED[2] turns ON (Slave 0 receives data)
4. **Final State:**
   - Board A: LED[0] OFF, LED[7] OFF (transaction complete)
   - Board B: LED[2] ON (data stored in memory)

**Verification:**
- Use logic analyzer on sdata line to verify frame format
- Check sclk is 12.5 MHz (80 ns period)
- Verify svalid/sready handshake timing

#### Test 2: Inter-Board READ

**Board A Setup:**
1. Reset
2. Set SW[3:0] = 4'b0100 (Master 0, READ, Slave 0)

**Board B Setup:**
1. Reset
2. Pre-load Slave 0 memory with known data (use WRITE first)

**Execute:**
1. On Board A: Toggle SW[0] HIGH → LOW
2. **Observe Board A:**
   - LED[0] turns ON (Master 0 busy)
   - LED[6] turns ON (bus active)
   - LED[7] turns ON (link active)
   - After response: LED[0] OFF, data received
3. **Observe Board B:**
   - LED[7] turns ON (link active)
   - LED[2] turns ON (Slave 0 sends data)

**Verification:**
- Compare data received on Board A with data written earlier
- Verify round-trip time: ~9 µs (54 bits × 80 ns + CDC latency)

#### Test 3: Bi-Directional Communication

**Setup:**
- Board A: Master 0 sends WRITE to Board B
- Board B: Master 0 sends WRITE to Board A

**Execute:**
1. Board A: Write data to Board B Slave 0
2. Board B: Write different data to Board A Slave 0
3. Board A: Read back from Slave 0 (should have Board B's data)
4. Board B: Read back from Slave 0 (should have Board A's data)

**Verification:**
- Data integrity maintained in both directions
- No cross-talk or interference
- LED[7] on both boards indicates link activity

#### Test 4: CDC Synchronization Test

**Purpose:** Verify clock domain crossing works correctly.

**Setup:**
- Board A and Board B have independent 50 MHz clocks (not synchronized)
- CDC synchronizers in `interboard_link.sv` handle metastability

**Execute:**
1. Perform 100 consecutive WRITE/READ cycles
2. Monitor for errors:
   - LED[5] should remain OFF (no parity errors)
   - All transactions should complete
   - No stuck states or timeouts

**Verification:**
- 100% transaction success rate
- No metastability-induced errors
- Consistent timing across all transactions

#### Test 5: Stress Test - Rapid Transactions

**Setup:**
- Board A continuously sends WRITE commands
- Toggle SW[0] rapidly (as fast as possible)

**Execute:**
1. Rapidly toggle SW[0] on Board A (10 times/second)
2. Monitor both boards for stability
3. Run for 1 minute

**Expected Behavior:**
- All transactions complete successfully
- No buffer overflows or underruns
- LEDs update correctly for each transaction
- No system lockup

**Verification:**
- System remains responsive
- No error indications (LED[5] OFF)
- Inter-board link stable (LED[7] toggles correctly)

### Inter-Board Demo Success Criteria

- [ ] Basic WRITE/READ transactions work between boards
- [ ] Bi-directional communication verified
- [ ] CDC synchronization prevents metastability errors
- [ ] Stress test passes (100 transactions)
- [ ] No signal integrity issues on GPIO
- [ ] Timing matches single-board loopback (±20% for CDC overhead)
- [ ] Both boards remain stable under continuous operation

---

## Demo 3: Multi-Team Inter-Board

This demo connects your boards with another team's implementation to verify protocol compatibility.

### Pre-Demo Coordination

**Exchange with Other Team:**
1. **Protocol Specification:**
   - Frame format: START(1) + CMD(2) + ADDR(12) + DATA(10) + PARITY(1) + STOP(1)
   - Clock frequency: 12.5 MHz serial clock
   - Handshake: svalid/sready 4-wire protocol

2. **Pin Assignments:**
   - Share GPIO_0 pin mappings
   - Verify 3.3V LVTTL compatibility
   - Agree on signal polarity (active-high/low)

3. **Test Plan:**
   - Agree on test sequence
   - Define success criteria
   - Plan troubleshooting approach

### Connection Setup

**Your Board → Other Team's Board:**
- Use same GPIO_0 wiring as Demo 2
- Verify pin compatibility first
- Keep wires short and secure

**Compatibility Checklist:**
- [ ] Frame format matches (27 bits total)
- [ ] Clock frequency matches (12.5 MHz ± 1%)
- [ ] Start/stop delimiters match
- [ ] Parity scheme matches (even parity, includes all bits except parity itself)
- [ ] Handshake protocol matches (svalid/sready)
- [ ] Voltage levels compatible (3.3V LVTTL)

### Demo Procedure

#### Test 1: One-Way WRITE (Your Board as Master)

**Setup:**
1. Your board: Master mode, WRITE command
2. Other team's board: Slave mode, ready to receive

**Execute:**
1. Your board: Toggle SW[0] (Master 0 request)
2. Monitor both boards for successful transaction
3. Other team verifies data received

**Success Criteria:**
- Transaction completes on your board (LED[0] goes OFF)
- Other team's board receives correct data
- No errors on either board

#### Test 2: One-Way WRITE (Other Team as Master)

**Setup:**
1. Your board: Slave mode, ready to receive
2. Other team's board: Master mode, WRITE command

**Execute:**
1. Other team: Initiate WRITE transaction
2. Your board: Verify data received (LED[2] turns ON)
3. Compare data with what was sent

**Success Criteria:**
- Your board receives transaction correctly
- Data matches what was sent
- No parity or decode errors

#### Test 3: Bi-Directional Exchange

**Setup:**
- Both boards act as master and slave simultaneously

**Execute:**
1. Your board sends WRITE to other team
2. Other team sends WRITE to your board
3. Both boards verify received data

**Success Criteria:**
- Both transactions succeed
- No collisions or arbitration issues
- Data integrity maintained

### Troubleshooting Multi-Team Issues

**Problem: No Response from Other Board**

Possible Causes:
1. **Pin mismatch:**
   - Verify GPIO_0 pin assignments match
   - Check sdata, sclk, svalid, sready connections
   - Use multimeter to verify continuity

2. **Clock mismatch:**
   - Measure sclk with oscilloscope
   - Verify both boards use 12.5 MHz serial clock
   - Check for clock skew or jitter

3. **Protocol mismatch:**
   - Verify frame format matches
   - Check start/stop bit values
   - Compare parity calculation method

**Problem: Parity Errors**

Possible Causes:
1. **Different parity schemes:**
   - Your design: even parity on bits [23:0]
   - Verify other team uses same method
   - Check which bits are included in parity

2. **Signal integrity:**
   - Reduce wire length
   - Check for ground connection
   - Add series resistors (33Ω) if needed

**Problem: Transactions Timeout**

Possible Causes:
1. **Handshake mismatch:**
   - Verify svalid/sready protocol
   - Check if other team uses different handshake
   - Use oscilloscope to observe timing

2. **CDC issues:**
   - Check if other team uses synchronizers
   - Verify both boards handle metastability
   - May need to reduce clock frequency

**Debugging Tools:**
- Oscilloscope: Verify signal levels and timing
- Logic analyzer: Capture full frame and decode
- Multimeter: Check voltage levels and continuity
- Test points: Add probe points to critical signals

---

## Troubleshooting Guide

### System Won't Program

**Symptoms:**
- Quartus Programmer can't detect device
- Programming fails at 0%

**Solutions:**
1. **Check USB Blaster connection:**
   - Ensure USB Blaster is firmly connected to JTAG header
   - Try different USB port
   - Reinstall USB Blaster driver

2. **Check power:**
   - Verify USB power cable is connected
   - Check PWR LED on DE0-Nano is lit
   - Try external 5V power supply

3. **Check JTAG chain:**
   - Run "Auto Detect" in Quartus Programmer
   - Should detect EP4CE22 device
   - If not detected, check JTAG cable

### LEDs Don't Respond

**Symptoms:**
- All LEDs stuck OFF or ON
- LEDs don't change with switch inputs

**Solutions:**
1. **Verify programming:**
   - Reprogram FPGA with fresh bitstream
   - Check "100% Successful" in Quartus Programmer

2. **Check reset:**
   - Press KEY0 to reset system
   - Hold for 1 second, then release

3. **Verify design:**
   - Re-run `just sim` to verify RTL is correct
   - Check for synthesis warnings
   - Verify timing closure in Quartus

### Inter-Board Link Not Working

**Symptoms:**
- LED[7] doesn't light up on either board
- No response from remote board

**Solutions:**
1. **Check wiring:**
   - Verify all 8 GPIO wires are connected
   - Check GND connection between boards
   - Ensure no reversed connections

2. **Verify signal integrity:**
   - Use oscilloscope to check sclk (should be 12.5 MHz)
   - Verify sdata transitions on each bit
   - Check svalid/sready handshake

3. **Check loopback mode:**
   - Verify `LOOPBACK_MODE = 0` in bitserial_top.sv
   - Recompile if needed
   - Reprogram both boards

4. **Test with shorter wires:**
   - Long wires can cause signal degradation
   - Try 2-3 inch jumpers
   - Add ground wire between every signal

### Parity Errors

**Symptoms:**
- LED[5] lights up frequently
- Transactions fail randomly

**Solutions:**
1. **Check signal integrity:**
   - Reduce wire length
   - Ensure good GND connection
   - Add series termination (33Ω resistors)

2. **Verify clock stability:**
   - Check 50 MHz oscillator is stable
   - Verify PLL settings if used
   - Check for clock glitches with scope

3. **Check for EMI:**
   - Move boards away from noise sources
   - Use shielded cables for GPIO
   - Add bypass capacitors near GPIO pins

### Transactions Timeout

**Symptoms:**
- LED[0] or LED[1] stays ON indefinitely
- System appears hung

**Solutions:**
1. **Reset system:**
   - Press KEY0 on both boards simultaneously
   - Wait 2 seconds
   - Retry transaction

2. **Check handshake:**
   - Verify svalid/sready are working
   - Use logic analyzer to observe handshake
   - Check for stuck signals

3. **Verify CDC:**
   - Ensure both boards are powered
   - Check for metastability in synchronizers
   - May need to add more FF stages

### Resource Utilization Too High

**Symptoms:**
- Quartus reports > 20% LE usage
- Timing closure fails

**Solutions:**
1. **Check synthesis settings:**
   - Verify optimization level (Balanced)
   - Enable physical synthesis
   - Check for inferred latches

2. **Optimize RTL:**
   - Review for unnecessary logic
   - Simplify FSMs if possible
   - Check for duplicated modules

3. **Review timing constraints:**
   - Verify SDC file is correct
   - Check for over-constrained paths
   - Relax non-critical timing if needed

---

## Expected Results

### Resource Utilization

**Target (Estimated):**
- Logic Elements: 2,500-3,500 LEs (11-16% of 22,320)
- Registers: 800-1,200
- Combinational ALUTs: 1,700-2,300
- Memory bits: 40,960 (7 M9K blocks)
- PLLs: 0 (using direct clock division)

**Verification:**
- Open `fpga/quartus/output_files/bitserial.fit.summary`
- Check LE utilization < 20%
- Verify no timing violations

### Timing Analysis

**Clock Constraints:**
- System clock (clk): 50 MHz (20 ns period)
- Serial clock (sclk_int): 12.5 MHz (80 ns period)

**Expected Fmax:**
- System clock: > 60 MHz (20% margin)
- Serial clock: > 15 MHz (20% margin)

**Critical Paths:**
- Serializer shift register: ~15 ns
- Deserializer shift register: ~15 ns
- Arbiter priority logic: ~10 ns
- Address decoder: ~8 ns

**Verification:**
- Open Quartus TimeQuest Analyzer
- Check setup/hold slack > 0 ns for all paths
- Verify no timing violations

### Performance Metrics

**Throughput:**
- WRITE: 463 kB/s (10 bits data / 27 bits frame × 12.5 MHz)
- READ: 231 kB/s (2 frames per transaction)
- SPLIT: 116 kB/s (4 frames per transaction)

**Latency:**
- Single-board WRITE: ~2.2 µs (27 bits × 80 ns)
- Single-board READ: ~4.3 µs (54 bits × 80 ns)
- Inter-board WRITE: ~3.0 µs (includes CDC overhead)
- Inter-board READ: ~5.5 µs (includes CDC overhead)

**Verification:**
- Use oscilloscope to measure transaction timing
- Capture svalid rising to sready falling
- Compare with expected values (±10%)

### Functional Verification

**Single-Board Loopback:**
- [ ] WRITE to all slaves (0, 1, 2) succeeds
- [ ] READ from all slaves returns data
- [ ] Split transaction on Slave 0 works
- [ ] Arbitration prioritizes Master 0
- [ ] Parity error detection works
- [ ] All 35 test scenarios pass

**Inter-Board Communication:**
- [ ] WRITE from Board A to Board B succeeds
- [ ] READ from Board A to Board B succeeds
- [ ] Bi-directional communication works
- [ ] CDC handles unsynchronized clocks
- [ ] Stress test (100 transactions) passes
- [ ] No signal integrity issues

**Multi-Team Demo:**
- [ ] Compatible with other team's design
- [ ] One-way WRITE works (your master)
- [ ] One-way WRITE works (their master)
- [ ] Bi-directional exchange succeeds
- [ ] No protocol mismatches

---

## Safety and Best Practices

### Electrical Safety

**Warnings:**
- Do not hot-plug GPIO connections while boards are powered
- Ensure GND connection before signal connections
- Verify voltage levels (3.3V LVTTL) before connecting
- Do not exceed maximum current draw (8 mA per pin)

**Best Practices:**
- Power off boards before changing connections
- Use anti-static wrist strap when handling boards
- Avoid touching components while powered
- Keep liquids away from electronics

### Signal Integrity

**Guidelines:**
- Keep GPIO wires < 6 inches for 12.5 MHz signals
- Use twisted pairs for differential signals (sdata+GND, sclk+GND)
- Add series resistors (33Ω) for impedance matching if needed
- Ensure solid GND connection between boards

**Debugging:**
- Use oscilloscope probes with short ground leads
- Minimize probe loading on high-speed signals
- Use 10:1 probes for signals > 10 MHz
- Capture on single-shot trigger for intermittent issues

### FPGA Configuration

**Recommendations:**
- Always program FPGA in .sof mode (SRAM-based)
- Do not use .pof mode (Flash-based) for development
- Keep backup of working bitstream
- Document any pin assignment changes

**Version Control:**
- Commit working bitstreams to git with tags
- Document synthesis settings in README
- Track resource utilization over time
- Keep old bitstreams for regression testing

---

## Appendix A: Quick Reference

### Switch Settings

| SW[3] | SW[2] | SW[1] | SW[0] | Function |
|-------|-------|-------|-------|----------|
| 0 | 0 | X | 1→0 | Master 0 WRITE to Slave 0 |
| 0 | 1 | X | 1→0 | Master 0 READ from Slave 0 |
| 1 | 0 | X | 1→0 | Master 0 WRITE to Slave 2 |
| 1 | 1 | X | 1→0 | Master 0 READ from Slave 2 |
| X | 0 | 1→0 | 0 | Master 1 WRITE to Slave 0 |
| X | 1 | 1→0 | 0 | Master 1 READ from Slave 0 |
| 0 | 0 | 1→0 | 1→0 | Both masters (arbitration test) |

### LED Indicators

| LED | Meaning | State |
|-----|---------|-------|
| 0 | Master 0 busy | ON during M0 transaction |
| 1 | Master 1 busy | ON during M1 transaction |
| 2 | Slave 0 response | ON when S0 responds |
| 3 | Slave 1 response | ON when S1 responds |
| 4 | Slave 2 response | ON when S2 responds |
| 5 | Error flag | ON for parity/decode error |
| 6 | Bus active | ON during serial transaction |
| 7 | Inter-board link | ON during GPIO communication |

### Serial Frame Format

```
Bit [26]: START = 1
Bit [25:24]: CMD (00=WRITE, 01=READ, 10=WAIT, 11=RESP)
Bit [23:12]: ADDR (12-bit address)
Bit [11:2]: DATA (10-bit data)
Bit [1]: PARITY (even parity of bits [23:0])
Bit [0]: STOP = 1
```

### Timing Summary

| Operation | Cycles | Time @ 12.5 MHz |
|-----------|--------|-----------------|
| WRITE | 27 | 2.16 µs |
| READ | 54 | 4.32 µs |
| SPLIT | 108 | 8.64 µs |
| Inter-board overhead | ~10 | ~0.8 µs |

---

## Appendix B: Command Reference

### Verilator Simulation

```bash
# Run full testbench
just sim

# Run specific test
cd tb
../verilator/zig-out/bin/verilator --binary --trace-fst -Wall \
  --timing -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND \
  --top bitserial_top_tb -I../rtl \
  bitserial_top_tb.sv ../rtl/*.sv
./obj_dir/Vbitserial_top_tb
```

### Quartus Synthesis

```bash
# Full synthesis flow
just synth-quartus

# Command-line compilation
cd fpga/quartus
quartus_sh --flow compile bitserial
```

### FPGA Programming

```bash
# Program FPGA (command-line)
cd fpga/quartus
quartus_pgm -c USB-Blaster -m JTAG -o "p;output_files/bitserial.sof@1"

# List available programmers
quartus_pgm --list
```

### Timing Analysis

```bash
# Run TimeQuest
cd fpga/quartus
quartus_sta bitserial

# Generate timing report
quartus_sta -t quartus/report_timing.tcl bitserial
```

---

## Appendix C: Pinout Tables

### Complete DE0-Nano Pinout (Used Pins)

| Signal | Pin | I/O | Standard | Drive |
|--------|-----|-----|----------|-------|
| clk | R8 | Input | 3.3-V LVTTL | - |
| rst_n | J15 | Input | 3.3-V LVTTL | - |
| SW[0] | M1 | Input | 3.3-V LVTTL | - |
| SW[1] | T8 | Input | 3.3-V LVTTL | - |
| SW[2] | B9 | Input | 3.3-V LVTTL | - |
| SW[3] | M15 | Input | 3.3-V LVTTL | - |
| LED[0] | A15 | Output | 3.3-V LVTTL | 8mA |
| LED[1] | A13 | Output | 3.3-V LVTTL | 8mA |
| LED[2] | B13 | Output | 3.3-V LVTTL | 8mA |
| LED[3] | A11 | Output | 3.3-V LVTTL | 8mA |
| LED[4] | D1 | Output | 3.3-V LVTTL | 8mA |
| LED[5] | F3 | Output | 3.3-V LVTTL | 8mA |
| LED[6] | B1 | Output | 3.3-V LVTTL | 8mA |
| LED[7] | L3 | Output | 3.3-V LVTTL | 8mA |
| sdata_out | A8 | Output | 3.3-V LVTTL | 8mA |
| sclk_out | D3 | Output | 3.3-V LVTTL | 8mA |
| svalid_out | B8 | Output | 3.3-V LVTTL | 8mA |
| sready_in | C3 | Input | 3.3-V LVTTL | - |
| sdata_in | A2 | Input | 3.3-V LVTTL | - |
| sclk_in | A3 | Input | 3.3-V LVTTL | - |
| svalid_in | B3 | Input | 3.3-V LVTTL | - |
| sready_out | B4 | Output | 3.3-V LVTTL | 8mA |

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-11-09 | Documentation Agent | Initial release |

---

**End of Demo Guide**
