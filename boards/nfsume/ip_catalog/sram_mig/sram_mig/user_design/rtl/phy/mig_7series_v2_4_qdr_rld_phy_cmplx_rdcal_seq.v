//*****************************************************************************
// (c) Copyright 2009 - 2014 Xilinx, Inc. All rights reserved.
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
// \   \   \/     Version: %version
//  \   \         Application: MIG
//  /   /         Filename: qdr_rld_phy_cmplx_rdcal_seq.v
// /___/   /\     Date Last Modified: $Date:  $
// \   \  /  \    Date Created: 09/26/2014
//  \___\/\___\
//
//Device: 7 Series
//Design Name: qdr_rld_phy_cmplx_rdcal
//
//Reference:
//Revision History:
// 
//*****************************************************************************

`timescale 1ps/1ps

module mig_7series_v2_4_qdr_rld_phy_cmplx_rdcal_seq #
  (parameter BRAM_ADDR_WIDTH    = 8,
   parameter TCQ                = 100,
   parameter nCK_PER_CLK        = 2)
  (/*AUTOARG*/
  // Outputs
  cmplx_seq_addr, cmplx_seq_done, cmplx_pause,
  // Inputs
  clk, cmplx_wr_done, cmplx_seq_rst
  );

  //***************************************************************************

  function integer clogb2 (input integer size);
    begin
      size = size - 1;
      for (clogb2=1; size>1; clogb2=clogb2+1)
        size = size >> 1;
    end
  endfunction // clogb2

  input clk;

  localparam ONE = 1;
  localparam TWO = 2;
  localparam SEGS = 23;
  localparam SEGS_MINUS_1 = SEGS-1;
  localparam SEG_CNT_WIDTH = clogb2(SEGS);
  localparam MAX_SEG_LENGTH = 30;
  localparam SEG_LENGTH_CNTR_WIDTH = clogb2(MAX_SEG_LENGTH);
  localparam MAX_SEG_DIV2 = MAX_SEG_LENGTH/2 + MAX_SEG_LENGTH%2;
  // Plus 1 because counting in whole numbers.
  localparam PAUSE_WIDTH = clogb2(MAX_SEG_DIV2 + 1);

  // Length probably only needs to be 5 bits, but 8 bits will be more readable as
  // a flat parameter.
  localparam [SEGS*8-1:0] SEG_LENGTHS = 
    {8'd30,                                                          //  1
     8'd14, 8'd13, 8'd12, 8'd10, 8'd9, 8'd8, 8'd7, 8'd5, 8'd4, 8'd3, // 10
      8'd6,  8'd5, 8'd4,  8'd3,  8'd2, 8'd1,                         //  6
      8'd6,  8'd5, 8'd4,  8'd3,  8'd2, 8'd1};                        //  6
                                                                     // ==
                                                                     // 23

  reg [BRAM_ADDR_WIDTH:0] seq_addr_ns, seq_addr_r;
  always @(posedge clk) seq_addr_r <= #TCQ seq_addr_ns;
  output [BRAM_ADDR_WIDTH:0] cmplx_seq_addr;
  assign cmplx_seq_addr = seq_addr_r;

  reg [SEG_CNT_WIDTH-1:0] seg_num_ns, seg_num_r;
  always @(posedge clk) seg_num_r <= #TCQ seg_num_ns;
  
  reg [SEG_LENGTH_CNTR_WIDTH:0] seg_run_ns, seg_run_r;
  always @(posedge clk) seg_run_r <= #TCQ seg_run_ns;

  wire [SEGS*8-1:0] seg_length_shift = SEG_LENGTHS >> seg_num_r * 8;
  wire [SEG_LENGTH_CNTR_WIDTH-1:0] seg_length = seg_length_shift[SEG_LENGTH_CNTR_WIDTH-1:0];

  reg cmplx_seq_done_r;
  output cmplx_seq_done;
  assign cmplx_seq_done = cmplx_seq_done_r;

  reg [PAUSE_WIDTH-1:0] pause_cnt_ns, pause_cnt_r;
  always @(posedge clk) pause_cnt_r <= #TCQ pause_cnt_ns;
  reg pause_ns, pause_r;
  always @(*) pause_ns = |pause_cnt_ns;
  always @(posedge clk) pause_r <= #TCQ pause_ns;
  output cmplx_pause;
  assign cmplx_pause = pause_r;

  input cmplx_wr_done;
  input cmplx_seq_rst;

  always @(*) begin
    
    cmplx_seq_done_r = 1'b0;
    pause_cnt_ns = pause_cnt_r;
    seq_addr_ns = seq_addr_r;
    seg_num_ns = seg_num_r;
    seg_run_ns = seg_run_r;

    if (|pause_cnt_r) pause_cnt_ns = pause_cnt_r - ONE[PAUSE_WIDTH-1:0];
    
    if (cmplx_seq_rst) begin
      pause_cnt_ns = 'b0;
      seq_addr_ns = 'b0;
      seg_num_ns = 'b0;
      seg_run_ns = 'b0;
    end else begin
      if (~pause_r) begin
	seg_run_ns = seg_run_ns + (nCK_PER_CLK ==2
                                    ? ONE[SEG_LENGTH_CNTR_WIDTH:0]
                                    : TWO[SEG_LENGTH_CNTR_WIDTH:0]);
	seq_addr_ns = seq_addr_r + (nCK_PER_CLK == 2
                                     ? ONE[BRAM_ADDR_WIDTH:0]
			             : TWO[BRAM_ADDR_WIDTH:0]);
        if (seg_run_r[SEG_LENGTH_CNTR_WIDTH:1] == seg_length - ONE[SEG_LENGTH_CNTR_WIDTH-1:0] &&
            nCK_PER_CLK == 4 | seq_addr_r[0]) begin
	  seg_run_ns = 'b0;
	  pause_cnt_ns = cmplx_wr_done ? MAX_SEG_DIV2[PAUSE_WIDTH-1:0] : 'b0;
	  if (seg_num_r == SEGS_MINUS_1[SEG_CNT_WIDTH-1:0] &&
              nCK_PER_CLK == 4 | seq_addr_r[0]) begin
            cmplx_seq_done_r = 1'b1;
	    seq_addr_ns = 'b0;
	    seg_num_ns = 'b0;
	  end else seg_num_ns = seg_num_r + ONE[SEG_CNT_WIDTH-1:0];
        end
      end
    end // else: !if(cmplx_seq_rst)
  end // always @ for 

endmodule // mig_7series_v2_4_qdr_rld_phy_cmplx_rdcal_seq



   
         
