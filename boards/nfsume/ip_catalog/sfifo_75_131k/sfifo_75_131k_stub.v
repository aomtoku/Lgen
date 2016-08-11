// Copyright 1986-2015 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2015.4 (lin64) Build 1412921 Wed Nov 18 09:44:32 MST 2015
// Date        : Thu Aug 11 17:09:07 2016
// Host        : jgn-tv4 running 64-bit unknown
// Command     : write_verilog -force -mode synth_stub
//               /home/aom/work/Lgen/boards/nfsume/ip_catalog/sfifo_75_131k/sfifo_75_131k_stub.v
// Design      : sfifo_75_131k
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7vx690tffg1761-3
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* X_CORE_INFO = "fifo_generator_v13_0_1,Vivado 2015.4" *)
module sfifo_75_131k(clk, rst, din, wr_en, rd_en, dout, full, empty)
/* synthesis syn_black_box black_box_pad_pin="clk,rst,din[74:0],wr_en,rd_en,dout[74:0],full,empty" */;
  input clk;
  input rst;
  input [74:0]din;
  input wr_en;
  input rd_en;
  output [74:0]dout;
  output full;
  output empty;
endmodule
