# Create Project
cd [file dirname [file normalize [info script]]]
create_project lab5 ./ -part xc7z020clg400-1 -force
set_property board_part tul.com.tw:pynq-z2:part0:1.0 [current_project]

# Add files
add_files [ glob ./src/design/* ]
add_files -fileset sim_1 [ glob ./src/sim/* ]
add_files -fileset constrs_1 ./src/lab5.xdc

# Add HDMI IP
set_property ip_repo_paths ./hdmi_tx_ip/ [current_project]
update_ip_catalog

create_ip -name hdmi_tx -vendor realdigital.org -library realdigital -version 1.1 -module_name hdmi_tx_0

# Add clk_wiz
create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name clk_wiz_0
set_property -dict [list \
	CONFIG.CLK_IN1_BOARD_INTERFACE {sys_clock} \
	CONFIG.CLKOUT2_USED {true} \
	CONFIG.CLKOUT3_USED {true} \
	CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {25} \
	CONFIG.CLKOUT3_REQUESTED_OUT_FREQ {125.000} \
	CONFIG.PRIM_IN_FREQ {125.000} \
	CONFIG.CLKIN1_JITTER_PS {80.0} \
	CONFIG.MMCM_CLKFBOUT_MULT_F {8.000} \
	CONFIG.MMCM_CLKIN1_PERIOD {8.000} \
	CONFIG.MMCM_CLKOUT1_DIVIDE {40} \
	CONFIG.MMCM_CLKOUT2_DIVIDE {8} \
	CONFIG.NUM_OUT_CLKS {3} \
	CONFIG.CLKOUT1_JITTER {124.615} \
	CONFIG.CLKOUT1_PHASE_ERROR {96.948} \
	CONFIG.CLKOUT2_JITTER {165.419} \
	CONFIG.CLKOUT2_PHASE_ERROR {96.948} \
	CONFIG.CLKOUT3_JITTER {119.348} \
	CONFIG.CLKOUT3_PHASE_ERROR {96.948}\
] [get_ips clk_wiz_0]
