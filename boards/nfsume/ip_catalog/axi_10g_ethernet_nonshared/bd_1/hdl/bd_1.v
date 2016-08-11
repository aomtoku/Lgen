//Copyright 1986-2015 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2015.4 (lin64) Build 1412921 Wed Nov 18 09:44:32 MST 2015
//Date        : Thu Aug 11 17:04:48 2016
//Host        : jgn-tv4 running 64-bit unknown
//Command     : generate_target bd_1.bd
//Design      : bd_1
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

(* CORE_GENERATION_INFO = "bd_1,IP_Integrator,{x_ipVendor=xilinx.com,x_ipLibrary=BlockDiagram,x_ipName=bd_1,x_ipVersion=1.00.a,x_ipLanguage=VERILOG,numBlks=4,numReposBlks=4,numNonXlnxBlks=0,numHierBlks=0,maxHierDepth=0,synth_mode=Global}" *) (* HW_HANDOFF = "axi_10g_ethernet_nonshared.hwdef" *) 
module bd_1
   (areset,
    areset_coreclk,
    coreclk,
    dclk,
    gtrxreset,
    gttxreset,
    m_axis_rx_tdata,
    m_axis_rx_tkeep,
    m_axis_rx_tlast,
    m_axis_rx_tuser,
    m_axis_rx_tvalid,
    mac_rx_configuration_vector,
    mac_status_vector,
    mac_tx_configuration_vector,
    pcs_pma_configuration_vector,
    pcs_pma_status_vector,
    pcspma_status,
    qplllock,
    qplloutclk,
    qplloutrefclk,
    reset_counter_done,
    rx_axis_aresetn,
    rx_resetdone,
    rx_statistics_valid,
    rx_statistics_vector,
    rxn,
    rxp,
    rxrecclk_out,
    s_axis_pause_tdata,
    s_axis_pause_tvalid,
    s_axis_tx_tdata,
    s_axis_tx_tkeep,
    s_axis_tx_tlast,
    s_axis_tx_tready,
    s_axis_tx_tuser,
    s_axis_tx_tvalid,
    signal_detect,
    sim_speedup_control,
    tx_axis_aresetn,
    tx_disable,
    tx_fault,
    tx_ifg_delay,
    tx_resetdone,
    tx_statistics_valid,
    tx_statistics_vector,
    txn,
    txoutclk,
    txp,
    txuserrdy,
    txusrclk,
    txusrclk2);
  input areset;
  input areset_coreclk;
  input coreclk;
  input dclk;
  input gtrxreset;
  input gttxreset;
  output [63:0]m_axis_rx_tdata;
  output [7:0]m_axis_rx_tkeep;
  output m_axis_rx_tlast;
  output m_axis_rx_tuser;
  output m_axis_rx_tvalid;
  input [79:0]mac_rx_configuration_vector;
  output [1:0]mac_status_vector;
  input [79:0]mac_tx_configuration_vector;
  input [535:0]pcs_pma_configuration_vector;
  output [447:0]pcs_pma_status_vector;
  output [7:0]pcspma_status;
  input qplllock;
  input qplloutclk;
  input qplloutrefclk;
  input reset_counter_done;
  input rx_axis_aresetn;
  output rx_resetdone;
  output rx_statistics_valid;
  output [29:0]rx_statistics_vector;
  input rxn;
  input rxp;
  output rxrecclk_out;
  input [15:0]s_axis_pause_tdata;
  input s_axis_pause_tvalid;
  input [63:0]s_axis_tx_tdata;
  input [7:0]s_axis_tx_tkeep;
  input s_axis_tx_tlast;
  output s_axis_tx_tready;
  input [0:0]s_axis_tx_tuser;
  input s_axis_tx_tvalid;
  input signal_detect;
  input sim_speedup_control;
  input tx_axis_aresetn;
  output tx_disable;
  input tx_fault;
  input [7:0]tx_ifg_delay;
  output tx_resetdone;
  output tx_statistics_valid;
  output [25:0]tx_statistics_vector;
  output txn;
  output txoutclk;
  output txp;
  input txuserrdy;
  input txusrclk;
  input txusrclk2;

  wire areset_1;
  wire areset_coreclk_1;
  wire coreclk_1;
  wire dclk_1;
  wire [0:0]dcm_locked_driver_dout;
  wire gtrxreset_1;
  wire gttxreset_1;
  wire [79:0]mac_rx_configuration_vector_1;
  wire [79:0]mac_tx_configuration_vector_1;
  wire [535:0]pcs_pma_configuration_vector_1;
  wire [2:0]pma_pmd_type_driver_dout;
  wire qplllock_1;
  wire qplloutclk_1;
  wire qplloutrefclk_1;
  wire reset_counter_done_1;
  wire rx_axis_aresetn_1;
  wire rxn_1;
  wire rxp_1;
  wire [15:0]s_axis_pause_1_TDATA;
  wire s_axis_pause_1_TVALID;
  wire [63:0]s_axis_tx_1_TDATA;
  wire [7:0]s_axis_tx_1_TKEEP;
  wire s_axis_tx_1_TLAST;
  wire s_axis_tx_1_TREADY;
  wire [0:0]s_axis_tx_1_TUSER;
  wire s_axis_tx_1_TVALID;
  wire signal_detect_1;
  wire sim_speedup_control_1;
  wire [63:0]ten_gig_eth_mac_m_axis_rx_TDATA;
  wire [7:0]ten_gig_eth_mac_m_axis_rx_TKEEP;
  wire ten_gig_eth_mac_m_axis_rx_TLAST;
  wire ten_gig_eth_mac_m_axis_rx_TUSER;
  wire ten_gig_eth_mac_m_axis_rx_TVALID;
  wire ten_gig_eth_mac_rx_statistics_valid;
  wire [29:0]ten_gig_eth_mac_rx_statistics_vector;
  wire [1:0]ten_gig_eth_mac_status_vector;
  wire ten_gig_eth_mac_tx_statistics_valid;
  wire [25:0]ten_gig_eth_mac_tx_statistics_vector;
  wire [7:0]ten_gig_eth_mac_xgmii_xgmac_RXC;
  wire [63:0]ten_gig_eth_mac_xgmii_xgmac_RXD;
  wire [7:0]ten_gig_eth_mac_xgmii_xgmac_TXC;
  wire [63:0]ten_gig_eth_mac_xgmii_xgmac_TXD;
  wire [15:0]ten_gig_eth_pcs_pma_core_gt_drp_interface_DADDR;
  wire ten_gig_eth_pcs_pma_core_gt_drp_interface_DEN;
  wire [15:0]ten_gig_eth_pcs_pma_core_gt_drp_interface_DI;
  wire [15:0]ten_gig_eth_pcs_pma_core_gt_drp_interface_DO;
  wire ten_gig_eth_pcs_pma_core_gt_drp_interface_DRDY;
  wire ten_gig_eth_pcs_pma_core_gt_drp_interface_DWE;
  wire [7:0]ten_gig_eth_pcs_pma_core_status;
  wire ten_gig_eth_pcs_pma_drp_req;
  wire ten_gig_eth_pcs_pma_rx_resetdone;
  wire ten_gig_eth_pcs_pma_rxrecclk_out;
  wire [447:0]ten_gig_eth_pcs_pma_status_vector;
  wire ten_gig_eth_pcs_pma_tx_disable;
  wire ten_gig_eth_pcs_pma_tx_resetdone;
  wire ten_gig_eth_pcs_pma_txn;
  wire ten_gig_eth_pcs_pma_txoutclk;
  wire ten_gig_eth_pcs_pma_txp;
  wire tx_axis_aresetn_1;
  wire tx_fault_1;
  wire [7:0]tx_ifg_delay_1;
  wire txuserrdy_1;
  wire txusrclk2_1;
  wire txusrclk_1;

  assign areset_1 = areset;
  assign areset_coreclk_1 = areset_coreclk;
  assign coreclk_1 = coreclk;
  assign dclk_1 = dclk;
  assign gtrxreset_1 = gtrxreset;
  assign gttxreset_1 = gttxreset;
  assign m_axis_rx_tdata[63:0] = ten_gig_eth_mac_m_axis_rx_TDATA;
  assign m_axis_rx_tkeep[7:0] = ten_gig_eth_mac_m_axis_rx_TKEEP;
  assign m_axis_rx_tlast = ten_gig_eth_mac_m_axis_rx_TLAST;
  assign m_axis_rx_tuser = ten_gig_eth_mac_m_axis_rx_TUSER;
  assign m_axis_rx_tvalid = ten_gig_eth_mac_m_axis_rx_TVALID;
  assign mac_rx_configuration_vector_1 = mac_rx_configuration_vector[79:0];
  assign mac_status_vector[1:0] = ten_gig_eth_mac_status_vector;
  assign mac_tx_configuration_vector_1 = mac_tx_configuration_vector[79:0];
  assign pcs_pma_configuration_vector_1 = pcs_pma_configuration_vector[535:0];
  assign pcs_pma_status_vector[447:0] = ten_gig_eth_pcs_pma_status_vector;
  assign pcspma_status[7:0] = ten_gig_eth_pcs_pma_core_status;
  assign qplllock_1 = qplllock;
  assign qplloutclk_1 = qplloutclk;
  assign qplloutrefclk_1 = qplloutrefclk;
  assign reset_counter_done_1 = reset_counter_done;
  assign rx_axis_aresetn_1 = rx_axis_aresetn;
  assign rx_resetdone = ten_gig_eth_pcs_pma_rx_resetdone;
  assign rx_statistics_valid = ten_gig_eth_mac_rx_statistics_valid;
  assign rx_statistics_vector[29:0] = ten_gig_eth_mac_rx_statistics_vector;
  assign rxn_1 = rxn;
  assign rxp_1 = rxp;
  assign rxrecclk_out = ten_gig_eth_pcs_pma_rxrecclk_out;
  assign s_axis_pause_1_TDATA = s_axis_pause_tdata[15:0];
  assign s_axis_pause_1_TVALID = s_axis_pause_tvalid;
  assign s_axis_tx_1_TDATA = s_axis_tx_tdata[63:0];
  assign s_axis_tx_1_TKEEP = s_axis_tx_tkeep[7:0];
  assign s_axis_tx_1_TLAST = s_axis_tx_tlast;
  assign s_axis_tx_1_TUSER = s_axis_tx_tuser[0];
  assign s_axis_tx_1_TVALID = s_axis_tx_tvalid;
  assign s_axis_tx_tready = s_axis_tx_1_TREADY;
  assign signal_detect_1 = signal_detect;
  assign sim_speedup_control_1 = sim_speedup_control;
  assign tx_axis_aresetn_1 = tx_axis_aresetn;
  assign tx_disable = ten_gig_eth_pcs_pma_tx_disable;
  assign tx_fault_1 = tx_fault;
  assign tx_ifg_delay_1 = tx_ifg_delay[7:0];
  assign tx_resetdone = ten_gig_eth_pcs_pma_tx_resetdone;
  assign tx_statistics_valid = ten_gig_eth_mac_tx_statistics_valid;
  assign tx_statistics_vector[25:0] = ten_gig_eth_mac_tx_statistics_vector;
  assign txn = ten_gig_eth_pcs_pma_txn;
  assign txoutclk = ten_gig_eth_pcs_pma_txoutclk;
  assign txp = ten_gig_eth_pcs_pma_txp;
  assign txuserrdy_1 = txuserrdy;
  assign txusrclk2_1 = txusrclk2;
  assign txusrclk_1 = txusrclk;
  bd_1_dcm_locked_driver_0 dcm_locked_driver
       (.dout(dcm_locked_driver_dout));
  bd_1_pma_pmd_type_driver_0 pma_pmd_type_driver
       (.dout(pma_pmd_type_driver_dout));
  bd_1_ten_gig_eth_mac_0 ten_gig_eth_mac
       (.pause_req(s_axis_pause_1_TVALID),
        .pause_val(s_axis_pause_1_TDATA),
        .reset(areset_1),
        .rx_axis_aresetn(rx_axis_aresetn_1),
        .rx_axis_tdata(ten_gig_eth_mac_m_axis_rx_TDATA),
        .rx_axis_tkeep(ten_gig_eth_mac_m_axis_rx_TKEEP),
        .rx_axis_tlast(ten_gig_eth_mac_m_axis_rx_TLAST),
        .rx_axis_tuser(ten_gig_eth_mac_m_axis_rx_TUSER),
        .rx_axis_tvalid(ten_gig_eth_mac_m_axis_rx_TVALID),
        .rx_clk0(coreclk_1),
        .rx_configuration_vector(mac_rx_configuration_vector_1),
        .rx_dcm_locked(dcm_locked_driver_dout),
        .rx_statistics_valid(ten_gig_eth_mac_rx_statistics_valid),
        .rx_statistics_vector(ten_gig_eth_mac_rx_statistics_vector),
        .status_vector(ten_gig_eth_mac_status_vector),
        .tx_axis_aresetn(tx_axis_aresetn_1),
        .tx_axis_tdata(s_axis_tx_1_TDATA),
        .tx_axis_tkeep(s_axis_tx_1_TKEEP),
        .tx_axis_tlast(s_axis_tx_1_TLAST),
        .tx_axis_tready(s_axis_tx_1_TREADY),
        .tx_axis_tuser(s_axis_tx_1_TUSER),
        .tx_axis_tvalid(s_axis_tx_1_TVALID),
        .tx_clk0(coreclk_1),
        .tx_configuration_vector(mac_tx_configuration_vector_1),
        .tx_dcm_locked(dcm_locked_driver_dout),
        .tx_ifg_delay(tx_ifg_delay_1),
        .tx_statistics_valid(ten_gig_eth_mac_tx_statistics_valid),
        .tx_statistics_vector(ten_gig_eth_mac_tx_statistics_vector),
        .xgmii_rxc(ten_gig_eth_mac_xgmii_xgmac_RXC),
        .xgmii_rxd(ten_gig_eth_mac_xgmii_xgmac_RXD),
        .xgmii_txc(ten_gig_eth_mac_xgmii_xgmac_TXC),
        .xgmii_txd(ten_gig_eth_mac_xgmii_xgmac_TXD));
  bd_1_ten_gig_eth_pcs_pma_0 ten_gig_eth_pcs_pma
       (.areset(areset_1),
        .areset_coreclk(areset_coreclk_1),
        .configuration_vector(pcs_pma_configuration_vector_1),
        .core_status(ten_gig_eth_pcs_pma_core_status),
        .coreclk(coreclk_1),
        .dclk(dclk_1),
        .drp_daddr_i(ten_gig_eth_pcs_pma_core_gt_drp_interface_DADDR),
        .drp_daddr_o(ten_gig_eth_pcs_pma_core_gt_drp_interface_DADDR),
        .drp_den_i(ten_gig_eth_pcs_pma_core_gt_drp_interface_DEN),
        .drp_den_o(ten_gig_eth_pcs_pma_core_gt_drp_interface_DEN),
        .drp_di_i(ten_gig_eth_pcs_pma_core_gt_drp_interface_DI),
        .drp_di_o(ten_gig_eth_pcs_pma_core_gt_drp_interface_DI),
        .drp_drdy_i(ten_gig_eth_pcs_pma_core_gt_drp_interface_DRDY),
        .drp_drdy_o(ten_gig_eth_pcs_pma_core_gt_drp_interface_DRDY),
        .drp_drpdo_i(ten_gig_eth_pcs_pma_core_gt_drp_interface_DO),
        .drp_drpdo_o(ten_gig_eth_pcs_pma_core_gt_drp_interface_DO),
        .drp_dwe_i(ten_gig_eth_pcs_pma_core_gt_drp_interface_DWE),
        .drp_dwe_o(ten_gig_eth_pcs_pma_core_gt_drp_interface_DWE),
        .drp_gnt(ten_gig_eth_pcs_pma_drp_req),
        .drp_req(ten_gig_eth_pcs_pma_drp_req),
        .gtrxreset(gtrxreset_1),
        .gttxreset(gttxreset_1),
        .pma_pmd_type(pma_pmd_type_driver_dout),
        .qplllock(qplllock_1),
        .qplloutclk(qplloutclk_1),
        .qplloutrefclk(qplloutrefclk_1),
        .reset_counter_done(reset_counter_done_1),
        .rx_resetdone(ten_gig_eth_pcs_pma_rx_resetdone),
        .rxn(rxn_1),
        .rxp(rxp_1),
        .rxrecclk_out(ten_gig_eth_pcs_pma_rxrecclk_out),
        .signal_detect(signal_detect_1),
        .sim_speedup_control(sim_speedup_control_1),
        .status_vector(ten_gig_eth_pcs_pma_status_vector),
        .tx_disable(ten_gig_eth_pcs_pma_tx_disable),
        .tx_fault(tx_fault_1),
        .tx_resetdone(ten_gig_eth_pcs_pma_tx_resetdone),
        .txn(ten_gig_eth_pcs_pma_txn),
        .txoutclk(ten_gig_eth_pcs_pma_txoutclk),
        .txp(ten_gig_eth_pcs_pma_txp),
        .txuserrdy(txuserrdy_1),
        .txusrclk(txusrclk_1),
        .txusrclk2(txusrclk2_1),
        .xgmii_rxc(ten_gig_eth_mac_xgmii_xgmac_RXC),
        .xgmii_rxd(ten_gig_eth_mac_xgmii_xgmac_RXD),
        .xgmii_txc(ten_gig_eth_mac_xgmii_xgmac_TXC),
        .xgmii_txd(ten_gig_eth_mac_xgmii_xgmac_TXD));
endmodule
