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
// \   \   \/     Version            : 1.4 
//  \   \         Application        : MIG
//  /   /         Filename           : qdr_phy_top.v
// /___/   /\     Date Last Modified : $date$
// \   \  /  \    Date Created       : Nov 18, 2008
//  \___\/\___\
//
//Device: 7 Series
//Design: QDRII+ SRAM
//
//Purpose:
//    This module
//  1. Instantiates all the modules used in the PHY
//
//Revision History:	12/10/2012  -Added logic to improve CQ_CQB capturing clock scheme.  
//                                  -Fixed dbg_pi_f_inc(dec),dbg_po_f_inc(dec) debug logic.
//			4/27/2013   - change  siganl "dbg_error_adj_latency" to "error_adj_latency". This signal will be asserted
//				      in FIXED_LATENCY_MODE == 1 and the target PHY_LATENCY is less than measured latency.
//                                  -  PI reset is connected to "rst_clk" which is stay asserted until CQ clock stable for 200 us.
////////////////////////////////////////////////////////////////////////////////


`timescale 1ps/1ps

(* X_CORE_INFO = "%migTag_%designType_7Series, %vivado_version" , CORE_GENERATION_INFO = "%designType_7Series,%migTag,{LANGUAGE=Verilog, SYNTHESIS_TOOL=%flowvendor, LEVEL=PHY,  NO_OF_CONTROLLERS=%noofcontrollers, %designWiseInfo}" *)
module mig_7series_v2_4_qdr_phy_top #
(
  parameter MEMORY_IO_DIR        = "UNIDIR",   // was named MEMORY_TYPE.
                                               // rename this to MEMORY_IO_DIR . 
                                               // this parameter is for the purpose of passing IO direction.
  
  parameter BUFG_FOR_OUTPUTS   = "OFF",	       //  This option is for design not using OCLKDELAY to shift
                                               //  K clock.  To use this option, a different infrastructer clock
                                               //  scheme is needed. Consult Xilinx for support.
  parameter PO_COARSE_BYPASS   = "FALSE",
  parameter SIMULATION         = "FALSE",
  parameter HW_SIM             = "NONE",
  parameter CPT_CLK_CQ_ONLY    = "TRUE",
  parameter ADDR_WIDTH         = 19,            //Adress Width
  parameter DATA_WIDTH         = 72,            //Data Width
  parameter BW_WIDTH           = 8,             //Byte Write Width
  parameter BURST_LEN          = 4,             //Burst Length
  
  parameter CLK_PERIOD         = 2500,          //Memory Clk Period (ps)
  parameter nCK_PER_CLK        = 2,
  parameter REFCLK_FREQ        = 200.0,         //Reference Clk Feq for IODELAYs
  parameter NUM_DEVICES        = 2,             //Memory Devices
  parameter N_DATA_LANES       = 4,
  parameter FIXED_LATENCY_MODE = 0,             //Fixed Latency for data reads
  parameter PHY_LATENCY        = 0,             //Value for Fixed Latency Mode
  parameter MEM_RD_LATENCY     = 2.0,            
  
  parameter CLK_STABLE         = 4000,          //Fabric clocks to wait for component PLL lock.
  parameter IODELAY_GRP        = "IODELAY_MIG", //May be assigned unique name 
                                                // when mult IP cores in design
  parameter MEM_TYPE           = "QDR2PLUS",    //Memory Type (QDR2PLUS, QDR2)
  parameter SIM_BYPASS_INIT_CAL= "OFF",         // "NONE" or "OFF" inhibit calibration SKIP.  Anything else
                                                // will cause all calibration to be skipped and default
                                                // values to be used.
  
  parameter IBUF_LPWR_MODE     = "OFF",         //Input buffer low power mode
  parameter IODELAY_HP_MODE    = "ON",          //IODELAY High Performance Mode
  parameter CQ_BITS            = 1,             //clog2(NUM_DEVICES - 1)   
  parameter Q_BITS             = 7,             //clog2(DATA_WIDTH - 1)
  parameter DEVICE_TAPS        = 32,            // Number of taps in the IDELAY chain
  parameter TAP_BITS           = 5,             // clog2(DEVICE_TAPS - 1)
  parameter BUFMR_DELAY        = 500,
  parameter MASTER_PHY_CTL     = 0,             // The bank number where master PHY_CONTROL resides
  parameter PLL_LOC            = 4'h1,
  parameter INTER_BANK_SKEW    = 0,
 
  // TAPSPERKCLK is the number of MMCM taps per "KCLK".  For QDR, KCLK is the component
  // KCLK.  TAPSPERKCLK depends on various ratios in the PLL/MMCMs.
  parameter TAPSPERKCLK        = 56,
  
  // five fields, one per possible I/O bank, 4 bits in each field, 
   // 1 per lane data=1/ctl=0
   parameter DATA_CTL_B0     = 4'hf,
   parameter DATA_CTL_B1     = 4'hf,
   parameter DATA_CTL_B2     = 4'hc,
   parameter DATA_CTL_B3     = 4'hf,
   parameter DATA_CTL_B4     = 4'hf,
   
   // this parameter specifies the location of the capture clock with respect
   // to read data.
   // Each byte refers to the information needed for data capture in the corresponding byte lane
   // Lower order nibble - is either 4'h1 or 4'h2. This refers to the capture clock in T1 or T2 byte lane
   // Higher order nibble - 4'h0 refers to clock present in the bank below the read data,
   //                       4'h1 refers to clock present in the same bank as the read data,
   //                       4'h2 refers to clock present in the bank above the read data.
   
   parameter CPT_CLK_SEL_B0 = 32'h12_12_11_11,
   parameter CPT_CLK_SEL_B1 = 32'h12_12_11_11,  
   parameter CPT_CLK_SEL_B2 = 32'h12_12_11_11,
   // defines the byte lanes in I/O banks being used in the interface
   // 1- Used, 0- Unused
   parameter BYTE_LANES_B0   = 4'b1111,
   parameter BYTE_LANES_B1   = 4'b1111,
   parameter BYTE_LANES_B2   = 4'b0011,
   parameter BYTE_LANES_B3   = 4'b0000,
   parameter BYTE_LANES_B4   = 4'b0000,
   
   parameter BYTE_GROUP_TYPE_B0 = 4'b1111,
   parameter BYTE_GROUP_TYPE_B1 = 4'b0000,
   parameter BYTE_GROUP_TYPE_B2 = 4'b0000,  
   parameter BYTE_GROUP_TYPE_B3 = 4'b0000, 
   parameter BYTE_GROUP_TYPE_B4 = 4'b0000, 
  
   
  // mapping for K clocks
  // this parameter needs to have an 8bit value per component, since the phy drives a K/K# clock pair to each memory it interfaces to
  // assuming a max. of 4 component interface. This parameter needs to be used in conjunction with NUM_DEVICES parameter which provides 
  // info. on the no. of components being interfaced to.
  // the 8 bit for each component is defined as follows: 
  // [7:4] - bank no. ; [3:0] - byte lane no. 
  
   // for now, PHY only supports a 3 component interface.
  
   parameter K_MAP  = 48'h00_00_00_00_00_11,
   parameter CQ_MAP = 48'h00_00_00_00_00_01,
  
  // mapping for CQ/CQ# clocks
  // this parameter needs to have a 4bit value per component. This will be 4 bits per component
  // the same parameter is applicable to CQ# clocks as well, since they both need to be placed in the same bank.
  // assuming a max. of 4 component interface. This parameter needs to be used in conjunction with NUM_DEVICES parameter which provides 
  // info. on the no. of components being interfaced to.
  // the 4 bit for each component is defined as follows: 
  // [3:0] - bank no. of the map
  
  // for now, PHY only supports a 3 component interface.
    
   // Mapping for address and control signals
   // The parameter contains the byte_lane and bit position information for 
   // a control signal. 
   // Each add/ctl bit will have 12 bits the assignments are
   // [3:0] - Bit position within a byte lane . 
   // [7:4] - Byte lane position within a bank. [5:4] have the byte lane position. 
    // [7:6] tied to 0 
   // [11:8] - Bank position. [10:8] have the bank position. [11] tied to zero . 
   
   parameter RD_MAP = 12'h218,
   parameter WR_MAP = 12'h219,
  
  // supports 22 bits of address bits 
   
   parameter ADD_MAP = 264'h217_216_21B_21A_215_214_213_212_211_210_209_208_207_206_20B_20A_205_204_203_202_201_200,
   
   parameter ADDR_CTL_MAP = 32'h00_00_21_20,  // for a max. of 3 banks
   
   //One parameter per data byte - 9bits per byte = 9*12
   parameter D0_MAP       = 108'h008_007_006_005_004_003_002_001_000,//byte 0 
   parameter D1_MAP       = 108'h008_007_006_005_004_003_002_001_000,//byte 1
   parameter D2_MAP       = 108'h008_007_006_005_004_003_002_001_000,//byte 2
   parameter D3_MAP       = 108'h008_007_006_005_004_003_002_001_000,//byte 3
   parameter D4_MAP       = 108'h008_007_006_005_004_003_002_001_000,//byte 4
   parameter D5_MAP       = 108'h008_007_006_005_004_003_002_001_000,//byte 5
   parameter D6_MAP       = 108'h008_007_006_005_004_003_002_001_000,//byte 6
   parameter D7_MAP       = 108'h008_007_006_005_004_003_002_001_000,//byte 7
   
   // byte writes for bytes 0 to 7 - 8*12
   parameter BW_MAP       = 96'h007_006_005_004_003_002_001_000,
   
   //One parameter per data byte - 9bits per byte = 9*12
   parameter Q0_MAP       = 108'h008_007_006_005_004_003_002_001_000,//byte 0 
   parameter Q1_MAP       = 108'h008_007_006_005_004_003_002_001_000,//byte 1
   parameter Q2_MAP       = 108'h008_007_006_005_004_003_002_001_000,//byte 2
   parameter Q3_MAP       = 108'h008_007_006_005_004_003_002_001_000,//byte 3
   parameter Q4_MAP       = 108'h008_007_006_005_004_003_002_001_000,//byte 4
   parameter Q5_MAP       = 108'h008_007_006_005_004_003_002_001_000,//byte 5
   parameter Q6_MAP       = 108'h008_007_006_005_004_003_002_001_000,//byte 6
   parameter Q7_MAP       = 108'h008_007_006_005_004_003_002_001_000,//byte 7
   
   // for each bank (B0 - B4), the validity of each bit within the byte lane is denoted by the following parameters
   // a 1 represents that the bit is chosen, a 0 represents an unused pin. 
   
   parameter BIT_LANES_B0    = 48'h1ff_3fd_1ff_1ff,            
   parameter BIT_LANES_B1    = 48'h000_000_000_000, 
   parameter BIT_LANES_B2    = 48'h000_000_000_000,
   parameter BIT_LANES_B3    = 48'h000_000_000_000, 
   parameter BIT_LANES_B4    = 48'h000_000_000_000,
  
   parameter DEBUG_PORT  = "ON", // Debug using Chipscope controls 
   parameter TCQ          = 100  //Register Delay
)
(

    // clocking and reset
  input                           clk,            // Fabric logic clock
  input                           rst,            // fabric reset based on PLL lock and system input reset.
  input                           clk_ref,        // Idelay_ctrl reference clock
                                                  // To hard PHY (external source)
  input                           clk_mem,        // Memory clock to hard PHY
  input                           freq_refclk,
  input                           pll_lock,
  input                           sync_pulse,
  
  input                           psdone,     
  output			  psen,       
  output   		          psincdec,	 

  input                           poc_sample_pd,
  output                          ref_dll_lock,
  input                           rst_phaser_ref,
  input                           mmcm_fshift_clk,
  output wire                     rst_clk,          //generated based on read clocks being stable
  input                           iddr_rst,
     
  //PHY Write Path Interface
  input                           wr_cmd0,          //wr command 0
  input                           wr_cmd1,          //wr command 1
  input       [ADDR_WIDTH-1:0]    wr_addr0,         //wr address 0
  input       [ADDR_WIDTH-1:0]    wr_addr1,         //wr address 1
  input                           rd_cmd0,          //rd command 0
  input                           rd_cmd1,          //rd command 1
  input       [ADDR_WIDTH-1:0]    rd_addr0,         //rd address 0
  input       [ADDR_WIDTH-1:0]    rd_addr1,         //rd address 1
  input       [DATA_WIDTH*2-1:0]  wr_data0,         //user write data 0
  input       [DATA_WIDTH*2-1:0]  wr_data1,         //user write data 1
  input       [BW_WIDTH*2-1:0]    wr_bw_n0,         //user byte writes 0
  input       [BW_WIDTH*2-1:0]    wr_bw_n1,         //user byte writes 1
  

  //PHY Read Path Interface 
  output wire                     init_calib_complete, //Calibration complete	
  output                          error_adj_latency,  // stage 2 cal latency adjustment error  

  output wire                     rd_valid0,        //Read valid for rd_data0
  output wire                     rd_valid1,        //Read valid for rd_data1
  output wire [DATA_WIDTH*2-1:0]  rd_data0,         //Read data 0
  output wire [DATA_WIDTH*2-1:0]  rd_data1,         //Read data 1


  //Memory Interface
  output wire                     qdr_dll_off_n,    //QDR - turn off dll in mem
  inout wire [NUM_DEVICES-1:0]    qdr_k_p,          //QDR clock K
  inout wire [NUM_DEVICES-1:0]    qdr_k_n,          //QDR clock K#
  output wire [ADDR_WIDTH-1:0]    qdr_sa,           //QDR Memory Address
  output wire                     qdr_w_n,          //QDR Write 
  output wire                     qdr_r_n,          //QDR Read
  output wire [BW_WIDTH-1:0]      qdr_bw_n,         //QDR Byte Writes to Mem
  output wire [DATA_WIDTH-1:0]    qdr_d,            //QDR Data to Memory
  input       [DATA_WIDTH-1:0]    qdr_q,            //QDR Data from Memory
  input       [NUM_DEVICES-1:0]   qdr_cq_p,         //QDR echo clock CQ 
  input       [NUM_DEVICES-1:0]   qdr_cq_n,         //QDR echo clock CQ#
  
  //Chipscope Debug Signals
  output poc_error,
  output wire [7:0]                 dbg_phy_status,          // phy status
  output [8:0]                      dbg_po_counter_read_val,
  output [5:0]                      dbg_pi_counter_read_val,
  input                             dbg_phy_init_wr_only,
  input                             dbg_phy_init_rd_only,
  input                             dbg_po_stg3_sel, 
  input                             dbg_po_sel,	
  input [CQ_BITS-1:0]               dbg_byte_sel,
  input [Q_BITS-1:0]                dbg_bit_sel,
  input                             dbg_pi_f_inc,
  input                             dbg_pi_f_dec,
  input                             dbg_po_f_inc,
  input                             dbg_po_f_dec,
  input                             dbg_idel_up_all,
  input                             dbg_idel_down_all,
  input                             dbg_idel_up,
  input                             dbg_idel_down,
  output [TAP_BITS*DATA_WIDTH-1:0]  dbg_idel_tap_cnt,
  output [TAP_BITS-1:0]             dbg_idel_tap_cnt_sel,
  output reg [2:0]                  dbg_select_rdata,
  output reg [8:0]                  dbg_align_rd0_r,
  output reg [8:0]                  dbg_align_rd1_r,
  output reg [8:0]                  dbg_align_fd0_r,
  output reg [8:0]                  dbg_align_fd1_r,
  output [DATA_WIDTH-1:0]           dbg_align_rd0,
  output [DATA_WIDTH-1:0]           dbg_align_rd1,
  output [DATA_WIDTH-1:0]           dbg_align_fd0,
  output [DATA_WIDTH-1:0]           dbg_align_fd1,
  output [255:0]                    dbg_mc_phy,
  output [107:0]                    dbg_PO_read_value,
  output [47:0]                     dbg_calib_po_tstpoint,
  output [2:0]                      dbg_byte_sel_cnt,
  output [1:0]                      dbg_phy_wr_cmd_n,       //cs debug - wr command
  output [ADDR_WIDTH*4-1:0]         dbg_phy_addr,          //cs debug - address
  output [1:0]                      dbg_phy_rd_cmd_n,       //cs debug - rd command
  output [DATA_WIDTH*4-1:0]         dbg_phy_wr_data,        //cs debug - wr data
  output [255:0]                    dbg_wr_init ,           //cs debug - initialization logic
  output [1023:0]                   dbg_rd_stage1_cal,      // stage 1 cal debug
  output [127:0]                    dbg_stage2_cal,         // stage 2 cal debug
  output [4:0]                      dbg_valid_lat,          // latency of the system
  output [N_DATA_LANES-1:0]         dbg_inc_latency,        // increase latency for dcb
  output [N_DATA_LANES-1:0]         dbg_error_max_latency,  // stage 2 cal max latency error
  output                            dbg_oclkdly_clk,
  output [1023:0]                   dbg_poc,
  input [5:0]                       dbg_K_left_shift_right,
  input [5:0]                       dbg_K_right_shift_left,
  input                             dbg_cmplx_wr_loop,
  input                             dbg_cmplx_rd_loop,
  input [2:0]                       dbg_cmplx_rd_lane
);
  
  parameter CMPLX_RDCAL_EN = (CLK_PERIOD > 2500 || !(SIM_BYPASS_INIT_CAL == "OFF" || SIM_BYPASS_INIT_CAL == "NONE"))
                              ? "FALSE" : "TRUE";

  // When set "TRUE", turns off POC centering and uses a simple KCLK centering based
  // on the middle of the discovered write data valid window in phaser out taps.
  parameter SKIP_POC = "FALSE";

  //Starting values for counters used to enforce minimum time between PO
  //adjustments (15 max value supported here)
  localparam PO_ADJ_GAP = SIMULATION == "TRUE"  ? 7 : 15;
  
  // RDLVL_SAMPS - The number of samples for both simple and complex cal.  Note that complex cal
  // samples are defined as a the sequence across the RAM width.  Each "sample" is pretty large.
  // PI_PHY_WAIT - Fabric clocks to wait following a PI update before sampling the data.
  // PI_E2E_WAIT - Fabric clocks to wait from one PI enable to the next.
  // PI_SU_WAIT  - Fabric clocks to wait from changing PI command to PI enable.
  // RDLVL_LOW_RES_MODE - Caused the IODELAY to increment by 4 and the PI to increment by 8.  Useful
  // for speeding up simulations when the data window is perfect and hi resolution is not required.
  // RDLVL_CMPLX_SEQ_LENGTH - Does not alter the pattern written or read from memory.  Causes _rdlvl to
  // only look at the subsequence of the given length.  Very useful for speeding up simulations.
  // MMCM_SAMP_WAIT - How long does POC wait following a PSEN to look at a sample result.
  // POC_SAMPLES - Number of samples in whole numbers.  Ie 0 = one sample.
  // PD_SIM_CAL_OPTION - Causes POC phase detector to place X's on its output when the sample might
  // be metastable.  Only useful for simulation.
  // WRCAL_SAMPLES - Write calibration sample count.
  // WRCAL_PCT_SAMPS_SOLID - Write calibration sample solid threshold.
  
  localparam RDLVL_SAMPS            = HW_SIM == "FAST" ? 1    : HW_SIM == "REGRESS" ? 5     : 50;
  localparam PI_PHY_WAIT            = 17;
  localparam PI_E2E_WAIT     	    = nCK_PER_CLK == 4 ? 4 : 8;
  localparam PI_SU_WAIT	   	    = 8;
  localparam RDLVL_LOW_RES_MODE     = HW_SIM == "FAST" ? "ON" : HW_SIM == "REGRESS" ? "OFF" : "OFF";
  localparam RDLVL_CMPLX_SEQ_LENGTH = HW_SIM == "FAST" ? 1    : HW_SIM == "REGRESS" ? 1     : 157;
  localparam MMCM_SAMP_WAIT         = HW_SIM == "FAST" ? 10   : HW_SIM == "REGRESS" ? 10    : 256;
  localparam POC_SAMPLES            = HW_SIM == "FAST" ? 0    : HW_SIM == "REGRESS" ? 1     : 2048;
  localparam PD_SIM_CAL_OPTION      = HW_SIM == "FAST" ? "NOT_NONE" : HW_SIM == "REGRESS" ? "NOT_NONE" : "NONE";
  localparam WRCAL_SAMPLES          = HW_SIM == "FAST" ? 4    : HW_SIM == "REGRESS" ? 4     : 2048;
  localparam WRCAL_PCT_SAMPS_SOLID  = HW_SIM == "FAST" ? 70   : HW_SIM == "REGRESS" ? 70    : 95;

  // These values are used by _rdlvl when SIM_BYPASS_INIT_CAL == "SKIP".  They should be sufficient
  // when simulations are done without noise, jitter etc.
  localparam SIM_BYPASS_PI_CENTER = 20;
  localparam SIM_BYPASS_IDELAY = 8;
  localparam CENTER_COMP_MODE = HW_SIM == "NONE"  ? "ON"  : "OFF";

  // Causes write data calibration to be skipped.  Use PO defaults set up in mc_phy.
  localparam WRCAL_DEFAULT = (!(SIM_BYPASS_INIT_CAL == "OFF" || SIM_BYPASS_INIT_CAL == "NONE") || CLK_PERIOD > 2500) ? "TRUE" : "FALSE";
   
  localparam   N_LANES           = (0+BYTE_LANES_B0[0]) + (0+BYTE_LANES_B0[1]) + (0+BYTE_LANES_B0[2]) + (0+BYTE_LANES_B0[3]) +  (0+BYTE_LANES_B1[0]) + (0+BYTE_LANES_B1[1]) + (0+BYTE_LANES_B1[2]) 
                                              + (0+BYTE_LANES_B1[3])  + (0+BYTE_LANES_B2[0]) + (0+BYTE_LANES_B2[1]) + (0+BYTE_LANES_B2[2]) + (0+BYTE_LANES_B2[3]); 
  localparam   PHY_0_IS_LAST_BANK   = ((BYTE_LANES_B1 != 0) || (BYTE_LANES_B2 != 0) || (BYTE_LANES_B3 != 0) || (BYTE_LANES_B4 != 0)) ?  "FALSE" : "TRUE";
  localparam   PHY_1_IS_LAST_BANK   = ((BYTE_LANES_B1 != 0) && ((BYTE_LANES_B2 != 0) || (BYTE_LANES_B3 != 0) || (BYTE_LANES_B4 != 0))) ?  "FALSE" : ((PHY_0_IS_LAST_BANK) ? "FALSE" : "TRUE");
  localparam   PHY_2_IS_LAST_BANK   = (BYTE_LANES_B2 != 0) && ((BYTE_LANES_B3 != 0) || (BYTE_LANES_B4 != 0)) ?  "FALSE" : ((PHY_0_IS_LAST_BANK || PHY_1_IS_LAST_BANK) ? "FALSE" : "TRUE");
  localparam HIGHEST_BANK        = (BYTE_LANES_B4 != 0 ? 5 : (BYTE_LANES_B3 != 0 ? 4 : (BYTE_LANES_B2 != 0 ? 3 :  (BYTE_LANES_B1 != 0  ? 2 : 1))));
  localparam HIGHEST_LANE_B0     =                        ((PHY_0_IS_LAST_BANK == "FALSE") ? 4 : BYTE_LANES_B0[3] ? 4 : BYTE_LANES_B0[2] ? 3 : BYTE_LANES_B0[1] ? 2 : BYTE_LANES_B0[0] ? 1 : 0);
  localparam HIGHEST_LANE_B1     = (HIGHEST_BANK > 2) ? 4 : ( BYTE_LANES_B1[3] ? 4 : BYTE_LANES_B1[2] ? 3 : BYTE_LANES_B1[1] ? 2 : BYTE_LANES_B1[0] ? 1 : 0);
  localparam HIGHEST_LANE_B2     = (HIGHEST_BANK > 3) ? 4 : ( BYTE_LANES_B2[3] ? 4 : BYTE_LANES_B2[2] ? 3 : BYTE_LANES_B2[1] ? 2 : BYTE_LANES_B2[0] ? 1 : 0);
  localparam HIGHEST_LANE_B3     = 0;
  localparam HIGHEST_LANE_B4     = 0;

  localparam HIGHEST_LANE        = (HIGHEST_LANE_B4 != 0) ? (HIGHEST_LANE_B4+16) : ((HIGHEST_LANE_B3 != 0) ? (HIGHEST_LANE_B3 + 12) : 
                                           ((HIGHEST_LANE_B2 != 0) ? (HIGHEST_LANE_B2 + 8)  : ((HIGHEST_LANE_B1 != 0) ? (HIGHEST_LANE_B1 + 4) : HIGHEST_LANE_B0)));
 
  localparam N_CTL_LANES = ((0+(!DATA_CTL_B0[0]) & BYTE_LANES_B0[0]) +
                           (0+(!DATA_CTL_B0[1]) & BYTE_LANES_B0[1]) +
                           (0+(!DATA_CTL_B0[2]) & BYTE_LANES_B0[2]) +
                           (0+(!DATA_CTL_B0[3]) & BYTE_LANES_B0[3])) +
                           ((0+(!DATA_CTL_B1[0]) & BYTE_LANES_B1[0]) +
                           (0+(!DATA_CTL_B1[1]) & BYTE_LANES_B1[1]) +
                           (0+(!DATA_CTL_B1[2]) & BYTE_LANES_B1[2]) +
                           (0+(!DATA_CTL_B1[3]) & BYTE_LANES_B1[3])) +
                           ((0+(!DATA_CTL_B2[0]) & BYTE_LANES_B2[0]) +
                           (0+(!DATA_CTL_B2[1]) & BYTE_LANES_B2[1]) +
                           (0+(!DATA_CTL_B2[2]) & BYTE_LANES_B2[2]) +
                           (0+(!DATA_CTL_B2[3]) & BYTE_LANES_B2[3])) +
                           ((0+(!DATA_CTL_B3[0]) & BYTE_LANES_B3[0]) +
                           (0+(!DATA_CTL_B3[1]) & BYTE_LANES_B3[1]) +
                           (0+(!DATA_CTL_B3[2]) & BYTE_LANES_B3[2]) +
                           (0+(!DATA_CTL_B3[3]) & BYTE_LANES_B3[3])) +
                           ((0+(!DATA_CTL_B4[0]) & BYTE_LANES_B4[0]) +
                           (0+(!DATA_CTL_B4[1]) & BYTE_LANES_B4[1]) +
                           (0+(!DATA_CTL_B4[2]) & BYTE_LANES_B4[2]) +
                           (0+(!DATA_CTL_B4[3]) & BYTE_LANES_B4[3]));
                           
  // Localparam to have the byte lane information for each byte 
  localparam CALIB_BYTE_LANE = {Q7_MAP[5:4],Q6_MAP[5:4],
                              Q5_MAP[5:4],Q4_MAP[5:4],Q3_MAP[5:4],
                              Q2_MAP[5:4],Q1_MAP[5:4],Q0_MAP[5:4]};
  // localparam to have the bank information for each byte 
  localparam CALIB_BANK = {Q7_MAP[10:8],Q6_MAP[10:8],
                           Q5_MAP[10:8],Q4_MAP[10:8],Q3_MAP[10:8],
                           Q2_MAP[10:8],Q1_MAP[10:8],Q0_MAP[10:8]}; 
                
  // Localparam to have the byte lane information for each write data byte 
  localparam OCLK_CALIB_BYTE_LANE = {D7_MAP[5:4],D6_MAP[5:4],
                              	     D5_MAP[5:4],D4_MAP[5:4],D3_MAP[5:4],
                                     D2_MAP[5:4],D1_MAP[5:4],D0_MAP[5:4]};
  // localparam to have the bank information for each write data byte 
  localparam OCLK_CALIB_BANK = {D7_MAP[10:8],D6_MAP[10:8],
                           	D5_MAP[10:8],D4_MAP[10:8],D3_MAP[10:8],
                           	D2_MAP[10:8],D1_MAP[10:8],D0_MAP[10:8]}; 
                
  localparam PRE_FIFO          = "TRUE";
  localparam PO_FINE_DELAY  = (PO_COARSE_BYPASS == "FALSE") ? 60:0;
  localparam PI_FINE_DELAY     = 33;
  
  
   // amount of total delay required for Address and controls                               
  localparam ADDR_CTL_90_SHIFT = 
    CLK_PERIOD > 2500 
       ? (MEMORY_IO_DIR == "UNIDIR" && BURST_LEN == 2) ? 0 : (CLK_PERIOD/4)
       : (MEMORY_IO_DIR == "UNIDIR" && BURST_LEN == 2) ? CLK_PERIOD/8 : (CLK_PERIOD/4);

  
  localparam ADDR_CTL_BANK = ADDR_CTL_MAP[7:4];
  
  // Function to generate IN/OUT parameters from BYTE_LANES parameter
  function [47:0] calc_phy_bitlanes_in_out;
    input [47:0]  bit_lanes;
    input [3:0]   byte_type;
    input         calc_phy_in;
    integer       z, y;
    begin
      calc_phy_bitlanes_in_out = 'b0;
      for (z = 0; z < 4; z = z + 1) begin
        for (y = 0; y < 12; y = y + 1) begin
          if ((byte_type[z])== 1) //INPUT
            if (calc_phy_in)
              calc_phy_bitlanes_in_out[(z*12)+y] = bit_lanes[(z*12)+y];
            else
              calc_phy_bitlanes_in_out[(z*12)+y] = 1'b0;
          else //OUTPUT
            if (calc_phy_in)
              calc_phy_bitlanes_in_out[(z*12)+y] = 1'b0;
            else
              calc_phy_bitlanes_in_out[(z*12)+y] = bit_lanes[(z*12)+y];
        end
      end
    end 
  endfunction
  
  //Calculate Phy parameters
  localparam BITLANES_IN_B0  = calc_phy_bitlanes_in_out(BIT_LANES_B0, BYTE_GROUP_TYPE_B0, 1);
  localparam BITLANES_IN_B1  = calc_phy_bitlanes_in_out(BIT_LANES_B1, BYTE_GROUP_TYPE_B1, 1);
  localparam BITLANES_IN_B2  = calc_phy_bitlanes_in_out(BIT_LANES_B2, BYTE_GROUP_TYPE_B2, 1);
  localparam BITLANES_IN_B3  = calc_phy_bitlanes_in_out(BIT_LANES_B3, BYTE_GROUP_TYPE_B3, 1);
  localparam BITLANES_IN_B4  = calc_phy_bitlanes_in_out(BIT_LANES_B4, BYTE_GROUP_TYPE_B4, 1);
             
  localparam BITLANES_OUT_B0  = calc_phy_bitlanes_in_out(BIT_LANES_B0, BYTE_GROUP_TYPE_B0, 0);
  localparam BITLANES_OUT_B1  = calc_phy_bitlanes_in_out(BIT_LANES_B1, BYTE_GROUP_TYPE_B1, 0);
  localparam BITLANES_OUT_B2  = calc_phy_bitlanes_in_out(BIT_LANES_B2, BYTE_GROUP_TYPE_B2, 0);
  localparam BITLANES_OUT_B3  = calc_phy_bitlanes_in_out(BIT_LANES_B3, BYTE_GROUP_TYPE_B3, 0);
  localparam BITLANES_OUT_B4  = calc_phy_bitlanes_in_out(BIT_LANES_B4, BYTE_GROUP_TYPE_B4, 0);

  
  //*************************************************************************************************************
  //Function to compute which byte lanes have a write clock (K) and which don't
  //this is needed only when doing write calibration
  //outputs a vector that indicates a byte lane has a DK clock (1) or it 
  //doesn't (0)
  function [7:0] calc_write_clock_loc;
    input [2:0]  ck_cnt;         //How many DK's to go through?
    input [3:0]  byte_lane_cnt;  //How many data lanes to go through?
    input [23:0] bank;       //bank location for the data
    input [15:0] byte_lane;  //byte lane location for data
    input [47:0] write_clock;//DK locations, Bank and Byte lane
    integer       x, y;
    begin
      calc_write_clock_loc = 'b0;
      y = 0;
      for (x = 0; x < ck_cnt; x = x + 1) //step through all K locations                
            for (y = 0; y < byte_lane_cnt; y = y + 1) //step through all byte lanes   .... N_DATA_LANES
                  if (bank[(y*3)+:3]== write_clock[((x*8)+4)+:3] &&		      // OCLK_CALIB_BANK
                      byte_lane[(y*2)+:2] == write_clock[(x*8)+:2])		      // OCLK_CALIB_BYTE_LANE
                    //If true the given byte lane contains a K clock
                        calc_write_clock_loc[y] = 1'b1;
    end //function end
  endfunction // for

  localparam BYTE_LANE_WITH_DK = {24'b0, calc_write_clock_loc (NUM_DEVICES, 
                                                               N_DATA_LANES, 
                                                               OCLK_CALIB_BANK, 
                                                               OCLK_CALIB_BYTE_LANE,
                                                               K_MAP)};
  /*AUTOWIRE*/
  // Beginning of automatic wires (for undeclared instantiated-module outputs)
  wire [(HIGHEST_LANE*12)-1:0] I;		// From u_qdr_phy_byte_lane_map of mig_7series_v2_4_qdr_phy_byte_lane_map.v
  wire [(HIGHEST_LANE*12)-1:0] O;		// From u_qdr_rld_mc_phy of mig_7series_v2_4_qdr_rld_mc_phy.v
  wire			cal_stage2_start;	// From u_qdr_phy_wr_top of mig_7series_v2_4_qdr_phy_wr_top.v
  wire [71:0]		cmplx_rd_burst_bytes;	// From u_qdr_phy_wr_top of mig_7series_v2_4_qdr_phy_wr_top.v
  wire			cmplx_rd_data_valid;	// From u_qdr_phy_wr_top of mig_7series_v2_4_qdr_phy_wr_top.v
  wire			cmplx_rdcal_start;	// From u_qdr_phy_wr_top of mig_7series_v2_4_qdr_phy_wr_top.v
  wire [(HIGHEST_BANK*4)-1:0] cq_clk;		// From u_qdr_phy_byte_lane_map of mig_7series_v2_4_qdr_phy_byte_lane_map.v
  wire [(HIGHEST_BANK*4)-1:0] cqn_clk;		// From u_qdr_phy_byte_lane_map of mig_7series_v2_4_qdr_phy_byte_lane_map.v
  wire [5:0]		ctl_lane_cnt;		// From u_qdr_phy_wr_top of mig_7series_v2_4_qdr_phy_wr_top.v
  wire			dbg_next_byte;		// From u_qdr_rld_phy_read_top of mig_7series_v2_4_qdr_rld_phy_read_top.v
  wire [31:0]		dbg_rdphy_top;		// From u_qdr_rld_phy_read_top of mig_7series_v2_4_qdr_rld_phy_read_top.v
  wire [(HIGHEST_BANK*8)-1:0] ddr_clk;		// From u_qdr_rld_mc_phy of mig_7series_v2_4_qdr_rld_mc_phy.v
  wire [5*DATA_WIDTH-1:0] dlyval_dq;		// From u_qdr_rld_phy_read_top of mig_7series_v2_4_qdr_rld_phy_read_top.v
  wire			edge_adv_cal_done;	// From u_qdr_rld_phy_read_top of mig_7series_v2_4_qdr_rld_phy_read_top.v
  wire			edge_adv_cal_start;	// From u_qdr_phy_wr_top of mig_7series_v2_4_qdr_phy_wr_top.v
  wire [2:0]		edge_cal_byte_cnt;	// From u_qdr_rld_phy_read_top of mig_7series_v2_4_qdr_rld_phy_read_top.v
  wire [(HIGHEST_LANE*12)-1:0] idelay_ce;	// From u_qdr_phy_byte_lane_map of mig_7series_v2_4_qdr_phy_byte_lane_map.v
  wire [HIGHEST_BANK*240-1:0] idelay_cnt_in;	// From u_qdr_phy_byte_lane_map of mig_7series_v2_4_qdr_phy_byte_lane_map.v
  wire [HIGHEST_BANK*240-1:0] idelay_cnt_out;	// From u_qdr_rld_mc_phy of mig_7series_v2_4_qdr_rld_mc_phy.v
  wire [(HIGHEST_LANE*12)-1:0] idelay_inc;	// From u_qdr_phy_byte_lane_map of mig_7series_v2_4_qdr_phy_byte_lane_map.v
  wire			if_a_empty;		// From u_qdr_rld_mc_phy of mig_7series_v2_4_qdr_rld_mc_phy.v
  wire			if_empty;		// From u_qdr_rld_mc_phy of mig_7series_v2_4_qdr_rld_mc_phy.v
  wire			if_rden;		// From u_qdr_rld_phy_read_top of mig_7series_v2_4_qdr_rld_phy_read_top.v
  wire [1:0]		int_rd_cmd_n;		// From u_qdr_phy_wr_top of mig_7series_v2_4_qdr_phy_wr_top.v
  wire			io_fifo_rden_cal_done;	// From u_qdr_phy_wr_top of mig_7series_v2_4_qdr_phy_wr_top.v
  wire [nCK_PER_CLK*2*ADDR_WIDTH-1:0] iob_addr;	// From u_qdr_phy_wr_top of mig_7series_v2_4_qdr_phy_wr_top.v
  wire [nCK_PER_CLK*2*BW_WIDTH-1:0] iob_bw;	// From u_qdr_phy_wr_top of mig_7series_v2_4_qdr_phy_wr_top.v
  wire			iob_dll_off_n;		// From u_qdr_phy_wr_top of mig_7series_v2_4_qdr_phy_wr_top.v
  wire [nCK_PER_CLK*2-1:0] iob_rd_n;		// From u_qdr_phy_wr_top of mig_7series_v2_4_qdr_phy_wr_top.v
  wire [nCK_PER_CLK*2*DATA_WIDTH-1:0] iob_wdata;// From u_qdr_phy_wr_top of mig_7series_v2_4_qdr_phy_wr_top.v
  wire [nCK_PER_CLK*2-1:0] iob_wr_n;		// From u_qdr_phy_wr_top of mig_7series_v2_4_qdr_phy_wr_top.v
  wire			kill_rd_valid;		// From u_qdr_phy_wr_top of mig_7series_v2_4_qdr_phy_wr_top.v
  wire			of_cmd_wr_en;		// From u_qdr_phy_wr_top of mig_7series_v2_4_qdr_phy_wr_top.v
  wire			of_ctl_a_full;		// From u_qdr_rld_mc_phy of mig_7series_v2_4_qdr_rld_mc_phy.v
  wire			of_ctl_full;		// From u_qdr_rld_mc_phy of mig_7series_v2_4_qdr_rld_mc_phy.v
  wire			of_data_a_full;		// From u_qdr_rld_mc_phy of mig_7series_v2_4_qdr_rld_mc_phy.v
  wire			of_data_full;		// From u_qdr_rld_mc_phy of mig_7series_v2_4_qdr_rld_mc_phy.v
  wire			of_data_wr_en;		// From u_qdr_phy_wr_top of mig_7series_v2_4_qdr_phy_wr_top.v
  wire [N_DATA_LANES-1:0] phase_valid;		// From u_qdr_rld_phy_read_top of mig_7series_v2_4_qdr_rld_phy_read_top.v
  wire			phy_ctl_a_full;		// From u_qdr_rld_mc_phy of mig_7series_v2_4_qdr_rld_mc_phy.v
  wire			phy_ctl_full;		// From u_qdr_rld_mc_phy of mig_7series_v2_4_qdr_rld_mc_phy.v
  wire			phy_ctl_ready;		// From u_qdr_rld_mc_phy of mig_7series_v2_4_qdr_rld_mc_phy.v
  wire [31:0]		phy_ctl_wd;		// From u_qdr_phy_wr_top of mig_7series_v2_4_qdr_phy_wr_top.v
  wire			phy_ctl_wr;		// From u_qdr_phy_wr_top of mig_7series_v2_4_qdr_phy_wr_top.v
  wire [HIGHEST_LANE*80-1:0] phy_din;		// From u_qdr_rld_mc_phy of mig_7series_v2_4_qdr_rld_mc_phy.v
  wire [HIGHEST_LANE*80-1:0] phy_dout;		// From u_qdr_phy_byte_lane_map of mig_7series_v2_4_qdr_phy_byte_lane_map.v
  wire [5:0]		pi_counter_read_val;	// From u_qdr_rld_mc_phy of mig_7series_v2_4_qdr_rld_mc_phy.v
  wire			pi_edge_adv;		// From u_qdr_rld_phy_read_top of mig_7series_v2_4_qdr_rld_phy_read_top.v
  wire			pi_en_stg2_f;		// From u_qdr_rld_phy_read_top of mig_7series_v2_4_qdr_rld_phy_read_top.v
  wire			pi_stg2_f_incdec;	// From u_qdr_rld_phy_read_top of mig_7series_v2_4_qdr_rld_phy_read_top.v
  wire			pi_stg2_load;		// From u_qdr_rld_phy_read_top of mig_7series_v2_4_qdr_rld_phy_read_top.v
  wire [CQ_BITS-1:0]	pi_stg2_rdlvl_cnt;	// From u_qdr_rld_phy_read_top of mig_7series_v2_4_qdr_rld_phy_read_top.v
  wire [5:0]		pi_stg2_reg_l;		// From u_qdr_rld_phy_read_top of mig_7series_v2_4_qdr_rld_phy_read_top.v
  wire			po_cnt_dec;		// From u_qdr_phy_wr_top of mig_7series_v2_4_qdr_phy_wr_top.v
  wire			po_cnt_inc;		// From u_qdr_phy_wr_top of mig_7series_v2_4_qdr_phy_wr_top.v
  wire [8:0]		po_counter_read_val;	// From u_qdr_rld_mc_phy of mig_7series_v2_4_qdr_rld_mc_phy.v
  wire			po_dec_done;		// From u_qdr_phy_wr_top of mig_7series_v2_4_qdr_phy_wr_top.v
  wire			po_delay_done;		// From u_qdr_rld_mc_phy of mig_7series_v2_4_qdr_rld_mc_phy.v
  wire			po_inc_done;		// From u_qdr_phy_wr_top of mig_7series_v2_4_qdr_phy_wr_top.v
  wire [nCK_PER_CLK*2*DATA_WIDTH-1:0] rd_data_map;// From u_qdr_phy_byte_lane_map of mig_7series_v2_4_qdr_phy_byte_lane_map.v
  wire [N_DATA_LANES-1:0] rdlvl_stg1_cal_bytes;	// From u_qdr_phy_wr_top of mig_7series_v2_4_qdr_phy_wr_top.v
  wire			rdlvl_stg1_done;	// From u_qdr_rld_phy_read_top of mig_7series_v2_4_qdr_rld_phy_read_top.v
  wire			rdlvl_stg1_fast;	// From u_qdr_phy_wr_top of mig_7series_v2_4_qdr_phy_wr_top.v
  wire			rdlvl_stg1_start;	// From u_qdr_phy_wr_top of mig_7series_v2_4_qdr_phy_wr_top.v
  wire			rdlvl_valid;		// From u_qdr_rld_phy_read_top of mig_7series_v2_4_qdr_rld_phy_read_top.v
  wire			read_cal_done;		// From u_qdr_rld_phy_read_top of mig_7series_v2_4_qdr_rld_phy_read_top.v
  wire			rst_stg1;		// From u_qdr_phy_wr_top of mig_7series_v2_4_qdr_phy_wr_top.v
  wire			rst_stg2;		// From u_qdr_phy_wr_top of mig_7series_v2_4_qdr_phy_wr_top.v
  wire [11:0]		tmp_lb_clk;		// From u_qdr_rld_mc_phy of mig_7series_v2_4_qdr_rld_mc_phy.v
  wire [4:0]		valid_latency;		// From u_qdr_rld_phy_read_top of mig_7series_v2_4_qdr_rld_phy_read_top.v
  wire			wrcal_addr_cntrl;	// From u_qdr_phy_wr_top of mig_7series_v2_4_qdr_phy_wr_top.v
  wire [1:0]		wrcal_byte_sel;		// From u_qdr_phy_wr_top of mig_7series_v2_4_qdr_phy_wr_top.v
  wire			wrcal_en;		// From u_qdr_phy_wr_top of mig_7series_v2_4_qdr_phy_wr_top.v
  wire			wrcal_inc;		// From u_qdr_phy_wr_top of mig_7series_v2_4_qdr_phy_wr_top.v
  wire			wrcal_po_en;		// From u_qdr_phy_wr_top of mig_7series_v2_4_qdr_phy_wr_top.v
  wire			wrcal_stg3;		// From u_qdr_phy_wr_top of mig_7series_v2_4_qdr_phy_wr_top.v
  // End of automatics

  // Loopback clock from K output back to POC phase detector.
  wire [1:0] lb_clk;
  assign lb_clk[0] = tmp_lb_clk[K_MAP[6:4]*4 + K_MAP[1:0]];
  assign lb_clk[1] = tmp_lb_clk[K_MAP[14:12]*4 + K_MAP[9:8]];
                          

  reg dbg_pi_f_inc_r;
  reg dbg_pi_f_dec_r;
  reg dbg_po_f_inc_r;
  reg dbg_po_f_dec_r;
  reg [5:0] byte_sel_cnt;
  reg [5:0] calib_sel;
  reg [HIGHEST_BANK-1:0] calib_zero_inputs;
  reg calib_in_common;
  reg po_fine_enable;
  reg po_fine_inc;
  reg pi_edge_adv_2r;
  reg pi_edge_adv_r;
  reg dbg_phy_pi_fine_inc;
  reg dbg_phy_pi_fine_enable;
  reg dbg_phy_po_fine_inc;
  reg dbg_phy_po_fine_enable;
  reg dbg_phy_po_co_inc;
  reg dbg_phy_po_co_enable;
  reg dbg_po_stg3_sel_r;
  reg dbg_po_sel_r;
  reg [2:0] dbg_select_rdata_r1;
  reg [2:0] dbg_select_rdata_r2;
  reg po_sel_fine_oclk_delay;
  
  always @(posedge clk) begin
    if (rst_clk) begin	  
	  dbg_po_stg3_sel_r		<= #TCQ 1'b0;
	  dbg_po_sel_r				<= #TCQ 1'b0;
	  end
	else if (init_calib_complete)  begin
	  dbg_po_stg3_sel_r	   <=  #TCQ dbg_po_stg3_sel;
	  dbg_po_sel_r				<=  #TCQ dbg_po_sel;
	  end
	else
	  dbg_po_stg3_sel_r	   <= #TCQ 1'b0;	  
  end // always @ (posedge clk)

  
  //simple bus to indicate phy status
  assign dbg_phy_status[0] = rst;

  // _po_adj state machine.  Highest level calibration steps.
  assign dbg_phy_status[3:1] = dbg_wr_init[130:128];

  // The three basic steps of the read side.
  assign dbg_phy_status[4] = rdlvl_stg1_done;
  assign dbg_phy_status[5] = edge_adv_cal_done;
  assign dbg_phy_status[6] = read_cal_done;

  // All done!
  assign dbg_phy_status[7] = init_calib_complete;
  
  assign dbg_byte_sel_cnt = byte_sel_cnt;

  //debug signals to adjust the fine_inc and fine_enable controls on the phasers
  always @(posedge clk) begin
    if (rst_clk) begin
      dbg_pi_f_inc_r         <= #TCQ 1'b0;
      dbg_pi_f_dec_r         <= #TCQ 1'b0;

      dbg_po_f_inc_r         <= #TCQ 1'b0;
      dbg_po_f_dec_r         <= #TCQ 1'b0;

      dbg_phy_po_fine_inc    <= #TCQ 1'b0;
      dbg_phy_po_fine_enable <= #TCQ 1'b0;
    end else begin
      //phaser_in controls

      //register chipscope controls for better timing
      dbg_pi_f_inc_r       <= #TCQ dbg_pi_f_inc;
      dbg_pi_f_dec_r       <= #TCQ dbg_pi_f_dec;

      //generate one clock pulse if VIO debug toggle the dbg_pi_f_inc or dbg_pi_f_dec
      dbg_phy_pi_fine_inc    <= #TCQ ~dbg_pi_f_inc_r  & dbg_pi_f_inc;
      dbg_phy_pi_fine_enable <= #TCQ ( ~dbg_pi_f_inc_r & dbg_pi_f_inc) | (~dbg_pi_f_dec_r & dbg_pi_f_dec);
      
      //phaser_out controls               
      dbg_po_f_inc_r       <= #TCQ dbg_po_f_inc;
      dbg_po_f_dec_r       <= #TCQ dbg_po_f_dec;

      //generate one clock pulse if VIO debug toggle the dbg_po_f_inc or dbg_po_f_dec

      dbg_phy_po_fine_inc       <= #TCQ ~dbg_po_f_inc_r & dbg_po_f_inc;
      dbg_phy_po_fine_enable    <= #TCQ (~dbg_po_f_inc_r & dbg_po_f_inc) | (~dbg_po_f_dec_r & dbg_po_f_dec);
      
      dbg_phy_po_co_inc         <= #TCQ 1'b0; //support coarse tap control later
      dbg_phy_po_co_enable      <= #TCQ 1'b0;
    end
  end
  
  assign dbg_po_counter_read_val = po_counter_read_val;
  assign dbg_pi_counter_read_val = pi_counter_read_val;


  // Calibrate interface to _mc_phy.   First phase is initial settings
  // of the phasers.  This phase ends when po_delay_done asserts high.  Next,
  // calibration is controlled by the read side.  Read side control is overriden
  // by wrcal_en asserts to allow the write side to adjust the phaser outs.
  // During read side control, the edge_cal will control after rdlvl_stg1_done,
  // although its not clear if this is used.
  // This continues until init_calib_complete when control is handed over to
  // debug.
  
  localparam [4:0] WRCAL_CALIB_ZERO = ~(5'b00001 << ADDR_CTL_BANK);
  
  reg [CQ_BITS-1:0] dbg_byte_sel_r;
  always @(posedge clk) dbg_byte_sel_r <= #TCQ dbg_byte_sel;

  wire [4:0] ac_setup_zero = ~(5'b00001 << ADDR_CTL_MAP[byte_sel_cnt*8+4+:3]);
  wire [4:0] calib_zero = ~(5'b00001 << CALIB_BANK[pi_stg2_rdlvl_cnt*3+:3]);
  wire [4:0] oclk_calib_zero = ~(5'b00001 << OCLK_CALIB_BANK[wrcal_byte_sel*3+:3]);
  wire [2:0] k_bank = K_MAP[wrcal_byte_sel*8+4+:3];
  wire [4:0] k_clk_calib_zero = ~(5'b00001 << k_bank);
  wire [4:0] edge_cal_calib_zero = ~(5'b00001 << CALIB_BANK[edge_cal_byte_cnt*3+:3]);
  wire [4:0] dbg_calib_zero = ~(5'b00001 << (dbg_po_sel_r
                                               ? OCLK_CALIB_BANK[dbg_byte_sel_r*3+:3] 
                                               : CALIB_BANK[dbg_byte_sel_r*3+:3]));
  
  always @(posedge clk) begin
    if (rst_clk || DEBUG_PORT == "OFF" && init_calib_complete) begin
      byte_sel_cnt <= #TCQ 6'b0;
      calib_in_common <= #TCQ 1'b0;
      calib_sel <= #TCQ 6'b000100;
      calib_zero_inputs <= #TCQ {HIGHEST_BANK{1'b1}};
      po_fine_enable <= #TCQ 1'b0;
      po_fine_inc <= #TCQ 1'b0;
      po_sel_fine_oclk_delay <= #TCQ 1'b0;
    end else begin
      calib_sel[2] <= #TCQ 1'b0;
      if (~po_delay_done) begin
	// phaser initialization
	if (~(PO_COARSE_BYPASS == "TRUE" && po_inc_done || PO_COARSE_BYPASS == "FALSE" && po_dec_done)) begin
	  // Initialize all phaser outs.
	  calib_sel[1:0] <= #TCQ ADDR_CTL_MAP[0+:2];
          calib_sel[5:3] <= #TCQ ADDR_CTL_MAP[4+:3];
	  calib_in_common <= #TCQ 1'b1;
          calib_zero_inputs <= #TCQ {HIGHEST_BANK{1'b0}};
	  po_fine_enable <= #TCQ po_cnt_inc || po_cnt_dec;	  
          po_fine_inc <= #TCQ PO_COARSE_BYPASS == "TRUE";
 	end else begin
          // Address/control phasers adjusted inside _mc_phy.
	  calib_sel[1:0]     <= #TCQ ADDR_CTL_MAP[byte_sel_cnt*8+:2];
          calib_sel[5:3]     <= #TCQ ADDR_CTL_MAP[byte_sel_cnt*8+4+:3];
	  calib_in_common <= #TCQ 1'b0;
	  calib_zero_inputs <= #TCQ ac_setup_zero[HIGHEST_BANK-1:0];
	  po_fine_enable <= #TCQ 1'b0;
	  po_fine_inc <= #TCQ 1'b0;
	end
      end else begin
	if (~init_calib_complete) begin
	  if (~wrcal_en) begin
	    // read side controlling
	    calib_in_common <= #TCQ 1'b0;
	    po_fine_inc <= #TCQ 1'b0;
	    po_fine_enable <= #TCQ 1'b0;
	    po_sel_fine_oclk_delay <= 1'b0;
	    if (rdlvl_stg1_done) begin
	      // edge_cal
	      byte_sel_cnt <= #TCQ {3'b0, edge_cal_byte_cnt};
	      calib_sel[1:0] <= #TCQ CALIB_BYTE_LANE[(edge_cal_byte_cnt*2)+:2];
	      calib_sel[5:3] <= #TCQ CALIB_BANK[(edge_cal_byte_cnt*3)+:3];
	      calib_zero_inputs <= #TCQ edge_cal_calib_zero[HIGHEST_BANK-1:0];
	    end else begin
	      // primary read calibration
	      byte_sel_cnt[CQ_BITS-1:0] <= #TCQ {{6-CQ_BITS{1'b0}}, pi_stg2_rdlvl_cnt};
	      calib_sel[1:0] <= #TCQ CALIB_BYTE_LANE[(pi_stg2_rdlvl_cnt*2)+:2];
	      calib_sel[5:3] <= #TCQ CALIB_BANK[(pi_stg2_rdlvl_cnt*3)+:3];
	      calib_zero_inputs <= #TCQ calib_zero[HIGHEST_BANK-1:0];
	    end
	  end else begin
	    // write side controlling
	    byte_sel_cnt <= #TCQ {4'b0, wrcal_byte_sel};
	    po_fine_inc <= #TCQ wrcal_inc;
	    po_fine_enable <= #TCQ wrcal_po_en;
	    po_sel_fine_oclk_delay <= #TCQ wrcal_stg3;
	    if (wrcal_addr_cntrl) begin
	      // Adjust address control
	      calib_in_common <= #TCQ 1'b1;
	      calib_sel[5:3] <= #TCQ ADDR_CTL_BANK[2:0];
              calib_zero_inputs <= #TCQ WRCAL_CALIB_ZERO[HIGHEST_BANK-1:0];
	    end else begin
	      // Adjust write data
	      calib_in_common <= #TCQ 1'b0;
	      if (wrcal_stg3) begin
	        calib_sel[1:0] <= #TCQ K_MAP[wrcal_byte_sel*8+:2];		
	        calib_sel[5:3] <= #TCQ k_bank;
		calib_zero_inputs <= #TCQ k_clk_calib_zero[HIGHEST_BANK-1:0];
	      end else begin
	        calib_sel[1:0] <= #TCQ OCLK_CALIB_BYTE_LANE[wrcal_byte_sel*2+:2];		
	        calib_sel[5:3] <= #TCQ OCLK_CALIB_BANK[wrcal_byte_sel*3+:3];
		calib_zero_inputs <= #TCQ oclk_calib_zero[HIGHEST_BANK-1:0];
	      end
	    end
	  end
	end else begin
	  // debug controlling
	    byte_sel_cnt <= #TCQ {{6-CQ_BITS{1'b0}}, dbg_byte_sel_r};
	    if (dbg_po_sel_r == 1'b0) begin // READ PATH
               calib_sel[1:0] <= #TCQ CALIB_BYTE_LANE[dbg_byte_sel_r*2+:2];
               calib_sel[5:3] <= #TCQ CALIB_BANK[dbg_byte_sel_r*3+:3];
 	     end else begin  //WRITE PATH
               calib_sel[1:0] <= #TCQ OCLK_CALIB_BYTE_LANE[dbg_byte_sel_r*2+:2];
               calib_sel[5:3] <= #TCQ OCLK_CALIB_BANK[dbg_byte_sel_r*3+:3];					   
             end
	    calib_in_common <= #TCQ 1'b0;
	    calib_zero_inputs <=  #TCQ dbg_calib_zero;
	    po_fine_inc <= #TCQ dbg_phy_po_fine_inc;
	    po_fine_enable <= #TCQ dbg_phy_po_fine_enable;
	    po_sel_fine_oclk_delay <= #TCQ dbg_po_stg3_sel_r;
	end
      end
    end // else: !if(rst_clk || DEBUG_PORT == "OFF" && init_calib_complete)
  end // always @ (posedge clk)
 
  // register pi_edge_adv to track register stages in calib_sel logic
  always @ (posedge clk) begin
     if (rst_clk) begin
       pi_edge_adv_r  <= #TCQ 0;
       pi_edge_adv_2r <= #TCQ 0;
     end else begin
       pi_edge_adv_r  <= #TCQ pi_edge_adv;
       pi_edge_adv_2r <= #TCQ pi_edge_adv_r;  
     end
  end 
                                                  
  //synthesis translate_off
  always @(posedge phy_ctl_ready)
    if (!rst)
      $display ("qdr_phy_top.v: phy_ctl_ready asserted  %t", $time);
  
  always @(posedge init_calib_complete)
    if (!rst)
      $display ("qdr_phy_top.v: init_calib_complete asserted  %t", $time);  
  //synthesis translate_on

  /* mig_7series_v2_4_qdr_phy_wr_top AUTO_TEMPLATE (
     .POC_USE_METASTABLE_SAMP           (),
     .POC_PCT_SAMPS_SOLID               (),) */
  
  mig_7series_v2_4_qdr_phy_wr_top #
    (/*AUTOINSTPARAM*/
     // Parameters
     .ADDR_WIDTH			(ADDR_WIDTH),
     .BURST_LEN				(BURST_LEN),
     .BW_WIDTH				(BW_WIDTH),
     .BYTE_LANE_WITH_DK			(BYTE_LANE_WITH_DK),
     .CLK_STABLE			(CLK_STABLE),
     .CMPLX_RDCAL_EN			(CMPLX_RDCAL_EN),
     .DATA_WIDTH			(DATA_WIDTH),
     .MEM_TYPE				(MEM_TYPE),
     .MMCM_SAMP_WAIT			(MMCM_SAMP_WAIT),
     .NUM_DEVICES			(NUM_DEVICES),
     .N_CTL_LANES			(N_CTL_LANES),
     .N_DATA_LANES			(N_DATA_LANES),
     .OCLK_CALIB_BYTE_LANE		(OCLK_CALIB_BYTE_LANE),
     .PD_SIM_CAL_OPTION			(PD_SIM_CAL_OPTION),
     .POC_PCT_SAMPS_SOLID		(),			 // Templated
     .POC_SAMPLES			(POC_SAMPLES),
     .POC_USE_METASTABLE_SAMP		(),			 // Templated
     .PO_ADJ_GAP			(PO_ADJ_GAP),
     .PO_COARSE_BYPASS			(PO_COARSE_BYPASS),
     .PRE_FIFO				(PRE_FIFO),
     .SKIP_POC				(SKIP_POC),
     .TAPSPERKCLK			(TAPSPERKCLK),
     .TCQ				(TCQ),
     .WRCAL_DEFAULT			(WRCAL_DEFAULT),
     .WRCAL_PCT_SAMPS_SOLID		(WRCAL_PCT_SAMPS_SOLID),
     .WRCAL_SAMPLES			(WRCAL_SAMPLES),
     .nCK_PER_CLK			(nCK_PER_CLK))
  u_qdr_phy_wr_top 
    (/*AUTOINST*/
     // Outputs
     .cal_stage2_start			(cal_stage2_start),
     .cmplx_rd_burst_bytes		(cmplx_rd_burst_bytes[71:0]),
     .cmplx_rd_data_valid		(cmplx_rd_data_valid),
     .cmplx_rdcal_start			(cmplx_rdcal_start),
     .ctl_lane_cnt			(ctl_lane_cnt[5:0]),
     .dbg_phy_addr			(dbg_phy_addr[ADDR_WIDTH*4-1:0]),
     .dbg_phy_rd_cmd_n			(dbg_phy_rd_cmd_n[1:0]),
     .dbg_phy_wr_cmd_n			(dbg_phy_wr_cmd_n[1:0]),
     .dbg_phy_wr_data			(dbg_phy_wr_data[DATA_WIDTH*4-1:0]),
     .dbg_poc				(dbg_poc[1023:0]),
     .dbg_wr_init			(dbg_wr_init[255:0]),
     .edge_adv_cal_start		(edge_adv_cal_start),
     .init_calib_complete		(init_calib_complete),
     .int_rd_cmd_n			(int_rd_cmd_n[1:0]),
     .io_fifo_rden_cal_done		(io_fifo_rden_cal_done),
     .iob_addr				(iob_addr[nCK_PER_CLK*2*ADDR_WIDTH-1:0]),
     .iob_bw				(iob_bw[nCK_PER_CLK*2*BW_WIDTH-1:0]),
     .iob_dll_off_n			(iob_dll_off_n),
     .iob_rd_n				(iob_rd_n[nCK_PER_CLK*2-1:0]),
     .iob_wdata				(iob_wdata[nCK_PER_CLK*2*DATA_WIDTH-1:0]),
     .iob_wr_n				(iob_wr_n[nCK_PER_CLK*2-1:0]),
     .kill_rd_valid			(kill_rd_valid),
     .of_cmd_wr_en			(of_cmd_wr_en),
     .of_data_wr_en			(of_data_wr_en),
     .phy_ctl_wd			(phy_ctl_wd[31:0]),
     .phy_ctl_wr			(phy_ctl_wr),
     .po_cnt_dec			(po_cnt_dec),
     .po_cnt_inc			(po_cnt_inc),
     .po_dec_done			(po_dec_done),
     .po_inc_done			(po_inc_done),
     .poc_error				(poc_error),
     .psen				(psen),
     .psincdec				(psincdec),
     .rdlvl_stg1_cal_bytes		(rdlvl_stg1_cal_bytes[N_DATA_LANES-1:0]),
     .rdlvl_stg1_fast			(rdlvl_stg1_fast),
     .rdlvl_stg1_start			(rdlvl_stg1_start),
     .rst_clk				(rst_clk),
     .rst_stg1				(rst_stg1),
     .rst_stg2				(rst_stg2),
     .wrcal_addr_cntrl			(wrcal_addr_cntrl),
     .wrcal_byte_sel			(wrcal_byte_sel[1:0]),
     .wrcal_en				(wrcal_en),
     .wrcal_inc				(wrcal_inc),
     .wrcal_po_en			(wrcal_po_en),
     .wrcal_stg3			(wrcal_stg3),
     // Inputs
     .clk				(clk),
     .clk_mem				(clk_mem),
     .dbg_K_left_shift_right		(dbg_K_left_shift_right[5:0]),
     .dbg_K_right_shift_left		(dbg_K_right_shift_left[5:0]),
     .dbg_cmplx_wr_loop			(dbg_cmplx_wr_loop),
     .dbg_phy_init_rd_only		(dbg_phy_init_rd_only),
     .dbg_phy_init_wr_only		(dbg_phy_init_wr_only),
     .edge_adv_cal_done			(edge_adv_cal_done),
     .iddr_rst				(iddr_rst),
     .lb_clk				(lb_clk[1:0]),
     .mmcm_fshift_clk			(mmcm_fshift_clk),
     .of_ctl_full			(of_ctl_full),
     .of_data_full			(of_data_full),
     .phase_valid			(phase_valid[N_DATA_LANES-1:0]),
     .phy_ctl_a_full			(phy_ctl_a_full),
     .phy_ctl_full			(phy_ctl_full),
     .phy_ctl_ready			(phy_ctl_ready),
     .po_counter_read_val		(po_counter_read_val[8:0]),
     .po_delay_done			(po_delay_done),
     .poc_sample_pd			(poc_sample_pd),
     .psdone				(psdone),
     .rd_addr0				(rd_addr0[ADDR_WIDTH-1:0]),
     .rd_addr1				(rd_addr1[ADDR_WIDTH-1:0]),
     .rd_cmd0				(rd_cmd0),
     .rd_cmd1				(rd_cmd1),
     .rdlvl_stg1_done			(rdlvl_stg1_done),
     .rdlvl_valid			(rdlvl_valid),
     .read_cal_done			(read_cal_done),
     .rst				(rst),
     .valid_latency			(valid_latency[4:0]),
     .wr_addr0				(wr_addr0[ADDR_WIDTH-1:0]),
     .wr_addr1				(wr_addr1[ADDR_WIDTH-1:0]),
     .wr_bw_n0				(wr_bw_n0[BW_WIDTH*2-1:0]),
     .wr_bw_n1				(wr_bw_n1[BW_WIDTH*2-1:0]),
     .wr_cmd0				(wr_cmd0),
     .wr_cmd1				(wr_cmd1),
     .wr_data0				(wr_data0[DATA_WIDTH*2-1:0]),
     .wr_data1				(wr_data1[DATA_WIDTH*2-1:0]));


  wire [nCK_PER_CLK*DATA_WIDTH-1:0] iserdes_rd = 
    {rd_data_map[DATA_WIDTH*3-1:DATA_WIDTH*2], rd_data_map[DATA_WIDTH-1:0]};
  
  wire [nCK_PER_CLK*DATA_WIDTH-1:0] iserdes_fd = 
    {rd_data_map[DATA_WIDTH*4-1:DATA_WIDTH*3], rd_data_map[DATA_WIDTH*2-1:DATA_WIDTH]};
  
  /* mig_7series_v2_4_qdr_rld_phy_read_top AUTO_TEMPLATE (
     .MEMORY_IO_DIR                     ("UNIDIR"),
     .RD_DATA_RISE_FALL                 ("TRUE"),
     .byte_cnt                          (edge_cal_byte_cnt[2:0]),
     .dbg_align_rd                      ({dbg_align_rd1, dbg_align_rd0}),
     .dbg_align_fd                      ({dbg_align_fd1, dbg_align_fd0}),
     .dbg_SM_en				(1'b0),    // Doesn't do anything.
     .po_en_stg2_f			(),
     .po_stg2_.*                        (),
     .rd_data                           ({rd_data1, rd_data0}),
     .rd_valid                          ({rd_valid1, rd_valid0}),
     .rst_wr_clk                        (rst),) */

 //Instantiate the top of the read path
  mig_7series_v2_4_qdr_rld_phy_read_top #
    (/*AUTOINSTPARAM*/
     // Parameters
     .BURST_LEN				(BURST_LEN),
     .BW_WIDTH				(BW_WIDTH),
     .CLK_PERIOD			(CLK_PERIOD),
     .CENTER_COMP_MODE                  (CENTER_COMP_MODE),
     .CMPLX_RDCAL_EN			(CMPLX_RDCAL_EN),
     .CQ_BITS				(CQ_BITS),
     .DATA_WIDTH			(DATA_WIDTH),
     .FIXED_LATENCY_MODE		(FIXED_LATENCY_MODE),
     .MEM_TYPE				(MEM_TYPE),
     .N_DATA_LANES			(N_DATA_LANES),
     .PHY_LATENCY			(PHY_LATENCY),
     .PI_E2E_WAIT			(PI_E2E_WAIT),
     .PI_PHY_WAIT			(PI_PHY_WAIT),
     .PI_SU_WAIT			(PI_SU_WAIT),
     .Q_BITS				(Q_BITS),
     .RDLVL_CMPLX_SEQ_LENGTH		(RDLVL_CMPLX_SEQ_LENGTH),
     .RDLVL_LOW_RES_MODE		(RDLVL_LOW_RES_MODE),
     .RDLVL_SAMPS			(RDLVL_SAMPS),
     .RD_DATA_RISE_FALL			("TRUE"),		 // Templated
     .REFCLK_FREQ			(REFCLK_FREQ),
     .SIM_BYPASS_IDELAY			(SIM_BYPASS_IDELAY),
     .SIM_BYPASS_INIT_CAL		(SIM_BYPASS_INIT_CAL),
     .SIM_BYPASS_PI_CENTER		(SIM_BYPASS_PI_CENTER),
     .TCQ				(TCQ),
     .nCK_PER_CLK			(nCK_PER_CLK))
  u_qdr_rld_phy_read_top 
    (/*AUTOINST*/
     // Outputs
     .byte_cnt				(edge_cal_byte_cnt[2:0]), // Templated
     .dbg_align_fd			({dbg_align_fd1, dbg_align_fd0}), // Templated
     .dbg_align_rd			({dbg_align_rd1, dbg_align_rd0}), // Templated
     .dbg_error_max_latency		(dbg_error_max_latency[N_DATA_LANES-1:0]),
     .dbg_inc_latency			(dbg_inc_latency[N_DATA_LANES-1:0]),
     .dbg_next_byte			(dbg_next_byte),
     .dbg_rd_stage1_cal			(dbg_rd_stage1_cal[1023:0]),
     .dbg_rdphy_top			(dbg_rdphy_top[31:0]),
     .dbg_stage2_cal			(dbg_stage2_cal[127:0]),
     .dbg_valid_lat			(dbg_valid_lat[4:0]),
     .dlyval_dq				(dlyval_dq[5*DATA_WIDTH-1:0]),
     .edge_adv_cal_done			(edge_adv_cal_done),
     .error_adj_latency			(error_adj_latency),
     .if_rden				(if_rden),
     .phase_valid			(phase_valid[N_DATA_LANES-1:0]),
     .pi_edge_adv			(pi_edge_adv),
     .pi_en_stg2_f			(pi_en_stg2_f),
     .pi_stg2_f_incdec			(pi_stg2_f_incdec),
     .pi_stg2_load			(pi_stg2_load),
     .pi_stg2_rdlvl_cnt			(pi_stg2_rdlvl_cnt[CQ_BITS-1:0]),
     .pi_stg2_reg_l			(pi_stg2_reg_l[5:0]),
     .po_en_stg2_f			(),			 // Templated
     .po_stg2_f_incdec			(),			 // Templated
     .po_stg2_load			(),			 // Templated
     .po_stg2_rdlvl_cnt			(),			 // Templated
     .po_stg2_reg_l			(),			 // Templated
     .rd_data				({rd_data1, rd_data0}),	 // Templated
     .rd_valid				({rd_valid1, rd_valid0}), // Templated
     .rdlvl_stg1_done			(rdlvl_stg1_done),
     .rdlvl_valid			(rdlvl_valid),
     .read_cal_done			(read_cal_done),
     .valid_latency			(valid_latency[4:0]),
     // Inputs
     .cal_stage2_start			(cal_stage2_start),
     .clk				(clk),
     .cmplx_rd_burst_bytes		(cmplx_rd_burst_bytes[71:0]),
     .cmplx_rd_data_valid		(cmplx_rd_data_valid),
     .cmplx_rdcal_start			(cmplx_rdcal_start),
     .dbg_SM_en				(1'b0),			 // Templated
     .dbg_byte_sel			(dbg_byte_sel[CQ_BITS-1:0]),
     .dbg_cmplx_rd_lane			(dbg_cmplx_rd_lane[2:0]),
     .dbg_cmplx_rd_loop			(dbg_cmplx_rd_loop),
     .edge_adv_cal_start		(edge_adv_cal_start),
     .if_empty				(if_empty),
     .int_rd_cmd_n			(int_rd_cmd_n[nCK_PER_CLK-1:0]),
     .iserdes_fd			(iserdes_fd[nCK_PER_CLK*DATA_WIDTH-1:0]),
     .iserdes_rd			(iserdes_rd[nCK_PER_CLK*DATA_WIDTH-1:0]),
     .kill_rd_valid			(kill_rd_valid),
     .pi_counter_read_val		(pi_counter_read_val[5:0]),
     .po_counter_read_val		(po_counter_read_val[8:0]),
     .rdlvl_stg1_cal_bytes		(rdlvl_stg1_cal_bytes[N_DATA_LANES-1:0]),
     .rdlvl_stg1_fast			(rdlvl_stg1_fast),
     .rdlvl_stg1_start			(rdlvl_stg1_start),
     .rst_stg1				(rst_stg1),
     .rst_stg2				(rst_stg2),
     .rst_wr_clk			(rst));			 // Templated

  /* mig_7series_v2_4_qdr_phy_byte_lane_map AUTO_TEMPLATE (
     .rst                               (rst_clk),
     .phy_init_data_sel                 (1'b0),
     .dbg_inc_q_all                     (1'b0),
     .dbg_dec_q_all                     (1'b0),
     .dbg_inc_q                         (1'b0),
     .dbg_dec_q                         (1'b0),
     .dbg_sel_q                         (dbg_bit_sel[Q_BITS-1:0]),
     .dbg_q_tapcnt                      (dbg_idel_tap_cnt[TAP_BITS*DATA_WIDTH-1:0]),) */
                                             
  mig_7series_v2_4_qdr_phy_byte_lane_map #
    (/*AUTOINSTPARAM*/
     // Parameters
     .ADDR_WIDTH			(ADDR_WIDTH),
     .ADD_MAP				(ADD_MAP),
     .BW_MAP				(BW_MAP),
     .BW_WIDTH				(BW_WIDTH),
     .BYTE_LANES_B0			(BYTE_LANES_B0),
     .BYTE_LANES_B1			(BYTE_LANES_B1),
     .BYTE_LANES_B2			(BYTE_LANES_B2),
     .BYTE_LANES_B3			(BYTE_LANES_B3),
     .BYTE_LANES_B4			(BYTE_LANES_B4),
     .CQ_MAP				(CQ_MAP),
     .D0_MAP				(D0_MAP),
     .D1_MAP				(D1_MAP),
     .D2_MAP				(D2_MAP),
     .D3_MAP				(D3_MAP),
     .D4_MAP				(D4_MAP),
     .D5_MAP				(D5_MAP),
     .D6_MAP				(D6_MAP),
     .D7_MAP				(D7_MAP),
     .DATA_CTL_B0			(DATA_CTL_B0),
     .DATA_CTL_B1			(DATA_CTL_B1),
     .DATA_CTL_B2			(DATA_CTL_B2),
     .DATA_CTL_B3			(DATA_CTL_B3),
     .DATA_CTL_B4			(DATA_CTL_B4),
     .DATA_WIDTH			(DATA_WIDTH),
     .HIGHEST_BANK			(HIGHEST_BANK),
     .HIGHEST_LANE			(HIGHEST_LANE),
     .K_MAP				(K_MAP),
     .MEMORY_IO_DIR			(MEMORY_IO_DIR),
     .MEM_RD_LATENCY			(MEM_RD_LATENCY),
     .NUM_DEVICES			(NUM_DEVICES),
     .Q0_MAP				(Q0_MAP),
     .Q1_MAP				(Q1_MAP),
     .Q2_MAP				(Q2_MAP),
     .Q3_MAP				(Q3_MAP),
     .Q4_MAP				(Q4_MAP),
     .Q5_MAP				(Q5_MAP),
     .Q6_MAP				(Q6_MAP),
     .Q7_MAP				(Q7_MAP),
     .Q_BITS				(Q_BITS),
     .RD_MAP				(RD_MAP),
     .TCQ				(TCQ),
     .WR_MAP				(WR_MAP),
     .nCK_PER_CLK			(nCK_PER_CLK)) 
  u_qdr_phy_byte_lane_map
    (/*AUTOINST*/
     // Outputs
     .I					(I[(HIGHEST_LANE*12)-1:0]),
     .cq_clk				(cq_clk[(HIGHEST_BANK*4)-1:0]),
     .cqn_clk				(cqn_clk[(HIGHEST_BANK*4)-1:0]),
     .dbg_q_tapcnt			(dbg_idel_tap_cnt[TAP_BITS*DATA_WIDTH-1:0]), // Templated
     .idelay_ce				(idelay_ce[(HIGHEST_LANE*12)-1:0]),
     .idelay_cnt_in			(idelay_cnt_in[HIGHEST_BANK*240-1:0]),
     .idelay_inc			(idelay_inc[(HIGHEST_LANE*12)-1:0]),
     .phy_dout				(phy_dout[HIGHEST_LANE*80-1:0]),
     .qdr_bw_n				(qdr_bw_n[BW_WIDTH-1:0]),
     .qdr_d				(qdr_d[DATA_WIDTH-1:0]),
     .qdr_dll_off_n			(qdr_dll_off_n),
     .qdr_k_n				(qdr_k_n[NUM_DEVICES-1:0]),
     .qdr_k_p				(qdr_k_p[NUM_DEVICES-1:0]),
     .qdr_r_n				(qdr_r_n),
     .qdr_sa				(qdr_sa[ADDR_WIDTH-1:0]),
     .qdr_w_n				(qdr_w_n),
     .rd_data_map			(rd_data_map[nCK_PER_CLK*2*DATA_WIDTH-1:0]),
     // Inputs
     .O					(O[(HIGHEST_LANE*12)-1:0]),
     .byte_sel_cnt			(byte_sel_cnt[5:0]),
     .clk				(clk),
     .dbg_dec_q				(1'b0),			 // Templated
     .dbg_dec_q_all			(1'b0),			 // Templated
     .dbg_inc_q				(1'b0),			 // Templated
     .dbg_inc_q_all			(1'b0),			 // Templated
     .dbg_sel_q				(dbg_bit_sel[Q_BITS-1:0]), // Templated
     .ddr_clk				(ddr_clk[HIGHEST_BANK*8-1:0]),
     .dlyval_dq				(dlyval_dq[5*DATA_WIDTH-1:0]),
     .idelay_cnt_out			(idelay_cnt_out[HIGHEST_BANK*240-1:0]),
     .iob_addr				(iob_addr[nCK_PER_CLK*2*ADDR_WIDTH-1:0]),
     .iob_bw				(iob_bw[nCK_PER_CLK*2*BW_WIDTH-1:0]),
     .iob_dll_off_n			(iob_dll_off_n),
     .iob_rd_n				(iob_rd_n[nCK_PER_CLK*2-1:0]),
     .iob_wdata				(iob_wdata[nCK_PER_CLK*2*DATA_WIDTH-1:0]),
     .iob_wr_n				(iob_wr_n[nCK_PER_CLK*2-1:0]),
     .phy_din				(phy_din[HIGHEST_LANE*80-1:0]),
     .phy_init_data_sel			(1'b0),			 // Templated
     .qdr_cq_n				(qdr_cq_n[NUM_DEVICES-1:0]),
     .qdr_cq_p				(qdr_cq_p[NUM_DEVICES-1:0]),
     .qdr_q				(qdr_q[DATA_WIDTH-1:0]),
     .rst				(rst_clk));		 // Templated

  wire pi_fine_enable = pi_en_stg2_f | dbg_phy_pi_fine_enable;
  wire pi_fine_inc = pi_stg2_f_incdec | dbg_phy_pi_fine_inc;
  wire idelay_ld = ~rdlvl_stg1_done;

  // AUTOINSTPARAM won't work well because lots of paramater computation
  // at the top of _mc_phy.  These probably should have been localparams.
  
  /* mig_7series_v2_4_qdr_rld_mc_phy AUTO_TEMPLATE (
     .dbg_byte_lane			(),
     .dbg_phy_4lanes			(),
     .sys_rst                           (rst),
     .rst_rd_clk                        (rst_clk),
     .phy_clk                           (clk),
     .phy_clk_fast                      (1'b0),
     .mem_refclk                        (clk_mem),
     .phy_write_calib                   (1'b0),
     .phy_read_calib                    (1'b0),
     .phy_rd_en                         (if_rden),
     .idelay_ce				(idelay_ce[(HIGHEST_LANE*12)-1:0]),
     .idelay_inc			(idelay_inc[(HIGHEST_LANE*12)-1:0]),
     .if_full                           (),
     .of_empty                          (),
     .mem_dq_ts                         (),
     .DCK_byte_cal_en                   (1'b0),
     .phy_cmd_wr_en                     (of_cmd_wr_en ),
     .phy_data_wr_en                    (of_data_wr_en),
     .po_coarse_enable                  (1'b0), 
     .po_edge_adv                       (1'b0),
     .po_coarse_inc                     (1'b0),
     .po_counter_load_en                (1'b0),  
     .po_counter_load_val               (9'b0),     
     .po_counter_read_en                (1'b1), 
     .po_coarse_overflow                (),     
     .po_fine_overflow                  (),
     .pi_edge_adv                       (pi_edge_adv_2r),
     .pi_counter_load_en                (pi_stg2_load),
     .pi_counter_load_val               (pi_stg2_reg_l),
     .pi_counter_read_en                (1'b1),
     .pi_fine_overflow                  (),) */
  
  mig_7series_v2_4_qdr_rld_mc_phy #
    (.MEMORY_TYPE                       (MEM_TYPE),
     .MEM_TYPE                          (MEM_TYPE),
     .SIMULATION                        (SIMULATION),
     .SIM_BYPASS_INIT_CAL               (SIM_BYPASS_INIT_CAL),
     .CPT_CLK_CQ_ONLY                   (CPT_CLK_CQ_ONLY),
     .INTERFACE_TYPE                    (MEMORY_IO_DIR),
     .ADDR_CTL_MAP                      (ADDR_CTL_MAP),
     .BYTE_LANES_B0                     (BYTE_LANES_B0), 
     .BYTE_LANES_B1                     (BYTE_LANES_B1),
     .BYTE_LANES_B2                     (BYTE_LANES_B2),
     .BYTE_LANES_B3                     (BYTE_LANES_B3),
     .BYTE_LANES_B4                     (BYTE_LANES_B4),
     .BITLANES_IN_B0                    (BITLANES_IN_B0),
     .BITLANES_IN_B1                    (BITLANES_IN_B1),
     .BITLANES_IN_B2                    (BITLANES_IN_B2),
     .BITLANES_IN_B3                    (BITLANES_IN_B3),
     .BITLANES_IN_B4                    (BITLANES_IN_B4),
     .BITLANES_OUT_B0                   (BITLANES_OUT_B0),
     .BITLANES_OUT_B1                   (BITLANES_OUT_B1),
     .BITLANES_OUT_B2                   (BITLANES_OUT_B2),
     .BITLANES_OUT_B3                   (BITLANES_OUT_B3),
     .BITLANES_OUT_B4                   (BITLANES_OUT_B4), 
     .DATA_CTL_B0                       (DATA_CTL_B0),
     .DATA_CTL_B1                       (DATA_CTL_B1),
     .DATA_CTL_B2                       (DATA_CTL_B2),
     .DATA_CTL_B3                       (DATA_CTL_B3),
     .DATA_CTL_B4                       (DATA_CTL_B4),
     .CPT_CLK_SEL_B0                    (CPT_CLK_SEL_B0),
     .CPT_CLK_SEL_B1                    (CPT_CLK_SEL_B1),  
     .CPT_CLK_SEL_B2                    (CPT_CLK_SEL_B2),
     .BYTE_GROUP_TYPE_B0                (BYTE_GROUP_TYPE_B0),
     .BYTE_GROUP_TYPE_B1                (BYTE_GROUP_TYPE_B1),
     .BYTE_GROUP_TYPE_B2                (BYTE_GROUP_TYPE_B2),
     .BYTE_GROUP_TYPE_B3                (BYTE_GROUP_TYPE_B3),
     .BYTE_GROUP_TYPE_B4                (BYTE_GROUP_TYPE_B4),
     .HIGHEST_LANE                      (HIGHEST_LANE),
     .BUFMR_DELAY                       (BUFMR_DELAY),
     .PLL_LOC                           (PLL_LOC),
     .INTER_BANK_SKEW                   (INTER_BANK_SKEW), 
     .MASTER_PHY_CTL                    (MASTER_PHY_CTL),
     .DIFF_CK                           (1'b1),
     .DIFF_DK                           (1'b1),
     .DIFF_CQ                           (1'b0),
     .CK_VALUE_D1                       (1'b0),
     .DK_VALUE_D1                       (1'b0),
     .CK_MAP                            (48'h0),
     .CK_WIDTH                          (0),
     .DK_MAP                            (K_MAP),
     .CQ_MAP                            (CQ_MAP),
     .DK_WIDTH                          (NUM_DEVICES),
     .CQ_WIDTH                          (NUM_DEVICES),      
     .IODELAY_GRP                       (IODELAY_GRP),
     .IODELAY_HP_MODE                   (IODELAY_HP_MODE),
     .CLK_PERIOD                        (CLK_PERIOD),
     .PRE_FIFO                          (PRE_FIFO),
     .PHY_0_PO_FINE_DELAY               (PO_FINE_DELAY),
     .PHY_0_PI_FINE_DELAY               (PI_FINE_DELAY),	  
     .REFCLK_FREQ                       (REFCLK_FREQ),
     .ADDR_CTL_90_SHIFT                 (ADDR_CTL_90_SHIFT),
     .BUFG_FOR_OUTPUTS                  (BUFG_FOR_OUTPUTS),
     .PO_COARSE_BYPASS                  (PO_COARSE_BYPASS),
     .TCQ                               (TCQ)) 
  u_qdr_rld_mc_phy
    (/*AUTOINST*/
     // Outputs
     .O					(O[(HIGHEST_LANE*12)-1:0]),
     .dbg_PO_read_value			(dbg_PO_read_value[107:0]),
     .dbg_byte_lane			(),			 // Templated
     .dbg_calib_po_tstpoint		(dbg_calib_po_tstpoint[47:0]),
     .dbg_mc_phy			(dbg_mc_phy[255:0]),
     .dbg_oclkdly_clk			(dbg_oclkdly_clk),
     .dbg_phy_4lanes			(),			 // Templated
     .ddr_clk				(ddr_clk[(HIGHEST_BANK*8)-1:0]),
     .idelay_cnt_out			(idelay_cnt_out[HIGHEST_BANK*240-1:0]),
     .if_a_empty			(if_a_empty),
     .if_empty				(if_empty),
     .if_full				(),			 // Templated
     .mem_dq_ts				(),			 // Templated
     .of_ctl_a_full			(of_ctl_a_full),
     .of_ctl_full			(of_ctl_full),
     .of_data_a_full			(of_data_a_full),
     .of_data_full			(of_data_full),
     .of_empty				(),			 // Templated
     .phy_ctl_a_full			(phy_ctl_a_full),
     .phy_ctl_full			(phy_ctl_full),
     .phy_ctl_ready			(phy_ctl_ready),
     .phy_din				(phy_din[HIGHEST_LANE*80-1:0]),
     .pi_counter_read_val		(pi_counter_read_val[5:0]),
     .pi_fine_overflow			(),			 // Templated
     .po_coarse_overflow		(),			 // Templated
     .po_counter_read_val		(po_counter_read_val[8:0]),
     .po_delay_done			(po_delay_done),
     .po_fine_overflow			(),			 // Templated
     .ref_dll_lock			(ref_dll_lock),
     .tmp_lb_clk			(tmp_lb_clk[11:0]),
     // Inputs
     .DCK_byte_cal_en			(1'b0),			 // Templated
     .I					(I[(HIGHEST_LANE*12)-1:0]),
     .calib_in_common			(calib_in_common),
     .calib_sel				(calib_sel[5:0]),
     .calib_zero_inputs			(calib_zero_inputs[HIGHEST_BANK-1:0]),
     .cq_clk				(cq_clk[(HIGHEST_BANK*4)-1:0]),
     .cqn_clk				(cqn_clk[(HIGHEST_BANK*4)-1:0]),
     .freq_refclk			(freq_refclk),
     .idelay_ce				(idelay_ce[(HIGHEST_LANE*12)-1:0]), // Templated
     .idelay_cnt_in			(idelay_cnt_in[HIGHEST_BANK*240-1:0]),
     .idelay_inc			(idelay_inc[(HIGHEST_LANE*12)-1:0]), // Templated
     .idelay_ld				(idelay_ld),
     .mem_refclk			(clk_mem),		 // Templated
     .phy_clk				(clk),			 // Templated
     .phy_clk_fast			(1'b0),			 // Templated
     .phy_cmd_wr_en			(of_cmd_wr_en ),	 // Templated
     .phy_ctl_wd			(phy_ctl_wd[31:0]),
     .phy_ctl_wr			(phy_ctl_wr),
     .phy_data_wr_en			(of_data_wr_en),	 // Templated
     .phy_dout				(phy_dout[HIGHEST_LANE*80-1:0]),
     .phy_rd_en				(if_rden),		 // Templated
     .phy_read_calib			(1'b0),			 // Templated
     .phy_write_calib			(1'b0),			 // Templated
     .pi_counter_load_en		(pi_stg2_load),		 // Templated
     .pi_counter_load_val		(pi_stg2_reg_l),	 // Templated
     .pi_counter_read_en		(1'b1),			 // Templated
     .pi_edge_adv			(pi_edge_adv_2r),	 // Templated
     .pi_fine_enable			(pi_fine_enable),
     .pi_fine_inc			(pi_fine_inc),
     .pll_lock				(pll_lock),
     .po_coarse_enable			(1'b0),			 // Templated
     .po_coarse_inc			(1'b0),			 // Templated
     .po_counter_load_en		(1'b0),			 // Templated
     .po_counter_load_val		(9'b0),			 // Templated
     .po_counter_read_en		(1'b1),			 // Templated
     .po_dec_done			(po_dec_done),
     .po_edge_adv			(1'b0),			 // Templated
     .po_fine_enable			(po_fine_enable),
     .po_fine_inc			(po_fine_inc),
     .po_inc_done			(po_inc_done),
     .po_sel_fine_oclk_delay		(po_sel_fine_oclk_delay),
     .rst				(rst),
     .rst_phaser_ref			(rst_phaser_ref),
     .rst_rd_clk			(rst_clk),		 // Templated
     .sync_pulse			(sync_pulse),
     .sys_rst				(rst));			 // Templated
 
  assign dbg_idel_tap_cnt_sel = dbg_idel_tap_cnt[(dbg_bit_sel*TAP_BITS)+:TAP_BITS];

  
  //register the data chipscope signals for better timing
  //needed if the interface gets wide and spans multiple banks
  //no need for reset
  always @ (posedge clk) begin
    if (dbg_bit_sel < 9) 
      dbg_select_rdata <= #TCQ 3'd0;
    else if (dbg_bit_sel < 18) 
      dbg_select_rdata <= #TCQ 3'd1;
    else if (dbg_bit_sel < 27)
      dbg_select_rdata <= #TCQ 3'd2;
    else if (dbg_bit_sel < 36) 
      dbg_select_rdata <= #TCQ 3'd3;
    else //default case for 9-bit interface
      dbg_select_rdata <= #TCQ 3'd0;
    
    //extra registers just in case
    dbg_select_rdata_r1 <= #TCQ dbg_select_rdata;
    dbg_select_rdata_r2 <= #TCQ dbg_select_rdata_r1;
  end

  //Use minimal chipscope signals to view data, so mux data
  //Supports up to 36-bit width
  generate 
    if (DATA_WIDTH <= 9) begin: gen_dbg_rdata_9_0
      always @ (posedge clk) begin
        dbg_align_rd0_r  <= #TCQ dbg_align_rd0[DATA_WIDTH-1:0];
        dbg_align_fd0_r  <= #TCQ dbg_align_fd0[DATA_WIDTH-1:0];
        dbg_align_rd1_r  <= #TCQ dbg_align_rd1[DATA_WIDTH-1:0];
        dbg_align_fd1_r  <= #TCQ dbg_align_fd1[DATA_WIDTH-1:0];
      end
      
    end else if (DATA_WIDTH <= 18)begin : gen_dbg_rdata_18_0
      always @ (posedge clk) begin
        if (dbg_select_rdata_r2 == 3'd0) begin
          dbg_align_rd0_r  <= #TCQ dbg_align_rd0[8:0];
          dbg_align_fd0_r  <= #TCQ dbg_align_fd0[8:0];
          dbg_align_rd1_r  <= #TCQ dbg_align_rd1[8:0];
          dbg_align_fd1_r  <= #TCQ dbg_align_fd1[8:0];
        end else begin
          dbg_align_rd0_r  <= #TCQ dbg_align_rd0[DATA_WIDTH-1:9];
          dbg_align_fd0_r  <= #TCQ dbg_align_fd0[DATA_WIDTH-1:9];
          dbg_align_rd1_r  <= #TCQ dbg_align_fd0[DATA_WIDTH-1:9];
          dbg_align_fd1_r  <= #TCQ dbg_align_fd1[DATA_WIDTH-1:9];
        end //end of if
      end //end always
    end else if (DATA_WIDTH <= 27)begin : gen_dbg_rdata_27_0
      always @ (posedge clk) begin
        if (dbg_select_rdata_r2 == 3'd0) begin
          dbg_align_rd0_r  <= #TCQ dbg_align_rd0[8:0];
          dbg_align_fd0_r  <= #TCQ dbg_align_fd0[8:0];
          dbg_align_rd1_r  <= #TCQ dbg_align_rd1[8:0];
          dbg_align_fd1_r  <= #TCQ dbg_align_fd1[8:0];
        end else if (dbg_select_rdata_r2 == 3'd1) begin
          dbg_align_rd0_r  <= #TCQ dbg_align_rd0[17:9];
          dbg_align_fd0_r  <= #TCQ dbg_align_fd0[17:9];
          dbg_align_rd1_r  <= #TCQ dbg_align_rd1[17:9];
          dbg_align_fd1_r  <= #TCQ dbg_align_fd1[17:9];
        end else begin
          dbg_align_rd0_r  <= #TCQ dbg_align_rd0[DATA_WIDTH-1:18];
          dbg_align_fd0_r  <= #TCQ dbg_align_fd0[DATA_WIDTH-1:18];
          dbg_align_rd1_r  <= #TCQ dbg_align_fd0[DATA_WIDTH-1:18];
          dbg_align_fd1_r  <= #TCQ dbg_align_fd1[DATA_WIDTH-1:18];
        end //end of if
      end //end always
    end else if (DATA_WIDTH <= 36)begin : gen_dbg_rdata_35_0
      always @ (posedge clk) begin
        if (dbg_select_rdata_r2 == 3'd0) begin
          dbg_align_rd0_r  <= #TCQ dbg_align_rd0[8:0];
          dbg_align_fd0_r  <= #TCQ dbg_align_fd0[8:0];
          dbg_align_rd1_r  <= #TCQ dbg_align_rd1[8:0];
          dbg_align_fd1_r  <= #TCQ dbg_align_fd1[8:0];
        end else if (dbg_select_rdata_r2 == 3'd1) begin
          dbg_align_rd0_r  <= #TCQ dbg_align_rd0[17:9];
          dbg_align_fd0_r  <= #TCQ dbg_align_fd0[17:9];
          dbg_align_rd1_r  <= #TCQ dbg_align_rd1[17:9];
          dbg_align_fd1_r  <= #TCQ dbg_align_fd1[17:9];
        end else if (dbg_select_rdata_r2 == 3'd2) begin
          dbg_align_rd0_r  <= #TCQ dbg_align_rd0[26:18];
          dbg_align_fd0_r  <= #TCQ dbg_align_fd0[26:18];
          dbg_align_rd1_r  <= #TCQ dbg_align_rd1[26:18];
          dbg_align_fd1_r  <= #TCQ dbg_align_fd1[26:18];
        end else begin
          dbg_align_rd0_r  <= #TCQ dbg_align_rd0[DATA_WIDTH-1:27];
          dbg_align_fd0_r  <= #TCQ dbg_align_fd0[DATA_WIDTH-1:27];
          dbg_align_rd1_r  <= #TCQ dbg_align_fd0[DATA_WIDTH-1:27];
          dbg_align_fd1_r  <= #TCQ dbg_align_fd1[DATA_WIDTH-1:27];
        end //end of if
      end //end always
    end
  endgenerate
  
endmodule // mig_7series_v2_4_qdr_phy_top


// Local Variables:
// verilog-library-directories:(".")
// verilog-library-extensions:(".v")
// End:
