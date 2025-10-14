# Quartus Synthesis for DE0-Nano Board

This directory contains the Intel Quartus Prime project files for synthesizing the bit-serial bus system on the Altera DE0-Nano board.

## Target Device

- **Board**: Altera DE0-Nano
- **FPGA**: Cyclone IV E EP4CE22F17C6
- **Resources**: 22,320 Logic Elements, 66 M9K RAM blocks
- **System Clock**: 50 MHz (onboard oscillator)
- **Serial Clock**: 12.5 MHz (derived, CLK/4)

## Project Files

- `bitserial.qpf` - Quartus project file
- `bitserial.qsf` - Quartus settings file (device, pins, RTL sources)
- `bitserial.sdc` - Synopsys Design Constraints (timing)
- `synth.tcl` - TCL script for command-line compilation

## Pin Assignments

### System Signals
- **Clock (clk_i)**: PIN_R8 (50 MHz oscillator)
- **Reset (rst_ni)**: PIN_J15 (KEY0 pushbutton, active-low)

### Master Interface
Due to limited switches/LEDs on DE0-Nano, the demo uses:
- **Switches**: Input control signals (m_req_i, m_we_i, m_addr_i, m_wdata_i)
- **LEDs**: Output status (m_gnt_o, m_ready_o, m_rdata_o, m_err_o)

**Note**: Pin assignments in `.qsf` file show switch/LED mapping. For full functionality, both masters share the same input switches in this demo configuration.

### Inter-board Serial Interface (Reserved)
GPIO_0 pins [7:0] are reserved for future inter-board communication:
- serial_sdata_out / serial_sdata_in
- serial_sclk_out / serial_sclk_in
- serial_svalid_out / serial_svalid_in
- serial_sready_out / serial_sready_in

These pins are commented out in the `.qsf` file until the `interboard_link` module is implemented.

## Expected Resource Usage

Based on Vivado synthesis validation (similar architecture):
- **Logic Elements**: ~3,000 / 22,320 (13%)
- **Registers**: ~500 / 82,000 (0.6%)
- **Memory**: Distributed RAM (10KB slave memories)

## Build Commands

### Synthesis
```bash
orb -s "just synth-quartus"
```

This runs the full compilation flow:
1. Analysis & Elaboration
2. Synthesis
3. Fitter (Place & Route)
4. Timing Analysis
5. Assembler (Generate .sof file)

### Open GUI
```bash
orb -s "just quartus-gui"
```

Opens the Quartus Prime GUI for manual inspection, simulation, or modification.

### Programming
```bash
orb -s "just quartus-program"
```

Programs the DE0-Nano board via USB Blaster. Requires:
- USB Blaster driver installed
- DE0-Nano connected via USB
- Board powered on

### Clean Build Files
```bash
orb -s "just quartus-clean"
```

Removes generated files: `db/`, `incremental_db/`, `output_files/`, reports.

## Output Files

After successful compilation, files are in `output_files/`:
- `bitserial.sof` - SRAM Object File (for FPGA programming)
- `bitserial.pof` - Programmer Object File (for EPCS configuration)
- `bitserial.fit.summary` - Resource utilization report
- `bitserial.sta.summary` - Timing analysis report
- `bitserial.flow.rpt` - Full compilation flow report

## Timing Constraints

The `.sdc` file defines:
- **Base clock**: 50 MHz system clock (20ns period)
- **Derived clock**: 12.5 MHz serial clock (CLK/4)
- **Input delays**: 5ns max for switches/buttons
- **Output delays**: 10ns max for LEDs
- **Clock uncertainty**: 0.5ns setup, 0.3ns hold
- **False paths**: Asynchronous reset
- **Multicycle paths**: Serial clock domain (4 system clocks per serial bit)

## Design Notes

### Single-Board Operation
Without inter-board connections, the design operates as a self-contained system:
- 2 masters (controlled by switches)
- 3 slaves (10KB, 4KB, 2KB memory)
- Serial bus with frame-atomic arbitration
- Internal loopback operation

### Inter-Board Communication (Future)
To enable board-to-board communication:
1. Implement `rtl/interboard_link.sv` with CDC (Clock Domain Crossing)
2. Uncomment GPIO pin assignments in `.qsf`
3. Connect two DE0-Nano boards via GPIO_0 ribbon cable
4. Test with other team's board

### Memory Implementation
The 10KB slave memories will likely infer as:
- **Distributed RAM** (using LUTs) - Expected due to single-cycle read requirement
- **Block RAM** (M9K blocks) - Possible if Quartus can infer with registered outputs

Resource reports will show the actual implementation choice.

## Troubleshooting

### Synthesis Errors
- Check `build/logs/quartus_synth.log` for detailed error messages
- Verify all RTL source files are listed in `.qsf`
- Ensure SystemVerilog 2005 syntax is used

### Timing Failures
- Review `output_files/bitserial.sta.summary` for critical paths
- Consider reducing clock frequency in `.sdc` file
- Check for long combinational paths in RTL

### Programming Issues
- Verify USB Blaster connection: `quartus_pgm -l` (list devices)
- Check board power and USB cable
- Update USB Blaster driver if needed

## Next Steps

1. **Synthesize on Quartus** - Run `just synth-quartus` with Quartus installed
2. **Verify Fmax** - Ensure design meets 50 MHz timing
3. **Program DE0-Nano** - Load `.sof` file onto board
4. **Test single-board** - Verify loopback operation with switches/LEDs
5. **Implement inter-board link** - Add CDC and GPIO interface
6. **Test two-board** - Validate inter-board communication
7. **Cross-team demo** - Communicate with another team's board

## References

- [DE0-Nano User Manual](https://www.terasic.com.tw/cgi-bin/page/archive.pl?No=593)
- [Cyclone IV Device Handbook](https://www.intel.com/content/www/us/en/programmable/documentation/lit-index.html)
- [Quartus Prime User Guides](https://www.intel.com/content/www/us/en/programmable/documentation/lit-index.html)
