-- Copyright 1986-2015 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2015.4 (lin64) Build 1412921 Wed Nov 18 09:44:32 MST 2015
-- Date        : Thu Aug 11 18:41:53 2016
-- Host        : jgn-tv4 running 64-bit unknown
-- Command     : write_vhdl -force -mode synth_stub
--               /home/aom/work/Lgen/boards/nfsume/ip_catalog/sram_mig/sram_mig_stub.vhdl
-- Design      : sram_mig
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xc7vx690tffg1761-3
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity sram_mig is
  Port ( 
    sys_clk_i : in STD_LOGIC;
    qdriip_cq_p : in STD_LOGIC_VECTOR ( 0 to 0 );
    qdriip_cq_n : in STD_LOGIC_VECTOR ( 0 to 0 );
    qdriip_q : in STD_LOGIC_VECTOR ( 35 downto 0 );
    qdriip_k_p : inout STD_LOGIC_VECTOR ( 0 to 0 );
    qdriip_k_n : inout STD_LOGIC_VECTOR ( 0 to 0 );
    qdriip_d : out STD_LOGIC_VECTOR ( 35 downto 0 );
    qdriip_sa : out STD_LOGIC_VECTOR ( 18 downto 0 );
    qdriip_w_n : out STD_LOGIC;
    qdriip_r_n : out STD_LOGIC;
    qdriip_bw_n : out STD_LOGIC_VECTOR ( 3 downto 0 );
    qdriip_dll_off_n : out STD_LOGIC;
    app_wr_cmd0 : in STD_LOGIC;
    app_wr_addr0 : in STD_LOGIC_VECTOR ( 18 downto 0 );
    app_wr_data0 : in STD_LOGIC_VECTOR ( 143 downto 0 );
    app_wr_bw_n0 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    app_rd_cmd0 : in STD_LOGIC;
    app_rd_addr0 : in STD_LOGIC_VECTOR ( 18 downto 0 );
    app_rd_valid0 : out STD_LOGIC;
    app_rd_data0 : out STD_LOGIC_VECTOR ( 143 downto 0 );
    app_wr_cmd1 : in STD_LOGIC;
    app_wr_addr1 : in STD_LOGIC_VECTOR ( 18 downto 0 );
    app_wr_data1 : in STD_LOGIC_VECTOR ( 71 downto 0 );
    app_wr_bw_n1 : in STD_LOGIC_VECTOR ( 7 downto 0 );
    app_rd_cmd1 : in STD_LOGIC;
    app_rd_addr1 : in STD_LOGIC_VECTOR ( 18 downto 0 );
    app_rd_valid1 : out STD_LOGIC;
    app_rd_data1 : out STD_LOGIC_VECTOR ( 71 downto 0 );
    clk : out STD_LOGIC;
    rst_clk : out STD_LOGIC;
    init_calib_complete : out STD_LOGIC;
    sys_rst : in STD_LOGIC
  );

end sram_mig;

architecture stub of sram_mig is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "sys_clk_i,qdriip_cq_p[0:0],qdriip_cq_n[0:0],qdriip_q[35:0],qdriip_k_p[0:0],qdriip_k_n[0:0],qdriip_d[35:0],qdriip_sa[18:0],qdriip_w_n,qdriip_r_n,qdriip_bw_n[3:0],qdriip_dll_off_n,app_wr_cmd0,app_wr_addr0[18:0],app_wr_data0[143:0],app_wr_bw_n0[15:0],app_rd_cmd0,app_rd_addr0[18:0],app_rd_valid0,app_rd_data0[143:0],app_wr_cmd1,app_wr_addr1[18:0],app_wr_data1[71:0],app_wr_bw_n1[7:0],app_rd_cmd1,app_rd_addr1[18:0],app_rd_valid1,app_rd_data1[71:0],clk,rst_clk,init_calib_complete,sys_rst";
begin
end;
