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
//  /   /         Filename: qdr_rld_phy_cmplx_rdcal_cntlr.v
// /___/   /\     Date Last Modified: $Date:  $
// \   \  /  \    Date Created: 09/26/2014
//  \___\/\___\
//
//Device: 7 Series
//Design Name: qdr_rld_phy_cmplx_rdcal_cntlr
//
//Reference:
//Revision History:
//
// Could possibly employ unused BRAM bits to indicate the "pause"... but
// for the read part two address/control streams are required.  Since
// there is only one BRAM, this is not be possible.  Implement two independent
// address/control generators.
// 
//*****************************************************************************

`timescale 1ps/1ps

module mig_7series_v2_4_qdr_rld_phy_cmplx_rdcal_cntlr #
  (parameter CMPLX_RDCAL_EN     = "TRUE",
   parameter CONFIG_WL          = 3,
   parameter BRAM_ADDR_WIDTH    = 8,
   parameter BRAM_DATA_WIDTH    = 16,
   parameter MEM_TYPE           = "RLD3",
   parameter N_DATA_LANES       = 4,
   parameter TCQ                = 100,
   parameter nCK_PER_CLK        = 2)
  (/*AUTOARG*/
  // Outputs
  cmplx_rd_data_valid, rom_addr, cmplx_rd_burst_bytes, cmplx_data,
  // Inputs
  clk, cmplx_victim_bit, cmplx_seq_addr, cmplx_pause, cmplx_seq_rst,
  cmplx_wr_done, valid_latency, mem_out
  );

  //***************************************************************************

  function integer clogb2 (input integer size);
    begin
      size = size - 1;
      for (clogb2=1; size>1; clogb2=clogb2+1)
        size = size >> 1;
    end
  endfunction // clogb2

  // In the _read_stage2_cal block, latency_cntr maxes at 31.  This
  // corresponds to 31-3 = 28 as max valid_latency.  valid_latency of
  // 19 corresponds to an equivalent read latency of 24 in this block.
  // valid_latency can advance 9 more steps from 19.  Therefore MAX_RD_LATENCY
  // in this block is then 24 + 9 = 33.
  localparam MAX_RD_LATENCY = 33;  
  localparam WR_LATENCY = CONFIG_WL + 1 + (nCK_PER_CLK == 4 ? -1 : 0);

  input clk;

  input [3:0] cmplx_victim_bit;
  input [BRAM_ADDR_WIDTH:0] cmplx_seq_addr;
  input cmplx_pause;
  input cmplx_seq_rst;
  input cmplx_wr_done;

  input [4:0] valid_latency;
  wire [5:0] lcl_rd_latency = {1'b0, valid_latency} + 6'd4;

  wire rd_data_valid = cmplx_wr_done && ~cmplx_pause && ~cmplx_seq_rst;
  
  reg [BRAM_ADDR_WIDTH:0] addr_shftr_r [0:MAX_RD_LATENCY-1];
  reg [3:0] victim_shftr_r [0:MAX_RD_LATENCY-1];
  reg [0:MAX_RD_LATENCY] data_valid_shftr_r ;
  reg [0:WR_LATENCY] wr_done_shftr_r;
  integer ii;
  always @(posedge clk) begin
    addr_shftr_r[0] <= #TCQ cmplx_seq_addr;
    victim_shftr_r[0] <= #TCQ cmplx_victim_bit;
    data_valid_shftr_r[0] <= #TCQ rd_data_valid;
    wr_done_shftr_r[0] = cmplx_wr_done;
    for (ii=1; ii<=MAX_RD_LATENCY; ii=ii+1)
      begin
      	data_valid_shftr_r[ii] <= #TCQ data_valid_shftr_r[ii-1];
	if (ii<MAX_RD_LATENCY) begin
	  addr_shftr_r[ii] <= #TCQ addr_shftr_r[ii-1];
	  victim_shftr_r[ii] <= #TCQ victim_shftr_r[ii-1];
	end
	if (ii <= WR_LATENCY) wr_done_shftr_r[ii] <= #TCQ wr_done_shftr_r[ii-1];
      end
  end

  wire [BRAM_ADDR_WIDTH:0] wr_addr = MEM_TYPE == "QDR2PLUS" ? cmplx_seq_addr : addr_shftr_r[WR_LATENCY-1];
  reg [BRAM_ADDR_WIDTH:0] rd_addr_ns, rd_addr_r;
  always @(posedge clk) rd_addr_r <= #TCQ rd_addr_ns;
  always @(*) rd_addr_ns = addr_shftr_r[lcl_rd_latency - 6'd2];

  wire [3:0] wr_victim_bit = victim_shftr_r[WR_LATENCY-1];
  wire [3:0] rd_victim_bit = victim_shftr_r[lcl_rd_latency - 6'b1];
  wire [3:0] victim_bit = cmplx_wr_done ? rd_victim_bit : wr_victim_bit;

  output cmplx_rd_data_valid;
  assign cmplx_rd_data_valid = data_valid_shftr_r[lcl_rd_latency];

  output [BRAM_ADDR_WIDTH-1:0] rom_addr;
  wire select_rd_addr = wr_done_shftr_r[WR_LATENCY];
  assign rom_addr = select_rd_addr ? rd_addr_r[BRAM_ADDR_WIDTH:1] : wr_addr[BRAM_ADDR_WIDTH:1];
  wire upper_half = select_rd_addr ? rd_addr_r[0] : wr_addr[0];
   
  input [BRAM_DATA_WIDTH-1:0] mem_out;
  reg [4*2*9-1:0] cmplx_burst_bytes_ns, cmplx_burst_bytes_r;
  always @(posedge clk) cmplx_burst_bytes_r <= #TCQ cmplx_burst_bytes_ns;
  output [4*2*9-1:0] cmplx_rd_burst_bytes;
  assign cmplx_rd_burst_bytes = cmplx_burst_bytes_r;
  reg [N_DATA_LANES*nCK_PER_CLK*2*9-1:0] cmplx_data_r;

  integer jj, kk, mm;
  always @(*) begin
    cmplx_burst_bytes_ns = 'b0;
    for (jj=0; jj<(nCK_PER_CLK == 4 ? 8 : 4); jj=jj+1) begin
      for (kk=0; kk<9; kk=kk+1)
	if (victim_bit == kk[3:0])
          cmplx_burst_bytes_ns[jj*9+kk] = mem_out[7-jj-4*upper_half];
	else cmplx_burst_bytes_ns[jj*9+kk] = mem_out[15-jj-4*upper_half];
      for (mm=0; mm<N_DATA_LANES; mm=mm+1)
	cmplx_data_r[N_DATA_LANES*jj*9+mm*9+:9] = cmplx_burst_bytes_r[jj*9+:9];
    end
  end
 
  output [N_DATA_LANES*nCK_PER_CLK*2*9-1:0] cmplx_data;
  assign cmplx_data = CMPLX_RDCAL_EN == "TRUE" 
           ? cmplx_data_r
           : 'b0;

endmodule // mig_7series_v2_4_qdr_rld_phy_cmplx_rdcal_cntlr

   
         
