// Copyright 1986-2015 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2015.4 (lin64) Build 1412921 Wed Nov 18 09:44:32 MST 2015
// Date        : Fri Aug 12 19:54:57 2016
// Host        : jgn-tv4 running 64-bit unknown
// Command     : write_verilog -force -mode synth_stub
//               /home/aom/project_3/project_3.srcs/sources_1/ip/asfifo_144_1024/asfifo_144_1024_stub.v
// Design      : asfifo_144_1024
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7vx690tffg1761-3
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "fifo_generator_v13_0_1,Vivado 2015.4" *)
module asfifo_144_1024(rst, wr_clk, rd_clk, din, wr_en, rd_en, dout, full, empty, prog_full, prog_empty)
/* synthesis syn_black_box black_box_pad_pin="rst,wr_clk,rd_clk,din[143:0],wr_en,rd_en,dout[143:0],full,empty,prog_full,prog_empty" */;
  input rst;
  input wr_clk;
  input rd_clk;
  input [143:0]din;
  input wr_en;
  input rd_en;
  output [143:0]dout;
  output full;
  output empty;
  output prog_full;
  output prog_empty;
endmodule
