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
// by a third party) even if such damage  or loss was
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
//  /   /         Filename           : qdr_rld_phy_read_top.v
// /___/   /\     Date Last Modified : $Date: 2011/06/02 08:36:30 $
// \   \  /  \    Date Created       : Nov 17, 2008
//  \___\/\___\
//
//Device: 7 Series
//Design: QDRII+ SRAM / RLDRAM II SDRAM
//
//Purpose:
//  This module
//  1. Instantiates all the read path submodules
//
//Revision History:	9/14/2012 - Fixed CR 678451.
//Revision History:	12/10/2012  -Improved CQ_CQB capturing clock scheme.  
//
////////////////////////////////////////////////////////////////////////////////
`timescale 1ps/1ps

module mig_7series_v2_4_qdr_rld_phy_read_top #
(
  parameter BURST_LEN           = 4,              // 4 = Burst Length 4, 2 = Burst Length 2
  parameter DATA_WIDTH          = 72,             // Total data width across all memories
  parameter BW_WIDTH            = 8,             //Byte Write Width
  parameter N_DATA_LANES        = 4,
  parameter FIXED_LATENCY_MODE  = 0,              // 0 = minimum latency mode, 1 = fixed latency mode
  parameter PHY_LATENCY         = 16,             // Indicates the desired latency for fixed latency mode
  parameter CLK_PERIOD          = 2500,           // Memory clock period in ps
  parameter RD_DATA_RISE_FALL   = "FALSE",      //Parameter to control how we present read data back to user
                                                // {rise, fall}, TRUE case
                                                // {fall, rise}, FALSE case
  parameter PI_PHY_WAIT		= 15,
  parameter PI_E2E_WAIT		= 4,
  parameter PI_SU_WAIT		= 8,
  parameter RDLVL_CMPLX_SEQ_LENGTH = 157,
  parameter RDLVL_LOW_RES_MODE  = "OFF",
  parameter MEM_TYPE            = "QDR2PLUS",     // Memory Type (QDR2PLUS, QDR2)
  parameter RDLVL_SAMPS         = 50,
  parameter CQ_BITS             = 1,              //clog2(NUM_BYTE_LANES - 1)   
  parameter Q_BITS              = 7,              //clog2(DATA_WIDTH - 1) 
  parameter nCK_PER_CLK         = 2,
  parameter REFCLK_FREQ         = 200.0, 
  parameter SIM_BYPASS_PI_CENTER = 31,
  parameter SIM_BYPASS_IDELAY   = 10,
  parameter SIM_BYPASS_INIT_CAL = "OFF",
  parameter TCQ                 = 100,            // Register delay
  parameter CENTER_COMP_MODE    = "OFF",
  parameter CMPLX_RDCAL_EN         = "FALSE"
)
(
   // System Signals
   input                                  clk,              // main system half freq clk
   input                                  rst_stg1,
   input                                  rst_stg2,
   input                                  rst_wr_clk, 
   input                                  if_empty,
   input       [nCK_PER_CLK*DATA_WIDTH-1:0] iserdes_rd,   // ISERDES output - rise data
   input       [nCK_PER_CLK*DATA_WIDTH-1:0] iserdes_fd,   // ISERDES output - fall data
   output wire                            if_rden,
  
   // Stage 1 calibration inputs/outputs
   input   [5:0]                           pi_counter_read_val,
   output wire                             pi_en_stg2_f,
   output wire                             pi_stg2_f_incdec,
   output wire                             pi_stg2_load,
   output wire [5:0]                       pi_stg2_reg_l,
   output wire [CQ_BITS-1:0]               pi_stg2_rdlvl_cnt,
   // Phaser OUT calibration signals - to control CQ# PHASER delay
   input [8:0]                             po_counter_read_val,
   
   output wire                             po_en_stg2_f,
   output wire                             po_stg2_f_incdec,
   output wire                             po_stg2_load,
   output wire [5:0]                       po_stg2_reg_l,
   output wire [CQ_BITS-1:0]               po_stg2_rdlvl_cnt, 
   output wire                             pi_edge_adv,
   output wire [2:0]                       byte_cnt,
   
   // Only output if Per-bit de-skew enabled
   output wire [5*DATA_WIDTH-1:0]          dlyval_dq,
   

   // User Interface
   output wire                                read_cal_done,   // Read calibration done
   output wire [2*nCK_PER_CLK*DATA_WIDTH-1:0] rd_data,         // user read data
   output wire [nCK_PER_CLK-1:0]              rd_valid,        // user read data valid
                                       
   // Write Path Interface                
   input                                  rdlvl_stg1_start,
   input [N_DATA_LANES-1:0]	          rdlvl_stg1_cal_bytes,
   input			          rdlvl_stg1_fast,
   output wire                            rdlvl_stg1_done,
   input                                  edge_adv_cal_start,
   input                                  cal_stage2_start,

   input                                  cmplx_rdcal_start,
   input                                  cmplx_rd_data_valid,
   input [71:0]                           cmplx_rd_burst_bytes,
   input                                  kill_rd_valid,
  
   output wire                            edge_adv_cal_done ,
   input  wire  [nCK_PER_CLK-1:0]         int_rd_cmd_n,     // internal rd cmd
   output wire  [N_DATA_LANES-1:0]        phase_valid,
   output wire                            error_adj_latency,  // stage 2 cal latency adjustment error
   output [4:0]                           valid_latency,
   output                                 rdlvl_valid,

 //ChipScope Debug Signals
  output wire [1023:0]                    dbg_rd_stage1_cal,      // stage 1 cal debug
  output wire [127:0]                     dbg_stage2_cal,         // stage 2 cal debug
  output wire [4:0]                       dbg_valid_lat,          // latency of the system
  input                                   dbg_SM_en,
  input [CQ_BITS-1:0]                     dbg_byte_sel,
  output wire [31:0]                      dbg_rdphy_top,
  output wire                             dbg_next_byte,
  output wire [nCK_PER_CLK*DATA_WIDTH-1:0]dbg_align_rd,
  output wire [nCK_PER_CLK*DATA_WIDTH-1:0]dbg_align_fd,
 
  output wire [N_DATA_LANES-1:0]           dbg_inc_latency,        // increase latency for dcb
  output wire [N_DATA_LANES-1:0]           dbg_error_max_latency,  // stage 2 cal max latency error
  input dbg_cmplx_rd_loop,
  input [2:0] dbg_cmplx_rd_lane
 
);

  // Fixup width mismatch.
  wire [3:0] lcl_dbg_byte_sel;

  generate if (CQ_BITS>=4) begin : cq_ge_four
    assign lcl_dbg_byte_sel = dbg_byte_sel[3:0];
  end
  else begin : cq_lt_four
    assign lcl_dbg_byte_sel = {{4-CQ_BITS{1'b0}}, dbg_byte_sel};
  end endgenerate

  localparam integer BYTE_LANE_WIDTH = 9;

  localparam DQS_WIDTH = DATA_WIDTH/9;
  localparam DQ_WIDTH = DATA_WIDTH;
  
 
  wire [nCK_PER_CLK*DATA_WIDTH-1:0]       rise_data;
  wire [nCK_PER_CLK*DATA_WIDTH-1:0]       fall_data;
  wire [N_DATA_LANES-1 :0]                inc_latency;
                                          
  wire  [6*N_DATA_LANES-1:0]              dbg_cpt_first_edge_cnt;
  wire  [6*N_DATA_LANES-1:0]              dbg_cpt_second_edge_cnt;
  wire                                    dbg_idel_up_all;
  wire                                    dbg_idel_down_all;
  wire                                    dbg_idel_up_cpt;
  wire                                    dbg_idel_down_cpt;
  wire                                    dbg_sel_all_idel_cpt;
  wire  [255:0]                           dbg_phy_rdlvl; 
  wire [N_DATA_LANES-1:0]                 error_max_latency;
  wire [2*nCK_PER_CLK*DATA_WIDTH-1:0]     iserdes_rd_data;
  wire                                    rdlvl_pi_en_stg2_f;
  wire                                    rdlvl_pi_stg2_f_incdec;
  wire                                    rdlvl_po_en_stg2_f;
  wire                                    rdlvl_po_stg2_f_incdec;
  wire [CQ_BITS-1:0]                      rdlvl_pi_stg2_cnt;
  wire [nCK_PER_CLK*DATA_WIDTH-1:0]       iserdes_rd_byte;
  wire [nCK_PER_CLK*DATA_WIDTH-1:0]       iserdes_fd_byte;
  wire [nCK_PER_CLK*DATA_WIDTH-1:0]       rise_data_byte;
  wire [nCK_PER_CLK*DATA_WIDTH-1:0]       fall_data_byte;
  wire [N_DATA_LANES-1:0]                 bitslip;
  
  reg                                     if_empty_r;
  reg                                     if_empty_2r;

  wire max_lat_done_r;

  // iserdes output data
  //assign iserdes_rd_data     = {iserdes_fd1, iserdes_rd1, iserdes_fd0, iserdes_rd0};
  generate
    if (nCK_PER_CLK == 4) begin: iserdes_rd_data_div4
	  assign iserdes_rd_data = {iserdes_fd[4*DATA_WIDTH-1:3*DATA_WIDTH], 
	                            iserdes_rd[4*DATA_WIDTH-1:3*DATA_WIDTH],
								iserdes_fd[3*DATA_WIDTH-1:2*DATA_WIDTH], 
	                            iserdes_rd[3*DATA_WIDTH-1:2*DATA_WIDTH],
	                            iserdes_fd[2*DATA_WIDTH-1:1*DATA_WIDTH], 
	                            iserdes_rd[2*DATA_WIDTH-1:1*DATA_WIDTH],
	                            iserdes_fd[DATA_WIDTH-1:0], 
								iserdes_rd[DATA_WIDTH-1:0]};
	  // read data to backend (UI)
	  assign rd_data         = (RD_DATA_RISE_FALL == "TRUE") ? 
	                           {rise_data[4*DATA_WIDTH-1:3*DATA_WIDTH], 
	                            fall_data[4*DATA_WIDTH-1:3*DATA_WIDTH],
								rise_data[3*DATA_WIDTH-1:2*DATA_WIDTH], 
	                            fall_data[3*DATA_WIDTH-1:2*DATA_WIDTH],
								rise_data[2*DATA_WIDTH-1:1*DATA_WIDTH], 
	                            fall_data[2*DATA_WIDTH-1:1*DATA_WIDTH],
								rise_data[DATA_WIDTH-1:0], 
	                            fall_data[DATA_WIDTH-1:0]} :
							   {fall_data[4*DATA_WIDTH-1:3*DATA_WIDTH], 
	                            rise_data[4*DATA_WIDTH-1:3*DATA_WIDTH],
								fall_data[3*DATA_WIDTH-1:2*DATA_WIDTH], 
	                            rise_data[3*DATA_WIDTH-1:2*DATA_WIDTH],
								fall_data[2*DATA_WIDTH-1:1*DATA_WIDTH], 
	                            rise_data[2*DATA_WIDTH-1:1*DATA_WIDTH],
								fall_data[DATA_WIDTH-1:0], 
	                            rise_data[DATA_WIDTH-1:0]};
    end else begin: iserdes_rd_data_div2
      assign iserdes_rd_data = {iserdes_fd[2*DATA_WIDTH-1:DATA_WIDTH], 
	                            iserdes_rd[2*DATA_WIDTH-1:DATA_WIDTH],
	                            iserdes_fd[DATA_WIDTH-1:0], 
								iserdes_rd[DATA_WIDTH-1:0]};
	  // read data to backend (UI)
	  assign rd_data         = (RD_DATA_RISE_FALL == "TRUE") ? 
	                           {rise_data[2*DATA_WIDTH-1:1*DATA_WIDTH], 
	                            fall_data[2*DATA_WIDTH-1:1*DATA_WIDTH],
								rise_data[DATA_WIDTH-1:0], 
	                            fall_data[DATA_WIDTH-1:0]} :
							   {fall_data[2*DATA_WIDTH-1:1*DATA_WIDTH], 
	                            rise_data[2*DATA_WIDTH-1:1*DATA_WIDTH],
								fall_data[DATA_WIDTH-1:0], 
	                            rise_data[DATA_WIDTH-1:0]};
    end
  endgenerate
    
  //debug signals
  assign dbg_align_rd       = rise_data;
  assign dbg_align_fd       = fall_data;
  assign dbg_next_byte      = 'b0;
  assign dbg_rdphy_top      = 'b0;
                                        
  assign po_en_stg2_f     = 1'b0;
  assign po_stg2_f_incdec = 1'b0;


  /*AUTOWIRE*/
  // Beginning of automatic wires (for undeclared instantiated-module outputs)
  wire [5:0]		largest_left_edge;	// From u_qdr_rld_phy_rdlvl of mig_7series_v2_4_qdr_rld_phy_rdlvl.v
  wire [5:0]		mem_out_dec;		// From u_qdr_rld_phy_pi_comp_rom of mig_7series_v2_4_qdr_rld_phy_pi_comp_rom.v
  wire [DQS_WIDTH-1:0]	rdlvl_scan_valid;	// From u_qdr_rld_phy_rdlvl of mig_7series_v2_4_qdr_rld_phy_rdlvl.v
  wire [5:0]		smallest_right_edge;	// From u_qdr_rld_phy_rdlvl of mig_7series_v2_4_qdr_rld_phy_rdlvl.v
  // End of automatics
  
  // Instantiate valid generator logic that retimes the valids for the out
  // going data.

  /*mig_7series_v2_4_qdr_rld_phy_read_vld_gen AUTO_TEMPLATE (
   .rst_clk                             (rst_stg2),
   .cal_done                            (read_cal_done),
   .data_valid                          (rd_valid),)*/
   
  mig_7series_v2_4_qdr_rld_phy_read_vld_gen #
    (/*AUTOINSTPARAM*/
     // Parameters
     .BURST_LEN				(BURST_LEN),
     .TCQ				(TCQ),
     .nCK_PER_CLK			(nCK_PER_CLK)) 
  u_qdr_rld_phy_read_vld_gen
    (/*AUTOINST*/
     // Outputs
     .data_valid			(rd_valid),		 // Templated
     .dbg_valid_lat			(dbg_valid_lat[4:0]),
     // Inputs
     .cal_done				(read_cal_done),	 // Templated
     .clk				(clk),
     .int_rd_cmd_n			(int_rd_cmd_n[nCK_PER_CLK-1:0]),
     .kill_rd_valid			(kill_rd_valid),
     .rst_clk				(rst_stg2),		 // Templated
     .valid_latency			(valid_latency[4:0]));
  
  mig_7series_v2_4_qdr_rld_phy_rdlvl #
    (/*AUTOINSTPARAM*/
     // Parameters
     .CENTER_COMP_MODE			(CENTER_COMP_MODE),      // Templated
     .CLK_PERIOD			(CLK_PERIOD),
     .CMPLX_RDCAL_EN			(CMPLX_RDCAL_EN),
     .CMPLX_SAMPS			(RDLVL_SAMPS),		 // Templated
     .CQ_BITS				(CQ_BITS),
     .DQS_WIDTH				(DQS_WIDTH),
     .DQ_WIDTH				(DQ_WIDTH),
     .DRAM_WIDTH			(BYTE_LANE_WIDTH),	 // Templated
     .PI_ADJ_VAL			(),			 // Templated
     .PI_E2E_WAIT			(PI_E2E_WAIT),
     .PI_PHY_WAIT			(PI_PHY_WAIT),
     .PI_SU_WAIT			(PI_SU_WAIT),
     .RD_DATA_RISE_FALL                 (RD_DATA_RISE_FALL),
     .RDLVL_CMPLX_MIN_VALID_EYE_PCT	(),			 // Templated
     .RDLVL_CMPLX_SEQ_LENGTH		(RDLVL_CMPLX_SEQ_LENGTH),
     .RDLVL_LOW_RES_MODE		(RDLVL_LOW_RES_MODE),
     .RDLVL_PCT_SAMPS_SOLID		(),			 // Templated
     .RDLVL_SIMP_MIN_VALID_EYE_PCT	(),			 // Templated
     .REFCLK_FREQ			(REFCLK_FREQ),
     .SIMP_SAMPS			(RDLVL_SAMPS),		 // Templated
     .SIM_BYPASS_IDELAY			(SIM_BYPASS_IDELAY),
     .SIM_BYPASS_INIT_CAL		(SIM_BYPASS_INIT_CAL),
     .SIM_BYPASS_PI_CENTER		(SIM_BYPASS_PI_CENTER),
     .TCQ				(TCQ),
     .nCK_PER_CLK			(nCK_PER_CLK))
  u_qdr_rld_phy_rdlvl
    (/*AUTOINST*/
     // Outputs
     .dbg_rd_stage1_cal			(dbg_rd_stage1_cal[1023:0]),
     .dlyval_dq				(dlyval_dq[5*DQ_WIDTH-1:0]),
     .largest_left_edge			(largest_left_edge[5:0]),
     .pi_stg2_load			(pi_stg2_load),
     .pi_stg2_reg_l			(pi_stg2_reg_l[5:0]),
     .rdlvl_pi_en_stg2_f		(pi_en_stg2_f),		 // Templated
     .rdlvl_pi_stg2_cnt			(pi_stg2_rdlvl_cnt),	 // Templated
     .rdlvl_pi_stg2_f_incdec		(pi_stg2_f_incdec),	 // Templated
     .rdlvl_scan_valid			(rdlvl_scan_valid[DQS_WIDTH-1:0]),
     .rdlvl_stg1_done			(rdlvl_stg1_done),
     .rdlvl_valid			(rdlvl_valid),
     .smallest_right_edge		(smallest_right_edge[5:0]),
     // Inputs
     .clk				(clk),
     .cmplx_rd_burst_bytes		(cmplx_rd_burst_bytes[71:0]),
     .cmplx_rd_data_valid		(cmplx_rd_data_valid),
     .cmplx_rdcal_start			(cmplx_rdcal_start),
     .dbg_cmplx_rd_lane			(dbg_cmplx_rd_lane[2:0]),
     .dbg_cmplx_rd_loop			(dbg_cmplx_rd_loop),
     .iserdes_rd_data			(iserdes_rd_data[2*nCK_PER_CLK*DQ_WIDTH-1:0]),
     .mem_out_dec			(mem_out_dec[5:0]),
     .pi_counter_read_val		(pi_counter_read_val[5:0]),
     .rd_data				(rd_data[2*nCK_PER_CLK*DQ_WIDTH-1:0]),
     .rdlvl_stg1_cal_bytes		(rdlvl_stg1_cal_bytes[DQS_WIDTH-1:0]),
     .rdlvl_stg1_fast			(rdlvl_stg1_fast),
     .rdlvl_stg1_start			(rdlvl_stg1_start),
     .rst_stg1				(rst_stg1),
     .rst_wr_clk			(rst_wr_clk));

  mig_7series_v2_4_qdr_rld_phy_pi_comp_rom #
    (/*AUTOINSTPARAM*/
     // Parameters
     .TCQ				(TCQ))
  u_qdr_rld_phy_pi_comp_rom
    (/*AUTOINST*/
     // Outputs
     .mem_out_dec			(mem_out_dec[5:0]),
     // Inputs
     .largest_left_edge			(largest_left_edge[5:0]),
     .smallest_right_edge		(smallest_right_edge[5:0]));

  // Instantiate the stage 2 calibration logic which resolves latencies in the
  // system and calibrates the valids.

  /*mig_7series_v2_4_qdr_rld_phy_read_stage2_cal AUTO_TEMPLATE (
   .rst_clk                             (rst_stg2),
   .iserdes_rd                          (rise_data),
   .iserdes_fd                          (fall_data),
   .cal_done                            (read_cal_done),
   .dbg_byte_sel                        (lcl_dbg_byte_sel),) */
   
  mig_7series_v2_4_qdr_rld_phy_read_stage2_cal #
    (/*AUTOINSTPARAM*/
     // Parameters
     .BURST_LEN				(BURST_LEN),
     .BW_WIDTH				(BW_WIDTH),
     .BYTE_LANE_WIDTH			(BYTE_LANE_WIDTH),
     .DATA_WIDTH			(DATA_WIDTH),
     .FIXED_LATENCY_MODE		(FIXED_LATENCY_MODE),
     .MEM_TYPE				(MEM_TYPE),
     .N_DATA_LANES			(N_DATA_LANES),
     .PHY_LATENCY			(PHY_LATENCY),
     .TCQ				(TCQ),
     .nCK_PER_CLK			(nCK_PER_CLK)) 
   u_qdr_rld_phy_read_stage2_cal
     (/*AUTOINST*/
      // Outputs
      .bitslip				(bitslip[N_DATA_LANES-1:0]),
      .byte_cnt				(byte_cnt[2:0]),
      .cal_done				(read_cal_done),	 // Templated
      .dbg_stage2_cal			(dbg_stage2_cal[127:0]),
      .edge_adv_cal_done		(edge_adv_cal_done),
      .error_adj_latency		(error_adj_latency),
      .error_max_latency		(error_max_latency[N_DATA_LANES-1:0]),
      .inc_latency			(inc_latency[N_DATA_LANES-1:0]),
      .max_lat_done_r			(max_lat_done_r),
      .phase_valid			(phase_valid[N_DATA_LANES-1:0]),
      .pi_edge_adv			(pi_edge_adv),
      .valid_latency			(valid_latency[4:0]),
      // Inputs
      .cal_stage2_start			(cal_stage2_start),
      .clk				(clk),
      .dbg_byte_sel			(lcl_dbg_byte_sel),	 // Templated
      .edge_adv_cal_start		(edge_adv_cal_start),
      .int_rd_cmd_n			(int_rd_cmd_n[nCK_PER_CLK-1:0]),
      .iserdes_fd			(fall_data),		 // Templated
      .iserdes_rd			(rise_data),		 // Templated
      .rdlvl_scan_valid			(rdlvl_scan_valid[N_DATA_LANES-1:0]),
      .rst_clk				(rst_stg2));		 // Templated
  
  
 // adjust latency in fixed latency mode or to align data bytes
 genvar nd_i;
  generate
    for (nd_i=0; nd_i < N_DATA_LANES; nd_i=nd_i+1) begin : nd_io_inst
	
	  //break up data into chunks per byte
	  if (nCK_PER_CLK == 4) begin: nd_io_inst_div4
	    assign iserdes_rd_byte[nd_i*4*BYTE_LANE_WIDTH+:4*BYTE_LANE_WIDTH] = 
		   {iserdes_rd[(nd_i*BYTE_LANE_WIDTH)+(3*DATA_WIDTH)+:BYTE_LANE_WIDTH],
		    iserdes_rd[(nd_i*BYTE_LANE_WIDTH)+(2*DATA_WIDTH)+:BYTE_LANE_WIDTH],
		    iserdes_rd[(nd_i*BYTE_LANE_WIDTH)+(1*DATA_WIDTH)+:BYTE_LANE_WIDTH],
		    iserdes_rd[nd_i*BYTE_LANE_WIDTH+:BYTE_LANE_WIDTH]};
	    assign iserdes_fd_byte[nd_i*4*BYTE_LANE_WIDTH+:4*BYTE_LANE_WIDTH] = 
		   {iserdes_fd[(nd_i*BYTE_LANE_WIDTH)+(3*DATA_WIDTH)+:BYTE_LANE_WIDTH],
		    iserdes_fd[(nd_i*BYTE_LANE_WIDTH)+(2*DATA_WIDTH)+:BYTE_LANE_WIDTH],
		    iserdes_fd[(nd_i*BYTE_LANE_WIDTH)+(1*DATA_WIDTH)+:BYTE_LANE_WIDTH],
		    iserdes_fd[nd_i*BYTE_LANE_WIDTH+:BYTE_LANE_WIDTH]};
		
		assign rise_data[nd_i*BYTE_LANE_WIDTH+:BYTE_LANE_WIDTH] = 
		    rise_data_byte[nd_i*4*BYTE_LANE_WIDTH+:BYTE_LANE_WIDTH];
		assign rise_data[nd_i*BYTE_LANE_WIDTH+(1*DATA_WIDTH)+:BYTE_LANE_WIDTH] = 
		    rise_data_byte[nd_i*4*BYTE_LANE_WIDTH+(1*BYTE_LANE_WIDTH)+:BYTE_LANE_WIDTH];
		assign rise_data[nd_i*BYTE_LANE_WIDTH+(2*DATA_WIDTH)+:BYTE_LANE_WIDTH] = 
		    rise_data_byte[nd_i*4*BYTE_LANE_WIDTH+(2*BYTE_LANE_WIDTH)+:BYTE_LANE_WIDTH];
		assign rise_data[nd_i*BYTE_LANE_WIDTH+(3*DATA_WIDTH)+:BYTE_LANE_WIDTH] = 
		    rise_data_byte[nd_i*4*BYTE_LANE_WIDTH+(3*BYTE_LANE_WIDTH)+:BYTE_LANE_WIDTH];
			
	    assign fall_data[nd_i*BYTE_LANE_WIDTH+:BYTE_LANE_WIDTH] = 
		    fall_data_byte[nd_i*4*BYTE_LANE_WIDTH+:BYTE_LANE_WIDTH];
		assign fall_data[nd_i*BYTE_LANE_WIDTH+(1*DATA_WIDTH)+:BYTE_LANE_WIDTH] = 
		    fall_data_byte[nd_i*4*BYTE_LANE_WIDTH+(1*BYTE_LANE_WIDTH)+:BYTE_LANE_WIDTH];
		assign fall_data[nd_i*BYTE_LANE_WIDTH+(2*DATA_WIDTH)+:BYTE_LANE_WIDTH] = 
		    fall_data_byte[nd_i*4*BYTE_LANE_WIDTH+(2*BYTE_LANE_WIDTH)+:BYTE_LANE_WIDTH];
		assign fall_data[nd_i*BYTE_LANE_WIDTH+(3*DATA_WIDTH)+:BYTE_LANE_WIDTH] = 
		    fall_data_byte[nd_i*4*BYTE_LANE_WIDTH+(3*BYTE_LANE_WIDTH)+:BYTE_LANE_WIDTH];
	  end else begin: nd_io_inst_div2
	    assign iserdes_rd_byte[nd_i*2*BYTE_LANE_WIDTH+:2*BYTE_LANE_WIDTH] = 
		   {iserdes_rd[(nd_i*BYTE_LANE_WIDTH)+DATA_WIDTH+:BYTE_LANE_WIDTH],
		    iserdes_rd[nd_i*BYTE_LANE_WIDTH+:BYTE_LANE_WIDTH]};
	    assign iserdes_fd_byte[nd_i*2*BYTE_LANE_WIDTH+:2*BYTE_LANE_WIDTH] = 
		   {iserdes_fd[(nd_i*BYTE_LANE_WIDTH)+DATA_WIDTH+:BYTE_LANE_WIDTH],
		    iserdes_fd[nd_i*BYTE_LANE_WIDTH+:BYTE_LANE_WIDTH]};
			
	    assign rise_data[nd_i*BYTE_LANE_WIDTH+:BYTE_LANE_WIDTH] = 
		    rise_data_byte[nd_i*2*BYTE_LANE_WIDTH+:BYTE_LANE_WIDTH];
		assign rise_data[nd_i*BYTE_LANE_WIDTH+DATA_WIDTH+:BYTE_LANE_WIDTH] = 
		    rise_data_byte[nd_i*2*BYTE_LANE_WIDTH+BYTE_LANE_WIDTH+:BYTE_LANE_WIDTH];
			
	    assign fall_data[nd_i*BYTE_LANE_WIDTH+:BYTE_LANE_WIDTH] = 
		    fall_data_byte[nd_i*2*BYTE_LANE_WIDTH+:BYTE_LANE_WIDTH];
		assign fall_data[nd_i*BYTE_LANE_WIDTH+DATA_WIDTH+:BYTE_LANE_WIDTH] = 
		    fall_data_byte[nd_i*2*BYTE_LANE_WIDTH+BYTE_LANE_WIDTH+:BYTE_LANE_WIDTH];
	  end

      // Instantiate the data align logic which realigns the data from the
      // ISERDES as needed.
      // will be needed if edge_adv does not work
	  
      mig_7series_v2_4_qdr_rld_phy_read_data_align #
       (
        .BYTE_LANE_WIDTH     (BYTE_LANE_WIDTH),
        .nCK_PER_CLK         (nCK_PER_CLK),
        .TCQ                 (TCQ)    
       ) 
       u_qdr_rld_phy_read_data_align 
       (
        .clk                 (clk),
        .rst_clk             (rst_stg2),
        .iserdes_rd          (iserdes_rd_byte[nd_i*nCK_PER_CLK*BYTE_LANE_WIDTH+:nCK_PER_CLK*BYTE_LANE_WIDTH]),
        .iserdes_fd          (iserdes_fd_byte[nd_i*nCK_PER_CLK*BYTE_LANE_WIDTH+:nCK_PER_CLK*BYTE_LANE_WIDTH]),
        .rise_data           (rise_data_byte[nd_i*nCK_PER_CLK*BYTE_LANE_WIDTH+:nCK_PER_CLK*BYTE_LANE_WIDTH]),
        .fall_data           (fall_data_byte[nd_i*nCK_PER_CLK*BYTE_LANE_WIDTH+:nCK_PER_CLK*BYTE_LANE_WIDTH]),
        .bitslip             (bitslip[nd_i]),
        .inc_latency         (inc_latency [nd_i]),
        .max_lat_done        (max_lat_done_r)
       );           
    end
  endgenerate
  
   
 always @ (posedge clk) begin
     if (rst_wr_clk) begin
        if_empty_r <= #TCQ 0;
        if_empty_2r <= #TCQ 0;
     end else begin
        if_empty_r <= #TCQ if_empty;
        if_empty_2r <= #TCQ if_empty_r;
     end
   end
   
   // Always read from input data FIFOs when not empty
   assign if_rden = ~if_empty_2r;
 
   // Debug signals
  assign dbg_inc_latency       = inc_latency;
  assign dbg_error_max_latency = error_max_latency;


endmodule

// Local Variables:
// verilog-library-directories:(".")
// verilog-library-extensions:(".v")
// End:
