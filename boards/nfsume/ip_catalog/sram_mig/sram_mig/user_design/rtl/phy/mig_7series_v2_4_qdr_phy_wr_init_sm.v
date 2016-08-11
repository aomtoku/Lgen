//*****************************************************************************
//(c) Copyright 2009 - 2013 Xilinx, Inc. All rights reserved.
//
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
//
// DISCLAIMER
// This disclaimer is noot a license and does not grant any
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
//  /   /         Filename           : qdr_phy_wr_init_sm.v
// /___/   /\     Date Last Modified : $date$
// \   \  /  \    Date Created       : Nov 12, 2008 
//  \___\/\___\
//
//Device: 7 Series
//Design: QDRII+ SRAM
//
//Purpose:
// This block has overall control of the qdr initialization and calibration
// procedure including reset.
//
// This block issues writes and then repeated reads to memory.  There are
// two basic halves to be calibrated.  The read side and the write side.
//
// A stage1 pattern is written to memory, and then continuous reads
// are issued.  The read side is told when to start looking for the stage1
// test pattern in the data read from memory.  rdlvl_stg1_done tells this
// block the read side has finished attempting to calibrate to the memory
// reads.
//
// Next a stage2 pattern is written to memory.  The read side attempts to
// find the stage2 pattern and indicates this on phase_valid.  this block waits
// for 31 fabric cycles after the first read to look at the match results 
// (phase_valid) from the read side.  The sample can also be terminated by
// edge_adv_cal_done.  This means that the stage2 read side has successfully
// phase aligned.  This is generally not necessary, but may make the algorithm
// run faster.

// For a given setting of the phaser outs, WRCAL_SAMPLES cycles
// will be attempted.  There is also a thresholding feature so that results
// with some noise will be promoted to a solid one.  At the end of WRCAL_SAMPLES
// the phaser out adjust block (_po_adj) is called to look at the results and adjust
// the phaser outs as it sees fit.  When the _po_adj block signals its done
// adjusting the phaser outs, everything is reset and it all starts over.
//
// To make the algorithm run faster the SKP_STG1_SEEN_VAL feature keeps track
// if its has ever seen valid results on a lane, further stage1 calibrations
// will be skipped.
//
// If things are going well, eventually the _po_adj block will signal phaser out
// adjust done and that the K clock is centered in the write data.  At this point the read
// side is again reset for one more alignment with the K clock centered in
// the write data.  
//
// Once the final stg1 cycle is complete, the stg2 calibration proceeds in
// two pieces.  edge_adv_cal_start is again set high, but for this last time
// the state machine waits for edge_adv_cal_done to transtition hi instead of 
// WRCAL_SAMPLES.  This indicates that the read data has been aligned to the 
// proper edge of the fabric clock.
//
// The second half of the stg2 calibration determines the read latency.  It
// starts by waiting 31 fabric clocks to make sure the read data bus is idle, and then
// issus a single read.  The stg2 calibration is then told to look for the data
// by asserting cal_stg2_start.  The state machine waits for cal_stg2_done and then
// sets init_calib_complete high.
//
// At the end of the latency calibration, if enabled, "complex" calibration may
// start first by writing the complex pattern to memory, then repeatedly reading
// that pattern and telling the stage 1 calibration to run.  It will wait here
// until the stage 1 calibrator signals its done.
//
// This block generates all commands, addresses and write data sent to the memories.
// Stage1 uses an eight data word pattern, stage2 uses a 4 data word pattern.
// Since we support only nCK_PER_CLK = 2, the stage1 pattern requires two fabric
// clocks and the stage2 pattern only one.
//
// Burst 2 and 4 are supported.  The number of fabric clocks required is the
// same for both modes.  The write data is also identical.  The difference is
// in the address and the read and write commands.  The _control_io block
// knows about the burst size.  This block generates 4 addresses per fabric
// clock.  In burst 4 mode, the address is SDR so only two are used.
// 
// read side signals:
// rdlvl_stg1_start - Sorta of a master enable to the read side.  It will perform
//                    its basic stage 1 calibration cycle and then halt.
// edge_adv_cal_start - Start looking for the stage2 pattern in the read data.
// edge_adv_cal_done - Read data is aligned to proper edge of the fabric clock.
// phase_valid - Valid phase 2 data has been detected.
// rst_stg1, rst_stg2 - Reset indicated read stage.
// cal_stage2_start - Perform the latency calibration.
// read_cal_done - Latency calibration done.
// dbg_phy_init_wr_only - Hang writing the cal1 pattern forever.
// dbg_phy_init_rd_only - Hang reading the cal1 pattern forever.
//
////////////////////////////////////////////////////////////////////////////////


