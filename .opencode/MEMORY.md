# BSBUS Project Memory

## Current State (Nov 30, 2025)

### Synthesis Complete
- **Bitstream generated**: `fpga/quartus/bitserial.sof` (703KB)
- **Resource usage**: 3,149 / 22,320 LEs (14%)
- **BRAM**: Slave 1 & 2 inferred to M9K, Slave 0 uses fabric (async read for split)
- **Timing**: Fails slow corner by ~2ns, passes fast corner

### Timing Status
- Slow 1200mV 85C: **-1.917ns** (fails)
- Fast 1200mV 0C: **+0.621ns** (passes)
- Likely to work in practice (room temperature, nominal voltage)

### Memory Sizes (Reduced for Fitting)
- Slave 0: 256B (was 4KB) - uses fabric, async read for split transactions
- Slave 1: 256B (was 4KB) - uses M9K BRAM
- Slave 2: 128B (was 2KB) - uses M9K BRAM

### Known Issues
1. `slave_mem.sv:107` - Latch inference warnings for `split_pending_q`, `split_addr_q`, `split_delay_q`
2. `parallel_to_serial.sv:36` - Unused signal `is_read_q`
3. Minor truncation warnings in `addr_decoder.sv`

## Quartus Environment (Orb)
```bash
export QUARTUS_ROOTDIR=/home/tony/altera_lite/25.1std/quartus
```

### Synthesis Command
```bash
orb -s "export QUARTUS_ROOTDIR=/home/tony/altera_lite/25.1std/quartus && cd /Users/tony/arc/dev/bsbus/fpga/quartus && /home/tony/altera_lite/25.1std/quartus/bin/quartus_sh -t synth.tcl"
```

## Deferred Tasks (Demo: Wed Dec 3)

### Priority 1: FPGA Programming
- [ ] Program DE0-Nano with `bitserial.sof`
- [ ] Test basic functionality on hardware

### Priority 2: Inter-Board Demo
- [ ] Coordinate with other group
- [ ] Connect GPIO pins between boards
- [ ] Test serial frame transmission

### Priority 3: Demo Prep
- [ ] Document switch/LED mappings
- [ ] Prepare test scenarios
- [ ] Single-board loopback as backup

## Key Files
- RTL: `rtl/*.sv`
- Quartus project: `fpga/quartus/bitserial.qsf`
- Timing constraints: `fpga/quartus/bitserial.sdc`
- Bitstream: `fpga/quartus/bitserial.sof`

## Patches Applied
1. Quartus `libccl_sqlite3.so` - AVX instruction patch for Rosetta
2. Quartus `qenv.sh` - SSE CPU check bypass for aarch64
3. `frame_decoder.sv:90` - Removed unsynthesizable `.name()` call
