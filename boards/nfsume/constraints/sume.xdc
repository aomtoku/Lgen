set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property CFGBVS GND [current_design]
set_property CONFIG_VOLTAGE 1.8 [current_design]

# FPGA_SYSCLK (200MHz)
set_property -dict { PACKAGE_PIN G18   IOSTANDARD LVDS     } [get_ports { clk_ref_n }];
set_property -dict { PACKAGE_PIN H19   IOSTANDARD LVDS     } [get_ports { clk_ref_p }];
create_clock -add -name sys_clk_pin -period 5.00 -waveform {0 2.5} [get_ports {clk_ref_p}]; 

# I2C
set_property SLEW SLOW [get_ports i2c_clk]
set_property DRIVE 16 [get_ports i2c_clk]
set_property PACKAGE_PIN AK24 [get_ports i2c_clk]
set_property PULLUP true [get_ports i2c_clk]
set_property IOSTANDARD LVCMOS18 [get_ports i2c_clk]

set_property SLEW SLOW [get_ports i2c_data]
set_property DRIVE 16 [get_ports i2c_data]
set_property PACKAGE_PIN AK25 [get_ports i2c_data]
set_property PULLUP true [get_ports i2c_data]
set_property IOSTANDARD LVCMOS18 [get_ports i2c_data]

