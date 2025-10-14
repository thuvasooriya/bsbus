# Vivado synthesis script for bit-serial bus system
# This performs synthesis only (no implementation) to check for synthesizability

set rtl_dir "rtl"
set build_dir "build/vivado"

# Create output directory
file mkdir $build_dir

# Read design files in dependency order
read_verilog -sv $rtl_dir/bus_pkg.sv
read_verilog -sv $rtl_dir/serializer.sv
read_verilog -sv $rtl_dir/deserializer.sv
read_verilog -sv $rtl_dir/tx_controller.sv
read_verilog -sv $rtl_dir/frame_decoder.sv
read_verilog -sv $rtl_dir/parallel_to_serial.sv
read_verilog -sv $rtl_dir/serial_to_parallel.sv
read_verilog -sv $rtl_dir/serial_arbiter.sv
read_verilog -sv $rtl_dir/addr_decoder.sv
read_verilog -sv $rtl_dir/slave_mem.sv
read_verilog -sv $rtl_dir/bitserial_top.sv

# Set top module
set_property top bitserial_top [current_fileset]

# Run synthesis (without targeting specific part - generic synthesis check)
# Note: This checks for synthesizability without targeting a specific FPGA
synth_design -top bitserial_top -mode out_of_context

# Generate reports
report_utilization -file $build_dir/utilization_synth.rpt
report_timing_summary -file $build_dir/timing_synth.rpt

# Write checkpoint
write_checkpoint -force $build_dir/post_synth.dcp

puts ""
puts "=========================================="
puts "Synthesis check complete!"
puts "Reports written to $build_dir/"
puts "  - utilization_synth.rpt"
puts "  - timing_synth.rpt"
puts "=========================================="
puts ""
