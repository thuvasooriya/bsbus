# Vivado Simulation Setup - Complete

## Summary

Successfully set up Vivado xsim simulation infrastructure for the bit-serial bus project. The setup uses direct command-line tools (xvlog/xelab/xsim) instead of TCL scripts, following the pattern from your reference justfile.

## What Was Created

### 1. Justfile Updates
- Added `VIVADO_SETTINGS` variable pointing to Vivado 2024.1
- Added `SIM_DIR` to project structure
- Updated `setup` target to create `sim/` directory
- Updated `clean` target to remove simulation artifacts
- Added 14 new recipes (7 compile + 7 sim targets) marked `[linux]`:
  - `compile-vivado-serializer` / `sim-vivado-serializer`
  - `compile-vivado-deserializer` / `sim-vivado-deserializer`
  - `compile-vivado-parallel-to-serial` / `sim-vivado-parallel-to-serial`
  - `compile-vivado-serial-to-parallel` / `sim-vivado-serial-to-parallel`
  - `compile-vivado-addr-decoder` / `sim-vivado-addr-decoder`
  - `compile-vivado-serial-arbiter` / `sim-vivado-serial-arbiter`
  - `compile-vivado-bitserial-top` / `sim-vivado-bitserial-top`
  - `sim-vivado-all` (runs all 7 simulations)

### 2. Documentation
- Created `sim/vivado/README.md` explaining:
  - How to run simulations via `orb` on macOS
  - How to run directly on Linux
  - Differences between Vivado xsim and Verilator
  - Where outputs are stored
  - Troubleshooting tips

### 3. Main README Updates
- Added **Simulation** section with both Verilator and Vivado commands
- Updated **Development Status** to show all completed testbenches
- Added test pass counts (e.g., "5/5 tests", "21/21 tests")

## Usage

### From macOS (via orb remote execution)

Run individual tests:
```bash
orb -s "just sim-vivado-serializer"
orb -s "just sim-vivado-deserializer"
orb -s "just sim-vivado-parallel-to-serial"
orb -s "just sim-vivado-serial-to-parallel"
orb -s "just sim-vivado-addr-decoder"
orb -s "just sim-vivado-serial-arbiter"
orb -s "just sim-vivado-bitserial-top"
```

Run all tests:
```bash
orb -s "just sim-vivado-all"
```

### From Linux (direct)

```bash
just sim-vivado-serializer
just sim-vivado-deserializer
# ... etc ...
just sim-vivado-all
```

## How It Works

Each simulation has two stages:

**1. Compilation (`compile-vivado-*`)**
- Sources Vivado settings from `$HOME/Xilinx/Vivado/2024.1/settings64.sh`
- Compiles all required RTL and testbench files using `xvlog -sv`
- Includes both RTL and testbench directories (`-i`)
- Logs output to `build/logs/xvlog_<name>.log`

**2. Simulation (`sim-vivado-*`)**
- Elaborates design with `xelab -debug typical`
- Runs simulation with `xsim -runall`
- Generates waveform database (`.wdb`) in `build/waves/`
- Logs output to `build/logs/xsim_<name>.log`

## Outputs

All outputs are organized in the `build/` directory:

```
build/
├── logs/
│   ├── xvlog_serializer.log
│   ├── xelab_serializer.log
│   ├── xsim_serializer.log
│   └── ... (one set for each testbench)
└── waves/
    ├── serializer.wdb
    ├── deserializer.wdb
    └── ... (one for each testbench)
```

Temporary files created during simulation:
- `xsim.dir/` - Simulation working directory
- `.Xil/` - Vivado temporary files
- `*.jou`, `*.log`, `*.pb` - Journal and log files

All temporary files are cleaned by `just clean`.

## File List

```
rtl/serializer.sv                  [COMPILE] All tests
rtl/deserializer.sv                [COMPILE] All tests
rtl/frame_decoder.sv               [COMPILE] All tests
rtl/tx_controller.sv               [COMPILE] All tests
rtl/rx_controller.sv               [COMPILE] Top-level only
rtl/parallel_to_serial.sv          [COMPILE] All tests
rtl/serial_to_parallel.sv          [COMPILE] All tests
rtl/serial_arbiter.sv              [COMPILE] All tests
rtl/addr_decoder.sv                [COMPILE] All tests
rtl/slave_mem.sv                   [COMPILE] Top-level only
rtl/bitserial_top.sv               [COMPILE] Top-level only
rtl/bus_pkg.sv                     [COMPILE] All tests

tb/serializer_tb.sv                [TB] Serialization test
tb/deserializer_tb.sv              [TB] Deserialization tests
tb/parallel_to_serial_tb.sv        [TB] Master adapter tests
tb/serial_to_parallel_tb.sv        [TB] Slave adapter tests
tb/addr_decoder_tb.sv              [TB] Address decode tests
tb/serial_arbiter_tb.sv            [TB] Arbitration tests
tb/bitserial_top_tb.sv             [TB] System tests
```

## Verification Status

### Verilator (macOS) - ✅ All Passing
```
✅ serializer_tb          - PASS
✅ deserializer_tb        - PASS (5/5)
✅ parallel_to_serial_tb  - PASS (3/3)
✅ serial_to_parallel_tb  - PASS (5/5)
✅ addr_decoder_tb        - PASS (11/11)
✅ serial_arbiter_tb      - PASS (21/21)
✅ bitserial_top_tb       - PASS (35/35)
```

### Vivado xsim (Linux) - ⏳ Ready to Test
All compile and simulation recipes are set up and ready to run via `orb`.

## Next Steps

1. **Test one simulation via orb**:
   ```bash
   orb -s "just sim-vivado-serializer"
   ```

2. **Check logs** (after orb sync):
   ```bash
   cat build/logs/xvlog_serializer.log
   cat build/logs/xsim_serializer.log
   ```

3. **If successful, run all**:
   ```bash
   orb -s "just sim-vivado-all"
   ```

4. **View waveforms** (on Linux with Vivado GUI):
   ```bash
   vivado -mode gui
   # Open → Waveform Database → build/waves/serializer.wdb
   ```

## Notes

- Vivado 2024.1 path is hardcoded in `VIVADO_SETTINGS` - update if different
- All recipes are marked `[linux]` so they won't appear in `just --list` on macOS
- Testbenches must call `$finish;` to exit xsim properly
- Pass/fail detection relies on console output (check logs)
- Waveforms are in Vivado's `.wdb` format (not compatible with GTKWave/Surfer)

## Architecture Match

This setup follows your reference justfile pattern:
- ✅ `[linux]` attribute for Vivado commands
- ✅ Sources `VIVADO_SETTINGS` in bash scripts
- ✅ Uses direct xvlog/xelab/xsim commands (not TCL)
- ✅ Logs to `build/logs/`
- ✅ Waveforms to `build/waves/`
- ✅ Compatible with `orb -s "just ..."` execution
- ✅ Separate compile and simulate targets
- ✅ `sim-vivado-all` aggregates all tests
