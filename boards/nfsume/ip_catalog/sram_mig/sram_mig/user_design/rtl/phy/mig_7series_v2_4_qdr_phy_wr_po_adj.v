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
//  /   /         Filename           : _qdr_phy_wr_po_adj.v
// /___/   /\     Date Last Modified : $date$
// \   \  /  \    Date Created       : Nov 12, 2008 
//  \___\/\___\
//
//Device: 7 Series
//Design: QDRII+ SRAM
//
//Purpose:
// init_sm block is nominally in control of sequencing through write read
// pattern with the read side.  After the prescribed number of samples,
// the _init_sm block requests for the phaser outs to be adjusted. This block
// implements the high level algorithm for making these adjustments.  
//
// This block also manages the POC.  At the proper time, it will calibrate the POC
// with the measured left and right edges of the data window and then center
// the K clock in that window.  When this is done, it will signal init_sm with
// adj_done and K_is_at_center.
//
// Controlling the phaser outs is somewhat complex.  The _po_cntlr block takes
// care of this lower level detail.  The _po_cntlr block sends three signals
// that instruct this block when it can adjust the phasers and when that's
// done.  po_su_rdy says the command is setup and the phaser adjustment can
// be enabled.  po_adj_done says any phaser adjustment is complete.  Next phaser
// can be adjusted, or adjust complete my be signaled to _init_sm.
//
// Supports 1 or 2 components and up to N_DATA_LANES data lanes.
//
// Internal to this block, we have a logical K byte space numbered from 0 to
// 1.  And a logical byte space numbered from 0 to N_DATA_LANES-1.
// _phy_top converts from logical space to {bank, byte}.
//
// In some cases we need to know if the byte we're indexing is a K byte.  This
// is accomplished with the BYTE_LANE_WITH_DK bit vector.  Each bit in the vector
// corresponds to a logical byte.
//
////////////////////////////////////////////////////////////////////////////////

