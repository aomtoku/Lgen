//*****************************************************************************
// (c) Copyright 2009 - 2010 Xilinx, Inc. All rights reserved.
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
// /___/  \  /   Vendor             : Xilinx
// \   \   \/    Version            : 2.4
//  \   \        Application        : MIG
//  /   /        Filename           : sram_mig.veo
// /___/   /\    Date Last Modified : $Date: 2011/06/02 08:36:26 $
// \   \  /  \   Date Created       : Fri Jan 14 2011
//  \___\/\___\
//
// Device           : 7 Series
// Design Name      : QDRII+ SDRAM
// Purpose          : Template file containing code that can be used as a model
//                    for instantiating a CORE Generator module in a HDL design.
// Revision History :
//*****************************************************************************

// The following must be inserted into your Verilog file for this
// core to be instantiated. Change the instance name and port connections
// (in parentheses) to your own signal names.

//----------- Begin Cut here for INSTANTIATION Template ---// INST_TAG

sram_mig u_sram_mig (
  // Memory interface ports
  .qdriip_cq_p                     (qdriip_cq_p),  // input       [0:0]     qdriip_cq_p
  .qdriip_cq_n                     (qdriip_cq_n),  // input       [0:0]     qdriip_cq_n
  .qdriip_q                        (qdriip_q),  // input       [35:0]      qdriip_q
  .qdriip_k_p                      (qdriip_k_p),  // inout wire [0:0]     qdriip_k_p
  .qdriip_k_n                      (qdriip_k_n),  // inout wire [0:0]     qdriip_k_n
  .qdriip_d                        (qdriip_d),  // output wire [35:0]      qdriip_d
  .qdriip_sa                       (qdriip_sa),  // output wire [18:0]      qdriip_sa
  .qdriip_w_n                      (qdriip_w_n),  // output wire                       qdriip_w_n
  .qdriip_r_n                      (qdriip_r_n),  // output wire                       qdriip_r_n
  .qdriip_bw_n                     (qdriip_bw_n),  // output wire [3:0]        qdriip_bw_n
  .qdriip_dll_off_n                (qdriip_dll_off_n),  // output wire                       qdriip_dll_off_n
  .init_calib_complete              (init_calib_complete),  // output                                       init_calib_complete
  // Application interface ports
  .app_wr_cmd0                     (app_wr_cmd0),  // input                             app_wr_cmd0
  .app_wr_cmd1                     (app_wr_cmd1),  // input                             app_wr_cmd1
  .app_wr_addr0                    (app_wr_addr0),  // input  [18:0]           app_wr_addr0
  .app_wr_addr1                    (app_wr_addr1),  // input  [18:0]           app_wr_addr1
  .app_rd_cmd0                     (app_rd_cmd0),  // input                             app_rd_cmd0
  .app_rd_cmd1                     (app_rd_cmd1),  // input                             app_rd_cmd1
  .app_rd_addr0                    (app_rd_addr0),  // input  [18:0]           app_rd_addr0
  .app_rd_addr1                    (app_rd_addr1),  // input  [18:0]           app_rd_addr1
  .app_wr_data0                    (app_wr_data0),  // input  [143:0] app_wr_data0
  .app_wr_data1                    (app_wr_data1),  // input  [143:0] app_wr_data1
  .app_wr_bw_n0                    (app_wr_bw_n0),  // input  [15:0]   app_wr_bw_n0
  .app_wr_bw_n1                    (app_wr_bw_n1),  // input  [15:0]   app_wr_bw_n1
  .app_rd_valid0                   (app_rd_valid0),  // output wire                       app_rd_valid0
  .app_rd_valid1                   (app_rd_valid1),  // output wire                       app_rd_valid1
  .app_rd_data0                    (app_rd_data0),  // output wire [143:0] app_rd_data0
  .app_rd_data1                    (app_rd_data1),  // output wire [143:0] app_rd_data1
  .clk                             (clk),  // output wire                       clk
  .rst_clk                         (rst_clk),  // output wire                       rst_clk
  // System Clock Ports
  .sys_clk_i                       (sys_clk_i),  // input                                        sys_clk_i
  .sys_rst                        (sys_rst)  // input sys_rst
  );

// INST_TAG_END ------ End INSTANTIATION Template ---------

// You must compile the wrapper file sram_mig.v when simulating
// the core, sram_mig. When compiling the wrapper file, be sure to
// reference the XilinxCoreLib Verilog simulation library. For detailed
// instructions, please refer to the "CORE Generator Help".
