# Synopsys Design Constraints (SDC) for Bit-Serial Bus System
# Target: Altera DE0-Nano Board (50 MHz system clock)

# Create base clock - 50 MHz from onboard oscillator
create_clock -name clk_i -period 20.000 [get_ports {clk_i}]

# Use derive_clock_uncertainty for automatic clock uncertainty calculation
derive_clock_uncertainty

# Input delays for asynchronous inputs (reset, master inputs)
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
set_output_delay -clock clk_i -max 10.0 [get_ports {m_gnt_o[*]}]
set_output_delay -clock clk_i -min 0.0 [get_ports {m_gnt_o[*]}]

set_output_delay -clock clk_i -max 10.0 [get_ports {m_ready_o[*]}]
set_output_delay -clock clk_i -min 0.0 [get_ports {m_ready_o[*]}]

set_output_delay -clock clk_i -max 10.0 [get_ports {m_rdata_o[*][*]}]
set_output_delay -clock clk_i -min 0.0 [get_ports {m_rdata_o[*][*]}]

set_output_delay -clock clk_i -max 10.0 [get_ports {m_err_o[*]}]
set_output_delay -clock clk_i -min 0.0 [get_ports {m_err_o[*]}]

# False paths for asynchronous reset
set_false_path -from [get_ports {rst_ni}] -to [all_registers]
