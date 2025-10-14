# Quartus Synthesis Script for Bit-Serial Bus System
# Target: Altera DE0-Nano (Cyclone IV E EP4CE22F17C6)

# Load Quartus II Tcl package
package require ::quartus::project
package require ::quartus::flow

# Project name
set project_name "bitserial"

# Check if project exists, if not create it
if {[is_project_open]} {
    project_close
}

if {![project_exists $project_name]} {
    project_new $project_name -overwrite
    puts "Created new project: $project_name"
} else {
    project_open $project_name
    puts "Opened existing project: $project_name"
}

# Run full compilation flow
puts "\n=========================================="
puts "Starting Quartus Compilation Flow"
puts "Target: DE0-Nano (EP4CE22F17C6)"
puts "==========================================\n"

# Execute compilation
if {[catch {execute_flow -compile} result]} {
    puts "ERROR: Compilation failed!"
    puts $result
    project_close
    exit 1
} else {
    puts "\n=========================================="
    puts "Compilation Successful!"
    puts "==========================================\n"
}

# Load the report package
load_package report

# Open the compilation results
if {[catch {load_report} result]} {
    puts "ERROR: Could not load report database"
    project_close
    exit 1
}

# Print resource utilization summary
puts "=========================================="
puts "Resource Utilization Summary"
puts "==========================================\n"

# Get fitter summary panel
set panel_name "Fitter||Fitter Summary"
if {[get_report_panel_names -filter $panel_name] != ""} {
    set row_count [get_report_panel_row_count -name $panel_name]
    for {set i 0} {$i < $row_count} {incr i} {
        set row_data [get_report_panel_row -name $panel_name -row $i]
        puts [join $row_data " : "]
    }
}

puts "\n=========================================="
puts "Timing Analysis Summary"
puts "==========================================\n"

# Get timing analyzer summary
set panel_name "TimeQuest Timing Analyzer||Slow 1200mV 85C Model||Slow 1200mV 85C Model Fmax Summary"
if {[get_report_panel_names -filter "*Fmax Summary*"] != ""} {
    set panel_names [get_report_panel_names -filter "*Fmax Summary*"]
    set panel_name [lindex $panel_names 0]
    set row_count [get_report_panel_row_count -name $panel_name]
    for {set i 0} {$i < $row_count} {incr i} {
        set row_data [get_report_panel_row -name $panel_name -row $i]
        puts [join $row_data " : "]
    }
}

# Unload report
unload_report

# Close project
project_close

puts "\n=========================================="
puts "Build Complete!"
puts "Output files in: output_files/"
puts "  - bitserial.sof (FPGA programming file)"
puts "  - bitserial.fit.summary (resource report)"
puts "  - bitserial.sta.summary (timing report)"
puts "==========================================\n"

exit 0
