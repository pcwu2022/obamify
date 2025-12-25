create_clock -period 20 [get_ports CLOCK_50]
create_clock -period 20 [get_ports CLOCK2_50]
create_clock -period 20 [get_ports CLOCK3_50]

# Camera pixel clock from D5M sensor (25MHz, same as D5M_XCLKIN)
create_clock -period 40 -name D5M_PIXLCLK [get_ports D5M_PIXLCLK]

# I2C control clock (generated internally, ~400kHz from divided CLOCK_50)
# This is a divided clock used for I2C communication
create_clock -period 2500 -name I2C_CTRL_CLK [get_registers {*mI2C_CTRL_CLK}]

derive_pll_clocks
derive_clock_uncertainty

# Clock groups - asynchronous clock domains
# Camera pixel clock is asynchronous to system clocks
set_clock_groups -asynchronous \
    -group [get_clocks {D5M_PIXLCLK}] \
    -group [get_clocks {CLOCK_50 pll_0|altpll_component|auto_generated|pll1|clk[*]}] \
    -group [get_clocks {I2C_CTRL_CLK}]

# The design uses inverted clocks (~D5M_PIXLCLK, ~VGA_CLK_in) for some FIFOs
# These are handled by Quartus automatically, but we set false paths for
# cross-domain transfers to avoid impossible timing requirements
set_false_path -from [get_clocks {D5M_PIXLCLK}] -to [get_clocks {pll_0|altpll_component|auto_generated|pll1|clk[*]}]
set_false_path -from [get_clocks {pll_0|altpll_component|auto_generated|pll1|clk[*]}] -to [get_clocks {D5M_PIXLCLK}]
