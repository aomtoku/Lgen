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
// /___/  \  /    Vendor             : Xilinx
// \   \   \/     Version            : 2.4
//  \   \         Application        : MIG
//  /   /         Filename           : sim_tb_top.v
// /___/   /\     Date Last Modified : $Date: 2011/06/07 13:45:16 $
// \   \  /  \    Date Created       : Fri Jan 14 2011
//  \___\/\___\
//
// Device           : 7 Series
// Design Name      : QDRII+ SRAM
// Purpose          :
//                   Top-level testbench for testing QDRII+.
//                   Instantiates:
//                     1. IP_TOP (top-level representing FPGA, contains core,
//                        clocking, built-in testbench/memory checker and other
//                        support structures)
//                     2. QDRII+ Memory Instantiations (Samsung only)
//                     3. Miscellaneous clock generation and reset logic
// Reference        :
// Revision History :
//******************************************************************************

`timescale  1 ps/100 fs

module sim_tb_top;


   localparam MEM_TYPE              = "QDR2PLUS";
                                     // # of CK/CK# outputs to memory.
   localparam DATA_WIDTH            = 36;
                                     // # of DQ (data)
   localparam BW_WIDTH              = 4;
                                     // # of byte writes (data_width/9)
   localparam ADDR_WIDTH            = 19;
                                     // Address Width
   localparam NUM_DEVICES           = 1;
                                     // # of memory components connected

   //***************************************************************************
   // The following parameters are mode register settings
   //***************************************************************************
   localparam BURST_LEN             = 4;
                                     // Burst Length of the design (4 or 2).
   
   //***************************************************************************
   // The following parameters are multiplier and divisor factors for MMCM.
   // Based on the selected design frequency these parameters vary.
   //***************************************************************************
   localparam CLKIN_PERIOD          = 5000;
                                     // Input Clock Period

   //***************************************************************************
   // Simulation parameters
   //***************************************************************************
   localparam SIM_BYPASS_INIT_CAL   = "FAST";
                                     // # = "OFF" -  Complete memory init &
                                     //              calibration sequence
                                     // # = "FAST" - Skip memory init & use
                                     //              abbreviated calib sequence
   localparam SIMULATION            = "TRUE";
                                     // Should be TRUE during design simulations and
                                     // FALSE during implementations

   //***************************************************************************
   // IODELAY and PHY related parameters
   //***************************************************************************
   localparam TCQ                   = 100;
   //localparam IODELAY_GRP           = "SRAM_MIG_IODELAY_MIG";
                                     // It is associated to a set of IODELAYs with
                                     // an IDELAYCTRL that have same IODELAY CONTROLLER
                                     // clock frequency.
   localparam RST_ACT_LOW           = 0;
                                     // =1 for active low reset,
                                     // =0 for active high.

   
   //***************************************************************************
   // Referece clock frequency parameters
   //***************************************************************************
   localparam REFCLK_FREQ           = 200.0;
                                     // IODELAYCTRL reference clock frequency

   // Number of taps in target IDELAY
   localparam integer DEVICE_TAPS = 32;
      
   //***************************************************************************
   // System clock frequency parameters
   //***************************************************************************
   localparam CLK_PERIOD            = 2000;
                                     // memory tCK paramter.
                                     // # = Clock Period in pS.
   localparam nCK_PER_CLK           = 2;
                                     // # of memory CKs per fabric CLK

   //***************************************************************************
   // Traffic Gen related parameters
   //***************************************************************************
   localparam BL_WIDTH              = 8;
   localparam PORT_MODE             = "BI_MODE";
   localparam DATA_MODE             = 4'b0010;
   localparam EYE_TEST              = "FALSE";
                                     // set EYE_TEST = "TRUE" to probe memory
                                     // signals. Traffic Generator will only
                                     // write to one single location and no
                                     // read transactions will be generated.
   localparam DATA_PATTERN          = "DGEN_ALL";
                                      // "DGEN_HAMMER"; "DGEN_WALKING1",
                                      // "DGEN_WALKING0","DGEN_ADDR","
                                      // "DGEN_NEIGHBOR","DGEN_PRBS","DGEN_ALL"
   localparam CMD_PATTERN           = "CGEN_ALL";
                                      // "CGEN_PRBS","CGEN_FIXED","CGEN_BRAM",
                                      // "CGEN_SEQUENTIAL", "CGEN_ALL"
   localparam BEGIN_ADDRESS         = 32'h00000000;
   localparam END_ADDRESS           = 32'h00000fff;
   localparam PRBS_EADDR_MASK_POS   = 32'hfffff000;

   //***************************************************************************
   // Wait period for the read strobe (CQ) to become stable
   //***************************************************************************
   //localparam CLK_STABLE            = (20*1000*1000/(CLK_PERIOD*2));
                                     // Cycles till CQ/CQ# is stable

   //***************************************************************************
   // Debug parameter
   //***************************************************************************
   localparam DEBUG_PORT            = "OFF";
                                     // # = "ON" Enable debug signals/controls.
                                     //   = "OFF" Disable debug signals/controls.
      

  //**************************************************************************//
  // Local parameters Declarations
  //**************************************************************************//

  // Memory Component parameters
   localparam MEMORY_WIDTH          = DATA_WIDTH/NUM_DEVICES;
   localparam BW_COMP               = BW_WIDTH/NUM_DEVICES;

  //============================================================================
  //                        Delay Specific Parameters
  //============================================================================
   localparam TPROP_PCB_CTRL        = 0.00;             //Board delay value
   localparam TPROP_PCB_CQ          = 0.00;             //CQ delay
   localparam TPROP_PCB_DATA        = 0.00;             //DQ delay value
   localparam TPROP_PCB_DATA_RD     = 0.00;             //READ DQ delay value


  localparam real REFCLK_PERIOD = (1000000.0/(2*REFCLK_FREQ));
  localparam RESET_PERIOD = 200000; //in pSec  
    

  //**************************************************************************//
  // Wire Declarations
  //**************************************************************************//
  reg                                sys_rst_n;
  wire                               sys_rst;



   reg                      sys_clk;



   reg                      clk_ref;



   reg                     qdriip_w_n_delay;
   reg                     qdriip_r_n_delay;
   reg                     qdriip_dll_off_n_delay;
   wire [NUM_DEVICES-1:0]   qdriip_k_p_fpga;
   wire [NUM_DEVICES-1:0]   qdriip_k_n_fpga;
   reg [ADDR_WIDTH-1:0]    qdriip_sa_delay;
   reg [BW_WIDTH-1:0]      qdriip_bw_n_delay;
   reg [DATA_WIDTH-1:0]    qdriip_d_delay;
   reg [DATA_WIDTH-1:0]    qdriip_q_delay;
   reg [NUM_DEVICES-1:0]   qdriip_cq_p_delay;
   reg [NUM_DEVICES-1:0]   qdriip_cq_n_delay;


  wire                               init_calib_complete;
  wire                               tg_compare_error;

   wire                     qdriip_w_n;
   wire                     qdriip_r_n;
   wire                     qdriip_dll_off_n;
   wire [NUM_DEVICES-1:0]    qdriip_k_p_sram;
   wire [NUM_DEVICES-1:0]    qdriip_k_n_sram;
   wire [ADDR_WIDTH-1:0]    qdriip_sa;
   wire [BW_WIDTH-1:0]      qdriip_bw_n;
   wire [DATA_WIDTH-1:0]    qdriip_d;
   wire [DATA_WIDTH-1:0]    qdriip_q;
   wire [NUM_DEVICES-1:0]   qdriip_cq_p;
   wire [NUM_DEVICES-1:0]   qdriip_cq_n;



//**************************************************************************//

  //**************************************************************************//
  // Reset Generation
  //**************************************************************************//
  initial begin
    sys_rst_n = 1'b0;
    #RESET_PERIOD
      sys_rst_n = 1'b1;
   end

   assign sys_rst = RST_ACT_LOW ? sys_rst_n : ~sys_rst_n;

  //**************************************************************************//
  // Clock Generation
  //**************************************************************************//


   initial
     sys_clk    = 1'b0;
   // Generate design clock
   always #(CLKIN_PERIOD/2.0) sys_clk = ~sys_clk;



   initial
     clk_ref     = 1'b0;
   // Generate 200 MHz reference clock
   always #(REFCLK_PERIOD) clk_ref = ~clk_ref;




 
  //===========================================================================
  //                            BOARD Parameters
  //===========================================================================
  //These parameter values can be changed to model varying board delays
  //between the Virtex-6 device and the QDR II memory model
  // always @(qdriip_k_p or qdriip_k_n or qdriip_sa or qdriip_bw_n or qdriip_w_n or
  //          qdriip_d or qdriip_r_n or qdriip_q or qdriip_cq_p or qdriip_cq_n or
  //          qdriip_dll_off_n)

   always @*
   begin
     //qdriip_k_p_delay       <= #TPROP_PCB_CTRL    qdriip_k_p;
     //qdriip_k_n_delay       <= #TPROP_PCB_CTRL    qdriip_k_n;
     qdriip_sa_delay        <= #TPROP_PCB_CTRL    qdriip_sa;
     qdriip_bw_n_delay      <= #TPROP_PCB_CTRL    qdriip_bw_n;
     qdriip_w_n_delay       <= #TPROP_PCB_CTRL    qdriip_w_n;
     qdriip_d_delay         <= #TPROP_PCB_DATA    qdriip_d;
     qdriip_r_n_delay       <= #TPROP_PCB_CTRL    qdriip_r_n;
     qdriip_q_delay         <= #TPROP_PCB_DATA_RD qdriip_q;
     qdriip_cq_p_delay      <= #TPROP_PCB_CQ      qdriip_cq_p;
     qdriip_cq_n_delay      <= #TPROP_PCB_CQ      qdriip_cq_n;
     qdriip_dll_off_n_delay <= #TPROP_PCB_CTRL    qdriip_dll_off_n;
   end


  genvar kwd;
  generate
    for (kwd = 0;kwd < NUM_DEVICES;kwd = kwd+1) begin : k_delay
      WireDelay #(
        .Delay_g    (TPROP_PCB_CTRL),
        .Delay_rd   (TPROP_PCB_CTRL),
        .ERR_INSERT ("OFF")
      ) u_delay_k_p (
        .A             (qdriip_k_p_fpga[kwd]),
        .B             (qdriip_k_p_sram[kwd]),
        .reset         (sys_rst_n),
        .phy_init_done (init_calib_complete)
       );
      WireDelay #(
        .Delay_g    (TPROP_PCB_CTRL),
        .Delay_rd   (TPROP_PCB_CTRL),
        .ERR_INSERT ("OFF")
      ) u_delay_k_n (
        .A             (qdriip_k_n_fpga[kwd]),
        .B             (qdriip_k_n_sram[kwd]),
        .reset         (sys_rst_n),
        .phy_init_done (init_calib_complete)
       );
    end
  endgenerate


  //===========================================================================
  //                         FPGA Memory Controller
  //===========================================================================

  example_top #(

   .MEM_TYPE                (MEM_TYPE),
   .DATA_WIDTH              (DATA_WIDTH),
   .BW_WIDTH                (BW_WIDTH),
   .ADDR_WIDTH              (ADDR_WIDTH),

   //***************************************************************************
   // The following parameters are mode register settings
   //***************************************************************************
   .BURST_LEN               (BURST_LEN),

   //***************************************************************************
   // Simulation parameters
   //***************************************************************************
   .SIMULATION              (SIMULATION),

   //***************************************************************************
   // IODELAY and PHY related parameters
   //***************************************************************************
   .TCQ                     (TCQ),
      .DEVICE_TAPS                   (DEVICE_TAPS),

   
   //***************************************************************************
   // System clock frequency parameters
   //***************************************************************************
   .nCK_PER_CLK                   (nCK_PER_CLK),
      

   .BL_WIDTH                (BL_WIDTH),
   .PORT_MODE               (PORT_MODE),
   .DATA_MODE               (DATA_MODE),
   .EYE_TEST                (EYE_TEST),
   .DATA_PATTERN            (DATA_PATTERN),
   .CMD_PATTERN             (CMD_PATTERN),
   .BEGIN_ADDRESS           (BEGIN_ADDRESS),
   .END_ADDRESS             (END_ADDRESS),
   .PRBS_EADDR_MASK_POS     (PRBS_EADDR_MASK_POS),

   //***************************************************************************
   // Debug parameters
   //***************************************************************************
   .DEBUG_PORT              (DEBUG_PORT),
                                     // # = "ON" Enable debug signals/controls.
                                     //   = "OFF" Disable debug signals/controls.
      
      .RST_ACT_LOW               (RST_ACT_LOW)
   ) u_ip_top (


    .sys_clk_i            (sys_clk),



    .qdriip_dll_off_n      (qdriip_dll_off_n),
    .qdriip_cq_p           (qdriip_cq_p),
    .qdriip_cq_n           (qdriip_cq_n),
    .qdriip_q              (qdriip_q),
    .qdriip_k_p            (qdriip_k_p_fpga),
    .qdriip_k_n            (qdriip_k_n_fpga),
    .qdriip_d              (qdriip_d),
    .qdriip_sa             (qdriip_sa),
    .qdriip_w_n            (qdriip_w_n),
    .qdriip_r_n            (qdriip_r_n),
    .qdriip_bw_n           (qdriip_bw_n),


      .init_calib_complete (init_calib_complete),
      .tg_compare_error    (tg_compare_error),
      .sys_rst             (sys_rst)
     );

  //**************************************************************************//
  // Memory Models instantiations
  //**************************************************************************//

  // MIG does not output Cypress memory models. You have to instantiate the
  // appropriate Cypress memory model for the cypress controller designs
  // generated from MIG. Memory model instance name must be modified as per
  // the model downloaded from the memory vendor website
  genvar i;
  generate
    for(i=0; i<NUM_DEVICES; i=i+1)begin : COMP_INST
      cyqdr2_b4 QDR2PLUS_MEM
        (
         .TCK   ( 1'b0 ),
         .TMS   ( 1'b1 ),
         .TDI   ( 1'b1 ),
         .TDO   (),
         .D     ( qdriip_d_delay[(MEMORY_WIDTH*i)+:MEMORY_WIDTH] ),
         .Q     ( qdriip_q [(MEMORY_WIDTH*i)+:MEMORY_WIDTH]),
         .A     ( qdriip_sa_delay ),
         .K     ( qdriip_k_p_sram[i] ),
         .Kb    ( qdriip_k_n_sram[i] ),
         .RPSb  ( qdriip_r_n_delay ),
         .WPSb  ( qdriip_w_n_delay ),
         .BWS0b ( qdriip_bw_n_delay[(i*BW_COMP)] ),
         .BWS1b ( qdriip_bw_n_delay[(i*BW_COMP)+1] ),
         .BWS2b ( qdriip_bw_n_delay[(i*BW_COMP)+2] ),
         .BWS3b ( qdriip_bw_n_delay[(i*BW_COMP)+3] ),
         .CQ    ( qdriip_cq_p[i] ),
         .CQb   ( qdriip_cq_n[i] ),
         .ZQ    ( 1'b1 ),
         .DOFF  ( qdriip_dll_off_n_delay ),
         .QVLD  ( )
         );
    end
  endgenerate


  //***************************************************************************
  // Reporting the test case status
  // Status reporting logic exists both in simulation test bench (sim_tb_top)
  // and sim.do file for ModelSim. Any update in simulation run time or time out
  // in this file need to be updated in sim.do file as well.
  //***************************************************************************
  initial
  begin : Logging
     fork
        begin : calibration_done
           wait (init_calib_complete);
           $display("Calibration Done");
           #50000000.0;
           if (!tg_compare_error) begin
              $display("TEST PASSED");
           end
           else begin
              $display("TEST FAILED: DATA ERROR");
           end
           disable calib_not_done;
            $finish;
        end

        begin : calib_not_done
           if (SIM_BYPASS_INIT_CAL == "OFF")
             #2500000000.0;
           else
             #700000000.0;
           if (!init_calib_complete) begin
              $display("TEST FAILED: INITIALIZATION DID NOT COMPLETE");
           end
           disable calibration_done;
            $finish;
        end
     join
  end
    

endmodule
