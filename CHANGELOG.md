# Changelog

## 2025-11-30

### FPGA Synthesis
- Completed Quartus synthesis for DE0-Nano (EP4CE22F17C6)
- Generated bitstream: `fpga/quartus/bitserial.sof`
- Resource usage: 3,149 LEs (14%), 2 M9K BRAMs
- Timing: -1.917ns slack at slow corner, +0.621ns at fast corner

### RTL Fixes
- Reduced memory sizes in `bus_pkg.sv` (256B/256B/128B) for FPGA fitting
- Fixed `frame_decoder.sv:90` - removed unsynthesizable `.name()` call

### Quartus Setup
- Added optimization settings to `bitserial.qsf` (AGGRESSIVE PERFORMANCE mode)
- Patched Quartus 25.1std for Apple Silicon (Orb/Rosetta)

## 2024-11-28

### RTL
- Added I/O documentation comments to all modules
- Implemented split-transaction support in serial_arbiter (split_pending, split_owner tracking)
- Added SPLIT_CAPABLE parameter to slave_mem
- Wired split signals in bitserial_top (Slave 0 = split-capable)
- Fixed frame-atomic grant logic in arbiter

### Verification
- Added reset tests to addr_decoder_tb
- Added split transaction tests to serial_arbiter_tb
- Expanded serializer_tb with PASS/FAIL reporting
- All 113 tests pass on Verilator and Vivado xsim

### Documentation
- Created typst report (report/main.typ)
- Added group_assignment_title style
- Generated timing diagrams (WaveDrom) and block diagram (SVG)
- Added deferred tasks to AGENTS.md

### Build
- Added justfile recipes: report, report-watch, report-diagrams
- Verified Vivado simulation via orb

## Test Summary

| Module | Tests |
|--------|-------|
| serializer_tb | 8 |
| deserializer_tb | 5 |
| parallel_to_serial_tb | 3 |
| serial_to_parallel_tb | 5 |
| addr_decoder_tb | 18 |
| serial_arbiter_tb | 39 |
| bitserial_top_tb | 35 |
| **Total** | **113** |