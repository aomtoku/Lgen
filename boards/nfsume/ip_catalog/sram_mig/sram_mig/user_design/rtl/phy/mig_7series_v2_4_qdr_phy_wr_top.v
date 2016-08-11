//*****************************************************************************
//(c) Copyright 2009 - 2013 Xilinx, Inc. All rights reserved.
//
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
//
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
//
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.

////////////////////////////////////////////////////////////////////////////////
//   ____  ____
//  /   /\/   /
// /___/  \  /    Vendor             : Xilinx
// \   \   \/     Version            : %version 
//  \   \         Application        : MIG
//  /   /         Filename           : qdr_phy_wr_top.v
// /___/   /\     Date Last Modified : $date$
// \   \  /  \    Date Created       : Nov 12, 2008 
//  \___\/\___\
//
//Device: 7 Series
//Design: QDRII+ SRAM
//
//Purpose:
//    This module
//  1. Instantiates all the write path submodules
//
//
////////////////////////////////////////////////////////////////////////////////

`timescale 1ps/1ps

module mig_7series_v2_4_qdr_phy_wr_top #
  (parameter ADDR_WIDTH               = 19,
   parameter BURST_LEN                = 4,
   parameter BW_WIDTH                 = 8,
   parameter BYTE_LANE_WITH_DK        = 1,
   parameter CLK_STABLE               = 4000,
   parameter CMPLX_RDCAL_EN           = "FALSE",
   parameter DATA_WIDTH               = 72,
   parameter MEM_TYPE                 = "QDR2PLUS",
   parameter MMCM_SAMP_WAIT           = 256,
   parameter NUM_DEVICES              = 1,
   parameter N_CTL_LANES              = 2,
   parameter N_DATA_LANES             = 4, 
   parameter OCLK_CALIB_BYTE_LANE     = 16'b00_00_00_00_11_10_01_00,
   parameter PO_ADJ_GAP               = 7,
   parameter PO_COARSE_BYPASS         = "FALSE",
   parameter POC_USE_METASTABLE_SAMP  = "FALSE",
   parameter POC_PCT_SAMPS_SOLID      = 95,
   parameter POC_SAMPLES              = 2048,
   parameter PRE_FIFO                 = "TRUE",
   parameter SKIP_POC                 = "FALSE",
   parameter PD_SIM_CAL_OPTION        = "NONE",
   parameter TAPSPERKCLK              = 56,
   parameter TCQ                      = 100,
   parameter WRCAL_DEFAULT            = "FALSE",
   parameter WRCAL_SAMPLES            = 2048,
   parameter WRCAL_PCT_SAMPS_SOLID    = 95,
   parameter nCK_PER_CLK              = 2)
  (/*AUTOARG*/
  // Outputs
  wrcal_stg3, wrcal_po_en, wrcal_inc, wrcal_byte_sel,
  wrcal_addr_cntrl, rst_stg2, rst_stg1, rdlvl_stg1_start,
  rdlvl_stg1_fast, rdlvl_stg1_cal_bytes, psincdec, psen, poc_error,
  po_inc_done, po_dec_done, po_cnt_inc, po_cnt_dec, phy_ctl_wr,
  phy_ctl_wd, of_data_wr_en, of_cmd_wr_en, kill_rd_valid, iob_wr_n,
  iob_wdata, iob_rd_n, iob_dll_off_n, iob_bw, iob_addr, int_rd_cmd_n,
  edge_adv_cal_start, dbg_wr_init, dbg_poc, dbg_phy_wr_data,
  dbg_phy_wr_cmd_n, dbg_phy_rd_cmd_n, dbg_phy_addr, cmplx_rdcal_start,
  cmplx_rd_data_valid, cmplx_rd_burst_bytes, cal_stage2_start,
  ctl_lane_cnt, rst_clk, io_fifo_rden_cal_done, wrcal_en,
  init_calib_complete,
  // Inputs
  wr_data1, wr_data0, wr_cmd1, wr_cmd0, wr_bw_n1, wr_bw_n0, wr_addr1,
  wr_addr0, valid_latency, rst, read_cal_done, rdlvl_valid,
  rdlvl_stg1_done, rd_cmd1, rd_cmd0, rd_addr1, rd_addr0, psdone,
  poc_sample_pd, po_delay_done, po_counter_read_val, phy_ctl_ready,
  phy_ctl_full, phy_ctl_a_full, phase_valid, of_data_full,
  of_ctl_full, mmcm_fshift_clk, lb_clk, iddr_rst, edge_adv_cal_done,
  dbg_phy_init_wr_only, dbg_phy_init_rd_only, dbg_cmplx_wr_loop,
  dbg_K_right_shift_left, dbg_K_left_shift_right, clk, clk_mem
  );
  
  function integer clogb2 (input integer size); // ceiling logb2
    begin
      size = size - 1;
      for (clogb2=1; size>1; clogb2=clogb2+1)
            size = size >> 1;
    end
  endfunction // clogb2

  localparam BRAM_ADDR_WIDTH    = 8; 

  /*AUTOINPUT*/                                         
  // Beginning of automatic inputs (from unused autoinst inputs)
  input			clk;			// To u_qdr_phy_wr_control of mig_7series_v2_4_qdr_phy_wr_control_io.v, ...
  input [5:0]		dbg_K_left_shift_right;	// To u_qdr_phy_po_adj of mig_7series_v2_4_qdr_phy_wr_po_adj.v
  input [5:0]		dbg_K_right_shift_left;	// To u_qdr_phy_po_adj of mig_7series_v2_4_qdr_phy_wr_po_adj.v
  input			dbg_cmplx_wr_loop;	// To u_qdr_phy_wr_init_sm of mig_7series_v2_4_qdr_phy_wr_init_sm.v
  input			dbg_phy_init_rd_only;	// To u_qdr_phy_wr_init_sm of mig_7series_v2_4_qdr_phy_wr_init_sm.v
  input			dbg_phy_init_wr_only;	// To u_qdr_phy_wr_init_sm of mig_7series_v2_4_qdr_phy_wr_init_sm.v
  input			edge_adv_cal_done;	// To u_qdr_phy_wr_init_sm of mig_7series_v2_4_qdr_phy_wr_init_sm.v
  input			iddr_rst;		// To u_qdr_phy_poc_pd0 of mig_7series_v2_4_poc_pd.v, ...
  input [1:0]		lb_clk;			// To u_qdr_phy_poc_pd0 of mig_7series_v2_4_poc_pd.v, ...
  input			mmcm_fshift_clk;	// To u_qdr_phy_poc_pd0 of mig_7series_v2_4_poc_pd.v, ...
  input			of_ctl_full;		// To u_qdr_rld_phy_cntrl_init of mig_7series_v2_4_qdr_rld_phy_cntrl_init.v
  input			of_data_full;		// To u_qdr_rld_phy_cntrl_init of mig_7series_v2_4_qdr_rld_phy_cntrl_init.v
  input [N_DATA_LANES-1:0] phase_valid;		// To u_qdr_phy_wr_init_sm of mig_7series_v2_4_qdr_phy_wr_init_sm.v
  input			phy_ctl_a_full;		// To u_qdr_rld_phy_cntrl_init of mig_7series_v2_4_qdr_rld_phy_cntrl_init.v
  input			phy_ctl_full;		// To u_qdr_rld_phy_cntrl_init of mig_7series_v2_4_qdr_rld_phy_cntrl_init.v
  input			phy_ctl_ready;		// To u_qdr_rld_phy_cntrl_init of mig_7series_v2_4_qdr_rld_phy_cntrl_init.v
  input [8:0]		po_counter_read_val;	// To u_qdr_phy_po_adj of mig_7series_v2_4_qdr_phy_wr_po_adj.v, ...
  input			po_delay_done;		// To u_qdr_phy_wr_init_sm of mig_7series_v2_4_qdr_phy_wr_init_sm.v
  input			poc_sample_pd;		// To u_qdr_phy_poc of mig_7series_v2_4_poc_top.v
  input			psdone;			// To u_qdr_phy_poc of mig_7series_v2_4_poc_top.v
  input [ADDR_WIDTH-1:0] rd_addr0;		// To u_qdr_phy_wr_control of mig_7series_v2_4_qdr_phy_wr_control_io.v
  input [ADDR_WIDTH-1:0] rd_addr1;		// To u_qdr_phy_wr_control of mig_7series_v2_4_qdr_phy_wr_control_io.v
  input			rd_cmd0;		// To u_qdr_phy_wr_control of mig_7series_v2_4_qdr_phy_wr_control_io.v
  input			rd_cmd1;		// To u_qdr_phy_wr_control of mig_7series_v2_4_qdr_phy_wr_control_io.v
  input			rdlvl_stg1_done;	// To u_qdr_phy_wr_init_sm of mig_7series_v2_4_qdr_phy_wr_init_sm.v
  input			rdlvl_valid;		// To u_qdr_phy_wr_init_sm of mig_7series_v2_4_qdr_phy_wr_init_sm.v
  input			read_cal_done;		// To u_qdr_phy_wr_init_sm of mig_7series_v2_4_qdr_phy_wr_init_sm.v
  input			rst;			// To u_qdr_phy_wr_init_sm of mig_7series_v2_4_qdr_phy_wr_init_sm.v
  input [4:0]		valid_latency;		// To u_qdr_phy_cmplx_rdcal of mig_7series_v2_4_qdr_rld_phy_cmplx_rdcal.v
  input [ADDR_WIDTH-1:0] wr_addr0;		// To u_qdr_phy_wr_control of mig_7series_v2_4_qdr_phy_wr_control_io.v
  input [ADDR_WIDTH-1:0] wr_addr1;		// To u_qdr_phy_wr_control of mig_7series_v2_4_qdr_phy_wr_control_io.v
  input [BW_WIDTH*2-1:0] wr_bw_n0;		// To u_qdr_phy_wr_data of mig_7series_v2_4_qdr_phy_wr_data_io.v
  input [BW_WIDTH*2-1:0] wr_bw_n1;		// To u_qdr_phy_wr_data of mig_7series_v2_4_qdr_phy_wr_data_io.v
  input			wr_cmd0;		// To u_qdr_phy_wr_control of mig_7series_v2_4_qdr_phy_wr_control_io.v, ...
  input			wr_cmd1;		// To u_qdr_phy_wr_control of mig_7series_v2_4_qdr_phy_wr_control_io.v, ...
  input [DATA_WIDTH*2-1:0] wr_data0;		// To u_qdr_phy_wr_data of mig_7series_v2_4_qdr_phy_wr_data_io.v
  input [DATA_WIDTH*2-1:0] wr_data1;		// To u_qdr_phy_wr_data of mig_7series_v2_4_qdr_phy_wr_data_io.v
  // End of automatics
  /*AUTOOUTPUT*/
  // Beginning of automatic outputs (from unused autoinst outputs)
  output		cal_stage2_start;	// From u_qdr_phy_wr_init_sm of mig_7series_v2_4_qdr_phy_wr_init_sm.v
  output [71:0]		cmplx_rd_burst_bytes;	// From u_qdr_phy_cmplx_rdcal of mig_7series_v2_4_qdr_rld_phy_cmplx_rdcal.v
  output		cmplx_rd_data_valid;	// From u_qdr_phy_cmplx_rdcal of mig_7series_v2_4_qdr_rld_phy_cmplx_rdcal.v
  output		cmplx_rdcal_start;	// From u_qdr_phy_wr_init_sm of mig_7series_v2_4_qdr_phy_wr_init_sm.v
  output [ADDR_WIDTH*4-1:0] dbg_phy_addr;	// From u_qdr_phy_wr_control of mig_7series_v2_4_qdr_phy_wr_control_io.v
  output [1:0]		dbg_phy_rd_cmd_n;	// From u_qdr_phy_wr_control of mig_7series_v2_4_qdr_phy_wr_control_io.v
  output [1:0]		dbg_phy_wr_cmd_n;	// From u_qdr_phy_wr_control of mig_7series_v2_4_qdr_phy_wr_control_io.v
  output [DATA_WIDTH*4-1:0] dbg_phy_wr_data;	// From u_qdr_phy_wr_data of mig_7series_v2_4_qdr_phy_wr_data_io.v
  output [1023:0]	dbg_poc;		// From u_qdr_phy_poc of mig_7series_v2_4_poc_top.v
  output [255:0]	dbg_wr_init;		// From u_qdr_phy_wr_init_sm of mig_7series_v2_4_qdr_phy_wr_init_sm.v, ...
  output		edge_adv_cal_start;	// From u_qdr_phy_wr_init_sm of mig_7series_v2_4_qdr_phy_wr_init_sm.v
  output [1:0]		int_rd_cmd_n;		// From u_qdr_phy_wr_control of mig_7series_v2_4_qdr_phy_wr_control_io.v
  output [nCK_PER_CLK*2*ADDR_WIDTH-1:0] iob_addr;// From u_qdr_phy_wr_control of mig_7series_v2_4_qdr_phy_wr_control_io.v
  output [nCK_PER_CLK*2*BW_WIDTH-1:0] iob_bw;	// From u_qdr_phy_wr_data of mig_7series_v2_4_qdr_phy_wr_data_io.v
  output		iob_dll_off_n;		// From u_qdr_phy_wr_init_sm of mig_7series_v2_4_qdr_phy_wr_init_sm.v
  output [nCK_PER_CLK*2-1:0] iob_rd_n;		// From u_qdr_phy_wr_control of mig_7series_v2_4_qdr_phy_wr_control_io.v
  output [nCK_PER_CLK*2*DATA_WIDTH-1:0] iob_wdata;// From u_qdr_phy_wr_data of mig_7series_v2_4_qdr_phy_wr_data_io.v
  output [nCK_PER_CLK*2-1:0] iob_wr_n;		// From u_qdr_phy_wr_control of mig_7series_v2_4_qdr_phy_wr_control_io.v
  output		kill_rd_valid;		// From u_qdr_phy_wr_init_sm of mig_7series_v2_4_qdr_phy_wr_init_sm.v
  output		of_cmd_wr_en;		// From u_qdr_rld_phy_cntrl_init of mig_7series_v2_4_qdr_rld_phy_cntrl_init.v
  output		of_data_wr_en;		// From u_qdr_rld_phy_cntrl_init of mig_7series_v2_4_qdr_rld_phy_cntrl_init.v
  output [31:0]		phy_ctl_wd;		// From u_qdr_rld_phy_cntrl_init of mig_7series_v2_4_qdr_rld_phy_cntrl_init.v
  output		phy_ctl_wr;		// From u_qdr_rld_phy_cntrl_init of mig_7series_v2_4_qdr_rld_phy_cntrl_init.v
  output		po_cnt_dec;		// From u_qdr_phy_wr_po_init of mig_7series_v2_4_qdr_phy_wr_po_init.v
  output		po_cnt_inc;		// From u_qdr_phy_wr_po_init of mig_7series_v2_4_qdr_phy_wr_po_init.v
  output		po_dec_done;		// From u_qdr_phy_wr_po_init of mig_7series_v2_4_qdr_phy_wr_po_init.v
  output		po_inc_done;		// From u_qdr_phy_wr_po_init of mig_7series_v2_4_qdr_phy_wr_po_init.v
  output		poc_error;		// From u_qdr_phy_poc of mig_7series_v2_4_poc_top.v
  output		psen;			// From u_qdr_phy_poc of mig_7series_v2_4_poc_top.v
  output		psincdec;		// From u_qdr_phy_poc of mig_7series_v2_4_poc_top.v
  output [N_DATA_LANES-1:0] rdlvl_stg1_cal_bytes;// From u_qdr_phy_wr_init_sm of mig_7series_v2_4_qdr_phy_wr_init_sm.v
  output		rdlvl_stg1_fast;	// From u_qdr_phy_wr_init_sm of mig_7series_v2_4_qdr_phy_wr_init_sm.v
  output		rdlvl_stg1_start;	// From u_qdr_phy_wr_init_sm of mig_7series_v2_4_qdr_phy_wr_init_sm.v
  output		rst_stg1;		// From u_qdr_phy_wr_init_sm of mig_7series_v2_4_qdr_phy_wr_init_sm.v
  output		rst_stg2;		// From u_qdr_phy_wr_init_sm of mig_7series_v2_4_qdr_phy_wr_init_sm.v
  output		wrcal_addr_cntrl;	// From u_qdr_phy_po_cntlr of mig_7series_v2_4_qdr_phy_wr_po_cntlr.v
  output [1:0]		wrcal_byte_sel;		// From u_qdr_phy_po_cntlr of mig_7series_v2_4_qdr_phy_wr_po_cntlr.v
  output		wrcal_inc;		// From u_qdr_phy_po_cntlr of mig_7series_v2_4_qdr_phy_wr_po_cntlr.v
  output		wrcal_po_en;		// From u_qdr_phy_po_cntlr of mig_7series_v2_4_qdr_phy_wr_po_cntlr.v
  output		wrcal_stg3;		// From u_qdr_phy_po_cntlr of mig_7series_v2_4_qdr_phy_wr_po_cntlr.v
  // End of automatics

  /*AUTOWIRE*/
  // Beginning of automatic wires (for undeclared instantiated-module outputs)
  wire			K_is_at_center;		// From u_qdr_phy_po_adj of mig_7series_v2_4_qdr_phy_wr_po_adj.v
  wire			adj_done;		// From u_qdr_phy_po_adj of mig_7series_v2_4_qdr_phy_wr_po_adj.v
  wire [1:0]		byte_sel;		// From u_qdr_phy_po_adj of mig_7series_v2_4_qdr_phy_wr_po_adj.v
  wire [N_DATA_LANES*nCK_PER_CLK*18-1:0] cmplx_data;// From u_qdr_phy_cmplx_rdcal of mig_7series_v2_4_qdr_rld_phy_cmplx_rdcal.v
  wire			cmplx_pause;		// From u_qdr_phy_cmplx_rdcal of mig_7series_v2_4_qdr_rld_phy_cmplx_rdcal.v
  wire [BRAM_ADDR_WIDTH:0] cmplx_seq_addr;	// From u_qdr_phy_cmplx_rdcal of mig_7series_v2_4_qdr_rld_phy_cmplx_rdcal.v
  wire			cmplx_seq_done;		// From u_qdr_phy_cmplx_rdcal of mig_7series_v2_4_qdr_rld_phy_cmplx_rdcal.v
  wire			cmplx_seq_rst;		// From u_qdr_phy_wr_init_sm of mig_7series_v2_4_qdr_phy_wr_init_sm.v
  wire [3:0]		cmplx_victim_bit;	// From u_qdr_phy_wr_init_sm of mig_7series_v2_4_qdr_phy_wr_init_sm.v
  wire			cmplx_wr_done;		// From u_qdr_phy_wr_init_sm of mig_7series_v2_4_qdr_phy_wr_init_sm.v
  wire			inc;			// From u_qdr_phy_po_adj of mig_7series_v2_4_qdr_phy_wr_po_adj.v
  wire [ADDR_WIDTH-1:0]	init_rd_addr0;		// From u_qdr_phy_wr_init_sm of mig_7series_v2_4_qdr_phy_wr_init_sm.v
  wire [ADDR_WIDTH-1:0]	init_rd_addr1;		// From u_qdr_phy_wr_init_sm of mig_7series_v2_4_qdr_phy_wr_init_sm.v
  wire [1:0]		init_rd_cmd;		// From u_qdr_phy_wr_init_sm of mig_7series_v2_4_qdr_phy_wr_init_sm.v
  wire [ADDR_WIDTH-1:0]	init_wr_addr0;		// From u_qdr_phy_wr_init_sm of mig_7series_v2_4_qdr_phy_wr_init_sm.v
  wire [ADDR_WIDTH-1:0]	init_wr_addr1;		// From u_qdr_phy_wr_init_sm of mig_7series_v2_4_qdr_phy_wr_init_sm.v
  wire [1:0]		init_wr_cmd;		// From u_qdr_phy_wr_init_sm of mig_7series_v2_4_qdr_phy_wr_init_sm.v
  wire [DATA_WIDTH*2-1:0] init_wr_data0;	// From u_qdr_phy_wr_init_sm of mig_7series_v2_4_qdr_phy_wr_init_sm.v
  wire [DATA_WIDTH*2-1:0] init_wr_data1;	// From u_qdr_phy_wr_init_sm of mig_7series_v2_4_qdr_phy_wr_init_sm.v
  wire			kbyte_sel;		// From u_qdr_phy_po_adj of mig_7series_v2_4_qdr_phy_wr_po_adj.v
  wire			ktap_at_left_edge;	// From u_qdr_phy_po_adj of mig_7series_v2_4_qdr_phy_wr_po_adj.v
  wire			ktap_at_right_edge;	// From u_qdr_phy_po_adj of mig_7series_v2_4_qdr_phy_wr_po_adj.v
  wire [N_DATA_LANES-1:0] lanes_solid;		// From u_qdr_phy_wr_init_sm of mig_7series_v2_4_qdr_phy_wr_init_sm.v
  wire			mmcm_edge_detect_done;	// From u_qdr_phy_poc of mig_7series_v2_4_poc_top.v
  wire			mmcm_edge_detect_rdy;	// From u_qdr_phy_po_adj of mig_7series_v2_4_qdr_phy_wr_po_adj.v
  wire			mmcm_lbclk_edge_aligned;// From u_qdr_phy_poc of mig_7series_v2_4_poc_top.v
  wire			pd_out_selected;	// From u_qdr_phy_po_cntlr of mig_7series_v2_4_qdr_phy_wr_po_cntlr.v
  wire			po_adj_done;		// From u_qdr_phy_po_cntlr of mig_7series_v2_4_qdr_phy_wr_po_cntlr.v
  wire			po_en;			// From u_qdr_phy_po_adj of mig_7series_v2_4_qdr_phy_wr_po_adj.v
  wire			po_su_rdy;		// From u_qdr_phy_po_cntlr of mig_7series_v2_4_qdr_phy_wr_po_cntlr.v
  wire			poc_backup;		// From u_qdr_phy_poc of mig_7series_v2_4_poc_top.v
  wire			stg3;			// From u_qdr_phy_po_adj of mig_7series_v2_4_qdr_phy_wr_po_adj.v
  wire [5:0]		stg3_po_cntr;		// From u_qdr_phy_po_cntlr of mig_7series_v2_4_qdr_phy_wr_po_cntlr.v
  wire			wrcal_adj_done;		// From u_qdr_phy_po_cntlr of mig_7series_v2_4_qdr_phy_wr_po_cntlr.v
  wire			wrcal_adj_rdy;		// From u_qdr_phy_wr_init_sm of mig_7series_v2_4_qdr_phy_wr_init_sm.v
  // End of automatics

  
  input clk_mem; // unused
  output [5:0] ctl_lane_cnt;   // unused
  output rst_clk;  
  output io_fifo_rden_cal_done;
  output wrcal_en;
  wire [1:0] pd_out;
  output init_calib_complete;
  
  mig_7series_v2_4_qdr_phy_wr_control_io #
    (/*AUTOINSTPARAM*/
     // Parameters
     .ADDR_WIDTH			(ADDR_WIDTH),
     .BURST_LEN				(BURST_LEN),
     .TCQ				(TCQ),
     .nCK_PER_CLK			(nCK_PER_CLK))
  u_qdr_phy_wr_control 
    (/*AUTOINST*/
     // Outputs
     .dbg_phy_addr			(dbg_phy_addr[ADDR_WIDTH*4-1:0]),
     .dbg_phy_rd_cmd_n			(dbg_phy_rd_cmd_n[1:0]),
     .dbg_phy_wr_cmd_n			(dbg_phy_wr_cmd_n[1:0]),
     .int_rd_cmd_n			(int_rd_cmd_n[1:0]),
     .iob_addr				(iob_addr[nCK_PER_CLK*2*ADDR_WIDTH-1:0]),
     .iob_rd_n				(iob_rd_n[nCK_PER_CLK*2-1:0]),
     .iob_wr_n				(iob_wr_n[nCK_PER_CLK*2-1:0]),
     // Inputs
     .clk				(clk),
     .init_calib_complete		(init_calib_complete),
     .init_rd_addr0			(init_rd_addr0[ADDR_WIDTH-1:0]),
     .init_rd_addr1			(init_rd_addr1[ADDR_WIDTH-1:0]),
     .init_rd_cmd			(init_rd_cmd[1:0]),
     .init_wr_addr0			(init_wr_addr0[ADDR_WIDTH-1:0]),
     .init_wr_addr1			(init_wr_addr1[ADDR_WIDTH-1:0]),
     .init_wr_cmd			(init_wr_cmd[1:0]),
     .rd_addr0				(rd_addr0[ADDR_WIDTH-1:0]),
     .rd_addr1				(rd_addr1[ADDR_WIDTH-1:0]),
     .rd_cmd0				(rd_cmd0),
     .rd_cmd1				(rd_cmd1),
     .rst_clk				(rst_clk),
     .wr_addr0				(wr_addr0[ADDR_WIDTH-1:0]),
     .wr_addr1				(wr_addr1[ADDR_WIDTH-1:0]),
     .wr_cmd0				(wr_cmd0),
     .wr_cmd1				(wr_cmd1));

  mig_7series_v2_4_qdr_phy_wr_data_io #
    (/*AUTOINSTPARAM*/
     // Parameters
     .BURST_LEN				(BURST_LEN),
     .BW_WIDTH				(BW_WIDTH),
     .DATA_WIDTH			(DATA_WIDTH),
     .TCQ				(TCQ),
     .nCK_PER_CLK			(nCK_PER_CLK))
  u_qdr_phy_wr_data 
    (/*AUTOINST*/
     // Outputs
     .dbg_phy_wr_data			(dbg_phy_wr_data[DATA_WIDTH*4-1:0]),
     .iob_bw				(iob_bw[nCK_PER_CLK*2*BW_WIDTH-1:0]),
     .iob_wdata				(iob_wdata[nCK_PER_CLK*2*DATA_WIDTH-1:0]),
     // Inputs
     .clk				(clk),
     .init_calib_complete		(init_calib_complete),
     .init_wr_cmd			(init_wr_cmd[1:0]),
     .init_wr_data0			(init_wr_data0[DATA_WIDTH*2-1:0]),
     .init_wr_data1			(init_wr_data1[DATA_WIDTH*2-1:0]),
     .rst_clk				(rst_clk),
     .wr_bw_n0				(wr_bw_n0[BW_WIDTH*2-1:0]),
     .wr_bw_n1				(wr_bw_n1[BW_WIDTH*2-1:0]),
     .wr_cmd0				(wr_cmd0),
     .wr_cmd1				(wr_cmd1),
     .wr_data0				(wr_data0[DATA_WIDTH*2-1:0]),
     .wr_data1				(wr_data1[DATA_WIDTH*2-1:0]));

  /* mig_7series_v2_4_qdr_phy_wr_init_sm AUTO_TEMPLATE (
     .CK_WIDTH                          (NUM_DEVICES),
     .SKIP_STG1_SEEN_VAL                (),
     .WRCAL_HYSTERESIS                  (),) */
  
  mig_7series_v2_4_qdr_phy_wr_init_sm #
    (/*AUTOINSTPARAM*/
     // Parameters
     .ADDR_WIDTH			(ADDR_WIDTH),
     .BRAM_ADDR_WIDTH			(BRAM_ADDR_WIDTH),
     .BURST_LEN				(BURST_LEN),
     .BW_WIDTH				(BW_WIDTH),
     .BYTE_LANE_WITH_DK			(BYTE_LANE_WITH_DK),
     .CK_WIDTH				(NUM_DEVICES),		 // Templated
     .CLK_STABLE			(CLK_STABLE),
     .CMPLX_RDCAL_EN			(CMPLX_RDCAL_EN),
     .DATA_WIDTH			(DATA_WIDTH),
     .N_DATA_LANES			(N_DATA_LANES),
     .PO_ADJ_GAP			(PO_ADJ_GAP),
     .SKIP_STG1_SEEN_VAL		(),			 // Templated
     .TCQ				(TCQ),
     .WRCAL_DEFAULT			(WRCAL_DEFAULT),
     .WRCAL_HYSTERESIS			(),			 // Templated
     .WRCAL_PCT_SAMPS_SOLID		(WRCAL_PCT_SAMPS_SOLID),
     .WRCAL_SAMPLES			(WRCAL_SAMPLES),
     .nCK_PER_CLK			(nCK_PER_CLK))
  u_qdr_phy_wr_init_sm 
    (/*AUTOINST*/
     // Outputs
     .cal_stage2_start			(cal_stage2_start),
     .cmplx_rdcal_start			(cmplx_rdcal_start),
     .cmplx_seq_rst			(cmplx_seq_rst),
     .cmplx_victim_bit			(cmplx_victim_bit[3:0]),
     .cmplx_wr_done			(cmplx_wr_done),
     .dbg_wr_init			(dbg_wr_init[127:0]),
     .edge_adv_cal_start		(edge_adv_cal_start),
     .init_calib_complete		(init_calib_complete),
     .init_rd_addr0			(init_rd_addr0[ADDR_WIDTH-1:0]),
     .init_rd_addr1			(init_rd_addr1[ADDR_WIDTH-1:0]),
     .init_rd_cmd			(init_rd_cmd[1:0]),
     .init_wr_addr0			(init_wr_addr0[ADDR_WIDTH-1:0]),
     .init_wr_addr1			(init_wr_addr1[ADDR_WIDTH-1:0]),
     .init_wr_cmd			(init_wr_cmd[1:0]),
     .init_wr_data0			(init_wr_data0[DATA_WIDTH*2-1:0]),
     .init_wr_data1			(init_wr_data1[DATA_WIDTH*2-1:0]),
     .iob_dll_off_n			(iob_dll_off_n),
     .kill_rd_valid			(kill_rd_valid),
     .lanes_solid			(lanes_solid[N_DATA_LANES-1:0]),
     .rdlvl_stg1_cal_bytes		(rdlvl_stg1_cal_bytes[N_DATA_LANES-1:0]),
     .rdlvl_stg1_fast			(rdlvl_stg1_fast),
     .rdlvl_stg1_start			(rdlvl_stg1_start),
     .rst_clk				(rst_clk),
     .rst_stg1				(rst_stg1),
     .rst_stg2				(rst_stg2),
     .wrcal_adj_rdy			(wrcal_adj_rdy),
     // Inputs
     .K_is_at_center			(K_is_at_center),
     .clk				(clk),
     .cmplx_data			(cmplx_data[N_DATA_LANES*nCK_PER_CLK*2*9-1:0]),
     .cmplx_pause			(cmplx_pause),
     .cmplx_seq_addr			(cmplx_seq_addr[BRAM_ADDR_WIDTH:0]),
     .cmplx_seq_done			(cmplx_seq_done),
     .dbg_cmplx_wr_loop			(dbg_cmplx_wr_loop),
     .dbg_phy_init_rd_only		(dbg_phy_init_rd_only),
     .dbg_phy_init_wr_only		(dbg_phy_init_wr_only),
     .edge_adv_cal_done			(edge_adv_cal_done),
     .kbyte_sel				(kbyte_sel),
     .phase_valid			(phase_valid[N_DATA_LANES-1:0]),
     .po_delay_done			(po_delay_done),
     .rdlvl_stg1_done			(rdlvl_stg1_done),
     .rdlvl_valid			(rdlvl_valid),
     .read_cal_done			(read_cal_done),
     .rst				(rst),
     .wrcal_adj_done			(wrcal_adj_done));

  /* mig_7series_v2_4_qdr_rld_phy_cmplx_rdcal AUTO_TEMPLATE (
     .CONFIG_WL                         (2),
     .rst                               (rst_clk),) */
  mig_7series_v2_4_qdr_rld_phy_cmplx_rdcal #
    (/*AUTOINSTPARAM*/
     // Parameters
     .BRAM_ADDR_WIDTH			(BRAM_ADDR_WIDTH),
     .CMPLX_RDCAL_EN			(CMPLX_RDCAL_EN),
     .CONFIG_WL				(2),			 // Templated
     .MEM_TYPE				(MEM_TYPE),
     .N_DATA_LANES			(N_DATA_LANES),
     .TCQ				(TCQ),
     .nCK_PER_CLK			(nCK_PER_CLK))
  u_qdr_phy_cmplx_rdcal 
    (/*AUTOINST*/
     // Outputs
     .cmplx_data			(cmplx_data[N_DATA_LANES*nCK_PER_CLK*18-1:0]),
     .cmplx_pause			(cmplx_pause),
     .cmplx_rd_burst_bytes		(cmplx_rd_burst_bytes[71:0]),
     .cmplx_rd_data_valid		(cmplx_rd_data_valid),
     .cmplx_seq_addr			(cmplx_seq_addr[BRAM_ADDR_WIDTH:0]),
     .cmplx_seq_done			(cmplx_seq_done),
     // Inputs
     .clk				(clk),
     .cmplx_seq_rst			(cmplx_seq_rst),
     .cmplx_victim_bit			(cmplx_victim_bit[3:0]),
     .cmplx_wr_done			(cmplx_wr_done),
     .valid_latency			(valid_latency[4:0]));

  /* mig_7series_v2_4_qdr_phy_wr_po_adj AUTO_TEMPLATE (
     .STG3_MIN_VALID_EYE                (),
     .rst                               (rst_clk),) */
  mig_7series_v2_4_qdr_phy_wr_po_adj #
    (/*AUTOINSTPARAM*/
     // Parameters
     .BYTE_LANE_WITH_DK			(BYTE_LANE_WITH_DK),
     .NUM_DEVICES			(NUM_DEVICES),
     .N_DATA_LANES			(N_DATA_LANES),
     .SKIP_POC				(SKIP_POC),
     .STG3_MIN_VALID_EYE		(),			 // Templated
     .TCQ				(TCQ))
  u_qdr_phy_po_adj  
    (/*AUTOINST*/
     // Outputs
     .K_is_at_center			(K_is_at_center),
     .adj_done				(adj_done),
     .byte_sel				(byte_sel[1:0]),
     .dbg_wr_init			(dbg_wr_init[191:128]),
     .inc				(inc),
     .kbyte_sel				(kbyte_sel),
     .ktap_at_left_edge			(ktap_at_left_edge),
     .ktap_at_right_edge		(ktap_at_right_edge),
     .mmcm_edge_detect_rdy		(mmcm_edge_detect_rdy),
     .po_en				(po_en),
     .stg3				(stg3),
     // Inputs
     .clk				(clk),
     .dbg_K_left_shift_right		(dbg_K_left_shift_right[5:0]),
     .dbg_K_right_shift_left		(dbg_K_right_shift_left[5:0]),
     .lanes_solid			(lanes_solid[N_DATA_LANES-1:0]),
     .mmcm_edge_detect_done		(mmcm_edge_detect_done),
     .mmcm_lbclk_edge_aligned		(mmcm_lbclk_edge_aligned),
     .po_adj_done			(po_adj_done),
     .po_counter_read_val		(po_counter_read_val[8:0]),
     .po_su_rdy				(po_su_rdy),
     .poc_backup			(poc_backup),
     .rst				(rst_clk),		 // Templated
     .stg3_po_cntr			(stg3_po_cntr[5:0]));

  /* mig_7series_v2_4_qdr_phy_wr_po_cntlr AUTO_TEMPLATE (
     .PO_SETUP                          (3),
     .rst                               (rst_clk),) */
  
  mig_7series_v2_4_qdr_phy_wr_po_cntlr #
    (/*AUTOINSTPARAM*/
     // Parameters
     .NUM_DEVICES			(NUM_DEVICES),
     .PO_ADJ_GAP			(PO_ADJ_GAP),
     .PO_SETUP				(3),			 // Templated
     .TCQ				(TCQ))
  u_qdr_phy_po_cntlr 
    (/*AUTOINST*/
     // Outputs
     .dbg_wr_init			(dbg_wr_init[255:192]),
     .pd_out_selected			(pd_out_selected),
     .po_adj_done			(po_adj_done),
     .po_su_rdy				(po_su_rdy),
     .stg3_po_cntr			(stg3_po_cntr[5:0]),
     .wrcal_addr_cntrl			(wrcal_addr_cntrl),
     .wrcal_adj_done			(wrcal_adj_done),
     .wrcal_byte_sel			(wrcal_byte_sel[1:0]),
     .wrcal_en				(wrcal_en),
     .wrcal_inc				(wrcal_inc),
     .wrcal_po_en			(wrcal_po_en),
     .wrcal_stg3			(wrcal_stg3),
     // Inputs
     .adj_done				(adj_done),
     .byte_sel				(byte_sel[1:0]),
     .clk				(clk),
     .inc				(inc),
     .pd_out				(pd_out[1:0]),
     .po_counter_read_val		(po_counter_read_val[8:0]),
     .po_en				(po_en),
     .rst				(rst_clk),		 // Templated
     .stg3				(stg3),
     .wrcal_adj_rdy			(wrcal_adj_rdy));
    
  /* mig_7series_v2_4_qdr_rld_phy_cntrl_init AUTO_TEMPLATE (
     .MEM_TYPE                          ("QDR2"),
     .phy_ctl_data_offset               (6'b000000),
     .phy_ctl_cmd                       (3'b001),
     .rst                               (rst_clk),) */
  
  mig_7series_v2_4_qdr_rld_phy_cntrl_init #
    (/*AUTOINSTPARAM*/
     // Parameters
     .MEM_TYPE				("QDR2"),		 // Templated
     .PRE_FIFO				(PRE_FIFO),
     .TCQ				(TCQ)) 
  u_qdr_rld_phy_cntrl_init
    (/*AUTOINST*/
     // Outputs
     .io_fifo_rden_cal_done		(io_fifo_rden_cal_done),
     .of_cmd_wr_en			(of_cmd_wr_en),
     .of_data_wr_en			(of_data_wr_en),
     .phy_ctl_wd			(phy_ctl_wd[31:0]),
     .phy_ctl_wr			(phy_ctl_wr),
     // Inputs
     .clk				(clk),
     .of_ctl_full			(of_ctl_full),
     .of_data_full			(of_data_full),
     .phy_ctl_a_full			(phy_ctl_a_full),
     .phy_ctl_cmd			(3'b001),		 // Templated
     .phy_ctl_data_offset		(6'b000000),		 // Templated
     .phy_ctl_full			(phy_ctl_full),
     .phy_ctl_ready			(phy_ctl_ready),
     .rst				(rst_clk));		 // Templated

  
  mig_7series_v2_4_qdr_phy_wr_po_init #
    (/*AUTOINSTPARAM*/
     // Parameters
     .PO_ADJ_GAP			(PO_ADJ_GAP),
     .PO_COARSE_BYPASS			(PO_COARSE_BYPASS),
     .TCQ				(TCQ)) 
  u_qdr_phy_wr_po_init
    (/*AUTOINST*/
     // Outputs
     .po_cnt_dec			(po_cnt_dec),
     .po_cnt_inc			(po_cnt_inc),
     .po_dec_done			(po_dec_done),
     .po_inc_done			(po_inc_done),
     // Inputs
     .clk				(clk),
     .io_fifo_rden_cal_done		(io_fifo_rden_cal_done),
     .po_counter_read_val		(po_counter_read_val[8:0]),
     .rst_clk				(rst_clk));

 /* mig_7series_v2_4_poc_top AUTO_TEMPLATE (
     .CCENABLE                      (0),
     .LANE_CNT_WIDTH                (1),
     .PCT_SAMPS_SOLID               (POC_PCT_SAMPS_SOLID),
     .SAMPLES                       (POC_SAMPLES),
     .SCANFROMRIGHT                 (0),
     .lane                          (kbyte_sel),
     .ninety_offsets                (2'b0),
     .pd_out                        (pd_out_selected),
     .rise_lead_right               (),
     .rise_trail_right              (),
     .rst                           (rst_clk),
     .use_noise_window              (1'b0),) */

  localparam TAPCNTRWIDTH               = clogb2(TAPSPERKCLK);
  // POC_SAMPLES counts in whole numbers, ie 0 is one sample.
  localparam SAMPCNTRWIDTH              = clogb2(POC_SAMPLES+1);
  
  mig_7series_v2_4_poc_top #
    (/*AUTOINSTPARAM*/
     // Parameters
     .CCENABLE				(0),			 // Templated
     .LANE_CNT_WIDTH			(1),			 // Templated
     .MMCM_SAMP_WAIT			(MMCM_SAMP_WAIT),
     .PCT_SAMPS_SOLID			(POC_PCT_SAMPS_SOLID),	 // Templated
     .POC_USE_METASTABLE_SAMP		(POC_USE_METASTABLE_SAMP),
     .SAMPCNTRWIDTH			(SAMPCNTRWIDTH),
     .SAMPLES				(POC_SAMPLES),		 // Templated
     .SCANFROMRIGHT			(0),			 // Templated
     .TAPCNTRWIDTH			(TAPCNTRWIDTH),
     .TAPSPERKCLK			(TAPSPERKCLK),
     .TCQ				(TCQ)) 
  u_qdr_phy_poc
    (/*AUTOINST*/
     // Outputs
     .dbg_poc				(dbg_poc[1023:0]),
     .mmcm_edge_detect_done		(mmcm_edge_detect_done),
     .mmcm_lbclk_edge_aligned		(mmcm_lbclk_edge_aligned),
     .poc_backup			(poc_backup),
     .poc_error				(poc_error),
     .psen				(psen),
     .psincdec				(psincdec),
     .rise_lead_right			(),			 // Templated
     .rise_trail_right			(),			 // Templated
     // Inputs
     .clk				(clk),
     .ktap_at_left_edge			(ktap_at_left_edge),
     .ktap_at_right_edge		(ktap_at_right_edge),
     .lane				(kbyte_sel),		 // Templated
     .mmcm_edge_detect_rdy		(mmcm_edge_detect_rdy),
     .ninety_offsets			(2'b0),			 // Templated
     .pd_out				(pd_out_selected),	 // Templated
     .poc_sample_pd			(poc_sample_pd),
     .psdone				(psdone),
     .rst				(rst_clk),		 // Templated
     .use_noise_window			(1'b0));			 // Templated
  
  /* mig_7series_v2_4_poc_pd AUTO_TEMPLATE (
    .SIM_CAL_OPTION                    (PD_SIM_CAL_OPTION),
    .kclk                              (lb_clk[@]),
    .mmcm_ps_clk                       (mmcm_fshift_clk),
    .pd_out                            (pd_out[@]),) */
  
  mig_7series_v2_4_poc_pd #
    (/*AUTOINSTPARAM*/
     // Parameters
     .POC_USE_METASTABLE_SAMP		(POC_USE_METASTABLE_SAMP),
     .SIM_CAL_OPTION			(PD_SIM_CAL_OPTION),	 // Templated
     .TCQ				(TCQ)) 
  u_qdr_phy_poc_pd0
    (/*AUTOINST*/
     // Outputs
     .pd_out				(pd_out[0]),		 // Templated
     // Inputs
     .clk				(clk),
     .iddr_rst				(iddr_rst),
     .kclk				(lb_clk[0]),		 // Templated
     .mmcm_ps_clk			(mmcm_fshift_clk));	 // Templated

  mig_7series_v2_4_poc_pd #
    (/*AUTOINSTPARAM*/
     // Parameters
     .POC_USE_METASTABLE_SAMP		(POC_USE_METASTABLE_SAMP),
     .SIM_CAL_OPTION			(PD_SIM_CAL_OPTION),	 // Templated
     .TCQ				(TCQ)) 
  u_qdr_phy_poc_pd1
    (/*AUTOINST*/
     // Outputs
     .pd_out				(pd_out[1]),		 // Templated
     // Inputs
     .clk				(clk),
     .iddr_rst				(iddr_rst),
     .kclk				(lb_clk[1]),		 // Templated
     .mmcm_ps_clk			(mmcm_fshift_clk));	 // Templated
          

endmodule // mig_7series_v2_4_qdr_phy_wr_top

// Local Variables:
// verilog-library-directories:("." "../../../poc_impl/v2_4/phy")
// verilog-library-extensions:(".v")
// End:
