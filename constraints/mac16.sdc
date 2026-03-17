# =============================================================================
# SDC Constraints for MAC16
# Target frequency: 500MHz -> Period = 2.0ns
# =============================================================================

# Clock definition
create_clock -name clk -period 2.0 [get_ports clk]

# Clock uncertainty (jitter + skew)
set_clock_uncertainty 0.1 [get_clocks clk]

# Clock transition
set_clock_transition 0.05 [get_clocks clk]

# Input delay constraints (assume 30% of clock period)
set_input_delay -clock clk -max 0.6 [get_ports {a[*] b[*] en mode}]
set_input_delay -clock clk -min 0.1 [get_ports {a[*] b[*] en mode}]

# Reset input delay (async reset, looser constraint)
set_input_delay -clock clk -max 0.8 [get_ports rst_n]
set_input_delay -clock clk -min 0.1 [get_ports rst_n]

# Output delay constraints (assume 30% of clock period)
set_output_delay -clock clk -max 0.6 [get_ports {out_31[*] carry out_ready}]
set_output_delay -clock clk -min 0.1 [get_ports {out_31[*] carry out_ready}]

# Driving cell and load
# (Adjust based on actual technology library)
# set_driving_cell -lib_cell INVX1 -pin Y [all_inputs]
set_load 0.05 [all_outputs]

# Max fanout
set_max_fanout 20 [current_design]

# Max transition
set_max_transition 0.15 [current_design]

# False path for async reset
set_false_path -from [get_ports rst_n]

# Design rule constraints
set_max_area 0
