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
//  /   /         Filename: qdr_rld_phy_cmplx_rdcal.v
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
// 
//*****************************************************************************

`timescale 1ps/1ps

module mig_7series_v2_4_qdr_rld_phy_cmplx_rdcal #
  (parameter BRAM_ADDR_WIDTH    = 8,
   parameter CMPLX_RDCAL_EN     = "TRUE",
   parameter CONFIG_WL          = 3,
   parameter MEM_TYPE           = "RLD3",
   parameter N_DATA_LANES       = 4,
   parameter TCQ                = 100,
   parameter nCK_PER_CLK        = 2)
  (/*AUTOARG*/
  // Outputs
  cmplx_seq_done, cmplx_rd_data_valid, cmplx_rd_burst_bytes,
  cmplx_data, cmplx_seq_addr, cmplx_pause,
  // Inputs
  valid_latency, cmplx_wr_done, cmplx_victim_bit, cmplx_seq_rst, clk
  );

  //***************************************************************************

  function integer clogb2 (input integer size);
    begin
      size = size - 1;
      for (clogb2=1; size>1; clogb2=clogb2+1)
        size = size >> 1;
    end
  endfunction // clogb2

  localparam BRAM_DATA_WIDTH = 16;

  /*AUTOINPUT*/
  // Beginning of automatic inputs (from unused autoinst inputs)
  input			clk;			// To u_cmplx_rdcal_seq of mig_7series_v2_4_qdr_rld_phy_cmplx_rdcal_seq.v, ...
  input			cmplx_seq_rst;		// To u_cmplx_rdcal_seq of mig_7series_v2_4_qdr_rld_phy_cmplx_rdcal_seq.v, ...
  input [3:0]		cmplx_victim_bit;	// To u_cmplx_rdcal_cntlr of mig_7series_v2_4_qdr_rld_phy_cmplx_rdcal_cntlr.v
  input			cmplx_wr_done;		// To u_cmplx_rdcal_seq of mig_7series_v2_4_qdr_rld_phy_cmplx_rdcal_seq.v, ...
  input [4:0]		valid_latency;		// To u_cmplx_rdcal_cntlr of mig_7series_v2_4_qdr_rld_phy_cmplx_rdcal_cntlr.v
  // End of automatics
  /*AUTOOUTPUT*/
  // Beginning of automatic outputs (from unused autoinst outputs)
  output [N_DATA_LANES*nCK_PER_CLK*18-1:0] cmplx_data;// From u_cmplx_rdcal_cntlr of mig_7series_v2_4_qdr_rld_phy_cmplx_rdcal_cntlr.v
  output [71:0]		cmplx_rd_burst_bytes;	// From u_cmplx_rdcal_cntlr of mig_7series_v2_4_qdr_rld_phy_cmplx_rdcal_cntlr.v
  output		cmplx_rd_data_valid;	// From u_cmplx_rdcal_cntlr of mig_7series_v2_4_qdr_rld_phy_cmplx_rdcal_cntlr.v
  output		cmplx_seq_done;		// From u_cmplx_rdcal_seq of mig_7series_v2_4_qdr_rld_phy_cmplx_rdcal_seq.v
  // End of automatics
  /*AUTOWIRE*/
  // Beginning of automatic wires (for undeclared instantiated-module outputs)
  wire [BRAM_DATA_WIDTH-1:0] mem_out;		// From u_cmplx_rdcal_rom of mig_7series_v2_4_qdr_rld_phy_cmplx_rdcal_rom.v
  wire [BRAM_ADDR_WIDTH-1:0] rom_addr;		// From u_cmplx_rdcal_cntlr of mig_7series_v2_4_qdr_rld_phy_cmplx_rdcal_cntlr.v
  // End of automatics

  output [BRAM_ADDR_WIDTH:0] cmplx_seq_addr;
  output cmplx_pause;
  
  mig_7series_v2_4_qdr_rld_phy_cmplx_rdcal_seq #
    (/*AUTOINSTPARAM*/
     // Parameters
     .BRAM_ADDR_WIDTH			(BRAM_ADDR_WIDTH),
     .TCQ				(TCQ),
     .nCK_PER_CLK			(nCK_PER_CLK))
  u_cmplx_rdcal_seq
    (/*AUTOINST*/
     // Outputs
     .cmplx_pause			(cmplx_pause),
     .cmplx_seq_addr			(cmplx_seq_addr[BRAM_ADDR_WIDTH:0]),
     .cmplx_seq_done			(cmplx_seq_done),
     // Inputs
     .clk				(clk),
     .cmplx_seq_rst			(cmplx_seq_rst),
     .cmplx_wr_done			(cmplx_wr_done));
  
  mig_7series_v2_4_qdr_rld_phy_cmplx_rdcal_cntlr #
    (/*AUTOINSTPARAM*/
     // Parameters
     .BRAM_ADDR_WIDTH			(BRAM_ADDR_WIDTH),
     .BRAM_DATA_WIDTH			(BRAM_DATA_WIDTH),
     .CMPLX_RDCAL_EN			(CMPLX_RDCAL_EN),
     .CONFIG_WL				(CONFIG_WL),
     .MEM_TYPE				(MEM_TYPE),
     .N_DATA_LANES			(N_DATA_LANES),
     .TCQ				(TCQ),
     .nCK_PER_CLK			(nCK_PER_CLK))
  u_cmplx_rdcal_cntlr
    (/*AUTOINST*/
     // Outputs
     .cmplx_data			(cmplx_data[N_DATA_LANES*nCK_PER_CLK*2*9-1:0]),
     .cmplx_rd_burst_bytes		(cmplx_rd_burst_bytes[4*2*9-1:0]),
     .cmplx_rd_data_valid		(cmplx_rd_data_valid),
     .rom_addr				(rom_addr[BRAM_ADDR_WIDTH-1:0]),
     // Inputs
     .clk				(clk),
     .cmplx_pause			(cmplx_pause),
     .cmplx_seq_addr			(cmplx_seq_addr[BRAM_ADDR_WIDTH:0]),
     .cmplx_seq_rst			(cmplx_seq_rst),
     .cmplx_victim_bit			(cmplx_victim_bit[3:0]),
     .cmplx_wr_done			(cmplx_wr_done),
     .mem_out				(mem_out[BRAM_DATA_WIDTH-1:0]),
     .valid_latency			(valid_latency[4:0]));

  mig_7series_v2_4_qdr_rld_phy_cmplx_rdcal_rom #
    (/*AUTOINSTPARAM*/
     // Parameters
     .BRAM_ADDR_WIDTH			(BRAM_ADDR_WIDTH),
     .BRAM_DATA_WIDTH			(BRAM_DATA_WIDTH),
     .TCQ				(TCQ))
  u_cmplx_rdcal_rom
    (/*AUTOINST*/
     // Outputs
     .mem_out				(mem_out[BRAM_DATA_WIDTH-1:0]),
     // Inputs
     .rom_addr				(rom_addr[BRAM_ADDR_WIDTH-1:0]));
    
    

endmodule // mig_7series_v2_4_qdr_rld_phy_cmplx_rdcal

// Local Variables:
// verilog-library-directories:(".")
// verilog-library-extensions:(".v")
// End:
         
