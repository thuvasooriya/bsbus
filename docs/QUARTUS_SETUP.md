# Quartus Setup on Orb (Apple Silicon)

This guide covers running Intel Quartus Prime on Apple Silicon Macs using Orb (Linux VM with Rosetta).

## Prerequisites

- macOS on Apple Silicon (M1/M2/M3)
- Orb installed: https://orbstack.dev/
- Quartus Prime Lite Edition downloaded

## Installation

### 1. Install Quartus in Orb

```bash
# Enter Orb shell
orb

# Download Quartus (or transfer from Mac)
cd /tmp
# Use Intel's download portal for Quartus Prime Lite

# Run installer
chmod +x QuartusLiteSetup-*.run
./QuartusLiteSetup-*.run --mode unattended --installdir /home/$USER/altera_lite/25.1std
```

### 2. Patch for Rosetta Compatibility

Quartus uses AVX instructions that Rosetta doesn't support. Apply these patches:

#### Patch libccl_sqlite3.so

```bash
# Download patched library (or build from source)
# Replace the original:
cp libccl_sqlite3_patched.so /home/$USER/altera_lite/25.1std/quartus/linux64/libccl_sqlite3.so
```

#### Patch qenv.sh for CPU Detection

Edit `/home/$USER/altera_lite/25.1std/quartus/adm/qenv.sh`:

```bash
# Find the SSE check section and add aarch64 bypass:
# Before the CPU feature checks, add:
if [ "$(uname -m)" = "aarch64" ]; then
    # Skip CPU checks on Rosetta/aarch64
    :
else
    # Original CPU checks here
fi
```

## Environment Setup

Add to your shell config (`~/.bashrc` or `~/.zshrc` in Orb):

```bash
export QUARTUS_ROOTDIR=/home/$USER/altera_lite/25.1std/quartus
export PATH=$QUARTUS_ROOTDIR/bin:$PATH
```

## Running Quartus

### From Mac Terminal

```bash
# Run Quartus shell command
orb -s "export QUARTUS_ROOTDIR=/home/tony/altera_lite/25.1std/quartus && quartus_sh --version"

# Run synthesis script
orb -s "export QUARTUS_ROOTDIR=/home/tony/altera_lite/25.1std/quartus && cd /path/to/project && quartus_sh -t synth.tcl"
```

### Interactive Session

```bash
# Enter Orb
orb

# Set environment
export QUARTUS_ROOTDIR=/home/$USER/altera_lite/25.1std/quartus

# Run Quartus GUI (requires X11 forwarding)
quartus &

# Or run shell
quartus_sh
```

## Project Synthesis

### Using synth.tcl Script

Create `synth.tcl` in your Quartus project directory:

```tcl
package require ::quartus::project
package require ::quartus::flow

project_open -force bitserial

puts "\n=========================================="
puts "Starting Quartus Compilation Flow"
puts "Target: DE0-Nano (EP4CE22F17C6)"
puts "==========================================\n"

execute_flow -compile

project_close
```

### Run Synthesis

```bash
orb -s "export QUARTUS_ROOTDIR=/home/tony/altera_lite/25.1std/quartus && \
        cd /Users/tony/arc/dev/bsbus/fpga/quartus && \
        $QUARTUS_ROOTDIR/bin/quartus_sh -t synth.tcl"
```

## Justfile Integration

Add to your `justfile`:

```just
# Quartus environment
quartus_root := "/home/tony/altera_lite/25.1std/quartus"
quartus_env := "export QUARTUS_ROOTDIR=" + quartus_root

# Run Quartus synthesis
synth:
    orb -s "{{quartus_env}} && cd {{justfile_directory()}}/fpga/quartus && {{quartus_root}}/bin/quartus_sh -t synth.tcl"

# Open Quartus GUI
quartus-gui:
    orb -s "{{quartus_env}} && {{quartus_root}}/bin/quartus &"

# Check Quartus version
quartus-version:
    orb -s "{{quartus_env}} && {{quartus_root}}/bin/quartus_sh --version"
```

## Programming the FPGA

### Using Quartus Programmer

```bash
# List available programmers
orb -s "export QUARTUS_ROOTDIR=/home/tony/altera_lite/25.1std/quartus && \
        quartus_pgm -l"

# Program device
orb -s "export QUARTUS_ROOTDIR=/home/tony/altera_lite/25.1std/quartus && \
        cd /path/to/project && \
        quartus_pgm -m jtag -o 'p;bitserial.sof'"
```

Note: USB passthrough to Orb may require additional setup for the USB-Blaster.

## Synthesis Results (Nov 30, 2025)

| Metric         | Value                       |
| -------------- | --------------------------- |
| Device         | EP4CE22F17C6 (Cyclone IV E) |
| Logic Elements | 3,149 / 22,320 (14%)        |
| Registers      | 2,412                       |
| Memory Bits    | 3,072 (2x M9K)              |
| Pins           | 72 / 154 (47%)              |

### Timing

| Corner          | Setup Slack       |
| --------------- | ----------------- |
| Slow 1200mV 85C | -1.917ns (fails)  |
| Fast 1200mV 0C  | +0.621ns (passes) |

Design passes at fast corner; will work at room temperature.

## Troubleshooting

### "Illegal instruction" Error

The Rosetta patches weren't applied correctly. Verify:

- `libccl_sqlite3.so` is the patched version
- `qenv.sh` has the aarch64 bypass

### Quartus Hangs on Startup

Try running with minimal environment:

```bash
orb -s "unset DISPLAY && export QUARTUS_ROOTDIR=/home/tony/altera_lite/25.1std/quartus && quartus_sh --version"
```

### Timing Failures

If design fails timing at slow corner but passes fast corner:

1. Design will likely work at room temperature
2. To close timing: reduce clock frequency in SDC file
3. Enable aggressive optimization in QSF:
   ```tcl
   set_global_assignment -name OPTIMIZATION_MODE "AGGRESSIVE PERFORMANCE"
   ```

### USB-Blaster Not Detected

USB passthrough in Orb/OrbStack:

```bash
# Check if device is visible
orb -s "lsusb | grep -i altera"

# May need to configure udev rules in Orb
```

## File Locations

| Item            | Path                                      |
| --------------- | ----------------------------------------- |
| Quartus Install | `/home/tony/altera_lite/25.1std/quartus`  |
| Project Files   | `/Users/tony/arc/dev/bsbus/fpga/quartus/` |
| Bitstream       | `fpga/quartus/bitserial.sof`              |
| Timing Report   | `fpga/quartus/bitserial.sta.summary`      |
| Fitter Report   | `fpga/quartus/bitserial.fit.summary`      |

## Pin Assignments (DE0-Nano)

| Signal       | Pin | Description       |
| ------------ | --- | ----------------- |
| clk_i        | R8  | 50 MHz oscillator |
| rst_ni       | J15 | KEY0 pushbutton   |
| m_req_i[0]   | M1  | DIP switch        |
| m_req_i[1]   | T8  | DIP switch        |
| m_gnt_o[0]   | A15 | LED               |
| m_gnt_o[1]   | A13 | LED               |
| m_ready_o[0] | B13 | LED               |
| m_ready_o[1] | A11 | LED               |
| m_err_o[0]   | D1  | LED               |
| m_err_o[1]   | F3  | LED               |

See `fpga/quartus/bitserial.qsf` for complete pin mapping.

## Demo Operation

1. Press KEY0 to reset
2. Set DIP switches for master request/write enable
3. Observe LEDs for grant/ready/error status
4. Read data available on GPIO pins

## References

https://gist.github.com/federunco/f2bde2e25342c6284b68ce4ecf305e5d
