create_clock -period 20 [get_ports CLOCK_50]
create_clock -period 20 [get_ports CLOCK2_50]
create_clock -period 20 [get_ports CLOCK3_50]

# Camera pixel clock from D5M sensor
# The D5M outputs PIXLCLK at the same rate as D5M_XCLKIN (25MHz from PLL c2)
create_clock -period 40 -name D5M_PIXLCLK [get_ports D5M_PIXLCLK]

derive_pll_clocks
derive_clock_uncertainty

# Generated clocks for inverted clock signals used in the design
# These are created by logic inverters and used as FIFO clocks

# Inverted camera pixel clock (used by camera_capture_0)
create_generated_clock -name D5M_PIXLCLK_n \
    -source [get_ports D5M_PIXLCLK] \
    -invert \
    [get_pins {camera_capture_0|*}] -add

# Inverted VGA clock (used by SDRAM RD1 FIFO)  
create_generated_clock -name VGA_CLK_n \
    -source [get_pins {pll_0|altpll_component|auto_generated|pll1|clk[3]}] \
    -invert \
    [get_pins {sdram_ctrl_0|*}] -add

# Set clock groups - camera clock domain is asynchronous to system clocks
set_clock_groups -asynchronous \
    -group [get_clocks {D5M_PIXLCLK D5M_PIXLCLK_n}] \
    -group [get_clocks {CLOCK_50 pll_0|altpll_component|auto_generated|pll1|clk[*] VGA_CLK_n}]

# False paths for asynchronous resets and control signals crossing clock domains
# (Add specific paths if you know them)