`timescale 1ps/1ps

module mig_7series_v2_4_qdr_phy_wr_po_adj #
  (parameter BYTE_LANE_WITH_DK          = 1,
   parameter STG3_MIN_VALID_EYE         = 8,
   parameter N_DATA_LANES               = 4,
   parameter NUM_DEVICES                = 1,
   parameter SKIP_POC                   = "FALSE",
   parameter TCQ                        = 100)
  (/*AUTOARG*/
  // Outputs
  byte_sel, kbyte_sel, inc, stg3, po_en, adj_done, K_is_at_center,
  mmcm_edge_detect_rdy, ktap_at_left_edge, ktap_at_right_edge,
  dbg_wr_init,
  // Inputs
  clk, rst, lanes_solid, po_counter_read_val, po_su_rdy, po_adj_done,
  dbg_K_left_shift_right, dbg_K_right_shift_left, stg3_po_cntr,
  mmcm_edge_detect_done, mmcm_lbclk_edge_aligned, poc_backup
  );

  function integer clogb2 (input integer size); // ceiling logb2
    begin
      size = size - 1;
      for (clogb2=1; size>1; clogb2=clogb2+1)
            size = size >> 1;
    end
  endfunction // clogb2

  input clk, rst;

  reg [1:0] byte_sel_ns, byte_sel_r;
  always @(posedge clk) byte_sel_r <= #TCQ byte_sel_ns;
  output [1:0] byte_sel;
  assign byte_sel = byte_sel_ns;

  // Min eye size count at zero will equal one.  Whole number counting for the counter,
  // natural number for the parameter.
  // MIN_VALID_EYE specified in stg3 taps.  Stg2 taps half the delay of stg3.
  localparam MIN_VALID_STG3_EYE_MINUS_ONE = STG3_MIN_VALID_EYE - 1;  
  localparam MIN_VALID_STG2_EYE = 2 * MIN_VALID_STG3_EYE_MINUS_ONE;
  localparam EYE_SZ_WIDTH = clogb2(MIN_VALID_STG2_EYE + 1);
  localparam EYE_SZ_CNTR_WIDTH = N_DATA_LANES*EYE_SZ_WIDTH;
  localparam EYE_SZ_INDX_WIDTH = clogb2(EYE_SZ_CNTR_WIDTH);

  reg [EYE_SZ_CNTR_WIDTH-1:0] eye_sz_cnt_ns, eye_sz_cnt_r;
  always @(posedge clk) eye_sz_cnt_r <= #TCQ eye_sz_cnt_ns;
  reg [EYE_SZ_INDX_WIDTH-1:0] eye_sz_indx_ns, eye_sz_indx_r;
  always @(posedge clk) eye_sz_indx_r <= #TCQ eye_sz_indx_ns;
  always @(*) eye_sz_indx_ns = byte_sel_r * EYE_SZ_WIDTH;
  wire stg3_min_eye = eye_sz_cnt_r[eye_sz_indx_r+:EYE_SZ_WIDTH] ==
                        MIN_VALID_STG3_EYE_MINUS_ONE[EYE_SZ_WIDTH-1:0];

  reg [3:0] stg2_min_eyes, eyes_zero;
  integer ii;
  always @(*) for (ii=0; ii<4; ii=ii+1) begin
    if (BYTE_LANE_WITH_DK[ii] || N_DATA_LANES == 2 & ii >= 2) stg2_min_eyes[ii] = 1'b1;
    else stg2_min_eyes[ii] = eye_sz_cnt_r[ii*EYE_SZ_WIDTH+:EYE_SZ_WIDTH] ==
                               MIN_VALID_STG2_EYE[EYE_SZ_WIDTH-1:0];
    if (N_DATA_LANES == 2 && ii >= 2) eyes_zero[ii] = 1'b1;
    else eyes_zero[ii] = ~|eye_sz_cnt_r[ii*EYE_SZ_WIDTH+:EYE_SZ_WIDTH];
  end

  wire [EYE_SZ_CNTR_WIDTH-1:0] add_bit = {{EYE_SZ_CNTR_WIDTH-1{1'b0}}, 1'b1} << eye_sz_indx_r;
  wire [EYE_SZ_CNTR_WIDTH-1:0] eye_sz_cnt_inc = eye_sz_cnt_r + add_bit;

  reg [EYE_SZ_CNTR_WIDTH-1:0] eye_sz_cnt_dec;
  always @(*) begin
    eye_sz_cnt_dec = eye_sz_cnt_r;
    eye_sz_cnt_dec [eye_sz_indx_r+:EYE_SZ_WIDTH] =  
         eye_sz_cnt_r[eye_sz_indx_r+:EYE_SZ_WIDTH] + {EYE_SZ_WIDTH{1'b1}};
  end // always @ begin

  reg [EYE_SZ_CNTR_WIDTH-1:0] eye_sz_cnt_zero;
  always @(*) begin
    eye_sz_cnt_zero = eye_sz_cnt_r;
    eye_sz_cnt_zero [eye_sz_indx_r+:EYE_SZ_WIDTH] = {EYE_SZ_WIDTH{1'b0}}; 
  end
  
  reg kbyte_sel_ns, kbyte_sel_r;
  always @(posedge clk) kbyte_sel_r <= #TCQ kbyte_sel_ns;
  output kbyte_sel;
  assign kbyte_sel = kbyte_sel_r;
  
  reg inc_ns, inc_r;
  always @(posedge clk) inc_r <= #TCQ inc_ns;
  output inc;
  assign inc = inc_r;

  reg stg3_ns, stg3_r;
  always @(posedge clk) stg3_r <= #TCQ stg3_ns;
  output stg3;
  assign stg3 = stg3_r;

  reg po_en_ns, po_en_r;
  always @(posedge clk) po_en_r <= #TCQ po_en_ns;
  output po_en;
  assign po_en = po_en_r;
 
  reg adj_done_r;
  output adj_done;
  assign adj_done = adj_done_r;

  // 2'b00 corresponds to byte_sel 3.
  wire [1:0] lane_sel_cnt = byte_sel_r + 2'b01;
  wire lanes_done = (NUM_DEVICES == 1 || byte_sel_r[1])
                      ? lane_sel_cnt == N_DATA_LANES[1:0]
                      : byte_sel_r[0] ;

  input [N_DATA_LANES-1:0] lanes_solid;
  wire [3:0] ext_lanes_solid;
  generate if (N_DATA_LANES == 4) begin : four_data_lanes
    assign ext_lanes_solid = lanes_solid;
  end else begin : two_data_lanes
    assign ext_lanes_solid = {2'b0, lanes_solid};
  end endgenerate
  
  wire [3:0] klane_masked = BYTE_LANE_WITH_DK[3:0] & ext_lanes_solid;
  wire klane_solid = NUM_DEVICES == 1
                       ? |klane_masked
                       : kbyte_sel_r 
                          ? |klane_masked[3:2] 
                          : |klane_masked[1:0];

  wire [3:0] lane_mask = 4'b0001 << byte_sel_r;

  wire lane_solid = |(lane_mask & ext_lanes_solid);
  wire lane_stg2_min_eye = |(lane_mask & stg2_min_eyes);

  wire all_lanes_solid =  NUM_DEVICES == 1
                            ? &lanes_solid
                            : kbyte_sel_r 
                               ? &ext_lanes_solid[3:2]
                               : &ext_lanes_solid[1:0];

  wire all_lanes_solid_kmasked =  NUM_DEVICES == 1
                                    ? N_DATA_LANES == 4 ? &(lanes_solid | BYTE_LANE_WITH_DK[3:0]) : &(lanes_solid | BYTE_LANE_WITH_DK[1:0]) 
                                    : kbyte_sel_r 
                                       ? &(ext_lanes_solid[3:2] | BYTE_LANE_WITH_DK[3:2])
                                       : &(ext_lanes_solid[1:0] | BYTE_LANE_WITH_DK[1:0]);
   
  reg solid_valid_ns, solid_valid_r;
  always @(posedge clk) solid_valid_r <= #TCQ solid_valid_ns;

  // Need to mask out Klanes when looking for invalid.
  wire[3:0] lanes_invalid_kmasked = ext_lanes_solid & ~BYTE_LANE_WITH_DK[3:0];

  wire all_lanes_invalid = NUM_DEVICES ==1
                             ? ~|lanes_invalid_kmasked
                             : kbyte_sel_r
                                ? ~|lanes_invalid_kmasked[3:2]
                                : ~|lanes_invalid_kmasked[1:0];

  reg all_lanes_stg2_min_eyes_ns, all_lanes_stg2_min_eyes_r;
  always @(posedge clk) all_lanes_stg2_min_eyes_r <= #TCQ all_lanes_stg2_min_eyes_ns;
  always @(*) all_lanes_stg2_min_eyes_ns = NUM_DEVICES == 1
                                             ? &stg2_min_eyes
                                             : kbyte_sel_r 
                                                ? &stg2_min_eyes[3:2]
                                                : &stg2_min_eyes[1:0];

  wire is_klane = BYTE_LANE_WITH_DK[byte_sel_r];

  reg K_is_at_center_ns, K_is_at_center_r;
  always @(posedge clk) K_is_at_center_r <= #TCQ K_is_at_center_ns;
  output K_is_at_center;
  assign K_is_at_center = K_is_at_center_r;
  
  input [8:0] po_counter_read_val;
  input po_su_rdy;
  input po_adj_done;

  reg [5:0] klane_stg3_left_ns, klane_stg3_left_r;
  always @(posedge clk) klane_stg3_left_r <= #TCQ klane_stg3_left_ns;

  input [5:0] dbg_K_left_shift_right, dbg_K_right_shift_left;
  reg [5:0] k_left_cnt_ns, k_left_cnt_r;
  always @(posedge clk) k_left_cnt_r <= #TCQ k_left_cnt_ns;
  input [5:0] stg3_po_cntr;
  wire stg3_at_left = klane_stg3_left_r + dbg_K_left_shift_right == stg3_po_cntr;

  // Used only for SKIP_POC mode.
  reg [11:0] stg3_right_ns, stg3_right_r;
  always @(posedge clk) stg3_right_r <= #TCQ stg3_right_ns;
  wire [11:0] stg3_right_shifted = stg3_right_r >> (byte_sel_r[0] ? 6 : 0);
  wire [5:0] stg3_left_fudged = klane_stg3_left_r + dbg_K_left_shift_right;
  wire [5:0] computed_middle = (stg3_right_shifted[5:0] - stg3_left_fudged)/2 + stg3_left_fudged;
  wire computed_center_done = computed_middle == stg3_po_cntr;

  reg mmcm_edge_detect_rdy_ns, mmcm_edge_detect_rdy_r;
  always @(posedge clk) mmcm_edge_detect_rdy_r <= #TCQ mmcm_edge_detect_rdy_ns;
  output mmcm_edge_detect_rdy;
  assign mmcm_edge_detect_rdy = mmcm_edge_detect_rdy_r;
  
  reg ktap_at_left_edge_ns, ktap_at_left_edge_r;
  always @(posedge clk) ktap_at_left_edge_r <= #TCQ ktap_at_left_edge_ns;
  output ktap_at_left_edge;
  assign ktap_at_left_edge = ktap_at_left_edge_r;
  
  reg ktap_at_right_edge_ns, ktap_at_right_edge_r;
  always @(posedge clk) ktap_at_right_edge_r <= #TCQ ktap_at_right_edge_ns;
  output ktap_at_right_edge;
  assign ktap_at_right_edge = ktap_at_right_edge_r;

  input mmcm_edge_detect_done;
  input mmcm_lbclk_edge_aligned;
  input poc_backup;

  reg poc_backup_ns, poc_backup_r;
  always @(posedge clk) poc_backup_r <= #TCQ poc_backup_ns;

  reg [3:0] sm_ns, sm_r;
  always @(posedge clk) sm_r <= #TCQ sm_ns;

  // Provide nifty state names.  No load, synthesis should eliminate.  We'll
  // see about lint.
  reg [8*21-1:0] sm_ascii;

  always @(*) begin
  // Default next state assignments.
    eye_sz_cnt_ns = eye_sz_cnt_r;
    poc_backup_ns = poc_backup_r;
    sm_ns = sm_r;
    K_is_at_center_ns = K_is_at_center_r;
    k_left_cnt_ns = k_left_cnt_r;
    kbyte_sel_ns = kbyte_sel_r;
    klane_stg3_left_ns = klane_stg3_left_r;
    mmcm_edge_detect_rdy_ns = mmcm_edge_detect_rdy_r;
    ktap_at_left_edge_ns = ktap_at_left_edge_r;
    ktap_at_right_edge_ns = ktap_at_right_edge_r;
    byte_sel_ns = byte_sel_r;
    inc_ns = inc_r;
    solid_valid_ns = solid_valid_r;
    stg3_ns = stg3_r;
    stg3_right_ns = stg3_right_r;
    po_en_ns = 1'b0;
    adj_done_r = 1'b0;


    if (rst) begin
  // RESET next states
      eye_sz_cnt_ns = 'b0;
      sm_ns = /*AK("KLANE_2_VALID")*/4'd0;
      K_is_at_center_ns = 1'b0;
      kbyte_sel_ns = 1'b0;
      ktap_at_left_edge_ns = 1'b0;
      ktap_at_right_edge_ns = 1'b0;
      mmcm_edge_detect_rdy_ns = 1'b0;
      poc_backup_ns = 'b0;
      byte_sel_ns = 2'b0;
      stg3_ns = 1'b1;
      inc_ns = 1'b1;
       
    end else
      
  // State based actions and next states.       
      case (sm_r)

        /*AL("KLANE_2_VALID")*/4'd0:begin
	  sm_ascii = "KLANE_2_VALID";

	  po_en_ns = po_su_rdy && (~klane_solid || ~stg3_min_eye);

	  if (po_adj_done) begin
	    if (klane_solid) begin
	      if (stg3_min_eye) begin
	        sm_ns = /*AK("KLANE_2_EDGE")*/4'd1;
		inc_ns = 1'b0;
	      end else begin
		eye_sz_cnt_ns = eye_sz_cnt_inc;
		adj_done_r = 1'b1;
	      end
	    end else begin
              adj_done_r = 1'b1;
	      eye_sz_cnt_ns = eye_sz_cnt_zero;
	    end // else: !if(klane_solid)
	  end // if (po_adj_done)
	  
	end // case: 4'd0
   
       /*AL("KLANE_2_EDGE")*/4'd1:begin
	  sm_ascii = "KLANE_2_EDGE";
 
          if (po_su_rdy | po_adj_done) begin
            if (~eyes_zero[byte_sel_r]) begin
	      po_en_ns = 1'b1;
	      eye_sz_cnt_ns = eye_sz_cnt_dec;
	    end else begin
	      sm_ns = /*AK("NON_K_RIGHT_2_INVALID")*/4'd2;
	      klane_stg3_left_ns = po_counter_read_val[5:0];
	      byte_sel_ns = {kbyte_sel_r, 1'b0};
              stg3_ns = 1'b0;
	      inc_ns = 1'b1;
	    end
	  end // if (po_su_rdy | po_adj_done)
	  
       end // case: 4'd1
    
       /*AL("NON_K_RIGHT_2_INVALID")*/4'd2:begin
	  sm_ascii = "NON_K_RIGHT_2_INVALID";

          po_en_ns = po_su_rdy && lane_solid && ~is_klane;

	  if (po_adj_done) begin
	    if (all_lanes_invalid) begin
	      sm_ns = /*AK("NON_K_LEFT_2_VALID")*/4'd3;
	      byte_sel_ns = {kbyte_sel_r, 1'b0};
	      inc_ns = 1'b0;
	    end else begin
              if (lanes_done) begin
	        byte_sel_ns = {kbyte_sel_r, 1'b0};
                adj_done_r = 1'b1;
	      end else byte_sel_ns = byte_sel_r + 2'b01;
	    end
	  end // if (po_adj_done)
	  
	end // case: 4'd2

	/*AL("NON_K_LEFT_2_VALID")*/4'd3:begin
          sm_ascii = "NON_K_LEFT_2_VALID";
	    
      	  po_en_ns = po_su_rdy && ~is_klane && ~lane_solid | ~lane_stg2_min_eye;

	  if (po_adj_done) begin
	    if (all_lanes_stg2_min_eyes_r && all_lanes_solid_kmasked) begin
	      sm_ns = /*AK("NON_K_2_EDGE")*/4'd4;
	      byte_sel_ns = {kbyte_sel_r, 1'b0};
              inc_ns = 1'b1;
	    end else begin
	      if (~is_klane) begin
                if (lane_solid) begin
		  if (~lane_stg2_min_eye) eye_sz_cnt_ns = eye_sz_cnt_inc;
	 	end else eye_sz_cnt_ns = eye_sz_cnt_zero;
	      end
	      if (lanes_done) begin
	        byte_sel_ns = {kbyte_sel_r, 1'b0};
                adj_done_r = 1'b1;
	      end else byte_sel_ns = byte_sel_r + 2'b01;
	    end
	  end // if (po_adj_done)
	  
	end // case: 4'd3
	
	/*AL("NON_K_2_EDGE")*/4'd4:begin
          sm_ascii = "NON_K_2_EDGE";

	  solid_valid_ns = 'b0;

	  po_en_ns = po_su_rdy | po_adj_done && ~is_klane && ~eyes_zero[byte_sel_r];
	  
          if (po_en_ns) eye_sz_cnt_ns = eye_sz_cnt_dec;
	  
          if (po_adj_done) begin
	    if (eyes_zero[byte_sel_r]) byte_sel_ns = byte_sel_r + 2'b01;
	    if (&eyes_zero) begin
	      sm_ns = /*AK("SCAN_TO_MIN_RIGHT")*/4'd5;
	      eye_sz_cnt_ns = 'b0;
	      byte_sel_ns = {1'b0, kbyte_sel_r};
              stg3_ns = 1'b1;
	    end
	  end 
	  
	end // case: 4'd4
	  
	
	/*AL("SCAN_TO_MIN_RIGHT")*/4'd5:begin 
          sm_ascii = "SCAN_TO_MIN_RIGHT";

	  po_en_ns = po_su_rdy && all_lanes_solid || po_adj_done && ~stg3_min_eye;

	  if (po_en_ns && ~stg3_min_eye) eye_sz_cnt_ns = eye_sz_cnt_inc;

          k_left_cnt_ns = dbg_K_right_shift_left;	  

	  if (po_adj_done && stg3_min_eye) begin
	    solid_valid_ns = 'b1;
	    if (~all_lanes_solid && solid_valid_r) begin
	      sm_ns = /*AK("STG3_N_LEFT")*/4'd6;
	      eye_sz_cnt_ns = 'b0;
	      inc_ns = 1'b0;
	    end else adj_done_r = 1'b1;
	  end
	
	end // case: 4'd5
    
	/*AL("STG3_N_LEFT")*/4'd6:begin
	  sm_ascii = "STG3_N_LEFT";
	  
	  po_en_ns = po_su_rdy || po_adj_done && |k_left_cnt_r;
	  
          stg3_right_ns = po_counter_read_val[5:0];

	  k_left_cnt_ns = k_left_cnt_r - (po_adj_done ? 6'b1 : 6'b0);
	  
	  if (po_adj_done && ~|k_left_cnt_r) begin
	    sm_ns = /*AK("CENTER")*/4'd7;
	    ktap_at_right_edge_ns = 1'b1;  
	    if (SKIP_POC != "TRUE") mmcm_edge_detect_rdy_ns = 1'b1;
	  end
	  
	end // case: 4'd6

	// All centering with the POC happens here.  Note that the exit
	// from this state happens down at the bottom of the always block
	// in the POC state machine.
	/*AL("CENTER")*/4'd7:begin
	  sm_ascii = "CENTER";

	  if (SKIP_POC == "TRUE") begin
	    ktap_at_right_edge_ns = 1'b0;
	    if (computed_center_done) begin
	       sm_ns = /*AK("DONE")*/4'd8;
	       inc_ns = 1'b1;
	     end else po_en_ns = ktap_at_right_edge_r || po_adj_done;
	  end else
	    if (po_adj_done && ~mmcm_edge_detect_rdy) begin
	       if (ktap_at_left_edge_r && ~stg3_at_left) po_en_ns = 1'b1;
	       else begin
                 mmcm_edge_detect_rdy_ns = 1'b1;
	         inc_ns = 1'b1;
	       end
	    end
	  
	end // case: 4'd7
	
	/*AL("DONE")*/4'd8:begin
	  sm_ascii = "DONE";
          if (po_su_rdy) begin
	    po_en_ns = poc_backup_r;
	    poc_backup_ns = 1'b0;
	  end

	  if (po_adj_done) begin
	    if (NUM_DEVICES ==1 || kbyte_sel_r) begin
              K_is_at_center_ns = 1'b1;
	      adj_done_r = 1'b1;
	    end else begin
	      sm_ns = /*AK("KLANE_2_VALID")*/4'd0;
              kbyte_sel_ns = 1'b1;
	      byte_sel_ns = 2'b01;
	      inc_ns = 1'b1;
	    end
	  end
	end // case: 4'd8
	
      endcase // case (sm_r)

    // POC state machine.  Active when _rdy and _done are high.
    if (mmcm_edge_detect_rdy_r && mmcm_edge_detect_done) begin
      mmcm_edge_detect_rdy_ns = 1'b0;
      ktap_at_right_edge_ns = 1'b0;
      ktap_at_left_edge_ns = ktap_at_right_edge_r;
      po_en_ns = ~mmcm_lbclk_edge_aligned;
      if (mmcm_lbclk_edge_aligned) begin
        sm_ns = /*AK("DONE")*/4'd8;
	inc_ns = 1'b0;
      end
      poc_backup_ns = poc_backup;
    end // if (mmcm_edge_detect_rdy_r && mmcm_edge_detect_done)
    
  end // always @ begin

//  synthesis translate_off
  always @(sm_ascii) $display("PO_ADJ:%0t - k_byte_sel %b, %0s", $time(), kbyte_sel_r, sm_ascii);
  always @(posedge clk) if (mmcm_edge_detect_rdy_r && mmcm_edge_detect_done)
	  $display("PO_ADJ:%0t - k_byte_sel %b, ktap_right %b, ktap_left %b, aligned %b, stg3 %0d",
		   $time(),
		   kbyte_sel_r,
                   ktap_at_right_edge_r,                                                    
                   ktap_at_left_edge_r,
		   mmcm_lbclk_edge_aligned,
		   stg3_po_cntr);
  always @(K_is_at_center_r) $display("PO_ADJ:%0t - K_is_at_center %b", $time(), K_is_at_center_r);
//  synthesis translate_on

  output [191:128] dbg_wr_init;
   
  assign dbg_wr_init [130:128] = sm_r[2:0];
  assign dbg_wr_init [131] = 1'b0; 
  assign dbg_wr_init [133:132] = byte_sel_r[1:0];
  assign dbg_wr_init [134] = kbyte_sel_r;
  assign dbg_wr_init [135] = inc_r;
  assign dbg_wr_init [136] = stg3_r;
  assign dbg_wr_init [137] = po_en_r;
  assign dbg_wr_init [138] = adj_done_r;
  assign dbg_wr_init [139] = lanes_done;
  assign dbg_wr_init [140] = klane_solid;
  assign dbg_wr_init [141] = lane_solid;
  assign dbg_wr_init [142] = all_lanes_solid;
  assign dbg_wr_init [143] = all_lanes_invalid;
  assign dbg_wr_init [144] = is_klane;
  assign dbg_wr_init [150:145] = klane_stg3_left_r[5:0];
  assign dbg_wr_init [151] = K_is_at_center_r;
  assign dbg_wr_init [152] = mmcm_edge_detect_rdy_r;
  assign dbg_wr_init [153] = mmcm_edge_detect_done;   
  assign dbg_wr_init [154] = ktap_at_left_edge_r;
  assign dbg_wr_init [155] = ktap_at_right_edge_r;
  assign dbg_wr_init [156] = mmcm_lbclk_edge_aligned;
  assign dbg_wr_init [157] = poc_backup;
  assign dbg_wr_init [191:158] = 'b0;
  
endmodule // mig_7series_v2_4_qdr_phy_wr_po_adj

// Local Variables:
// verilog-autolabel-prefix: "4'd"
// End:
