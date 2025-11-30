set export := true

# =============================================================================
# SYSTEM-SPECIFIC CONFIGURATION
# =============================================================================

VERILATOR := "/Users/tony/arc/dev/archive/sort/verilator/zig-out/bin/verilator"
VERILATOR_CFLAGS := "-Wno-unused-command-line-argument"
VERILATOR_FLAGS := "-CFLAGS $VERILATOR_CFLAGS --binary -j 0"
VERIBLE_FORMAT := "verible-verilog-format"
MAKEFLAGS := "-s"
WAVE_VIEWER := "surfer"

# Vivado settings (Linux only - used via orb remote execution)

VIVADO_SETTINGS := "$HOME/Xilinx/Vivado/2024.1/settings64.sh"

# =============================================================================
# PROJECT DIRECTORY STRUCTURE
# =============================================================================

RTL_DIR := "rtl"
TB_DIR := "tb"
BUILD_DIR := "build"
FPGA_DIR := "fpga"

REPORT_DIR := "report"

default:
    @just --list

setup:
    mkdir -p {{ BUILD_DIR }}/logs {{ BUILD_DIR }}/waves

clean:
    rm -rf {{ BUILD_DIR }}
    rm -rf obj_dir
    rm -rf xsim.dir .Xil *.jou *.log *.pb *.wdb *.backup.jou *.backup.log

lint:
    {{ VERILATOR }} --lint-only -Wall \
        -I{{ RTL_DIR }} \
        {{ RTL_DIR }}/*.sv

format:
    {{ VERIBLE_FORMAT }} --inplace {{ RTL_DIR }}/*.sv
    {{ VERIBLE_FORMAT }} --inplace {{ TB_DIR }}/*.sv

format-check:
    {{ VERIBLE_FORMAT }} --verify {{ RTL_DIR }}/*.sv
    {{ VERIBLE_FORMAT }} --verify {{ TB_DIR }}/*.sv

sim-serializer:
    {{ VERILATOR }} {{ VERILATOR_FLAGS }} \
        -I{{ RTL_DIR }} \
        -Wno-WIDTHEXPAND \
        --trace --trace-fst \
        {{ RTL_DIR }}/bus_pkg.sv \
        {{ RTL_DIR }}/serializer.sv \
        {{ TB_DIR }}/serializer_tb.sv \
        --top-module serializer_tb
    timeout 20 ./obj_dir/Vserializer_tb

sim-deserializer:
    {{ VERILATOR }} {{ VERILATOR_FLAGS }} \
        -I{{ RTL_DIR }} \
        --trace --trace-fst \
        {{ RTL_DIR }}/bus_pkg.sv \
        {{ RTL_DIR }}/deserializer.sv \
        {{ TB_DIR }}/deserializer_tb.sv \
        --top-module deserializer_tb
    timeout 20 ./obj_dir/Vdeserializer_tb

sim-parallel-to-serial:
    {{ VERILATOR }} {{ VERILATOR_FLAGS }} \
        -I{{ RTL_DIR }} \
        --trace --trace-fst \
        {{ RTL_DIR }}/bus_pkg.sv \
        {{ RTL_DIR }}/serializer.sv \
        {{ RTL_DIR }}/deserializer.sv \
        {{ RTL_DIR }}/tx_controller.sv \
        {{ RTL_DIR }}/parallel_to_serial.sv \
        {{ TB_DIR }}/parallel_to_serial_tb.sv \
        --top-module parallel_to_serial_tb
    timeout 20 ./obj_dir/Vparallel_to_serial_tb

sim-serial-to-parallel:
    {{ VERILATOR }} {{ VERILATOR_FLAGS }} \
        -I{{ RTL_DIR }} \
        --trace --trace-fst \
        {{ RTL_DIR }}/bus_pkg.sv \
        {{ RTL_DIR }}/deserializer.sv \
        {{ RTL_DIR }}/frame_decoder.sv \
        {{ RTL_DIR }}/serial_to_parallel.sv \
        {{ TB_DIR }}/serial_to_parallel_tb.sv \
        --top-module serial_to_parallel_tb
    timeout 20 ./obj_dir/Vserial_to_parallel_tb

sim-addr-decoder:
    {{ VERILATOR }} {{ VERILATOR_FLAGS }} \
        -I{{ RTL_DIR }} \
        --trace --trace-fst \
        {{ RTL_DIR }}/bus_pkg.sv \
        {{ RTL_DIR }}/addr_decoder.sv \
        {{ TB_DIR }}/addr_decoder_tb.sv \
        --top-module addr_decoder_tb
    timeout 20 ./obj_dir/Vaddr_decoder_tb

sim-serial-arbiter:
    {{ VERILATOR }} {{ VERILATOR_FLAGS }} \
        -I{{ RTL_DIR }} \
        --trace --trace-fst \
        {{ RTL_DIR }}/bus_pkg.sv \
        {{ RTL_DIR }}/serial_arbiter.sv \
        {{ TB_DIR }}/serial_arbiter_tb.sv \
        --top-module serial_arbiter_tb
    timeout 20 ./obj_dir/Vserial_arbiter_tb

sim-bitserial-top:
    {{ VERILATOR }} {{ VERILATOR_FLAGS }} \
        -I{{ RTL_DIR }} \
        -Wno-WIDTHEXPAND \
        --trace --trace-fst \
        {{ RTL_DIR }}/bus_pkg.sv \
        {{ RTL_DIR }}/serializer.sv \
        {{ RTL_DIR }}/deserializer.sv \
        {{ RTL_DIR }}/tx_controller.sv \
        {{ RTL_DIR }}/frame_decoder.sv \
        {{ RTL_DIR }}/parallel_to_serial.sv \
        {{ RTL_DIR }}/serial_to_parallel.sv \
        {{ RTL_DIR }}/serial_arbiter.sv \
        {{ RTL_DIR }}/addr_decoder.sv \
        {{ RTL_DIR }}/slave_mem.sv \
        {{ RTL_DIR }}/bitserial_top.sv \
        {{ TB_DIR }}/bitserial_top_tb.sv \
        --top-module bitserial_top_tb
    timeout 20 ./obj_dir/Vbitserial_top_tb

sim-all: sim-serializer sim-deserializer sim-parallel-to-serial sim-serial-to-parallel sim-addr-decoder sim-serial-arbiter sim-bitserial-top

[linux]
compile-vivado-serializer: setup
    #!/bin/bash
    source {{ VIVADO_SETTINGS }}
    echo "Compiling serializer testbench with Vivado xvlog"
    xvlog -sv \
        -i {{ RTL_DIR }} -i {{ TB_DIR }} \
        {{ RTL_DIR }}/bus_pkg.sv \
        {{ RTL_DIR }}/serializer.sv \
        {{ TB_DIR }}/serializer_tb.sv \
        -log {{ BUILD_DIR }}/logs/xvlog_serializer.log

[linux]
sim-vivado-serializer: compile-vivado-serializer
    #!/bin/bash
    source {{ VIVADO_SETTINGS }}
    echo "Running serializer simulation with Vivado xsim"
    xelab serializer_tb -debug typical -log {{ BUILD_DIR }}/logs/xelab_serializer.log
    xsim serializer_tb -runall -log {{ BUILD_DIR }}/logs/xsim_serializer.log -wdb {{ BUILD_DIR }}/waves/serializer.wdb

[linux]
compile-vivado-deserializer: setup
    #!/bin/bash
    source {{ VIVADO_SETTINGS }}
    echo "Compiling deserializer testbench with Vivado xvlog"
    xvlog -sv \
        -i {{ RTL_DIR }} -i {{ TB_DIR }} \
        {{ RTL_DIR }}/bus_pkg.sv \
        {{ RTL_DIR }}/deserializer.sv \
        {{ RTL_DIR }}/frame_decoder.sv \
        {{ TB_DIR }}/deserializer_tb.sv \
        -log {{ BUILD_DIR }}/logs/xvlog_deserializer.log

[linux]
sim-vivado-deserializer: compile-vivado-deserializer
    #!/bin/bash
    source {{ VIVADO_SETTINGS }}
    echo "Running deserializer simulation with Vivado xsim"
    xelab deserializer_tb -debug typical -log {{ BUILD_DIR }}/logs/xelab_deserializer.log
    xsim deserializer_tb -runall -log {{ BUILD_DIR }}/logs/xsim_deserializer.log -wdb {{ BUILD_DIR }}/waves/deserializer.wdb

[linux]
compile-vivado-parallel-to-serial: setup
    #!/bin/bash
    source {{ VIVADO_SETTINGS }}
    echo "Compiling parallel_to_serial testbench with Vivado xvlog"
    xvlog -sv \
        -i {{ RTL_DIR }} -i {{ TB_DIR }} \
        {{ RTL_DIR }}/bus_pkg.sv \
        {{ RTL_DIR }}/serializer.sv \
        {{ RTL_DIR }}/tx_controller.sv \
        {{ RTL_DIR }}/parallel_to_serial.sv \
        {{ TB_DIR }}/parallel_to_serial_tb.sv \
        -log {{ BUILD_DIR }}/logs/xvlog_parallel_to_serial.log

[linux]
sim-vivado-parallel-to-serial: compile-vivado-parallel-to-serial
    #!/bin/bash
    source {{ VIVADO_SETTINGS }}
    echo "Running parallel_to_serial simulation with Vivado xsim"
    xelab parallel_to_serial_tb -debug typical -log {{ BUILD_DIR }}/logs/xelab_parallel_to_serial.log
    xsim parallel_to_serial_tb -runall -log {{ BUILD_DIR }}/logs/xsim_parallel_to_serial.log -wdb {{ BUILD_DIR }}/waves/parallel_to_serial.wdb

[linux]
compile-vivado-serial-to-parallel: setup
    #!/bin/bash
    source {{ VIVADO_SETTINGS }}
    echo "Compiling serial_to_parallel testbench with Vivado xvlog"
    xvlog -sv \
        -i {{ RTL_DIR }} -i {{ TB_DIR }} \
        {{ RTL_DIR }}/bus_pkg.sv \
        {{ RTL_DIR }}/deserializer.sv \
        {{ RTL_DIR }}/frame_decoder.sv \
        {{ RTL_DIR }}/serializer.sv \
        {{ RTL_DIR }}/serial_to_parallel.sv \
        {{ TB_DIR }}/serial_to_parallel_tb.sv \
        -log {{ BUILD_DIR }}/logs/xvlog_serial_to_parallel.log

[linux]
sim-vivado-serial-to-parallel: compile-vivado-serial-to-parallel
    #!/bin/bash
    source {{ VIVADO_SETTINGS }}
    echo "Running serial_to_parallel simulation with Vivado xsim"
    xelab serial_to_parallel_tb -debug typical -log {{ BUILD_DIR }}/logs/xelab_serial_to_parallel.log
    xsim serial_to_parallel_tb -runall -log {{ BUILD_DIR }}/logs/xsim_serial_to_parallel.log -wdb {{ BUILD_DIR }}/waves/serial_to_parallel.wdb

[linux]
compile-vivado-addr-decoder: setup
    #!/bin/bash
    source {{ VIVADO_SETTINGS }}
    echo "Compiling addr_decoder testbench with Vivado xvlog"
    xvlog -sv \
        -i {{ RTL_DIR }} -i {{ TB_DIR }} \
        {{ RTL_DIR }}/bus_pkg.sv \
        {{ RTL_DIR }}/addr_decoder.sv \
        {{ TB_DIR }}/addr_decoder_tb.sv \
        -log {{ BUILD_DIR }}/logs/xvlog_addr_decoder.log

[linux]
sim-vivado-addr-decoder: compile-vivado-addr-decoder
    #!/bin/bash
    source {{ VIVADO_SETTINGS }}
    echo "Running addr_decoder simulation with Vivado xsim"
    xelab addr_decoder_tb -debug typical -log {{ BUILD_DIR }}/logs/xelab_addr_decoder.log
    xsim addr_decoder_tb -runall -log {{ BUILD_DIR }}/logs/xsim_addr_decoder.log -wdb {{ BUILD_DIR }}/waves/addr_decoder.wdb

[linux]
compile-vivado-serial-arbiter: setup
    #!/bin/bash
    source {{ VIVADO_SETTINGS }}
    echo "Compiling serial_arbiter testbench with Vivado xvlog"
    xvlog -sv \
        -i {{ RTL_DIR }} -i {{ TB_DIR }} \
        {{ RTL_DIR }}/bus_pkg.sv \
        {{ RTL_DIR }}/serial_arbiter.sv \
        {{ TB_DIR }}/serial_arbiter_tb.sv \
        -log {{ BUILD_DIR }}/logs/xvlog_serial_arbiter.log

[linux]
sim-vivado-serial-arbiter: compile-vivado-serial-arbiter
    #!/bin/bash
    source {{ VIVADO_SETTINGS }}
    echo "Running serial_arbiter simulation with Vivado xsim"
    xelab serial_arbiter_tb -debug typical -log {{ BUILD_DIR }}/logs/xelab_serial_arbiter.log
    xsim serial_arbiter_tb -runall -log {{ BUILD_DIR }}/logs/xsim_serial_arbiter.log -wdb {{ BUILD_DIR }}/waves/serial_arbiter.wdb

[linux]
compile-vivado-bitserial-top: setup
    #!/bin/bash
    source {{ VIVADO_SETTINGS }}
    echo "Compiling bitserial_top testbench with Vivado xvlog"
    xvlog -sv \
        -i {{ RTL_DIR }} -i {{ TB_DIR }} \
        {{ RTL_DIR }}/bus_pkg.sv \
        {{ RTL_DIR }}/serializer.sv \
        {{ RTL_DIR }}/deserializer.sv \
        {{ RTL_DIR }}/frame_decoder.sv \
        {{ RTL_DIR }}/tx_controller.sv \
        {{ RTL_DIR }}/parallel_to_serial.sv \
        {{ RTL_DIR }}/serial_to_parallel.sv \
        {{ RTL_DIR }}/serial_arbiter.sv \
        {{ RTL_DIR }}/addr_decoder.sv \
        {{ RTL_DIR }}/slave_mem.sv \
        {{ RTL_DIR }}/bitserial_top.sv \
        {{ TB_DIR }}/bitserial_top_tb.sv \
        -log {{ BUILD_DIR }}/logs/xvlog_bitserial_top.log

[linux]
sim-vivado-bitserial-top: compile-vivado-bitserial-top
    #!/bin/bash
    source {{ VIVADO_SETTINGS }}
    echo "Running bitserial_top simulation with Vivado xsim"
    xelab bitserial_top_tb -debug typical -log {{ BUILD_DIR }}/logs/xelab_bitserial_top.log
    xsim bitserial_top_tb -runall -log {{ BUILD_DIR }}/logs/xsim_bitserial_top.log -wdb {{ BUILD_DIR }}/waves/bitserial_top.wdb

[linux]
sim-vivado-all: sim-vivado-serializer sim-vivado-deserializer sim-vivado-parallel-to-serial sim-vivado-serial-to-parallel sim-vivado-addr-decoder sim-vivado-serial-arbiter sim-vivado-bitserial-top

# =============================================================================
# VIVADO SYNTHESIS
# =============================================================================

[linux]
synth-vivado: setup
    #!/bin/bash
    source {{ VIVADO_SETTINGS }}
    echo "Running Vivado synthesis check"
    vivado -mode batch -source {{ FPGA_DIR }}/vivado/synth.tcl \
        -log {{ BUILD_DIR }}/logs/vivado_synth.log \
        -journal {{ BUILD_DIR }}/logs/vivado_synth.jou

# =============================================================================
# QUARTUS SYNTHESIS (DE0-Nano)
# =============================================================================

[linux]
synth-quartus: setup
    #!/bin/bash
    echo "Running Quartus synthesis for DE0-Nano"
    cd {{ FPGA_DIR }}/quartus
    quartus_sh -t synth.tcl 2>&1 | tee {{ BUILD_DIR }}/logs/quartus_synth.log

[linux]
quartus-gui: setup
    #!/bin/bash
    echo "Opening Quartus GUI"
    cd {{ FPGA_DIR }}/quartus
    quartus bitserial.qpf &

[linux]
quartus-program: setup
    #!/bin/bash
    echo "Programming DE0-Nano via USB Blaster"
    cd {{ FPGA_DIR }}/quartus
    quartus_pgm -c "USB-Blaster" -m jtag -o "p;output_files/bitserial.sof"

[linux]
quartus-clean:
    #!/bin/bash
    echo "Cleaning Quartus build files"
    cd {{ FPGA_DIR }}/quartus
    rm -rf db incremental_db output_files
    rm -f *.rpt *.summary *.qws *.jdi *.sld *.stp
    rm -f *.done *.pin *.smsg *.qpf~ *.qsf~

# =============================================================================
# REPORT GENERATION
# =============================================================================

report:
    cd {{ REPORT_DIR }} && typst compile main.typ main.pdf --root ..

report-watch:
    cd {{ REPORT_DIR }} && typst watch main.typ main.pdf --root ..

report-diagrams:
    cd {{ REPORT_DIR }}/diagrams && uv run generate_diagrams.py
