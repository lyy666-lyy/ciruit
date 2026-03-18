# =============================================================================
# SDC Constraints for MAC16
# Target: reasonable timing constraint for Empyrean_polaris synthesis
# =============================================================================

# Clock definition (100MHz example, adjust per actual target)
create_clock -name clk -period 10.0 [get_ports clk]

# Clock uncertainty (jitter + skew)
set_clock_uncertainty 0.3 [get_clocks clk]

# Clock transition
set_clock_transition 0.1 [get_clocks clk]

# Input delay constraints (assume 30% of clock period)
set_input_delay -clock clk -max 3.0 [get_ports {din_A[*] din_B[*] en}]
set_input_delay -clock clk -min 0.5 [get_ports {din_A[*] din_B[*] en}]

# Reset input delay (async reset, looser constraint)
set_input_delay -clock clk -max 4.0 [get_ports rst_n]
set_input_delay -clock clk -min 0.5 [get_ports rst_n]

# Output delay constraints (assume 30% of clock period)
set_output_delay -clock clk -max 3.0 [get_ports {mac_out[*] carry out_ready}]
set_output_delay -clock clk -min 0.5 [get_ports {mac_out[*] carry out_ready}]

# Driving cell and load
# (Adjust based on actual technology library)
# set_driving_cell -lib_cell INVX1 -pin Y [all_inputs]
set_load 0.05 [all_outputs]

# Max fanout
set_max_fanout 20 [current_design]

# Max transition
set_max_transition 0.3 [current_design]

# False path for async reset
set_false_path -from [get_ports rst_n]

# Design rule constraints
set_max_area 0
