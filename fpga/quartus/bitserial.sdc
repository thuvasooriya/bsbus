# Synopsys Design Constraints (SDC) for Bit-Serial Bus System
# Target: Altera DE0-Nano Board (50 MHz system clock)

# Create base clock - 50 MHz from onboard oscillator
create_clock -name clk_i -period 20.000 [get_ports {clk_i}]

# Create derived clock for serial interface (CLK/4 = 12.5 MHz)
# This is generated internally by the serializer/deserializer
create_generated_clock -name sclk -source [get_ports {clk_i}] -divide_by 4 [get_registers {*sclk_reg*}]

# Input delays for asynchronous inputs (reset, master inputs)
# Assume signals are stable 5ns before clock edge
set_input_delay -clock clk_i -max 5.0 [get_ports {rst_ni}]
set_input_delay -clock clk_i -min 0.0 [get_ports {rst_ni}]

set_input_delay -clock clk_i -max 5.0 [get_ports {m_req_i[*]}]
set_input_delay -clock clk_i -min 0.0 [get_ports {m_req_i[*]}]

set_input_delay -clock clk_i -max 5.0 [get_ports {m_we_i[*]}]
set_input_delay -clock clk_i -min 0.0 [get_ports {m_we_i[*]}]

set_input_delay -clock clk_i -max 5.0 [get_ports {m_addr_i[*][*]}]
set_input_delay -clock clk_i -min 0.0 [get_ports {m_addr_i[*][*]}]

set_input_delay -clock clk_i -max 5.0 [get_ports {m_wdata_i[*][*]}]
set_input_delay -clock clk_i -min 0.0 [get_ports {m_wdata_i[*][*]}]

# Output delays for master outputs
# LEDs should be stable within 10ns after clock edge
set_output_delay -clock clk_i -max 10.0 [get_ports {m_gnt_o[*]}]
set_output_delay -clock clk_i -min 0.0 [get_ports {m_gnt_o[*]}]

set_output_delay -clock clk_i -max 10.0 [get_ports {m_ready_o[*]}]
set_output_delay -clock clk_i -min 0.0 [get_ports {m_ready_o[*]}]

set_output_delay -clock clk_i -max 10.0 [get_ports {m_rdata_o[*][*]}]
set_output_delay -clock clk_i -min 0.0 [get_ports {m_rdata_o[*][*]}]

set_output_delay -clock clk_i -max 10.0 [get_ports {m_err_o[*]}]
set_output_delay -clock clk_i -min 0.0 [get_ports {m_err_o[*]}]

# Clock uncertainty for on-chip clock distribution
set_clock_uncertainty -setup 0.5 [get_clocks {clk_i}]
set_clock_uncertainty -hold 0.3 [get_clocks {clk_i}]

# False paths for asynchronous reset
set_false_path -from [get_ports {rst_ni}] -to [all_registers]

# Multicycle paths for serial clock domain
# Serial transactions take 4 system clocks per bit
set_multicycle_path -setup -from [get_clocks {sclk}] -to [get_clocks {clk_i}] 4
set_multicycle_path -hold -from [get_clocks {sclk}] -to [get_clocks {clk_i}] 3

# Future: Inter-board GPIO constraints (when implemented)
# set_input_delay -clock clk_i -max 8.0 [get_ports {serial_*_in}]
# set_output_delay -clock clk_i -max 8.0 [get_ports {serial_*_out}]
# set_false_path -from [get_ports {serial_*_in}] -to [all_registers]
# set_false_path -from [all_registers] -to [get_ports {serial_*_out}]
