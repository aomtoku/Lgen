//*****************************************************************************
// (c) Copyright 2009 - 2013 Xilinx, Inc. All rights reserved.
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
//
//*****************************************************************************
//   ____  ____
//  /   /\/   /
// /___/  \  /    Vendor: Xilinx
// \   \   \/     Version:
//  \   \         Application: MIG
//  /   /         Filename: _qdr_rld_phy_rdlvl.v
// /___/   /\     Date Last Modified: $Date: 2011/06/02 08:36:29 $
// \   \  /  \    Date Created:
//  \___\/\___\
//
//Device: 7 Series
//Design Name: QDRII+ SRAM / RLDRAM II/III SDRAM
//Purpose: Uses idelay dnd pi to place clock in middle of data eye.
//
// Step one is to find the left edge of the valid data eye.  Idelay is set
// to max and then scanned backwards to zero.  There are 31 idelays and each
// step is 78 pS for a max delay of 2418 pS.
//
// It is expected that when idelay is 31 we'll be far outside the data valid
// or possibly into the next.  The idea here is to warm up the hysteresis in
// a region where we don't care.  Also, we want to find the left _edge_ of the
// data valid window.  We want to see a transition from invalid to valid.
//
// It is possible if CLK_PERIOD is small enough to find the left edge of
// the next data valid window, but as long as we use the window closest to
// min idelay we should be in the data valid window with the smallest possible
// idelay.

//*****************************************************************************

