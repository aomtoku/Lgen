-- Copyright 1986-2015 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2015.4 (lin64) Build 1412921 Wed Nov 18 09:44:32 MST 2015
-- Date        : Thu Aug 11 17:09:07 2016
-- Host        : jgn-tv4 running 64-bit unknown
-- Command     : write_vhdl -force -mode synth_stub
--               /home/aom/work/Lgen/boards/nfsume/ip_catalog/sfifo_75_131k/sfifo_75_131k_stub.vhdl
-- Design      : sfifo_75_131k
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xc7vx690tffg1761-3
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity sfifo_75_131k is
  Port ( 
    clk : in STD_LOGIC;
    rst : in STD_LOGIC;
    din : in STD_LOGIC_VECTOR ( 74 downto 0 );
    wr_en : in STD_LOGIC;
    rd_en : in STD_LOGIC;
    dout : out STD_LOGIC_VECTOR ( 74 downto 0 );
    full : out STD_LOGIC;
    empty : out STD_LOGIC
  );

end sfifo_75_131k;

architecture stub of sfifo_75_131k is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "clk,rst,din[74:0],wr_en,rd_en,dout[74:0],full,empty";
attribute X_CORE_INFO : string;
attribute X_CORE_INFO of stub : architecture is "fifo_generator_v13_0_1,Vivado 2015.4";
begin
end;
