# SFP/QTH Transceiver clock (Must be set to value provided by Si5324, currently set to 156.25 MHz)
set_property PACKAGE_PIN E10 [get_ports xphy_refclk_clk_p]
set_property PACKAGE_PIN E9 [get_ports xphy_refclk_clk_n]
create_clock -add -name sfp_clk_pin -period 6.400 -waveform {0 3.200} [get_ports {xphy_refclk_clk_p}];

#SFP Transceivers
set_property PACKAGE_PIN AM29 [get_ports sfp_clk_alarm_b]
set_property IOSTANDARD LVCMOS18 [get_ports sfp_clk_alarm_b]
set_property IOSTANDARD LVDS [get_ports sfp_rec_clk_n]
set_property PACKAGE_PIN AW32 [get_ports sfp_rec_clk_p]
set_property PACKAGE_PIN AW33 [get_ports sfp_rec_clk_n]
set_property IOSTANDARD LVDS [get_ports sfp_rec_clk_p]

# eth led
set_property -dict { PACKAGE_PIN G13  IOSTANDARD LVCMOS15 } [get_ports { led[0] }];
set_property -dict { PACKAGE_PIN L15  IOSTANDARD LVCMOS15 } [get_ports { led[1] }];
set_property -dict { PACKAGE_PIN AL22 IOSTANDARD LVCMOS15 } [get_ports { led[2] }];
set_property -dict { PACKAGE_PIN BA20 IOSTANDARD LVCMOS15 } [get_ports { led[3] }];
set_property -dict { PACKAGE_PIN AY18 IOSTANDARD LVCMOS15 } [get_ports { led[4] }];
set_property -dict { PACKAGE_PIN AY17 IOSTANDARD LVCMOS15 } [get_ports { led[5] }];
set_property -dict { PACKAGE_PIN P31  IOSTANDARD LVCMOS15 } [get_ports { led[6] }];
set_property -dict { PACKAGE_PIN K32  IOSTANDARD LVCMOS15 } [get_ports { led[7] }];
#
set_property -dict { PACKAGE_PIN A5 } [get_ports { xphy0_rxn }];
set_property -dict { PACKAGE_PIN A6 } [get_ports { xphy0_rxp }];
set_property -dict { PACKAGE_PIN B3 } [get_ports { xphy0_txn }];
set_property -dict { PACKAGE_PIN B4 } [get_ports { xphy0_txp }];
set_property -dict { PACKAGE_PIN B8 } [get_ports { xphy1_rxp }];
set_property -dict { PACKAGE_PIN B7 } [get_ports { xphy1_rxn }];
set_property -dict { PACKAGE_PIN C2 } [get_ports { xphy1_txp }];
set_property -dict { PACKAGE_PIN C1 } [get_ports { xphy1_txn }];
set_property -dict { PACKAGE_PIN M18 IOSTANDARD LVCMOS18 } [get_ports { sfp_tx_disable[0] }];
set_property -dict { PACKAGE_PIN B31 IOSTANDARD LVCMOS18 } [get_ports { sfp_tx_disable[1] }]; 


# Else
set_false_path -to [get_ports -filter {NAME=~led*}]

