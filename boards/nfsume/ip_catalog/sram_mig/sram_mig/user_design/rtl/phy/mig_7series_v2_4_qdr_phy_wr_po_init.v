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
// \   \   \/     Version            : 2.4 
//  \   \         Application        : MIG
//  /   /         Filename           : _v2_3_qdr_phy_wr_po_init.v
// /___/   /\     Date Last Modified : $date$
// \   \  /  \    Date Created       : Nov 12, 2008 
//  \___\/\___\
//
//Device: 7 Series
//Design: QDRII+ SRAM
//
//Purpose:
//    This module seems to be in charge of initializing the po stg2.
//
////////////////////////////////////////////////////////////////////////////////

`timescale 1ps/1ps

module mig_7series_v2_4_qdr_phy_wr_po_init #
  (parameter PO_COARSE_BYPASS     = "FALSE",
   parameter PO_ADJ_GAP           = 7,
   parameter TCQ                  = 100)
  (/*AUTOARG*/
  // Outputs
  po_cnt_dec, po_cnt_inc, po_dec_done, po_inc_done,
  // Inputs
  clk, rst_clk, io_fifo_rden_cal_done, po_counter_read_val
  );

  
  //System Signals
  input clk;
  input rst_clk;

  input io_fifo_rden_cal_done;
  input [8:0] po_counter_read_val;
  output reg po_cnt_dec, po_cnt_inc;
  output reg po_dec_done, po_inc_done;
                                          
  reg [8:0] po_rdval_cnt;
  reg [2:0] io_fifo_rden_cal_done_r;
  reg [3:0] po_gap_enforcer;

   //**************************************************************************
   // Decrement all phaser_outs to starting position
   //**************************************************************************
   
   always @(posedge clk) begin
     io_fifo_rden_cal_done_r[0] <= #TCQ io_fifo_rden_cal_done;
     io_fifo_rden_cal_done_r[1] <= #TCQ io_fifo_rden_cal_done_r[0];
     io_fifo_rden_cal_done_r[2] <= #TCQ io_fifo_rden_cal_done_r[1];
   end
   
   localparam PO_STG2_MIN = 30;  //  D Write Path's stage 2 PO are set to 30 to make room for
                                 //  deskew between byte lanes using PO FINE delay.
   
   //counter to determine how much to decrement
   always @(posedge clk) begin
     if (rst_clk) begin
       po_rdval_cnt    <= #TCQ 'd0;
     end else if (io_fifo_rden_cal_done_r[1] && 
                 ~io_fifo_rden_cal_done_r[2]) begin
       po_rdval_cnt    <= #TCQ po_counter_read_val;
     end else if ((po_rdval_cnt > PO_STG2_MIN) && PO_COARSE_BYPASS == "FALSE")  begin
       if (po_cnt_dec)
         po_rdval_cnt  <= #TCQ po_rdval_cnt - 1;
       else            
         po_rdval_cnt  <= #TCQ po_rdval_cnt;
     end else if ((po_rdval_cnt == 'd0) && PO_COARSE_BYPASS == "FALSE")begin
       po_rdval_cnt    <= #TCQ po_rdval_cnt;

     end else if ((po_rdval_cnt < PO_STG2_MIN) && PO_COARSE_BYPASS == "TRUE")  begin
       if (po_cnt_inc)
         po_rdval_cnt  <= #TCQ po_rdval_cnt + 1;
       else            
         po_rdval_cnt  <= #TCQ po_rdval_cnt;
     end else if ((po_rdval_cnt == 'd30) &&  PO_COARSE_BYPASS == "TRUE") begin
       po_rdval_cnt    <= #TCQ po_rdval_cnt;
     end
   end
   
   //Counter used to adjust the time between decrements
   always @ (posedge clk) begin
     if (rst_clk || po_cnt_dec || po_cnt_inc) begin
	   po_gap_enforcer <= #TCQ PO_ADJ_GAP; //8 clocks between adjustments for HW
	 end else if (po_gap_enforcer != 'b0) begin
	   po_gap_enforcer <= #TCQ po_gap_enforcer - 1;
	 end else begin
	   po_gap_enforcer <= #TCQ po_gap_enforcer; //hold value
	 end
   end
   
   wire po_adjust_rdy = (po_gap_enforcer == 'b0) ? 1'b1 : 1'b0;
   
   //decrement signal
   always @(posedge clk) begin
     if (rst_clk) begin
       po_cnt_dec      <= #TCQ 1'b0;
     end else if (io_fifo_rden_cal_done_r[2] && (po_rdval_cnt > PO_STG2_MIN) && po_adjust_rdy) begin
       po_cnt_dec      <= #TCQ ~po_cnt_dec;
     end else if (po_rdval_cnt == 'd0) begin
       po_cnt_dec      <= #TCQ 1'b0;
     end
   end
   
   //increment signal
   always @(posedge clk) begin
     if (rst_clk) 
       po_cnt_inc      <= #TCQ 1'b0;  
     else if (PO_COARSE_BYPASS == "FALSE")
       po_cnt_inc      <= #TCQ 1'b0;  
     else if (io_fifo_rden_cal_done_r[2] && (po_rdval_cnt < PO_STG2_MIN) && po_adjust_rdy) begin
       po_cnt_inc      <= #TCQ ~po_cnt_inc;
     end else if (po_rdval_cnt == 'd30) begin
       po_cnt_inc      <= #TCQ 1'b0;
     end
   end

   
   //indicate when finished
   always @(posedge clk) begin
     if (rst_clk) begin
         if ( PO_COARSE_BYPASS == "FALSE")
       po_dec_done <= #TCQ 1'b0;
         else
            po_dec_done <= #TCQ 1'b1;

     end else if (((po_cnt_dec == 'd1) && (po_rdval_cnt == 'd1)) ||
                  (io_fifo_rden_cal_done_r[2] && (po_rdval_cnt == PO_STG2_MIN))) begin

       po_dec_done <= #TCQ 1'b1;
     end
   end
  
  
   
   //indicate when finished
   always @(posedge clk) begin
     if (rst_clk) 
       po_inc_done <= #TCQ 1'b0;
	 else if (	PO_COARSE_BYPASS == "FALSE")
        po_inc_done <= #TCQ 1'b0;

     else if (io_fifo_rden_cal_done_r[2] && (po_rdval_cnt == PO_STG2_MIN)) begin

       po_inc_done <= #TCQ 1'b1;
     end
   end
          

endmodule // mig_7series_v2_4_qdr_phy_wr_po_init
