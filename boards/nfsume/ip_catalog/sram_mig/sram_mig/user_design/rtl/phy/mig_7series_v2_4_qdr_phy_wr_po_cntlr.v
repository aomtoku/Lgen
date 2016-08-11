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
//  /   /         Filename           : _qdr_phy_wr_po_cntlr.v
// /___/   /\     Date Last Modified : $date$
// \   \  /  \    Date Created       : Nov 12, 2008 
//  \___\/\___\
//
//Device: 7 Series
//Design: QDRII+ SRAM
//
//Purpose:
//    Phaser out control for both the K byte stg3 and the stg2 non K byte lanes.
//    Abstracts phaser out control for the higher level logic.  Centralizes
//    various timing requirements.
//
//    Two primary timing parameters are command to enable setup and post enable
//    wait.  These can be set via parameters.
//
//    Basic idea is for this block to notice a change in the phaser out command
//    and start the po_wait counter with the po_setup bit set.  When this timer
//    times out signal that an enable is possible.  Continue counting to the PO_ADJ_GAP
//    time and signal done on po_adj_done.
//
////////////////////////////////////////////////////////////////////////////////

`timescale 1ps/1ps

module mig_7series_v2_4_qdr_phy_wr_po_cntlr #
  (parameter NUM_DEVICES          = 1,
   parameter PO_ADJ_GAP           = 15,
   parameter PO_SETUP             = 3,
   parameter TCQ                  = 100)
  (/*AUTOARG*/
  // Outputs
  pd_out_selected, wrcal_en, wrcal_byte_sel, wrcal_inc,
  wrcal_addr_cntrl, wrcal_adj_done, po_su_rdy, po_adj_done,
  wrcal_stg3, wrcal_po_en, stg3_po_cntr, dbg_wr_init,
  // Inputs
  clk, rst, pd_out, byte_sel, wrcal_adj_rdy, inc, stg3, po_en,
  adj_done, po_counter_read_val
  );

  function integer clogb2 (input integer size); // ceiling logb2
    begin
      size = size - 1;
      for (clogb2=1; size>1; clogb2=clogb2+1)
            size = size >> 1;
    end
  endfunction // clogb2

  localparam ONE = 1;
  localparam EIGHT = 8;
  localparam GAP_SU_WIDTH = clogb2(PO_ADJ_GAP < PO_SETUP ? PO_SETUP : PO_ADJ_GAP);
  localparam POW_WIDTH = GAP_SU_WIDTH < 4 ? 4 : GAP_SU_WIDTH;
  
  //System Signals
  input clk, rst;

  input [1:0] pd_out;
  input [1:0] byte_sel;
  output pd_out_selected;
  assign pd_out_selected = byte_sel[0] && NUM_DEVICES == 2 ? pd_out[1] : pd_out[0];

  input wrcal_adj_rdy;
  reg wrcal_adj_rdy_r;
  always @(posedge clk) wrcal_adj_rdy_r <= #TCQ wrcal_adj_rdy;
  output wrcal_en;
  assign wrcal_en = wrcal_adj_rdy;
  
  reg [1:0] wrcal_byte_sel_r, wrcal_byte_sel_r2; 
  always @(posedge clk) wrcal_byte_sel_r <= #TCQ byte_sel;
  always @(posedge clk) wrcal_byte_sel_r2 <= #TCQ wrcal_byte_sel_r;
  output [1:0] wrcal_byte_sel;
  assign wrcal_byte_sel = wrcal_byte_sel_r;
  
  input inc, stg3, po_en;
  reg wrcal_en_r, inc_r, stg3_r;
  always @(posedge clk) wrcal_en_r <= #TCQ wrcal_en;
  always @(posedge clk) inc_r <= #TCQ inc;
  always @(posedge clk) stg3_r <= #TCQ stg3;

  output wrcal_inc;
  assign wrcal_inc = inc_r;

  output wrcal_addr_cntrl;
  assign wrcal_addr_cntrl = 1'b0;

  input adj_done;
  reg wrcal_adj_done_r;
  always @(posedge clk) wrcal_adj_done_r <= adj_done;
  output wrcal_adj_done;
  assign wrcal_adj_done = wrcal_adj_done_r;
	   
  wire [4:0] next_command = {wrcal_byte_sel_r, inc, stg3};
  wire [4:0] current_command = {wrcal_byte_sel_r2, inc_r, stg3_r};
  wire new_command = ~wrcal_adj_done_r && |(next_command ^ current_command) | wrcal_en & ~wrcal_en_r;

  reg po_su_rdy_ns, po_su_rdy_r;
  always @(posedge clk) po_su_rdy_r <= #TCQ po_su_rdy_ns;
  output po_su_rdy;
  assign po_su_rdy = po_su_rdy_r;
 
  reg po_adj_done_ns, po_adj_done_r, po_adj_done_r2;
  always @(posedge clk) po_adj_done_r <= #TCQ po_adj_done_ns;
  always @(posedge clk) po_adj_done_r2 <= #TCQ po_adj_done_r;
  output po_adj_done;
  assign po_adj_done = po_adj_done_r2; 

  reg [POW_WIDTH-1:0] po_wait_ns, po_wait_r;
  always @(posedge clk) po_wait_r <= #TCQ po_wait_ns;
  reg po_setup_ns, po_setup_r;
  always @(posedge clk) po_setup_r <= #TCQ po_setup_ns;
  always @(*) begin
    if (rst) begin
      po_wait_ns = 'b0;
      po_setup_ns = 1'b0;
    end else begin
      po_wait_ns = po_wait_r;
      po_setup_ns = po_setup_r;
      if (|po_wait_r) po_wait_ns = po_wait_r - ONE[POW_WIDTH-1:0];
      if (new_command) begin
        po_wait_ns = PO_SETUP[POW_WIDTH-1:0];
        po_setup_ns = 1'b1;
      end
      if (po_su_rdy_r || po_en) begin
        po_setup_ns = 1'b0;
        po_wait_ns = PO_ADJ_GAP == 0 ? EIGHT[POW_WIDTH-1:0] : PO_ADJ_GAP[POW_WIDTH-1:0];
      end
    end // else: !if(rst)
  end // always @ po_su_rdy_ns

  always @(*) po_su_rdy_ns = po_setup_r && po_wait_ns == ONE[POW_WIDTH-1:0];
  always @(*) po_adj_done_ns = ~po_setup_r && po_wait_ns == ONE[POW_WIDTH-1:0];

  wire po_wait_one = po_wait_r == ONE[POW_WIDTH-1:0];

  reg wrcal_stg3_ns, wrcal_stg3_r;
  always @(posedge clk) wrcal_stg3_r <= #TCQ wrcal_stg3_ns;
  always @(*) wrcal_stg3_ns = stg3;
  output wrcal_stg3;
  assign wrcal_stg3 = wrcal_stg3_r;

  reg wrcal_po_en_r;
  always @(posedge clk) wrcal_po_en_r <= #TCQ po_en;
  output wrcal_po_en;
  assign wrcal_po_en = wrcal_po_en_r;

  // The following registers track the values held in the phaser outs.  Only stg3
  // used by the hardware.  Remainder optimized out by synthesis unless connected
  // to some debug ports.

  reg [5:0] stg3_0_ns, stg3_0_r, stg3_1_ns, stg3_1_r;
  reg [5:0] stg2_0_ns, stg2_0_r, stg2_1_ns, stg2_1_r, stg2_2_ns, stg2_2_r, stg2_3_ns, stg2_3_r;

  always @(posedge clk) stg3_0_r <= #TCQ stg3_0_ns;
  always @(posedge clk) stg3_1_r <= #TCQ stg3_1_ns;
  always @(posedge clk) stg2_0_r <= #TCQ stg2_0_ns;
  always @(posedge clk) stg2_1_r <= #TCQ stg2_1_ns;
  always @(posedge clk) stg2_2_r <= #TCQ stg2_2_ns;
  always @(posedge clk) stg2_3_r <= #TCQ stg2_3_ns;  

  wire set_po_reg_stg3 = po_adj_done_r2 && stg3;
  wire set_po_reg_stg2 = po_adj_done_r2 && ~stg3;

  input [8:0] po_counter_read_val;
  
  always @(*) stg3_0_ns = set_po_reg_stg3 && ~wrcal_byte_sel_r[0] ? po_counter_read_val[5:0] : stg3_0_r;
  always @(*) stg3_1_ns = set_po_reg_stg3 && wrcal_byte_sel_r[0] ? po_counter_read_val[5:0] : stg3_1_r;
  always @(*) stg2_0_ns = set_po_reg_stg2 && wrcal_byte_sel_r == 2'b00 ? po_counter_read_val[5:0] : stg2_0_r;
  always @(*) stg2_1_ns = set_po_reg_stg2 && wrcal_byte_sel_r == 2'b01 ? po_counter_read_val[5:0] : stg2_1_r;
  always @(*) stg2_2_ns = set_po_reg_stg2 && wrcal_byte_sel_r == 2'b10 ? po_counter_read_val[5:0] : stg2_2_r;
  always @(*) stg2_3_ns = set_po_reg_stg2 && wrcal_byte_sel_r == 2'b11 ? po_counter_read_val[5:0] : stg2_3_r;

  output [5:0] stg3_po_cntr;
  assign stg3_po_cntr = wrcal_byte_sel_r2[0] ? stg3_1_ns : stg3_0_ns;

  output [255:192] dbg_wr_init;

  assign dbg_wr_init[192] = pd_out_selected;
  assign dbg_wr_init[193] = wrcal_adj_rdy_r;
  assign dbg_wr_init[194] = wrcal_adj_done_r;
  assign dbg_wr_init[195] = po_su_rdy_r;
  assign dbg_wr_init[196] = po_adj_done;
  assign dbg_wr_init[202:197] = stg2_0_r;
  assign dbg_wr_init[208:203] = stg2_1_r;
  assign dbg_wr_init[214:209] = stg2_2_r;
  assign dbg_wr_init[220:215] = stg2_3_r;
  assign dbg_wr_init[226:221] = stg3_0_r;
  assign dbg_wr_init[232:227] = stg3_1_r;
  assign dbg_wr_init[255:233] = 'b0;
  
endmodule // mig_7series_v2_4_qdr_phy_wr_po_cntlr

// Local Variables:
// verilog-autolabel-prefix: "2'd"
// End:
