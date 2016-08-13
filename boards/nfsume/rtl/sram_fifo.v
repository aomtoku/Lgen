module sram_fifo (
	// Fifo Interface
	input  wire [143:0] idata,
	output wire [143:0] odata,
	output wire         ovalid,
	input  wire         wr_en,
	input  wire         rd_en,
	output wire         empty,
	output wire         full,
	output wire         ordy,
	input  wire         clk,
	input  wire         rst,
	output wire         sram_clk,
	output wire         clk_valid,
	// SRAM Interface
	input       [0:0]     qdriip_cq_p,  
	input       [0:0]     qdriip_cq_n,
	input       [35:0]    qdriip_q,
	inout wire  [0:0]     qdriip_k_p,
	inout wire  [0:0]     qdriip_k_n,
	output wire [35:0]    qdriip_d,
	output wire [18:0]    qdriip_sa,
	output wire           qdriip_w_n,
	output wire           qdriip_r_n,
	output wire [3:0]     qdriip_bw_n,
	output wire           qdriip_dll_off_n
);


localparam MAX_DEPTH = 524287;

reg	[18:0]	rd_addr, wr_addr;
reg	[18:0]	d_cnt;
wire			set;
integer	i;

/* Write address */
always @ (posedge clk) begin
	if (rst) 
		wr_addr	<= 0;
	else if (set) 
		if (wr_addr == MAX_DEPTH)
			wr_addr	<= 0;
		else
			wr_addr	<= wr_addr + 1;
end

/* Read address */
always @ (posedge clk) begin
	if (rst) 
		rd_addr	<= 0;
	else if (~empty & rd_en) 
		if (rd_addr == MAX_DEPTH)
			rd_addr	<= 0;
		else
			rd_addr	<= rd_addr + 1;
end

/* Data counter */
always @ (posedge clk) begin
	if (rst) 
		d_cnt	<= 0;
	else if (~full  & wr_en & ~(rd_en & ~empty)) 
		d_cnt	<= d_cnt + 1;
	else if (~empty & rd_en & ~wr_en) 
		d_cnt	<= d_cnt - 1;
end

/* Full, Empty, Set */
assign	full	= (d_cnt == MAX_DEPTH);
assign	empty	= (d_cnt == 0);
assign	set	= (~full | rd_en) & wr_en;

assign	ordy	= (d_cnt < MAX_DEPTH);

/*
 *  SRAM 
 *
 */
wire rst_clk;
wire init_calib_complete;
assign clk_valid = init_calib_complete & ~rst_clk;

wire         app_wr_cmd0 ;
wire         app_wr_cmd1 ;
wire [18:0]  app_wr_addr0;
wire [18:0]  app_wr_addr1;
wire         app_rd_cmd0 ;
wire         app_rd_cmd1 ;
wire [18:0]  app_rd_addr0 ;
wire [18:0]  app_rd_addr1 ;
wire [143:0] app_wr_data0 ;
wire [143:0] app_wr_data1 ;
wire [15:0]  app_wr_bw_n0 ;
wire [15:0]  app_wr_bw_n1 ;

wire         app_rd_valid0;
wire         app_rd_valid1;
wire [143:0] app_rd_data0;
wire [143:0] app_rd_data1;

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
  .init_calib_complete             (init_calib_complete),  // output                                       init_calib_complete
  // Application interface ports
  .app_wr_cmd0                     (app_wr_cmd0),  // input                             app_wr_cmd0
  .app_wr_cmd1                     (1'b0),  // input                             app_wr_cmd1
  .app_wr_addr0                    (app_wr_addr0), // input  [18:0]           app_wr_addr0
  .app_wr_addr1                    (19'd0), // input  [18:0]           app_wr_addr1
  .app_rd_cmd0                     (app_rd_cmd0),  // input                             app_rd_cmd0
  .app_rd_cmd1                     (1'b0),  // input                             app_rd_cmd1
  .app_rd_addr0                    (app_rd_addr0), // input  [18:0]           app_rd_addr0
  .app_rd_addr1                    (19'd0), // input  [18:0]           app_rd_addr1
  .app_wr_data0                    (app_wr_data0), // input  [143:0] app_wr_data0
  .app_wr_data1                    (144'd0), // input  [143:0] app_wr_data1
  .app_wr_bw_n0                    (app_wr_bw_n0), // input  [15:0]   app_wr_bw_n0
  .app_wr_bw_n1                    (16'd0), // input  [15:0]   app_wr_bw_n1
  .app_rd_valid0                   (app_rd_valid0),// output wire                       app_rd_valid0
  .app_rd_valid1                   (app_rd_valid1),// output wire                       app_rd_valid1
  .app_rd_data0                    (app_rd_data0), // output wire [143:0] app_rd_data0
  .app_rd_data1                    (app_rd_data1), // output wire [143:0] app_rd_data1
  .clk                             (sram_clk),     // output wire                       clk
  .rst_clk                         (rst_clk),      // output wire                       rst_clk
  // System Clock Ports
  .sys_clk_i                       (clk),  // input                                        sys_clk_i
  .sys_rst                         (rst)  // input sys_rst
);

assign app_wr_cmd0  = ~full & wr_en;
assign app_wr_addr0 = wr_addr;
assign app_wr_data0 = idata;
assign app_wr_bw_n0 = 16'd0;

assign app_rd_cmd0  = ~empty & rd_en;
assign app_rd_addr0 = rd_addr;

assign ovalid = app_rd_valid0;
assign odata  = app_rd_data0;

endmodule