`timescale 1ps/1ps

module mig_7series_v2_4_qdr_rld_phy_rdlvl # 
  (parameter TCQ                    = 100,
   parameter CENTER_COMP_MODE       = "OFF",
   parameter CMPLX_RDCAL_EN         = "FALSE",
   parameter CMPLX_SAMPS            = 50,
   parameter RDLVL_CMPLX_SEQ_LENGTH = 157,
   parameter CLK_PERIOD             = 2500,
   parameter DQ_WIDTH               = 36,
   parameter CQ_BITS                = 2,
   parameter DQS_WIDTH              = 4,
   parameter DRAM_WIDTH             = 9,
   parameter RDLVL_LOW_RES_MODE     = "OFF",
   parameter nCK_PER_CLK            = 2,
   parameter PI_PHY_WAIT            = 15,
   parameter PI_ADJ_VAL             = 0,
   parameter PI_E2E_WAIT            = 4,
   parameter PI_SU_WAIT             = 8,
   parameter RD_DATA_RISE_FALL      = "TRUE",
   parameter RDLVL_CMPLX_MIN_VALID_EYE_PCT = 13,
   parameter RDLVL_SIMP_MIN_VALID_EYE_PCT = 25,
   parameter RDLVL_PCT_SAMPS_SOLID  = 95,
   parameter REFCLK_FREQ            = 200.0, 
   parameter SIM_BYPASS_PI_CENTER   = 20,
   parameter SIM_BYPASS_IDELAY      = 10,
   parameter SIM_BYPASS_INIT_CAL    = "OFF",
   parameter SIMP_SAMPS             = 50)
  (/*AUTOARG*/
  // Outputs
  rdlvl_stg1_done, dlyval_dq, rdlvl_pi_stg2_cnt, largest_left_edge,
  smallest_right_edge, rdlvl_pi_en_stg2_f, rdlvl_pi_stg2_f_incdec,
  pi_stg2_load, pi_stg2_reg_l, rdlvl_scan_valid, rdlvl_valid,
  dbg_rd_stage1_cal,
  // Inputs
  clk, cmplx_rdcal_start, rdlvl_stg1_start, rdlvl_stg1_fast,
  dbg_cmplx_rd_loop, dbg_cmplx_rd_lane, rdlvl_stg1_cal_bytes,
  mem_out_dec, pi_counter_read_val, cmplx_rd_data_valid, rst_wr_clk,
  rst_stg1, rd_data, iserdes_rd_data, cmplx_rd_burst_bytes
  );

  function integer clogb2 (input integer size); // ceiling logb2
    begin
      size = size - 1;
      for (clogb2=1; size>1; clogb2=clogb2+1)
            size = size >> 1;
    end
  endfunction // clogb2

  // In LOW_RES mode, idelay location can be off by as much as 3 idelay_taps.  Reduce min PI
  // eyes by this amount.
  
  localparam integer PI_TAP = CLK_PERIOD/2/64;
  localparam integer IDELAY_TAP = 1_000_000/REFCLK_FREQ/64;
  localparam LOW_RES_PI_TAP_REDUCE = 4*IDELAY_TAP/PI_TAP;
  
  // Normalize to whole number counting.
  localparam SIMP_MIN_VALID_EYE = 64 * RDLVL_SIMP_MIN_VALID_EYE_PCT/100 - 1;
  localparam CMPLX_MIN_VALID_EYE = 64 * RDLVL_CMPLX_MIN_VALID_EYE_PCT/100 - 1;

  localparam SIMP_MIN_VALID_EYE_LOW_RES = SIMP_MIN_VALID_EYE <= LOW_RES_PI_TAP_REDUCE 
                                          ? 0
                                          : SIMP_MIN_VALID_EYE - LOW_RES_PI_TAP_REDUCE;

  localparam CMPLX_MIN_VALID_EYE_LOW_RES = CMPLX_MIN_VALID_EYE <= LOW_RES_PI_TAP_REDUCE 
                                           ? 0
                                           : CMPLX_MIN_VALID_EYE - LOW_RES_PI_TAP_REDUCE;
  reg [5:0] eye_width_ns, eye_width_r;
  input clk;
  always @(posedge clk) eye_width_r <= #TCQ eye_width_ns;
  input cmplx_rdcal_start;

  reg min_eye_ns, min_eye_r;
  always @(posedge clk) min_eye_r <= #TCQ min_eye_ns;
  always @(*) min_eye_ns = eye_width_r >= (cmplx_rdcal_start 
                                 ? RDLVL_LOW_RES_MODE == "OFF" ? CMPLX_MIN_VALID_EYE : CMPLX_MIN_VALID_EYE_LOW_RES[5:0]
                                 : RDLVL_LOW_RES_MODE == "OFF" ? SIMP_MIN_VALID_EYE : SIMP_MIN_VALID_EYE_LOW_RES[5:0]);

  localparam MAX_SAMPS = SIMP_SAMPS > CMPLX_SAMPS ? SIMP_SAMPS : CMPLX_SAMPS;
  localparam SAMP_CNTR_WIDTH = clogb2(MAX_SAMPS+1);

  wire [SAMP_CNTR_WIDTH-1:0] samps = cmplx_rdcal_start 
                             ? CMPLX_SAMPS[SAMP_CNTR_WIDTH-1:0]
                             : SIMP_SAMPS[SAMP_CNTR_WIDTH-1:0];

  localparam WAIT_WIDTH = clogb2(PI_PHY_WAIT+1);
  localparam PI_WAIT_WIDTH = clogb2(PI_SU_WAIT+1);

  localparam [4:0] DLYVAL_STEP = RDLVL_LOW_RES_MODE == "ON" ? 5'd4 : 5'd1;
  localparam [5:0] PI_STEP = RDLVL_LOW_RES_MODE == "ON" ? 6'd7 : 6'd0;

  localparam integer SIMP_THRESH = SIMP_SAMPS * RDLVL_PCT_SAMPS_SOLID * 0.01;
  localparam integer SIMP_HALF_THRESH = SIMP_SAMPS/2 * RDLVL_PCT_SAMPS_SOLID * 0.01;
  localparam integer CMPLX_THRESH = CMPLX_SAMPS * RDLVL_PCT_SAMPS_SOLID * 0.01;
  localparam integer CMPLX_HALF_THRESH = CMPLX_SAMPS/2 * RDLVL_PCT_SAMPS_SOLID * 0.01;

  // DRAM_WIDTH corresponds to victim rotate size.
  localparam CMPLX_LOOP_RUN = RDLVL_CMPLX_SEQ_LENGTH * DRAM_WIDTH * (nCK_PER_CLK == 2 ? 2 : 1);
  localparam CMPLX_LOOP_WIDTH = clogb2(CMPLX_LOOP_RUN+1);

  localparam [7:0] PATTERN = RD_DATA_RISE_FALL == "TRUE"
                              ? nCK_PER_CLK == 2 ? 8'b00000101 : 8'b01010101
			      : nCK_PER_CLK == 2 ? 8'b00001010 : 8'b10101010;
  localparam [8*DRAM_WIDTH-1:0] LANE_PATTERN = {{DRAM_WIDTH{PATTERN[7]}},
                                                {DRAM_WIDTH{PATTERN[6]}},
                                                {DRAM_WIDTH{PATTERN[5]}},
                                                {DRAM_WIDTH{PATTERN[4]}},
                                                {DRAM_WIDTH{PATTERN[3]}},
                                                {DRAM_WIDTH{PATTERN[2]}},
                                                {DRAM_WIDTH{PATTERN[1]}},
                                                {DRAM_WIDTH{PATTERN[0]}}};
  
  input rdlvl_stg1_start;
  reg rdlvl_stg1_start_r;
  always @(posedge clk) rdlvl_stg1_start_r <= #TCQ rdlvl_stg1_start;
  input rdlvl_stg1_fast;

  reg rdlvl_stg1_done_ns, rdlvl_stg1_done_r;
  always @(posedge clk) rdlvl_stg1_done_r <= #TCQ rdlvl_stg1_done_ns;
  output rdlvl_stg1_done;
  assign rdlvl_stg1_done = rdlvl_stg1_done_r;

  reg [4:0] dlyval_ns, dlyval_r;
  always @(posedge clk) dlyval_r <= #TCQ dlyval_ns;
  // A means of feeding the results of the main always block back around.
  reg new_dlyval_r;
  wire new_dlyval = new_dlyval_r;
  reg dlyval_r_zero_ns, dlyval_r_zero_r;
  always @(posedge clk) dlyval_r_zero_r <= #TCQ dlyval_r_zero_ns;
  always @(*) dlyval_r_zero_ns = ~|dlyval_ns;

  reg dlyval_zero_ns, dlyval_zero_r;
  always @(posedge clk) dlyval_zero_r <= # TCQ dlyval_zero_ns;
  always @(*) dlyval_zero_ns = ~|dlyval_ns;

  wire [4:0] current_dlyval_step = (dlyval_r >= DLYVAL_STEP[4:0] ? DLYVAL_STEP[4:0] : 'b1);
  // Could be issue on implementation speed, except for implementation DLYVAL_STEP should always be 1.
  wire [4:0] current_eye_width_step = DLYVAL_STEP == 1 
                                        ? 'b1
                                        : current_dlyval_step >= eye_width_r
	                                   ? eye_width_r
	                                   : current_dlyval_step;
  
  reg [5*DQ_WIDTH-1:0] dlyval_dq_ns, dlyval_dq_r;
  always @(posedge clk) dlyval_dq_r <= #TCQ dlyval_dq_ns;
  output [5*DQ_WIDTH-1:0] dlyval_dq;
  assign dlyval_dq = dlyval_dq_r;

  reg [CQ_BITS:0] rdlvl_work_lane_ns, rdlvl_work_lane_r;
  always @(posedge clk) rdlvl_work_lane_r <= #TCQ rdlvl_work_lane_ns;
  
  integer jj;
  always @(*) begin
    dlyval_dq_ns = dlyval_dq_r;
    for (jj=0; jj<DQS_WIDTH; jj=jj+1)
      if (rdlvl_stg1_start & rdlvl_stg1_start_r & ~cmplx_rdcal_start & ~rdlvl_stg1_done_r &&
          rdlvl_stg1_fast | jj[CQ_BITS-1:0] == rdlvl_work_lane_ns[CQ_BITS-1:0])
        dlyval_dq_ns[jj*DRAM_WIDTH*5+:DRAM_WIDTH*5] = {DRAM_WIDTH{dlyval_ns}};
  end

  // Try to do this in a "friendly way", ie hangs at the selected lane and cleanly exits
  // if dbg_cmplx_rd_loop deasserts.
  input dbg_cmplx_rd_loop;
  input [2:0] dbg_cmplx_rd_lane;
  wire dbg_cmplx_rd_lane_up = dbg_cmplx_rd_lane[CQ_BITS-1:0] == rdlvl_work_lane_r[CQ_BITS-1:0];
  wire do_cmplx_byte_loop = dbg_cmplx_rd_loop && cmplx_rdcal_start;
  
  reg first_lane_ns, first_lane_r;
  always @(posedge clk) first_lane_r <= #TCQ first_lane_ns;

  function [CQ_BITS:0] next_lane (input [CQ_BITS-1:0] current_lane, 
                                  input [DQS_WIDTH-1:0] lane_vector,
                                  input init);
    integer ii;
    begin
      next_lane = 'b0;
      for (ii=0; ii<DQS_WIDTH; ii=ii+1)
	if (~lane_vector[next_lane] || ~init & ii <= current_lane) next_lane = next_lane + 'b1;
    end
  endfunction // next_lane

  input [DQS_WIDTH-1:0] rdlvl_stg1_cal_bytes;
  
  reg [CQ_BITS:0] next_lane_ns, next_lane_r;
  always @(posedge clk) next_lane_r <= #TCQ next_lane_ns;
  always @(*) next_lane_ns = next_lane(rdlvl_work_lane_r[CQ_BITS-1:0], rdlvl_stg1_cal_bytes, first_lane_r);

  wire work_lanes_done = ~do_cmplx_byte_loop && next_lane_r == DQS_WIDTH[CQ_BITS:0];
             
  reg [CQ_BITS-1:0] pi_lane_ns, pi_lane_r;
  always @(posedge clk) pi_lane_r <= #TCQ pi_lane_ns;

  localparam DQS_WIDTH_MINUS_ONE = DQS_WIDTH - 1;
  wire last_pi_lane = ~rdlvl_stg1_fast || pi_lane_r == DQS_WIDTH_MINUS_ONE[CQ_BITS-1:0];
  
  output [CQ_BITS-1:0] rdlvl_pi_stg2_cnt;
  assign rdlvl_pi_stg2_cnt = pi_lane_r[CQ_BITS-1:0];
  
  reg [5:0] left_ns, left_r, right_ns, right_r;
  always @(posedge clk) left_r <= #TCQ left_ns;
  always @(posedge clk) right_r <= #TCQ right_ns;
  
  output [5:0] largest_left_edge;
  assign largest_left_edge = left_r;
  output [5:0] smallest_right_edge;
  assign smallest_right_edge = right_r;

  // For the record, left_r and right_r should be left inside the detected valid window.
  // The compensation ROM was designed to compute the left shift based on an assumption
  // that the phaser is left one tap to the right of the data valid window.
  //
  // Because the phaser is left 1 tap to the right of the edge, we must add one
  // to get the phaser back to the right edge when using the simple centering algorithm.
  input [5:0] mem_out_dec;
  reg [5:0] left_slew_ns, left_slew_r;
  always @(posedge clk) left_slew_r <= #TCQ left_slew_ns;
  always @(*) left_slew_ns = PI_ADJ_VAL[5:0] +
                 (CENTER_COMP_MODE == "ON"
                    ? mem_out_dec
                    : (right_r - left_r)/2 + 6'b1);

  input [5:0] pi_counter_read_val;
  reg [5:0] pi_counter_read_val_r;
  always @(posedge clk) pi_counter_read_val_r <= #TCQ pi_counter_read_val;

  wire [5:0] left_slew_no_right_edge = CENTER_COMP_MODE == "ON" 
                                         ? left_slew_r 
                                         : right_r == pi_counter_read_val_r
                                            ? left_slew_r - 'b1
                                            : left_slew_r;
  
  reg [PI_WAIT_WIDTH-1:0] pi_wait_ns, pi_wait_r;
  always @(posedge clk) pi_wait_r <= #TCQ pi_wait_ns;
  wire pi_wait_idle = ~|pi_wait_r;

  reg rdlvl_pi_en_stg2_f_ns, rdlvl_pi_en_stg2_f_r;
  always @(posedge clk) rdlvl_pi_en_stg2_f_r <= #TCQ rdlvl_pi_en_stg2_f_ns;
  always @(*) rdlvl_pi_en_stg2_f_ns = pi_wait_ns == 'b1;
  output rdlvl_pi_en_stg2_f;
  assign rdlvl_pi_en_stg2_f = rdlvl_pi_en_stg2_f_r;

  reg rdlvl_pi_stg2_f_incdec_ns, rdlvl_pi_stg2_f_incdec_r;
  always @(posedge clk) rdlvl_pi_stg2_f_incdec_r <= #TCQ rdlvl_pi_stg2_f_incdec_ns;
  output rdlvl_pi_stg2_f_incdec;
  assign rdlvl_pi_stg2_f_incdec = rdlvl_pi_stg2_f_incdec_r;

  reg [5:0] pi_step_ns, pi_step_r, pi_step_cnt_ns, pi_step_cnt_r;
  always @(posedge clk) pi_step_cnt_r <= #TCQ pi_step_cnt_ns;
  always @(posedge clk) pi_step_r <= #TCQ pi_step_ns;
  wire [5:0] pi_step = pi_counter_read_val_r > 6'd63 - (PI_STEP + 'b1) ? 'b0 : PI_STEP;
  
  output pi_stg2_load;
  assign pi_stg2_load = 'b0;

  output [5:0] pi_stg2_reg_l;
  assign pi_stg2_reg_l = 'b0;

  // xxx_held is diagnostic.  Should be optimized out.
  reg samp_result_held_ns, samp_result_held_r;
  always @(posedge clk) samp_result_held_r <= #TCQ samp_result_held_ns;
  reg [SAMP_CNTR_WIDTH-1:0] samp_cnt_ns, samp_cnt_r, samps_match_ns, samps_match_r, samps_match_held_ns, samps_match_held_r;
  always @(posedge clk) samp_cnt_r <= #TCQ samp_cnt_ns;
  wire samp_end = samp_cnt_ns == samps;
  always @(posedge clk) samps_match_r <= #TCQ samps_match_ns;
  always @(posedge clk) samps_match_held_r <= #TCQ samps_match_held_ns;

  reg prev_match_ns, prev_match_r;
  always @(posedge clk) prev_match_r <= #TCQ prev_match_ns;

  reg hyst_warmup_ns, hyst_warmup_r;
  always @(posedge clk) hyst_warmup_r <= #TCQ hyst_warmup_ns;

  wire samps_ge_thresh = cmplx_rdcal_start ? samps_match_r >= CMPLX_THRESH : samps_match_r >= SIMP_THRESH;
  wire samps_le_half_thresh = cmplx_rdcal_start ? samps_match_r <= CMPLX_HALF_THRESH : samps_match_r <= SIMP_HALF_THRESH;

  reg samp_result_ns, samp_result_r;
  always @(posedge clk) samp_result_r <= #TCQ samp_result_ns;
  always @(*) samp_result_ns = prev_match_r && ~samps_le_half_thresh || samps_ge_thresh;

  wire rdlvl_lane_match;

  input cmplx_rd_data_valid;
  reg cmplx_rd_data_valid_r;
  always @(posedge clk) cmplx_rd_data_valid_r <= #TCQ cmplx_rd_data_valid;
 
  input rst_wr_clk;
  reg [7:0] simp_min_eye_ns, simp_min_eye_r, cmplx_min_eye_ns, cmplx_min_eye_r;
  always @(posedge clk) simp_min_eye_r <= #TCQ simp_min_eye_ns;
  always @(posedge clk) cmplx_min_eye_r <= #TCQ cmplx_min_eye_ns;
  
  input rst_stg1;

  reg cmplx_accum_ns, cmplx_accum_r;
  always @(posedge clk) cmplx_accum_r <= #TCQ cmplx_accum_ns;

  reg [CMPLX_LOOP_WIDTH-1:0] cmplx_loop_cnt_ns, cmplx_loop_cnt_r;
  always @(posedge clk) cmplx_loop_cnt_r <= #TCQ cmplx_loop_cnt_ns;
  
  reg [4:0] match_out_ns, match_out_r, dlyval_edge_ns, dlyval_edge_r;
  always @(posedge clk) match_out_r <= #TCQ match_out_ns;
  always @(posedge clk) dlyval_edge_r <= #TCQ dlyval_edge_ns;

  reg dlyval_min_eye_ns, dlyval_min_eye_r;
  always @(posedge clk) dlyval_min_eye_r <= #TCQ dlyval_min_eye_ns;
  always @(*) dlyval_min_eye_ns = ~|eye_width_ns;
  
  reg stg2_2_zero_ns, stg2_2_zero_r;
  always @ (posedge clk) stg2_2_zero_r <= #TCQ stg2_2_zero_ns;
  
  reg [WAIT_WIDTH-1:0] sm_wait_ns, sm_wait_r;
  always @(posedge clk) sm_wait_r <= #TCQ sm_wait_ns;
  wire sm_wait_idle = ~|sm_wait_r;

  reg [2:0] sm_ns, sm_r;
  always @(posedge clk) sm_r <= #TCQ sm_ns;
  reg [8*25-1:0] sm_ascii;

  reg [1:0] seq_sm_ns, seq_sm_r;
  always @(posedge clk) seq_sm_r <= #TCQ seq_sm_ns;
  reg [8*25-1:0] seq_sm_ascii;

  always @(*) begin
    // Default next state assignments.
    cmplx_accum_ns = cmplx_accum_r;
    cmplx_loop_cnt_ns = cmplx_loop_cnt_r;
    new_dlyval_r = 'b0;
    dlyval_ns = dlyval_r;
    dlyval_edge_ns = dlyval_edge_r;
    left_ns = left_r;
    eye_width_ns = eye_width_r;
    first_lane_ns = first_lane_r;
    hyst_warmup_ns = hyst_warmup_r;
    match_out_ns = match_out_r;
    rdlvl_pi_stg2_f_incdec_ns = rdlvl_pi_stg2_f_incdec_r;
    pi_step_ns = pi_step_r;
    prev_match_ns = prev_match_r;
    right_ns = right_r;
    rdlvl_stg1_done_ns = 'b0;
    rdlvl_work_lane_ns = rdlvl_work_lane_r;
    samp_cnt_ns = samp_cnt_r;
    samps_match_ns = samps_match_r;
    samps_match_held_ns = samps_match_held_r;
    samp_result_held_ns = samp_result_held_r;
    sm_ns = sm_r;
    seq_sm_ns = seq_sm_r;
    stg2_2_zero_ns = stg2_2_zero_r;
    simp_min_eye_ns = rst_wr_clk ? 8'hff << DQS_WIDTH : simp_min_eye_r;
    cmplx_min_eye_ns = rst_wr_clk ? 8'hff << DQS_WIDTH : cmplx_min_eye_r;

    sm_wait_ns = sm_wait_r;
    if (|sm_wait_r) sm_wait_ns = sm_wait_r - 'b1;
    if (rdlvl_pi_en_stg2_f_r || new_dlyval) sm_wait_ns = PI_PHY_WAIT[WAIT_WIDTH-1:0];

    pi_step_cnt_ns = pi_step_cnt_r;
    if (pi_wait_r == 'b1 && |pi_step_cnt_r) pi_step_cnt_ns = pi_step_cnt_r - 'b1;
    if (pi_wait_r == 'b1 && ~|pi_step_cnt_r) pi_step_cnt_ns = pi_step_r;

    pi_lane_ns = pi_lane_r;
    if (rdlvl_stg1_fast && pi_wait_r == 'b1 && ~|pi_step_cnt_r) pi_lane_ns = pi_lane_r + 'b1;
    
    pi_wait_ns = pi_wait_r;
    if (|pi_wait_r) pi_wait_ns = pi_wait_r - 'b1;
    if (pi_wait_r == 'b1 && |pi_step_cnt_r) pi_wait_ns = PI_E2E_WAIT[PI_WAIT_WIDTH-1:0];
    if (pi_wait_r == 'b1 && ~|pi_step_cnt_r && ~last_pi_lane) pi_wait_ns = PI_SU_WAIT[PI_WAIT_WIDTH-1:0];
	   
    if (~rdlvl_stg1_start || ~rdlvl_stg1_start_r) begin
      // RESET next states
      sm_ns = /*AK("SET_LANE")*/'d0;
      sm_ascii = "RESET";
      first_lane_ns = 1'b1;
      dlyval_ns = 'b0;
      pi_wait_ns = 'b0;
      samps_match_held_ns = 'b0;
      stg2_2_zero_ns = 'b1;
    end else
      
      // State based actions and next states.       
      case (sm_r)

        /*AL("SET_LANE")*/'d0:begin
	  sm_ascii = "SET_LANE";
	  if (work_lanes_done) sm_ns = /*AK("DONE")*/'d7;
	  else begin
	    if (stg2_2_zero_r) begin
              sm_ns = /*AK("PHASERS_TO")*/'d4;
	      sm_wait_ns = PI_SU_WAIT[WAIT_WIDTH-1:0];
	      rdlvl_pi_stg2_f_incdec_ns = 1'b0;
            end else sm_ns = /*AK("SAMP")*/'d3;
	    if (!(do_cmplx_byte_loop && dbg_cmplx_rd_lane_up))
	      rdlvl_work_lane_ns = next_lane_r;
	    if (rdlvl_stg1_fast) pi_lane_ns = 'b0;
	    else pi_lane_ns = rdlvl_work_lane_ns[CQ_BITS-1:0]; 
	    if (cmplx_rdcal_start) seq_sm_ns = 'd2;
	    else seq_sm_ns = 'd0;
	    prev_match_ns = 'b0;
	    first_lane_ns = 'b0;
	    new_dlyval_r = 'b1;
      	    dlyval_ns = 'd31;
	    dlyval_edge_ns = 'd0;
	    eye_width_ns = 'b0;
	    hyst_warmup_ns = 'b0;
	    match_out_ns = 'b0;
	    samp_cnt_ns = 'b0;
            samps_match_ns = 'b0;
	    samps_match_held_ns = samps_match_r;
	    cmplx_loop_cnt_ns = 'b0;
	    cmplx_accum_ns = 'b1;
	    left_ns = 'd0;
	    right_ns = 'd63;
	    if (~cmplx_rdcal_start) simp_min_eye_ns[rdlvl_work_lane_ns] = 1'b0;
          end // else: !if(work_lanes_done)
	end // case: 'd0
	
	/*AL("COMPUTE_THRESH")*/'d1:begin
	  sm_ascii = "COMPUTE_THRESH";
	  sm_ns  = /*AK("EVAL")*/'d2;
	end

	/*AL("EVAL")*/'d2:begin
	  sm_ascii = "EVAL";
	  sm_ns  = /*AK("SAMP")*/'d3;
	  samp_cnt_ns = 'b0;
          samps_match_ns = 'b0;
	  samps_match_held_ns = samps_match_r;
	  cmplx_loop_cnt_ns = 'b0;
	  cmplx_accum_ns = 'b1;
 	  samp_result_held_ns = samp_result_r;
	  case (seq_sm_r)
	    'd0:begin
	      seq_sm_ascii = "DLYVAL";
	      hyst_warmup_ns = 1'b1;
	      prev_match_ns = samp_result_r;
	      if (samps_ge_thresh && ~prev_match_r && ~&dlyval_r) begin
		seq_sm_ns = 'd1;
		pi_wait_ns = PI_SU_WAIT[PI_WAIT_WIDTH-1:0];
		pi_step_cnt_ns = pi_step;
		pi_step_ns = pi_step;
		eye_width_ns = eye_width_r + pi_step + 'b1;
              end else begin
		new_dlyval_r = 'b1;
	        if (hyst_warmup_r) dlyval_ns = dlyval_r - current_dlyval_step;
	        if (dlyval_zero_r) begin
		  dlyval_ns = match_out_ns;
		  seq_sm_ns = 'd2;
		  eye_width_ns = 'b0;
	        end
	      end // else: !if(samps_ge_thresh && ~prev_match_r && ~&dlyval_r)
	    end // case: 'd0

	    'd1:begin
	      seq_sm_ascii = "DLYVAL_SCAN";
	      pi_wait_ns = PI_SU_WAIT[PI_WAIT_WIDTH-1:0];
	      pi_step_cnt_ns = pi_step;
	      pi_step_ns = pi_step;
	      eye_width_ns = eye_width_r + pi_step + 'b1;
	      prev_match_ns = samp_result_r;
	      if (min_eye_r && samp_result_r) match_out_ns = dlyval_r + current_dlyval_step;
	      if (~samp_result_r || min_eye_r) begin
	        eye_width_ns = 'b0;
		seq_sm_ns = 'd0;
	        rdlvl_pi_stg2_f_incdec_ns = 'b0;
      	        pi_step_cnt_ns = pi_counter_read_val_r - 'b1;
	        pi_step_ns = pi_counter_read_val_r - current_dlyval_step;
		new_dlyval_r = 'b1;
	        dlyval_ns = dlyval_r - 'b1;
	        if (dlyval_r_zero_r) begin
		  dlyval_ns = match_out_ns;
		  seq_sm_ns = 'd2;
	        end
	      end // if (~samp_result_r || min_eye_r)
	    end // case: 'd1
	    
	    'd2:begin
	      seq_sm_ascii = "LEFT";
	      if (pi_counter_read_val_r == 'd63) begin
                sm_ns = /*AK("SETUP_SLEW_LEFT")*/'d5;
		sm_wait_ns = 'd1;
              end else begin 
                pi_wait_ns = PI_SU_WAIT[PI_WAIT_WIDTH-1:0];
		pi_step_cnt_ns = pi_step;
		pi_step_ns = pi_step;
		if (samp_result_r) eye_width_ns = eye_width_r + pi_step + 'b1;
		else eye_width_ns = 'b0;
	        if (samps_ge_thresh && min_eye_r) begin
                  seq_sm_ns = 'd3;
		  if (cmplx_rdcal_start) cmplx_min_eye_ns[rdlvl_work_lane_r] = 1'b1;
                  else simp_min_eye_ns[rdlvl_work_lane_r] = 1'b1;
		end
		if (samps_ge_thresh && ~|eye_width_r) left_ns = pi_counter_read_val_r;
	      end
	    end // case: 'd2

	   'd3:begin
	     seq_sm_ascii = "RIGHT";
	     if (pi_counter_read_val_r == 'd63 || ~samp_result_r) begin
               sm_ns = /*AK("SETUP_SLEW_LEFT")*/'d5;
	       sm_wait_ns = 'd2;
	       if (~samp_result_r) begin
                 right_ns = pi_counter_read_val_r - 'd1;
	       end
             end else begin 
               pi_wait_ns = PI_SU_WAIT[PI_WAIT_WIDTH-1:0];
	       pi_step_cnt_ns = pi_step;
	       pi_step_ns = pi_step;
	     end
	   end // case: 'd3
	  endcase // case (seq_sm_r)
	end
	
        /*AL("SAMP")*/'d3:begin
	  sm_ascii = "SAMP";
	  if (sm_wait_idle && pi_wait_idle) begin
	    rdlvl_pi_stg2_f_incdec_ns = 'b1;
	    if (cmplx_rdcal_start) begin
	      if (cmplx_loop_cnt_r == CMPLX_LOOP_RUN[CMPLX_LOOP_WIDTH-1:0]) begin
		samps_match_ns = samps_match_r + (cmplx_accum_r ? 'b1 : 'b0);
		samp_cnt_ns = samp_cnt_r + 'b1;
		cmplx_loop_cnt_ns = 'b0;
	        cmplx_accum_ns = 'b1;
		if (samp_end) sm_ns =  /*AK("COMPUTE_THRESH")*/'d1;
	      end  else if (cmplx_rd_data_valid_r) begin
	        cmplx_accum_ns = cmplx_accum_r && (rdlvl_lane_match ? 'b1 : 'b0);
		cmplx_loop_cnt_ns = cmplx_loop_cnt_r + 'b1;
	      end
	    end  else begin
	      samp_cnt_ns = samp_cnt_r + 'b1;
	      samps_match_ns = samps_match_r + (rdlvl_lane_match ? 'b1 : 'b0);
	      if (samp_end) sm_ns =  /*AK("COMPUTE_THRESH")*/'d1;
	    end // else: !if(cmplx_rdcal_start)
	  end // if (sm_wait_idle && pi_wait_idle)
	end // case: 'd2

	// Setting pi_wait_ns = 'b1 because phaser command setup in SET_LANE following by PI_SU_WAIT.
	/*AL("PHASERS_TO")*/'d4:begin
	  sm_ascii = "PHASERS_TO";
	  pi_step_ns = pi_counter_read_val_r - 'b1;
	  if (sm_wait_idle) begin
	    stg2_2_zero_ns = 'b0;
	    if (!(SIM_BYPASS_INIT_CAL == "OFF" || SIM_BYPASS_INIT_CAL == "NONE")) begin
	      sm_ns = /*AK("SLEW")*/'d6;
              if (SIM_BYPASS_PI_CENTER[5:0] > pi_counter_read_val_r) begin
                pi_step_ns = SIM_BYPASS_PI_CENTER[5:0] - pi_counter_read_val_r - 'b1;
	        rdlvl_pi_stg2_f_incdec_ns = 1'b1;
		pi_wait_ns = PI_SU_WAIT[PI_WAIT_WIDTH-1:0];
	      end else if (SIM_BYPASS_PI_CENTER[5:0] < pi_counter_read_val_r) begin
                pi_step_ns = pi_counter_read_val_r - SIM_BYPASS_PI_CENTER[5:0] - 'b1;
		pi_wait_ns = 'b1;
	      end
	    end else begin
              if (|pi_counter_read_val_r) pi_wait_ns = 'b1;
	      sm_ns = /*AK("SAMP")*/'d3;
	    end // else: !if(!(SIM_BYPASS_INIT_CAL == "OFF" || SIM_BYPASS_INIT_CAL == "NONE"))
	  end // if (sm_wait_idle)
	  pi_step_cnt_ns = pi_step_ns;
      	end // case: 'd3

	/*AL("SETUP_SLEW_LEFT")*/'d5:begin
	  sm_ascii = "SETUP_SLEW_LEFT";
	  if (sm_wait_r == 'b1) begin
	    rdlvl_pi_stg2_f_incdec_ns = 1'b0;
            // pi_step counts in whole numbers.  ie zero means one step.
            pi_step_ns = left_slew_no_right_edge - 'b1;
	    pi_step_cnt_ns = pi_step_ns;
	    pi_wait_ns = PI_SU_WAIT[PI_WAIT_WIDTH-1:0];
	    sm_ns =  /*AK("SLEW")*/'d6;
	  end
      	end // case: 'd4	

	/*AL("SLEW")*/'d6:begin
	  sm_ascii = "SLEW";
          if (sm_wait_idle && pi_wait_idle)
	    if (work_lanes_done) begin
              sm_ns =  /*AK("DONE")*/'d7;
	      sm_wait_ns = PI_SU_WAIT[PI_WAIT_WIDTH-1:0];
            end else begin
              sm_ns =  /*AK("SET_LANE")*/'d0;
	      stg2_2_zero_ns = 'b1;
	    end	  
      	end // case: 'd4

	/*AL("DONE")*/'d7:begin
	  sm_ascii = "DONE";
	  if (sm_wait_idle) rdlvl_stg1_done_ns = ~rst_stg1;
	end

      endcase // case (sm_r)

    if (!(SIM_BYPASS_INIT_CAL == "OFF" || SIM_BYPASS_INIT_CAL == "NONE")) dlyval_ns = SIM_BYPASS_IDELAY[4:0];
    
  end // always @ begin

  input [2*nCK_PER_CLK*DQ_WIDTH-1:0] rd_data, iserdes_rd_data;

  reg [2*4*DQ_WIDTH-1:0] rd_data_norm, iserdes_norm;

  integer kk;
  always @(*) begin
    rd_data_norm ='b0;
    iserdes_norm = 'b0;
    for (kk=0; kk<2*nCK_PER_CLK; kk=kk+1) begin
      rd_data_norm[kk*DQ_WIDTH+:DQ_WIDTH] = rd_data[kk*DQ_WIDTH+:DQ_WIDTH];
      iserdes_norm[kk*DQ_WIDTH+:DQ_WIDTH] = iserdes_rd_data[kk*DQ_WIDTH+:DQ_WIDTH];
    end
  end

  input [71:0] cmplx_rd_burst_bytes;
  reg [2*4*9-1:0] rd_data_lane_ns, rd_data_lane_r, iserdes_lane_ns, iserdes_lane_r;
  reg [7:0] rd_data_comp_ns, rd_data_comp_r, iserdes_comp_ns, iserdes_comp_r;
  reg [8:0] rd_data_bit_comp_ns, rd_data_bit_comp_r, iserdes_bit_comp_ns, iserdes_bit_comp_r;
  always @(posedge clk) rd_data_bit_comp_r <= #TCQ rd_data_bit_comp_ns;
  always @(posedge clk) iserdes_bit_comp_r <= #TCQ iserdes_bit_comp_ns;
  always @(posedge clk) iserdes_lane_r <= #TCQ iserdes_lane_ns;
  always @(posedge clk) rd_data_lane_r <= #TCQ rd_data_lane_ns;
  always @(posedge clk) rd_data_comp_r <= #TCQ rd_data_comp_ns;
  always @(posedge clk) iserdes_comp_r <= #TCQ iserdes_comp_ns;
  integer pp;
  always @(*) begin
    rd_data_bit_comp_ns = 'b0;
    iserdes_bit_comp_ns = 'b0;
    rd_data_comp_ns = 'b0;
    iserdes_comp_ns = 'b0;
    for (pp=0; pp<8; pp=pp+1) begin
      rd_data_lane_ns[pp*DRAM_WIDTH+:DRAM_WIDTH] = rd_data_norm[pp*DQ_WIDTH+rdlvl_work_lane_r*DRAM_WIDTH+:DRAM_WIDTH];
      iserdes_lane_ns[pp*DRAM_WIDTH+:DRAM_WIDTH] = iserdes_norm[pp*DQ_WIDTH+rdlvl_work_lane_r*DRAM_WIDTH+:DRAM_WIDTH];
      // Originally simple compares done on iserdes output.  Timing is better to use rd_data.
      // rd_data also had timing problems for x72.  Shifted to _r version of rd_data_lane.
      if (rd_data_lane_r[pp*DRAM_WIDTH+:DRAM_WIDTH] == LANE_PATTERN[pp*DRAM_WIDTH+:DRAM_WIDTH]) iserdes_comp_ns[pp] = 'b1;
      if (rd_data_lane_r[pp*DRAM_WIDTH+:DRAM_WIDTH] == cmplx_rd_burst_bytes[pp*DRAM_WIDTH+:DRAM_WIDTH]) rd_data_comp_ns[pp] = 'b1;
      iserdes_bit_comp_ns = iserdes_bit_comp_ns | 
                            (iserdes_lane_r[pp*DRAM_WIDTH+:DRAM_WIDTH] == LANE_PATTERN[pp*DRAM_WIDTH+:DRAM_WIDTH] ? 9'h0 : 9'h1ff);
      rd_data_bit_comp_ns = rd_data_bit_comp_ns | 
                            (rd_data_lane_r[pp*DRAM_WIDTH+:DRAM_WIDTH] == cmplx_rd_burst_bytes[pp*DRAM_WIDTH+:DRAM_WIDTH] ? 9'h0 : 9'h1ff);
    end
  end // always @ begin

  assign rdlvl_lane_match = cmplx_rdcal_start ? &rd_data_comp_r : &iserdes_comp_r;
  wire [8:0] bit_comp = cmplx_rdcal_start ? rd_data_bit_comp_r : iserdes_bit_comp_r;

  reg [DQS_WIDTH*5-1:0] simp_dlyval_ns, simp_dlyval_r;
  always @(posedge clk) simp_dlyval_r <= #TCQ simp_dlyval_ns;
  output [DQS_WIDTH-1:0] rdlvl_scan_valid;
  assign rdlvl_scan_valid = simp_min_eye_r[DQS_WIDTH-1:0];
  output rdlvl_valid;
  assign rdlvl_valid = !(SIM_BYPASS_INIT_CAL == "NONE" || SIM_BYPASS_INIT_CAL == "OFF") ||
                       (rdlvl_scan_valid && CMPLX_RDCAL_EN == "FALSE" | &cmplx_min_eye_r);

  reg [DQS_WIDTH*6-1:0] simp_left_ns, simp_left_r, cmplx_left_ns, cmplx_left_r;
  always @(posedge clk) simp_left_r <= #TCQ simp_left_ns;
  always @(posedge clk) cmplx_left_r <= #TCQ cmplx_left_ns;
  reg [DQS_WIDTH-1:0] simp_left_63, cmplx_left_63;

  reg [DQS_WIDTH*6-1:0] simp_right_ns, simp_right_r, cmplx_right_ns, cmplx_right_r;
  always @(posedge clk) simp_right_r <= #TCQ simp_right_ns;
  always @(posedge clk) cmplx_right_r <= #TCQ cmplx_right_ns;
  reg [DQS_WIDTH-1:0] simp_right_63, cmplx_right_63;

  reg [DQS_WIDTH*6-1:0] simp_center_ns, simp_center_r, cmplx_center_ns, cmplx_center_r;
  always @(posedge clk) simp_center_r <= #TCQ simp_center_ns;
  always @(posedge clk) cmplx_center_r <= #TCQ cmplx_center_ns;

  integer ii;
  always @(*) begin
    cmplx_left_ns = cmplx_left_r;
    cmplx_right_ns = cmplx_right_r;
    cmplx_center_ns = cmplx_center_r;
    simp_dlyval_ns = simp_dlyval_r;
    simp_left_ns = simp_left_r;
    simp_right_ns = simp_right_r;
    simp_center_ns = simp_center_r;
    for (ii=0; ii<DQS_WIDTH; ii=ii+1) begin
      if (rdlvl_stg1_start && rdlvl_stg1_start_r && ~rdlvl_stg1_done && 
          rdlvl_stg1_fast | ii[CQ_BITS-1:0] == rdlvl_work_lane_ns[CQ_BITS-1:0]) begin
	if (~cmplx_rdcal_start) begin 
          simp_dlyval_ns[ii*5+:5] = dlyval_ns;
	  simp_left_ns[ii*6+:6] = left_ns;
          simp_right_ns[ii*6+:6] = right_ns;
          simp_center_ns[ii*6+:6] = pi_counter_read_val_r; 
	end
	cmplx_left_ns[ii*6+:6] = left_ns;
	cmplx_right_ns[ii*6+:6] = right_ns;
	cmplx_center_ns[ii*6+:6] = pi_counter_read_val_r;
      end
       
      simp_left_63[ii] = simp_left_r[ii*6+:6] == 'd63;
      cmplx_left_63[ii] = cmplx_left_r[ii*6+:6] == 'd63;
      simp_right_63[ii] = simp_right_r[ii*6+:6] == 'd63;
      cmplx_right_63[ii] = cmplx_right_r[ii*6+:6] == 'd63;
    end
  end // always @ begin

  output [1023:0] dbg_rd_stage1_cal;

  assign dbg_rd_stage1_cal[5:0] = {3'b0, sm_r};
  assign dbg_rd_stage1_cal[11:6] = {4'b0, seq_sm_r};

  assign dbg_rd_stage1_cal[15] = rdlvl_stg1_start;
  assign dbg_rd_stage1_cal[16] = rdlvl_stg1_done;
  assign dbg_rd_stage1_cal[17] = rdlvl_stg1_fast;
  assign dbg_rd_stage1_cal[30:26] = 'b0;

  assign dbg_rd_stage1_cal[31] = cmplx_rdcal_start;
  assign dbg_rd_stage1_cal[32] = cmplx_rd_data_valid_r;
  assign dbg_rd_stage1_cal[40:33] = 'b0;

  assign dbg_rd_stage1_cal[48:41] = rd_data_comp_r;
  assign dbg_rd_stage1_cal[56:49] = iserdes_comp_r;
  assign dbg_rd_stage1_cal[57] = rdlvl_lane_match;
  assign dbg_rd_stage1_cal[60:58] = 'b0;

  assign dbg_rd_stage1_cal[66:61] = largest_left_edge;
  assign dbg_rd_stage1_cal[72:67] = smallest_right_edge;
  assign dbg_rd_stage1_cal[78:73] = mem_out_dec;
  assign dbg_rd_stage1_cal[80:79] = 'b0;
  
  assign dbg_rd_stage1_cal[81] = rdlvl_pi_stg2_f_incdec;
  assign dbg_rd_stage1_cal[82] = rdlvl_pi_en_stg2_f;
  assign dbg_rd_stage1_cal[90:86] = 'b0;

  assign dbg_rd_stage1_cal[91] = prev_match_r;
  assign dbg_rd_stage1_cal[96:92] = match_out_r;
  assign dbg_rd_stage1_cal[109] = samp_result_held_r;

  assign dbg_rd_stage1_cal[153:110] = 'b0;

  generate if (DQS_WIDTH >= 8) begin: dqs_width_ge_8
    assign dbg_rd_stage1_cal[14:12] = rdlvl_work_lane_r[2:0];   
    assign dbg_rd_stage1_cal[25:18] = rdlvl_stg1_cal_bytes[7:0];
    assign dbg_rd_stage1_cal[85:83] = pi_lane_r[2:0];    
    assign dbg_rd_stage1_cal[154+:40] = simp_dlyval_r[39:0];    
    assign dbg_rd_stage1_cal[194+:48] = simp_left_r[47:0];
    assign dbg_rd_stage1_cal[242+:48] = simp_right_r[47:0];
    assign dbg_rd_stage1_cal[290+:48] = simp_center_r[47:0];
    assign dbg_rd_stage1_cal[338+:40] = 40'b0;    
    assign dbg_rd_stage1_cal[378+:48] = cmplx_left_r[47:0];
    assign dbg_rd_stage1_cal[426+:48] = cmplx_right_r[47:0];
    assign dbg_rd_stage1_cal[474+:48] = cmplx_center_r[47:0];
    assign dbg_rd_stage1_cal[666+:8] = 8'b0;
    assign dbg_rd_stage1_cal[674+:8] = 8'b0;
    assign dbg_rd_stage1_cal[682+:8] = simp_left_63[7:0];
    assign dbg_rd_stage1_cal[690+:8] = cmplx_left_63[7:0];
    assign dbg_rd_stage1_cal[698+:8] = simp_right_63[7:0];
    assign dbg_rd_stage1_cal[706+:8] = cmplx_right_63[7:0];
  end else begin: dqs_width_lt_8 // block: dqs_width_ge_8
    assign dbg_rd_stage1_cal[14:12] = {{3-CQ_BITS{1'b0}}, rdlvl_work_lane_r[CQ_BITS-1:0]};
    assign dbg_rd_stage1_cal[25:18] = {{8-DQS_WIDTH{1'b0}}, rdlvl_stg1_cal_bytes[DQS_WIDTH-1:0]};
    assign dbg_rd_stage1_cal[85:83] = {{3-CQ_BITS{1'b0}}, pi_lane_r[CQ_BITS-1:0]};
    assign dbg_rd_stage1_cal[154+:40] = {{8-DQS_WIDTH{5'b0}}, simp_dlyval_r[DQS_WIDTH*5-1:0]};
    assign dbg_rd_stage1_cal[194+:48] = {{8-DQS_WIDTH{6'b0}}, simp_left_r[DQS_WIDTH*6-1:0]};
    assign dbg_rd_stage1_cal[242+:48] = {{8-DQS_WIDTH{6'b0}}, simp_right_r[DQS_WIDTH*6-1:0]};
    assign dbg_rd_stage1_cal[290+:48] = {{8-DQS_WIDTH{6'b0}}, simp_center_r[DQS_WIDTH*6-1:0]};
    assign dbg_rd_stage1_cal[338+:40] = 40'b0;   
    assign dbg_rd_stage1_cal[378+:48] = {{8-DQS_WIDTH{6'b0}}, cmplx_left_r[DQS_WIDTH*6-1:0]};
    assign dbg_rd_stage1_cal[426+:48] = {{8-DQS_WIDTH{6'b0}}, cmplx_right_r[DQS_WIDTH*6-1:0]};
    assign dbg_rd_stage1_cal[474+:48] = {{8-DQS_WIDTH{6'b0}}, cmplx_center_r[DQS_WIDTH*6-1:0]};
    assign dbg_rd_stage1_cal[666+:8] = 8'b0;
    assign dbg_rd_stage1_cal[674+:8] = 8'b0;
    assign dbg_rd_stage1_cal[682+:8] = {{8-DQS_WIDTH{1'b0}}, simp_left_63[DQS_WIDTH-1:0]};
    assign dbg_rd_stage1_cal[690+:8] = {{8-DQS_WIDTH{1'b0}}, cmplx_left_63[DQS_WIDTH-1:0]};
    assign dbg_rd_stage1_cal[698+:8] = {{8-DQS_WIDTH{1'b0}}, simp_right_63[DQS_WIDTH-1:0]};
    assign dbg_rd_stage1_cal[706+:8] = {{8-DQS_WIDTH{1'b0}}, cmplx_right_63[DQS_WIDTH-1:0]};
  end endgenerate // block: dqs_width_lt_8

  generate if (SAMP_CNTR_WIDTH >= 6) begin : samp_cntr_width_ge_6
    assign dbg_rd_stage1_cal[102:97] = samp_cnt_r[5:0];
    assign dbg_rd_stage1_cal[108:103] = samps_match_r[5:0];
  end else begin : samp_cntr_width_lt_6
    assign dbg_rd_stage1_cal[102:97] = {{6-SAMP_CNTR_WIDTH{1'b0}}, samp_cnt_r[SAMP_CNTR_WIDTH-1:0]};
    assign dbg_rd_stage1_cal[108:103] = {{6-SAMP_CNTR_WIDTH{1'b0}}, samps_match_r[SAMP_CNTR_WIDTH-1:0]};
  end endgenerate

  assign dbg_rd_stage1_cal[522+:72] = rd_data_lane_r;
  assign dbg_rd_stage1_cal[594+:72] = iserdes_lane_r;
  assign dbg_rd_stage1_cal[714+:72] = cmplx_rd_burst_bytes;
  assign dbg_rd_stage1_cal[786+:9] = bit_comp;
  assign dbg_rd_stage1_cal[795+:8] = simp_min_eye_r;
  assign dbg_rd_stage1_cal[803+:8] = cmplx_min_eye_r;

  assign dbg_rd_stage1_cal[1023:811] = 'b0;
  
endmodule

// Local Variables:  
// verilog-autolabel-prefix: "'d"
// End:
