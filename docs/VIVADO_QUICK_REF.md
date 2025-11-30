# Vivado Simulation - Quick Reference

## Run from macOS (via orb)

```bash
# Individual tests
orb -s "just sim-vivado-serializer"
orb -s "just sim-vivado-deserializer"
orb -s "just sim-vivado-parallel-to-serial"
orb -s "just sim-vivado-serial-to-parallel"
orb -s "just sim-vivado-addr-decoder"
orb -s "just sim-vivado-serial-arbiter"
orb -s "just sim-vivado-bitserial-top"

# All tests
orb -s "just sim-vivado-all"
```

## Run from Linux (direct)

```bash
# Individual tests
just sim-vivado-serializer
just sim-vivado-deserializer
just sim-vivado-parallel-to-serial
just sim-vivado-serial-to-parallel
just sim-vivado-addr-decoder
just sim-vivado-serial-arbiter
just sim-vivado-bitserial-top

# All tests
just sim-vivado-all
```

## Check Results

```bash
# Compilation logs
cat build/logs/xvlog_*.log

# Elaboration logs
cat build/logs/xelab_*.log

# Simulation logs (contains pass/fail)
cat build/logs/xsim_*.log

# Waveforms (Vivado GUI on Linux)
vivado -mode gui
# Open → Waveform Database → build/waves/<testbench>.wdb
```

## Clean Up

```bash
just clean
```
