################################################################################
# Base Clock Definitions
################################################################################
create_clock -period 20.000 -name CLOCK_50 [get_ports CLOCK_50]
create_clock -period 20.000 -name CLOCK2_50 [get_ports CLOCK2_50]
create_clock -period 20.000 -name CLOCK3_50 [get_ports CLOCK3_50]

# Camera pixel clock - external input, approximately 96 MHz typical for D5M
# Adjust period based on actual camera configuration
create_clock -period 10.416 -name D5M_PIXLCLK [get_ports D5M_PIXLCLK]

################################################################################
# PLL-derived Clocks
################################################################################
derive_pll_clocks
derive_clock_uncertainty

################################################################################
# Generated/Inverted Clock Definitions
# These are used for SDRAM FIFO read clocks
################################################################################
create_generated_clock -name VGA_CLK_inv -source [get_pins {pll_0|altpll_component|auto_generated|pll1|clk[3]}] -invert [get_registers {*RD1*}]
create_generated_clock -name CLOCK_50_inv -source [get_ports CLOCK_50] -invert [get_registers {*RD2*}]

################################################################################
# Clock Domain Crossing Constraints
# Set false paths between asynchronous clock domains to prevent timing
# analyzer from reporting violations on properly synchronized crossings
################################################################################

# Camera clock domain to SDRAM/system clock domain
set_false_path -from [get_clocks D5M_PIXLCLK] -to [get_clocks {pll_0|*|clk[0]}]
set_false_path -from [get_clocks {pll_0|*|clk[0]}] -to [get_clocks D5M_PIXLCLK]
set_false_path -from [get_clocks D5M_PIXLCLK] -to [get_clocks CLOCK_50]
set_false_path -from [get_clocks CLOCK_50] -to [get_clocks D5M_PIXLCLK]

# VGA clock domain crossings
set_false_path -from [get_clocks {pll_0|*|clk[3]}] -to [get_clocks {pll_0|*|clk[0]}]
set_false_path -from [get_clocks {pll_0|*|clk[0]}] -to [get_clocks {pll_0|*|clk[3]}]
set_false_path -from [get_clocks {pll_0|*|clk[3]}] -to [get_clocks CLOCK_50]
set_false_path -from [get_clocks CLOCK_50] -to [get_clocks {pll_0|*|clk[3]}]

# SDRAM FIFO clock domain crossings (the FIFOs handle synchronization internally)
set_false_path -from [get_clocks CLOCK_50] -to [get_clocks {pll_0|*|clk[0]}]
set_false_path -from [get_clocks {pll_0|*|clk[0]}] -to [get_clocks CLOCK_50]

################################################################################
# SignalTap Debug Logic Constraints
# These paths often cause hold violations due to clock domain crossing
################################################################################
set_false_path -to [get_keepers {*sld_signaltap*}]
set_false_path -from [get_keepers {*sld_signaltap*}]
set_false_path -to [get_keepers {*altera_reserved*}]
set_false_path -from [get_keepers {*altera_reserved*}]

################################################################################
# External I/O Constraints
################################################################################

# SRAM interface - asynchronous memory
set_false_path -from [get_ports SRAM_DQ*]
set_false_path -to [get_ports SRAM_*]

# SDRAM interface timing is handled by the SDRAM controller
# The DQ bus is bidirectional and crosses clock domains
set_false_path -from [get_ports DRAM_DQ*]

# Camera input data
set_false_path -from [get_ports D5M_D*]
set_false_path -from [get_ports D5M_FVAL]
set_false_path -from [get_ports D5M_LVAL]
set_false_path -from [get_ports D5M_STROBE]

# VGA outputs - timing is not critical
set_false_path -to [get_ports VGA_*]

# Keys and switches are asynchronous inputs
set_false_path -from [get_ports KEY*]
set_false_path -from [get_ports SW*]

# LEDs and HEX displays
set_false_path -to [get_ports LED*]
set_false_path -to [get_ports HEX*]

################################################################################
# Multicycle Paths (if any paths need relaxed timing)
################################################################################
# Add multicycle constraints here if needed for specific slow paths

