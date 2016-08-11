proj = "dnskv"

sim_top = app_tb
outdir = build

# Xilinx sources and top module
RTL_SRC := rtl/SFP_CLK_INIT_rtl/i2c/trunk/rtl/verilog/i2c_master_bit_ctrl.v  \
           rtl/SFP_CLK_INIT_rtl/pkg_clk_init_engine.vhd                      \
           rtl/SFP_CLK_INIT_rtl/i2c/trunk/rtl/verilog/i2c_master_byte_ctrl.v \
           rtl/SFP_CLK_INIT_rtl/clk_init_engine.vhd                          \
           rtl/SFP_CLK_INIT_rtl/i2c/trunk/rtl/verilog/i2c_master_top.v       \
           rtl/SFP_CLK_INIT_rtl/sfp_refclk_init.vhd                          \
           rtl/pcs_pma_conf.v                                                \
           rtl/eth_mac_conf.v                                                \
           rtl/eth_top.v                                                     \
           rtl/top.v

## libraries
#INC_SRC := $(wildcard ../../cores/pkg/*.sv)
#INC_SRC := $(wildcard ../../cores/pkg/*.sv) \
#           $(wildcard ../../cores/xgmiisync/rtl/*.sv) \
#           $(wildcard ../../cores/crc32/rtl/*.v) \
#           $(wildcard ../../cores/eth_fcs/rtl/*.sv) \
#           $(wildcard ../../cores/txfifo/rtl/*.sv)

#IM_SRC := $(wildcard test/*.sv)

#VERILATOR_SRC := test/app_tb.cpp

IP_SRC := ip_catalog/axi_10g_ethernet_0/axi_10g_ethernet_0.xci  \
          ip_catalog/axi_10g_ethernet_nonshared/axi_10g_ethernet_nonshared.xci \
          ip_catalog/ila_0/ila_0.xci                            \
		  ip_catalog/sfifo_75_131k/sfifo_75_131k.xci            \
          ip_catalog/axis_data_fifo_1/axis_data_fifo_1.xci      \
		  ip_catalog/sram_mig/sram_mig.xci                      \
          ip_catalog/si5324_regs_rom/si5324_regs_rom.xcix

XDC_SRC := constraints/sume.xdc      \
           ip_catalog/sram_mig/sram_mig/user_design/constraints/sram_mig.xdc \
           constraints/sume-eth.xdc 

TCL_SRC := scripts/vivado_createprj.tcl  \
           scripts/vivado_synth.tcl      \
           scripts/vivado_place.tcl      \
           scripts/vivado_route.tcl      \
           scripts/vivado_bitstream.tcl

all: bitstream

prj: $(proj).xpr
$(proj).xpr: $(TCL_SRC) $(RTL_SRC) $(IP_SRC) $(XDC_SRC)
	test -e $(outdir) || mkdir $(outdir)
	vivado -mode batch -source scripts/vivado_createprj.tcl -log $(outdir)/createprj_log.txt -nojournal -tclargs "$(RTL_SRC)" "$(IP_SRC)" "$(XDC_SRC)"

synth: $(outdir)/post_syn.dcp
$(outdir)/post_syn.dcp: $(TCL_SRC) $(RTL_SRC) $(IP_SRC) $(XDC_SRC)
	test -e $(outdir) || mkdir $(outdir)
	vivado -mode batch -source scripts/vivado_synth.tcl -log $(outdir)/syn_log.txt -nojournal -tclargs "$(RTL_SRC)" "$(IP_SRC)" "$(XDC_SRC)"

place: $(outdir)/post_place.dcp
$(outdir)/post_place.dcp: $(outdir)/post_syn.dcp
	vivado -mode batch -source scripts/vivado_place.tcl -log $(outdir)/place_log.txt -nojournal

route: $(outdir)/post_route.dcp
$(outdir)/post_route.dcp: $(outdir)/post_place.dcp
	vivado -mode batch -source scripts/vivado_route.tcl -log $(outdir)/route_log.txt -nojournal

bitstream: $(outdir)/$(proj).bit
$(outdir)/$(proj).bit: $(outdir)/post_route.dcp
	vivado -mode batch -source scripts/vivado_bitstream.tcl -log $(outdir)/bitstream_log.txt -nojournal

program: $(outdir)/$(proj).bit
	vivado -mode batch -source scripts/vivado_program.tcl -log $(outdir)/program_log.txt -nojournal

load: $(outdir)/$(proj).bit
	./script/xprog.sh load $(outdir)/$(proj).bit

#sim: sim-verilator
#
#lint: $(INC_SRC) $(RTL_SRC)
#	verilator -Wall --lint-only --cc --top-module $(sim_top) -sv $(INC_SRC) $(RTL_SRC)

#sim-verilator:
#	verilator -Wall -DSIMULATION --cc --trace --top-module $(sim_top) -sv $(INC_SRC) $(SIM_SRC) --exe $(VERILATOR_SRC)
#	make -j -C obj_dir/ -f V$(sim_top).mk V$(sim_top)
#	obj_dir/V$(sim_top)

synth-clean:
	rm -f fsm_encoding.os usage_stat*
	rm -rf build .Xil
	rm -rf *.jou *.log *.mif *.hw  *.ip_user_files *.cache  *.sim *.runs *.srcs

sim-clean:
	rm -f wave.vcd
	rm -rf obj_dir

.PHONY: clean load
clean: sim-clean synth-clean

.PHONY: distclean
distclean:
	git clean -Xdf