`timescale 1ps/1ps

module mig_7series_v2_4_qdr_phy_wr_init_sm #
 (parameter BYTE_LANE_WITH_DK = 4'h0,// BYTE vector that shows which byte lane has K clock.
                                      // "1000" : byte group 3
                                      // "0001" : byte group 0
  parameter N_DATA_LANES       = 4,
  parameter BURST_LEN          = 4,    //Burst Length
  parameter BRAM_ADDR_WIDTH    = 8,
  parameter CK_WIDTH           = 1,
  parameter CMPLX_RDCAL_EN     = "FALSE",
  parameter ADDR_WIDTH         = 19,   //Address Width
  parameter DATA_WIDTH         = 72,   //Data Width  
  parameter BW_WIDTH           = 8,
  parameter CLK_STABLE         = 4000,  // In fabric clocks.
  parameter PO_ADJ_GAP         = 7,    //Time to wait between PO adj
  parameter SKIP_STG1_SEEN_VAL = "ON",
  parameter TCQ                = 100,
  parameter WRCAL_DEFAULT      = "FALSE",
  parameter WRCAL_HYSTERESIS   = "TRUE",
  parameter WRCAL_PCT_SAMPS_SOLID = 95,
  parameter WRCAL_SAMPLES      = 8,
  parameter nCK_PER_CLK        = 2)
  (/*AUTOARG*/
  // Outputs
  cmplx_rdcal_start, rdlvl_stg1_cal_bytes, rdlvl_stg1_fast,
  iob_dll_off_n, rst_clk, rdlvl_stg1_start, edge_adv_cal_start,
  rst_stg1, rst_stg2, cal_stage2_start, init_calib_complete,
  wrcal_adj_rdy, cmplx_victim_bit, init_wr_addr0, init_wr_addr1,
  init_rd_addr0, init_rd_addr1, init_wr_data0, init_wr_data1,
  init_wr_cmd, init_rd_cmd, cmplx_seq_rst, cmplx_wr_done,
  kill_rd_valid, lanes_solid, dbg_wr_init,
  // Inputs
  clk, rst, kbyte_sel, rdlvl_stg1_done, wrcal_adj_done,
  cmplx_seq_addr, cmplx_data, po_delay_done, K_is_at_center,
  edge_adv_cal_done, read_cal_done, dbg_phy_init_wr_only,
  dbg_phy_init_rd_only, cmplx_seq_done, dbg_cmplx_wr_loop,
  cmplx_pause, rdlvl_valid, phase_valid
  );

  function integer clogb2 (input integer size); // ceiling logb2
    begin
      size = size - 1;
      for (clogb2=1; size>1; clogb2=clogb2+1)
            size = size >> 1;
    end
  endfunction // clogb2

  localparam ONE = 1;
  localparam SAMP_CNT_WIDTH = clogb2(WRCAL_SAMPLES);

  localparam PHY_WAIT = 31;
  localparam EDGE_ADV_TIMEOUT = 500;
  localparam SM_CNTR_WIDTH = clogb2(EDGE_ADV_TIMEOUT+1);
  
  input clk;
  input rst;

  input kbyte_sel;
  reg [N_DATA_LANES-1:0] seen_valid_ns, seen_valid_r;
  always @(posedge clk) seen_valid_r <= #TCQ seen_valid_ns;
  wire suppress_stg1 = SKIP_STG1_SEEN_VAL == "ON" && CK_WIDTH == 1
                                                      ? &seen_valid_r
                                                      : kbyte_sel
                                                         ? &seen_valid_r[3:2]
                                                         : &seen_valid_r[1:0];

  reg cmplx_rdcal_start_ns, cmplx_rdcal_start_r;
  always @(posedge clk) cmplx_rdcal_start_r <= #TCQ cmplx_rdcal_start_ns;
  output cmplx_rdcal_start;
  assign cmplx_rdcal_start = cmplx_rdcal_start_r;

  reg [N_DATA_LANES-1:0] rdlvl_stg1_cal_bytes_ns, rdlvl_stg1_cal_bytes_r;
  always @(posedge clk) rdlvl_stg1_cal_bytes_r <= #TCQ rdlvl_stg1_cal_bytes_ns;
  always @(*) rdlvl_stg1_cal_bytes_ns = (SKIP_STG1_SEEN_VAL != "ON" || cmplx_rdcal_start_ns || WRCAL_DEFAULT == "TRUE") 
                                          ? {N_DATA_LANES{1'b1}}
                                          : CK_WIDTH == 1
                                             ? ~seen_valid_r
				             : kbyte_sel
				               ? {~seen_valid_r[3:2], 2'b0}
			                       : {2'b0, ~seen_valid_r[1:0]};
  output [N_DATA_LANES-1:0] rdlvl_stg1_cal_bytes;
  assign rdlvl_stg1_cal_bytes = rdlvl_stg1_cal_bytes_r;
  
  output rdlvl_stg1_fast;
  assign rdlvl_stg1_fast = 1'b0;

  //De-activate mem_dll_off_n signal to SRAM after stable K/K# clock
  reg rst_r;
  always @ (posedge clk) rst_r <= #TCQ rst;
  output iob_dll_off_n;
  assign iob_dll_off_n = ~rst_r;

  // Minus one since were counting in whole numbers.
  localparam MEM_PLL_LOCK_CLKS = CLK_STABLE - 1;

  localparam CQ_CNT_WIDTH = clogb2(MEM_PLL_LOCK_CLKS);
  reg [CQ_CNT_WIDTH-1:0] cq_cnt_ns, cq_cnt_r;
  always @(posedge clk) cq_cnt_r <= cq_cnt_ns;
  always @(*) begin
    cq_cnt_ns = cq_cnt_r;
    if (rst) cq_cnt_ns = {CQ_CNT_WIDTH{1'b0}};
    else if (cq_cnt_r != MEM_PLL_LOCK_CLKS[CQ_CNT_WIDTH-1:0]) 
      cq_cnt_ns = cq_cnt_r + ONE[CQ_CNT_WIDTH-1:0];
  end

  reg cq_stable_ns, cq_stable_r;
  always @(posedge clk) cq_stable_r <= #TCQ cq_stable_ns;
  always @(*) begin
    cq_stable_ns = cq_stable_r;
    if (rst) cq_stable_ns = 1'b0;
    else cq_stable_ns = cq_cnt_r == MEM_PLL_LOCK_CLKS[CQ_CNT_WIDTH-1:0];
  end // always @ begin

  output rst_clk;
  assign rst_clk  = ~cq_stable_r;

  //Stage 1 Calibration Pattern

  //00FF_00FF
  localparam [DATA_WIDTH*8-1:0] DATA_STAGE1 = 
                                {{DATA_WIDTH{1'b0}}, {DATA_WIDTH{1'b1}},
                                 {DATA_WIDTH{1'b0}}, {DATA_WIDTH{1'b1}},
                                 {DATA_WIDTH{1'b0}}, {DATA_WIDTH{1'b1}},
                                 {DATA_WIDTH{1'b0}}, {DATA_WIDTH{1'b1}}};      

  //Stage 2 Calibration Pattern 
  localparam  PATTERN_5 = 9'h155;
  localparam  PATTERN_A = 9'h0AA;
  // rise0_fall0_rise1_fall1 data pattern                                            
  localparam [DATA_WIDTH*4-1:0] DATA_STAGE2 = { {BW_WIDTH{PATTERN_A}},{BW_WIDTH{PATTERN_5}},
                                                {DATA_WIDTH{1'b0}},{DATA_WIDTH{1'b1}}};  

 //Signals to the read path that initialization can begin 
  reg rdlvl_stg1_start_ns, rdlvl_stg1_start_r;
  always @(posedge clk) rdlvl_stg1_start_r <= #TCQ rdlvl_stg1_start_ns;
  output rdlvl_stg1_start;
  assign rdlvl_stg1_start = rdlvl_stg1_start_r;

  input rdlvl_stg1_done;

  reg edge_adv_cal_start_ns, edge_adv_cal_start_r;
  always @(posedge clk) edge_adv_cal_start_r <= #TCQ edge_adv_cal_start_ns;
  output edge_adv_cal_start;
  assign edge_adv_cal_start = edge_adv_cal_start_r;

  reg rst_just_stg1_r;
  input wrcal_adj_done;
  
  reg rst_stg1_ns, rst_stg1_r;
  always @(*) rst_stg1_ns = wrcal_adj_done & ~suppress_stg1 || rst_clk || rst_just_stg1_r;
  always @(posedge clk) rst_stg1_r <= #TCQ rst_stg1_ns;

  reg rst_stg2_ns, rst_stg2_r;
  always @(posedge clk) rst_stg2_r <= #TCQ rst_stg2_ns;
  
  output rst_stg1, rst_stg2;
  assign rst_stg1 = rst_stg1_r;
  assign rst_stg2 = rst_stg2_r;

  reg cal_stage2_start_ns, cal_stage2_start_r;
  always @(posedge clk) cal_stage2_start_r <= #TCQ cal_stage2_start_ns;
  output cal_stage2_start;
  assign cal_stage2_start = cal_stage2_start_r;

  reg init_calib_complete_ns, init_calib_complete_r;
  always @(posedge clk) init_calib_complete_r <= #TCQ init_calib_complete_ns;
  output init_calib_complete;
  assign init_calib_complete = init_calib_complete_r;
 
  reg [SAMP_CNT_WIDTH:0] wrcal_samp_cnt_ns, wrcal_samp_cnt_r;
  always @(posedge clk) wrcal_samp_cnt_r <= wrcal_samp_cnt_ns;
  
  reg rst_samp_cnt;
  reg wrcal_adj_rdy_ns, wrcal_adj_rdy_r;
  always @(posedge clk) wrcal_adj_rdy_r <= #TCQ wrcal_adj_rdy_ns;
  output wrcal_adj_rdy;
  assign wrcal_adj_rdy = wrcal_adj_rdy_r;

  // For cmd, addr, data 0 and 1 suffix refers to first or second
  // kclk within a single fabric clk cycle.

  reg [3:0] victim_bit_ns, victim_bit_r;
  always @(posedge clk) victim_bit_r <= #TCQ victim_bit_ns;
  output [3:0] cmplx_victim_bit;
  assign cmplx_victim_bit = victim_bit_r;
  
  localparam PHY_INIT_SM_WIDTH = 15;

  localparam [PHY_INIT_SM_WIDTH-1:0] CAL_INIT                  =  15'b000_000_0000_0001;
  localparam [PHY_INIT_SM_WIDTH-1:0] CAL1_WR                   =  15'b000_0000_0000_0010; 
  localparam [PHY_INIT_SM_WIDTH-1:0] CAL1_RD                   =  15'b000_0000_0000_0100; 
  localparam [PHY_INIT_SM_WIDTH-1:0] CAL2_WR                   =  15'b000_0000_0000_1000; 
  localparam [PHY_INIT_SM_WIDTH-1:0] CAL2_RD_CONTINUOUS        =  15'b000_0000_0001_0000;
  localparam [PHY_INIT_SM_WIDTH-1:0] CAL2_RD                   =  15'b000_0000_0010_0000; 
  localparam [PHY_INIT_SM_WIDTH-1:0] WR_CAL_WAIT               =  15'b000_0000_0100_0000;
  localparam [PHY_INIT_SM_WIDTH-1:0] CAL2_RD_WAIT              =  15'b000_0000_1000_0000;
  localparam [PHY_INIT_SM_WIDTH-1:0] CAL_DONE                  =  15'b000_0001_0000_0000; 
  localparam [PHY_INIT_SM_WIDTH-1:0] CAL_DONE_WAIT             =  15'b000_0010_0000_0000;
  localparam [PHY_INIT_SM_WIDTH-1:0] CMPLX_WR                  =  15'b000_0100_0000_0000;
  localparam [PHY_INIT_SM_WIDTH-1:0] CMPLX_RD                  =  15'b000_1000_0000_0000;
  localparam [PHY_INIT_SM_WIDTH-1:0] STG2_ERR                  =  15'b001_0000_0000_0000;
  localparam [PHY_INIT_SM_WIDTH-1:0] EDGE_ADV_ERR              =  15'b010_0000_0000_0000;
  localparam [PHY_INIT_SM_WIDTH-1:0] WAIT_4_EDGE_ADV           =  15'b100_0000_0000_0000;
  
  reg [PHY_INIT_SM_WIDTH-1:0] phy_init_ns, phy_init_r;
  always @(posedge clk) phy_init_r <= #TCQ phy_init_ns;
  
  reg addr_bit_ns, addr_bit_r;
  always @(posedge clk) addr_bit_r <= #TCQ addr_bit_ns;

  input [BRAM_ADDR_WIDTH:0] cmplx_seq_addr;
  reg [BRAM_ADDR_WIDTH+4:0] cmplx_addr_r;
  wire [BRAM_ADDR_WIDTH+4:0] cmplx_addr_ns;
  always @(posedge clk) cmplx_addr_r <= #TCQ cmplx_addr_ns;
  assign cmplx_addr_ns = {victim_bit_r, cmplx_seq_addr};
  
  wire [ADDR_WIDTH-1:0] init_wr_addr0_ns, init_wr_addr1_ns, init_rd_addr0_ns, init_rd_addr1_ns;
  reg [ADDR_WIDTH-1:0] init_wr_addr0_r, init_wr_addr1_r, init_rd_addr0_r, init_rd_addr1_r;
  assign init_wr_addr0_ns = phy_init_r == CMPLX_WR
                              ? {{ADDR_WIDTH-BRAM_ADDR_WIDTH-6{1'b0}}, cmplx_addr_r, 1'b0}
                              : {                {ADDR_WIDTH-2{1'b0}},   addr_bit_r, 1'b0};
  assign init_wr_addr1_ns = phy_init_r == CMPLX_WR
                              ? {{ADDR_WIDTH-BRAM_ADDR_WIDTH-6{1'b0}}, BURST_LEN == 4 ? {1'b0, cmplx_addr_r} : {cmplx_addr_r, 1'b1}}
                              : {{ADDR_WIDTH-2{1'b0}},                 BURST_LEN == 4 ? {1'b0,   addr_bit_r} : {  addr_bit_r, 1'b1}};
  assign init_rd_addr0_ns = phy_init_r == CMPLX_RD
                              ? {{ADDR_WIDTH-BRAM_ADDR_WIDTH-6{1'b0}}, BURST_LEN == 4 ? {1'b0, cmplx_addr_ns} : {cmplx_addr_ns, 1'b0}}
                              : {{ADDR_WIDTH-2{1'b0}},                 BURST_LEN == 4 ? {1'b0,    addr_bit_r} : {   addr_bit_r, 1'b0}};
  assign init_rd_addr1_ns = phy_init_r == CMPLX_RD
                              ? {{ADDR_WIDTH-BRAM_ADDR_WIDTH-6{1'b0}}, cmplx_addr_ns, 1'b1}
                              : {                {ADDR_WIDTH-2{1'b0}},    addr_bit_r, 1'b1};
  always @(posedge clk) init_wr_addr0_r <= #TCQ init_wr_addr0_ns;
  always @(posedge clk) init_wr_addr1_r <= #TCQ init_wr_addr1_ns;
  always @(posedge clk) init_rd_addr0_r <= #TCQ init_rd_addr0_ns;
  always @(posedge clk) init_rd_addr1_r <= #TCQ init_rd_addr1_ns;
  output [ADDR_WIDTH-1:0] init_wr_addr0, init_wr_addr1, init_rd_addr0, init_rd_addr1;
  assign init_wr_addr0 = init_wr_addr0_r;
  assign init_wr_addr1 = init_wr_addr1_r;
  assign init_rd_addr0 = init_rd_addr0_r;
  assign init_rd_addr1 = init_rd_addr1_r;
  
  input [N_DATA_LANES*nCK_PER_CLK*2*9-1:0] cmplx_data;
  
  reg [DATA_WIDTH*2-1:0] init_wr_data0_ns, init_wr_data0_r, init_wr_data1_ns, init_wr_data1_r;
  always @(posedge clk) init_wr_data0_r <= #TCQ init_wr_data0_ns;
  always @(posedge clk) init_wr_data1_r <= #TCQ init_wr_data1_ns;
  always @(*) init_wr_data0_ns = phy_init_r == CMPLX_WR
		   ? {cmplx_data[DATA_WIDTH+:DATA_WIDTH], cmplx_data[0+:DATA_WIDTH]}
                   : rdlvl_stg1_done || suppress_stg1
                       ? DATA_STAGE2[(DATA_WIDTH*4)-1:(DATA_WIDTH*2)]  
                       : DATA_STAGE1[(addr_bit_r*DATA_WIDTH*4)+:(DATA_WIDTH*2)];
  always @(*) init_wr_data1_ns = phy_init_r == CMPLX_WR
		   ? {cmplx_data[3*DATA_WIDTH+:DATA_WIDTH], cmplx_data[2*DATA_WIDTH+:DATA_WIDTH]}
                   : rdlvl_stg1_done || suppress_stg1
                       ? DATA_STAGE2[(DATA_WIDTH*2)-1:0]
                       : DATA_STAGE1[(({addr_bit_r, 1'b0}+1)*DATA_WIDTH*2)+:(DATA_WIDTH*2)];
  output [DATA_WIDTH*2-1:0] init_wr_data0, init_wr_data1;
  assign init_wr_data0 = init_wr_data0_r;
  assign init_wr_data1 = init_wr_data1_r;

  reg [1:0] init_wr_cmd_ns, init_wr_cmd_r, init_rd_cmd_ns, init_rd_cmd_r;
  always @(posedge clk) init_wr_cmd_r <= #TCQ init_wr_cmd_ns;
  always @(posedge clk) init_rd_cmd_r <= #TCQ init_rd_cmd_ns;
  output [1:0] init_wr_cmd, init_rd_cmd;
  assign init_wr_cmd = init_wr_cmd_r;
  assign init_rd_cmd = init_rd_cmd_r;

  reg sample_r;
  
  reg [SM_CNTR_WIDTH-1:0] sm_cntr_ns, sm_cntr_r;
  always @(posedge clk) sm_cntr_r <= #TCQ sm_cntr_ns;

  input po_delay_done; 
  input K_is_at_center;
  input edge_adv_cal_done;
  input read_cal_done;
  input dbg_phy_init_wr_only;
  input dbg_phy_init_rd_only;

  reg cmplx_seq_rst_r;
  output cmplx_seq_rst;
  assign cmplx_seq_rst = cmplx_seq_rst_r;

  reg victim_rot_done_ns, victim_rot_done_r;
  always @(posedge clk) victim_rot_done_r <= #TCQ victim_rot_done_ns;
  input cmplx_seq_done;
  input dbg_cmplx_wr_loop;
  
  always @(*) begin
    victim_rot_done_ns = 1'b0;
    victim_bit_ns = victim_bit_r;
    if (rst_clk) victim_bit_ns = 'b0;
    else if (~cmplx_seq_rst && cmplx_seq_done) begin
      if (victim_bit_r[3]) begin
        victim_bit_ns = 'b0;
	if (~dbg_cmplx_wr_loop) victim_rot_done_ns = 1'b1;
      end else victim_bit_ns = victim_bit_r + 4'd1;
    end
  end // always @ begin

  reg cmplx_wr_done_r;
  output cmplx_wr_done;
  assign cmplx_wr_done = cmplx_wr_done_r;

  reg kill_rd_valid_ns, kill_rd_valid_r;
  always @(posedge clk) kill_rd_valid_r <= #TCQ kill_rd_valid_ns;
  output kill_rd_valid;
  assign kill_rd_valid = kill_rd_valid_r;
    
  input cmplx_pause;
  wire [N_DATA_LANES-1:0] lanes_solid_ns;  
  reg [N_DATA_LANES-1:0] lanes_solid_r;
  always @(posedge clk) lanes_solid_r <= #TCQ lanes_solid_ns;
  output [N_DATA_LANES-1:0] lanes_solid;
  assign lanes_solid = lanes_solid_r;
  reg [N_DATA_LANES-1:0] lanes_solid_prev_ns, lanes_solid_prev_r;
  always @(posedge clk) lanes_solid_prev_r <= #TCQ lanes_solid_prev_ns;

  input rdlvl_valid;

  //Initialization State Machine
  always @(*) begin

    addr_bit_ns = addr_bit_r;
    cal_stage2_start_ns = cal_stage2_start_r;
    cmplx_wr_done_r = 1'b0;
    cmplx_seq_rst_r = 1'b1;
    cmplx_rdcal_start_ns = cmplx_rdcal_start_r;
    edge_adv_cal_start_ns = edge_adv_cal_start_r;
    wrcal_samp_cnt_ns = wrcal_samp_cnt_r;
    rst_samp_cnt = 1'b0;
    phy_init_ns = phy_init_r;
    init_wr_cmd_ns = 2'b00;
    init_rd_cmd_ns = 2'b00;
    init_calib_complete_ns = 1'b0;
    kill_rd_valid_ns = kill_rd_valid_r;
    rdlvl_stg1_start_ns = rdlvl_stg1_start_r;
    rst_just_stg1_r = 1'b0;
    rst_stg2_ns = 'b0;
    sample_r = 1'b0;
    seen_valid_ns = seen_valid_r;
    sm_cntr_ns = sm_cntr_r;
    if (|sm_cntr_r) sm_cntr_ns = sm_cntr_r - 'h1;
    wrcal_adj_rdy_ns = 1'b0;

    if (rst_clk || ~po_delay_done) begin
      addr_bit_ns = 1'b0;
      cmplx_rdcal_start_ns = 1'b0;
      phy_init_ns = CAL_INIT;
      rdlvl_stg1_start_ns = 1'b0;
      cal_stage2_start_ns = 1'b0;
      edge_adv_cal_start_ns = 'b0;
      kill_rd_valid_ns = 'b0;
      seen_valid_ns = 'b0;
      rst_stg2_ns = 'b1;
    end else begin
      
      case (phy_init_r)
	
        // Wait here for initial phaser out adjustments have been made.  After
	// that this state is traversed after each phaser out adjustment and
	// a new write read sequence calibration sequence is begun.
        CAL_INIT : begin
	  addr_bit_ns = 1'b0;
	  wrcal_samp_cnt_ns = 'b0;
	  sm_cntr_ns = 'b0;
	  rst_samp_cnt = 1'b1;
          if (suppress_stg1) begin
	    phy_init_ns = CAL2_WR;
	  end else begin
            phy_init_ns = CAL1_WR;
	    rdlvl_stg1_start_ns = 1'b0;
          end
        end
        
        // Write 4 words in one fabric cycles.  Only difference between
	// burst 2 and 4 is the number of write commands sent.  Data
	// and address is taken care of outside this state machine.
        CAL1_WR :  begin
	  rdlvl_stg1_start_ns = 1'b1;
          init_wr_cmd_ns = (BURST_LEN == 4) ? 2'b10 : 2'b11;
          if (!dbg_phy_init_wr_only) phy_init_ns = CAL1_RD;
        end

        //Send read commands.  Terminate when read side says stage1 complete.
        CAL1_RD   : begin
          init_rd_cmd_ns = (BURST_LEN == 4) ? 2'b01 : 2'b11;
          if (rdlvl_stg1_done && !dbg_phy_init_rd_only) phy_init_ns = CAL2_WR;
        end
        
        // Write 4 words.  Corresponds to a single fabric cycle.  Only difference
	// between burst 2 and 4 is the number of write commands.
        CAL2_WR  :  begin
	  if (~|sm_cntr_r) begin
            init_wr_cmd_ns   = (BURST_LEN == 4) ? 2'b10 : 2'b11;
            phy_init_ns = CAL2_RD_CONTINUOUS;
	    wrcal_samp_cnt_ns = wrcal_samp_cnt_r + ONE[SAMP_CNT_WIDTH:0];
	    sm_cntr_ns = PHY_WAIT[SM_CNTR_WIDTH-1:0];
	  end
        end

	// Issue continuous reads.  Wait for 31 fabric clocks and then sample
	// result from read side once.  If clock is centered, go to latency
	// calibration.  If num WRCAL_SAMPLES achieved, adjust phasers.  Else
	// write and then read again.
        CAL2_RD_CONTINUOUS: begin 
          init_rd_cmd_ns = (BURST_LEN == 4) ? 2'b01 : 2'b11;
	  edge_adv_cal_start_ns = 'b1;

	  if (WRCAL_DEFAULT == "TRUE" || K_is_at_center) begin
	    phy_init_ns = WAIT_4_EDGE_ADV;
	    sm_cntr_ns = EDGE_ADV_TIMEOUT[SM_CNTR_WIDTH-1:0];
	  end else if (~|sm_cntr_r || edge_adv_cal_done) begin
	    sample_r = 1'b1;
	    if (wrcal_samp_cnt_r == WRCAL_SAMPLES[SAMP_CNT_WIDTH:0]) phy_init_ns =  WR_CAL_WAIT;
	    else begin
              phy_init_ns = CAL2_WR;
	      rst_stg2_ns = 'b1;
	      edge_adv_cal_start_ns = 'b0;
	      sm_cntr_ns = PHY_WAIT[SM_CNTR_WIDTH-1:0];
	    end
	  end
        end // case: CAL2_RD_CONTINUOUS

        // Wait here for edge_adv_cal_done or timeout.
	WAIT_4_EDGE_ADV : begin
	  init_rd_cmd_ns   = (BURST_LEN == 4) ? 2'b01 : 2'b11;
	  if (edge_adv_cal_done) begin
	    phy_init_ns = CAL2_RD_WAIT;
	    sm_cntr_ns = PHY_WAIT[SM_CNTR_WIDTH-1:0];
	  end else if (~|sm_cntr_r) phy_init_ns = EDGE_ADV_ERR;
	end
	
	// Wait here while _po_adj manipulates phaser outs.
        WR_CAL_WAIT  : begin
	  seen_valid_ns = seen_valid_r | lanes_solid_ns & rdlvl_stg1_cal_bytes;
          if (wrcal_adj_done) begin
            phy_init_ns =  CAL_INIT;
	    rst_stg2_ns = 1'b1;
	  end
	  else wrcal_adj_rdy_ns = 1'b1;
        end       

         // Wait following CAL2_RD_CONTINUOUS to make sure bus is quiescent before starting latency measurement.
         CAL2_RD_WAIT: begin
           if (~|sm_cntr_r) phy_init_ns = CAL2_RD;  
         end
	
         // One read for latency calibration.      
         CAL2_RD: begin
	   cal_stage2_start_ns = 1'b1;
	   sm_cntr_ns = EDGE_ADV_TIMEOUT[SM_CNTR_WIDTH-1:0];
           init_rd_cmd_ns  = BURST_LEN == 4 ? 2'b01 : 2'b11;
           phy_init_ns = CAL_DONE_WAIT;       
         end 

        // Stays here if all conditions met except read_cal_done
        // before asserting calibration complete   
        CAL_DONE_WAIT: begin
	  if (~|sm_cntr_r) phy_init_ns = STG2_ERR;
          else if (read_cal_done) 
            if (CMPLX_RDCAL_EN == "TRUE") begin
	      rdlvl_stg1_start_ns = 1'b0;
              phy_init_ns = CMPLX_WR;
	      sm_cntr_ns = 'b1;
            end else phy_init_ns = CAL_DONE;       
        end

	// Write complex pattern to memory.
        CMPLX_WR : begin
	  rst_just_stg1_r = 1'b1;
	  cmplx_seq_rst_r = 1'b0;
	  if (~|sm_cntr_r) init_wr_cmd_ns = (BURST_LEN == 4) ? 2'b10 : 2'b11;
	  if (victim_rot_done_r) begin
	    cmplx_seq_rst_r = 1'b1;
	    phy_init_ns = CMPLX_RD;
	    kill_rd_valid_ns = 'b1;
	    rdlvl_stg1_start_ns = 1'b1;
	    cmplx_rdcal_start_ns = 1'b1;
	    rst_just_stg1_r = 1'b0;
	  end	
        end

	// Continuously read complex read pattern until done signaled.
        CMPLX_RD : begin
	  cmplx_seq_rst_r = 1'b0;
	  cmplx_wr_done_r = 1'b1;
	  if (~cmplx_pause) init_rd_cmd_ns = (BURST_LEN == 4) ? 2'b01 : 2'b11;
	  if (rdlvl_stg1_done) begin
	    phy_init_ns = CAL_DONE;
	    cmplx_rdcal_start_ns = 1'b0;
	    sm_cntr_ns = 'h1f;
	  end
        end
  
        //Calibration Complete
        CAL_DONE : begin
	  if (~|sm_cntr_r) kill_rd_valid_ns = 'b0;
	  if (~|sm_cntr_r && rdlvl_valid) init_calib_complete_ns = 1'b1;
        end

	// stg2 hung trying to do edge advance.
        EDGE_ADV_ERR : begin
        end
	
	// stg2 hung trying to determine latency.
        STG2_ERR : begin
        end

      endcase
    end // else: !if(rst)

    if (dbg_phy_init_wr_only || dbg_phy_init_rd_only) addr_bit_ns = 1'b0;
  end // always @ begin

  input [N_DATA_LANES-1:0] phase_valid;

  localparam integer SAMPS_SOLID_THRESH = WRCAL_SAMPLES * WRCAL_PCT_SAMPS_SOLID * 0.01;
  localparam integer SAMPS_TO_ZERO_THRESH = WRCAL_SAMPLES >> 1;

  output wire [127:0] dbg_wr_init;

  genvar ii;
  generate for (ii=0; ii<N_DATA_LANES; ii=ii+1) begin : solid_cntr_present
  
    reg [SAMP_CNT_WIDTH:0] byte_comp_cnt_ns, byte_comp_cnt_r;
    always @(posedge clk) byte_comp_cnt_r <= #TCQ byte_comp_cnt_ns;
    always @(*) begin
      lanes_solid_prev_ns[ii] = lanes_solid_prev_r[ii];
      byte_comp_cnt_ns = byte_comp_cnt_r;
      if (rst) byte_comp_cnt_ns = {SAMP_CNT_WIDTH+1{1'b0}};
      else begin
        if (rst_samp_cnt) begin
	  lanes_solid_prev_ns[ii] = lanes_solid[ii];
          byte_comp_cnt_ns = {SAMP_CNT_WIDTH+1{1'b0}};
        end else if (sample_r) begin
          if (phase_valid[ii] == 1'b1) byte_comp_cnt_ns = byte_comp_cnt_r + ONE[SAMP_CNT_WIDTH:0];
	end
      end
    end // always @ begin
    assign lanes_solid_ns[ii] = (~lanes_solid_prev_r[ii] || WRCAL_HYSTERESIS == "FALSE")
                              ? byte_comp_cnt_r >= SAMPS_SOLID_THRESH[SAMP_CNT_WIDTH:0]
                              : byte_comp_cnt_r < SAMPS_TO_ZERO_THRESH[SAMP_CNT_WIDTH:0] ? 1'b0 : 1'b1;
                             
    assign dbg_wr_init[64+ii*16+:16] = {{16-(SAMP_CNT_WIDTH+1){1'b0}}, byte_comp_cnt_r};
  end endgenerate

  generate if (N_DATA_LANES < 4) begin : zero_unused_dbg
     assign dbg_wr_init[64+N_DATA_LANES*16+:(4-N_DATA_LANES)*16] = 'b0;
  end endgenerate

  wire qdr_edge_adv_err = phy_init_r == EDGE_ADV_ERR;
  wire qdr_stg2_err = phy_init_r == STG2_ERR;
  
  assign dbg_wr_init[PHY_INIT_SM_WIDTH-1:0] = phy_init_r;
  
  generate if (N_DATA_LANES == 4) begin : phase_valid_4
    assign dbg_wr_init[PHY_INIT_SM_WIDTH+:4] = phase_valid;
    assign dbg_wr_init[PHY_INIT_SM_WIDTH+4+:4] = lanes_solid_r;
    assign dbg_wr_init[PHY_INIT_SM_WIDTH+18+:4] = seen_valid_r;
  end else begin : phase_valid_not4
    assign dbg_wr_init[PHY_INIT_SM_WIDTH+:4] = {{4-N_DATA_LANES{1'b0}}, phase_valid};
    assign dbg_wr_init[PHY_INIT_SM_WIDTH+4+:4] = {{4-N_DATA_LANES{1'b0}}, lanes_solid_r};
    assign dbg_wr_init[PHY_INIT_SM_WIDTH+18+:4] = {{4-N_DATA_LANES{1'b0}}, seen_valid_r};
  end endgenerate
  
  assign dbg_wr_init[PHY_INIT_SM_WIDTH+8] = po_delay_done;
  assign dbg_wr_init[PHY_INIT_SM_WIDTH+9] = rdlvl_stg1_done;    
  assign dbg_wr_init[PHY_INIT_SM_WIDTH+10] = rdlvl_stg1_start;
  assign dbg_wr_init[PHY_INIT_SM_WIDTH+11] = edge_adv_cal_start;
  assign dbg_wr_init[PHY_INIT_SM_WIDTH+12] = edge_adv_cal_done;
  assign dbg_wr_init[PHY_INIT_SM_WIDTH+13] = cal_stage2_start;
  assign dbg_wr_init[PHY_INIT_SM_WIDTH+14] = read_cal_done;
  assign dbg_wr_init[PHY_INIT_SM_WIDTH+15] = rst_stg1_r;
  assign dbg_wr_init[PHY_INIT_SM_WIDTH+16] = rst_stg2_r;
  assign dbg_wr_init[PHY_INIT_SM_WIDTH+17] = suppress_stg1;

  assign dbg_wr_init[PHY_INIT_SM_WIDTH+22] = qdr_edge_adv_err;
  assign dbg_wr_init[PHY_INIT_SM_WIDTH+23] = qdr_stg2_err;
  assign dbg_wr_init[PHY_INIT_SM_WIDTH+24] = rst_samp_cnt;
  
  assign dbg_wr_init[63:PHY_INIT_SM_WIDTH+25] = 'b0;


// following is for simulation purpose
//  synthesis translate_off
    reg [8*50:0] phy_init_sm;
    always @(*) begin
       casex(phy_init_r)
         CAL_INIT            : begin phy_init_sm = "INIT"                       ; end
         CAL1_WR             : begin phy_init_sm = "CAL1_WR"                    ; end
         CAL1_RD             : begin phy_init_sm = "CAL1_RD"                    ; end     
         CAL2_WR             : begin phy_init_sm = "CAL2_WR"                    ; end    
         CAL2_RD_CONTINUOUS  : begin phy_init_sm = "CAL2_RD_CONTINUOUS"         ; end    
         CAL2_RD             : begin phy_init_sm = "CAL2_RD"                    ; end
         WR_CAL_WAIT         : begin phy_init_sm = "WR_CAL_WAIT"                ; end
         CAL2_RD_WAIT        : begin phy_init_sm = "CAL2_RD_WAIT"               ; end
         CAL_DONE            : begin phy_init_sm = "DONE"                       ; end
         CAL_DONE_WAIT       : begin phy_init_sm = "DONE_WAIT"                  ; end
	 CMPLX_WR            : begin phy_init_sm = "CMPLX_WR"                   ; end
	 CMPLX_RD            : begin phy_init_sm = "CMPLX_RD"                   ; end
	 STG2_ERR            : begin phy_init_sm = "STG2_ERR"                   ; end
 	 WAIT_4_EDGE_ADV     : begin phy_init_sm = "WAIT_4_EDGE_ADV"            ; end
	 EDGE_ADV_ERR        : begin phy_init_sm = "EDGE_ADV_ERR"               ; end
       endcase // casex (phy_init_r)
      
       $display("INIT_SM:%0t - %0s", $time(), phy_init_sm);
    end // always @ begin

  integer cmplx_sequences;
  always @(posedge clk) if (rst) cmplx_sequences <= #TCQ 0;
                        else if (cmplx_seq_done) cmplx_sequences <= #TCQ cmplx_sequences + 1;
  always @(posedge cmplx_seq_done) $display("INIT_SM:%0t - Complex sequence %0d done", $time(), cmplx_sequences);
//  synthesis translate_on
          
endmodule

