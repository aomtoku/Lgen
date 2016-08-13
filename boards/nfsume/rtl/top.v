`timescale 1ps / 1ps
`default_nettype none
`include "setup.v"

module top #(
	parameter MAX_TIMER = 1000 // nano second
)(
	// 200MHz reference clock input
	input wire clk_ref_p,
	input wire clk_ref_n,
	//-SI5324 I2C programming interface
	inout wire i2c_clk,
	inout wire i2c_data,
	// 156.25 MHz clock in
	input wire xphy_refclk_clk_p,
	input wire xphy_refclk_clk_n,
	output wire sfp_rec_clk_p,
	output wire sfp_rec_clk_n,
	input  wire sfp_clk_alarm_b,
	// 10G PHY ports
	output wire xphy0_txp,
	output wire xphy0_txn,
	input wire xphy0_rxp,
	input wire xphy0_rxn,
	output wire xphy1_txp,
	output wire xphy1_txn,
	input wire xphy1_rxp,
	input wire xphy1_rxn,
	//output wire xphy2_txp,
	//output wire xphy2_txn,
	//input wire xphy2_rxp,
	//input wire xphy2_rxn,
	//output wire xphy3_txp,
	//output wire xphy3_txn,
	//input wire xphy3_rxp,
	//input wire xphy3_rxn,
	output wire [1:0] sfp_tx_disable,   

	// SRAM Interface
	input wire  [0:0]     qdriip_cq_p,  
	input wire  [0:0]     qdriip_cq_n,
	input wire  [35:0]    qdriip_q,
	inout wire  [0:0]     qdriip_k_p,
	inout wire  [0:0]     qdriip_k_n,
	output wire [35:0]    qdriip_d,
	output wire [18:0]    qdriip_sa,
	output wire           qdriip_w_n,
	output wire           qdriip_r_n,
	output wire [3:0]     qdriip_bw_n,
	output wire           qdriip_dll_off_n,
	//// BUTTON
	//input wire button_n,
	//input wire button_s,
	//input wire button_w,
	//input wire button_e,
	//input wire button_c,
	//// DIP SW
	//input wire [3:0] dipsw,
	// Diagnostic LEDs
	output wire [7:0] led
 );

// Clock and Reset
wire clk_ref_200, clk_ref_200_i;
wire sys_rst;

reg [7:0] cold_counter = 8'h0;
reg cold_reset = 1'b0;

always @(posedge clk_ref_200) begin
	if (cold_counter != 8'hff) begin
		cold_reset <= 1'b1;
		cold_counter <= cold_counter + 8'd1;
	end else
		cold_reset <= 1'b0;
end

assign sys_rst = cold_reset; // | button_c;

// -------------------
// -- Local Signals --
// -------------------
  
// Ethernet related signal declarations
wire		xphyrefclk_i;
wire		xgemac_clk_156;
wire		dclk_i;
wire		clk156_25; 
wire		xphy_gt0_tx_resetdone;
wire		xphy_gt1_tx_resetdone;
wire		xphy_tx_fault;
   
wire [63:0]	xgmii_txd_0, xgmii_txd_1;
wire [7:0]	xgmii_txc_0, xgmii_txc_1;
wire [63:0]	xgmii_rxd_0, xgmii_rxd_1;
wire [7:0]	xgmii_rxc_0, xgmii_rxc_1;

wire [3:0]	xphy_tx_disable;
wire		xphy_gt_txclk322;
wire		xphy_gt_txusrclk;
wire		xphy_gt_txusrclk2;
wire		xphy_gt_qplllock;
wire		xphy_gt_qplloutclk;
wire		xphy_gt_qplloutrefclk;
wire		xphy_gt_txuserrdy;
wire		xphy_areset_clk_156_25;
wire		xphy_reset_counter_done;
wire		xphy_gttxreset;
wire		xphy_gtrxreset;


wire [4:0]	xphy0_prtad;
wire		xphy0_signal_detect;
wire [7:0]	xphy0_status;

wire [4:0]	xphy1_prtad;
wire		xphy1_signal_detect;
wire [7:0]	xphy1_status;

// ---------------
// Clock and Reset
// ---------------

// Register to improve timing

IBUFGDS # (
	.DIFF_TERM    ("TRUE"),
	.IBUF_LOW_PWR ("FALSE")
) diff_clk_200 (
	.I    (clk_ref_p  ),
	.IB   (clk_ref_n  ),
	.O    (clk_ref_200_i )  
);

BUFG u_bufg_clk_ref (
	.O (clk_ref_200),
	.I (clk_ref_200_i)
);

//- Clocking
wire [11:0]	device_temp;
wire		clk50, clk100;
reg [1:0]	clk_divide = 2'b00;


always @(posedge clk_ref_200)
	clk_divide  <= clk_divide + 1'b1;

BUFG buffer_clk50 (
	.I    (clk_divide[1]),
	.O    (clk50	)
);

BUFG buffer_clk100 (
	.I    (clk_divide[0]),
	.O    (clk100	)
);

sfp_refclk_init sfp_refclk_init0 (
	.CLK               (clk100),
	.RST               (sys_rst),
	.SFP_REC_CLK_P     (sfp_rec_clk_p), //: out std_logic;
	.SFP_REC_CLK_N     (sfp_rec_clk_n), //: out std_logic;
	.SFP_CLK_ALARM_B   (sfp_clk_alarm_b), //: in std_logic;
	.I2C_FPGA_SCL      (i2c_clk), //: inout std_logic;
	.I2C_FPGA_SDA      (i2c_data)  //: inout std_logic
);

wire sim_speedup_control = 1'b0;
 
//- Network Path instance #0
assign xphy0_prtad = 5'd0;
assign xphy0_signal_detect  = 1'b1;
assign xphy_tx_fault = 1'b0;

network_path_shared network_path_inst_0 (
	.xphy_refclk_p(xphy_refclk_clk_p),
	.xphy_refclk_n(xphy_refclk_clk_n),
	.xphy_txp(xphy0_txp),
	.xphy_txn(xphy0_txn),
	.xphy_rxp(xphy0_rxp),
	.xphy_rxn(xphy0_rxn),
	.txusrclk(xphy_gt_txusrclk),
	.txusrclk2(xphy_gt_txusrclk2),
	.tx_resetdone(xphy_gt0_tx_resetdone),
	.xgmii_txd(xgmii_txd_0),
	.xgmii_txc(xgmii_txc_0),
	.xgmii_rxd(xgmii_rxd_0),
	.xgmii_rxc(xgmii_rxc_0),
	.areset_clk156(xphy_areset_clk_156_25),
	.gttxreset(xphy_gttxreset),
	.gtrxreset(xphy_gtrxreset),
	.txuserrdy(xphy_gt_txuserrdy),
	.qplllock(xphy_gt_qplllock),
	.qplloutclk(xphy_gt_qplloutclk),
	.qplloutrefclk(xphy_gt_qplloutrefclk),
	.reset_counter_done(xphy_reset_counter_done),
	.dclk(xgemac_clk_156),  
	.xphy_status(xphy0_status),
	.xphy_tx_disable(xphy_tx_disable[0]),
	.signal_detect(xphy0_signal_detect),
	.tx_fault(xphy_tx_fault), 
	.prtad(xphy0_prtad),
	.clk156(xgemac_clk_156),
	.sys_rst(sys_rst),
	.sim_speedup_control(sim_speedup_control)
); 

//- Network Path instance #1
assign xphy1_prtad = 5'd1;
assign xphy1_signal_detect = 1'b1;

network_path network_path_inst_1 (
	.xphy_txp(xphy1_txp),
	.xphy_txn(xphy1_txn),
	.xphy_rxp(xphy1_rxp),
	.xphy_rxn(xphy1_rxn),
	.txusrclk(xphy_gt_txusrclk),
	.txusrclk2(xphy_gt_txusrclk2),
	.tx_resetdone(xphy_gt1_tx_resetdone),
	.xgmii_txd(xgmii_txd_1),
	.xgmii_txc(xgmii_txc_1),
	.xgmii_rxd(xgmii_rxd_1),
	.xgmii_rxc(xgmii_rxc_1),
	.areset_clk156(xphy_areset_clk_156_25),
	.gttxreset(xphy_gttxreset),
	.gtrxreset(xphy_gtrxreset),
	.txuserrdy(xphy_gt_txuserrdy),
	.qplllock(xphy_gt_qplllock),
	.qplloutclk(xphy_gt_qplloutclk),
	.qplloutrefclk(xphy_gt_qplloutrefclk),
	.reset_counter_done(xphy_reset_counter_done),
	.dclk(xgemac_clk_156),  
	.xphy_status(xphy1_status),
	.xphy_tx_disable(xphy_tx_disable[1]),
	.signal_detect(xphy1_signal_detect),
	.tx_fault(xphy_tx_fault), 
	.prtad(xphy1_prtad),
	.clk156(xgemac_clk_156),
	.sys_rst(sys_rst),
	.sim_speedup_control(sim_speedup_control)
  ); 


// Combined 10GBASE-R quad link status
assign led[7:0] = {4'b000, 1'b0, 1'b0, xphy1_status[0], xphy0_status[0]};

//- Disable Laser when unconnected on SFP+
assign sfp_tx_disable = 4'b0000;

// ----------------------
// -- User Application --
// ----------------------

reg         toggle;
reg [143:0] tx_tmp;

always @ (posedge xgemac_clk_156) 
	if (sys_rst) begin
		toggle <= 0;
		tx_tmp <= 0;
	end else begin
		toggle <= ~toggle;
		if (toggle == 0)
			tx_tmp[ 71: 0] <= {xgmii_rxd_0, xgmii_rxc_0};
		else
			tx_tmp[143:72] <= {xgmii_rxd_0, xgmii_rxc_0};
	end


reg dc_state;
reg [31:0] waitcnt;

localparam DC_STOP  = 1'b0,
           DC_START = 1'b1;

/*
 *  Async FIFO
 */
wire sram_clk;
wire sram_init;
wire [143:0] asfifo_din;
wire [143:0] asfifo_dout;
wire asfifo_wr_en;
wire asfifo_rd_en;
wire asfifo_full, asfifo_empty;

assign asfifo_rd_en = ~asfifo_empty;
assign asfifo_din   = tx_tmp;

asfifo_144_1024 u_asfifo (
  .rst    (sys_rst),        // input wire rst
  .wr_clk (xgemac_clk_156),  // input wire wr_clk
  .rd_clk (sram_clk),  // input wire rd_clk
  .din    (asfifo_din),        // input wire [143 : 0] din
  .wr_en  (asfifo_wr_en),    // input wire wr_en
  .rd_en  (asfifo_rd_en),    // input wire rd_en
  .dout   (asfifo_dout),      // output wire [143 : 0] dout
  .full   (asfifo_full),      // output wire full
  .empty  (asfifo_empty)    // output wire empty
);


/*
 *  Sram Based FIFO
 */
wire [143:0] sram_odata;
wire         sram_ovalid;
wire         sram_rd_en;
wire         sram_empty, sram_full;

sram_fifo u_sram_fifo(
	// Fifo Interface
	.idata         (asfifo_dout),
	.odata         (sram_odata),
	.ovalid        (sram_ovalid),
	.wr_en         (asfifo_rd_en),
	.rd_en         (sram_rd_en),
	.empty         (sram_empty),
	.full          (sram_full),
	.ordy          (),
	.clk           (clk_ref_200),
	.rst           (sys_rst),
	.sram_clk      (sram_clk),
	.clk_valid     (sram_init),
	// SRAM Interface
	.qdriip_cq_p   (qdriip_cq_p), 
	.qdriip_cq_n   (qdriip_cq_n), 
	.qdriip_q      (qdriip_q),    
	.qdriip_k_p    (qdriip_k_p),  
	.qdriip_k_n    (qdriip_k_n),  
	.qdriip_d      (qdriip_d),    
	.qdriip_sa     (qdriip_sa),   
	.qdriip_w_n    (qdriip_w_n),  
	.qdriip_r_n    (qdriip_r_n),  
	.qdriip_bw_n   (qdriip_bw_n), 
	.qdriip_dll_off_n(qdriip_dll_off_n)
);


wire prog_full, prog_empty;
assign sram_rd_en = dc_state == DC_START && ~prog_full;
assign asfifo_wr_en = toggle == 0 && xphy_gt0_tx_resetdone == 1 &&
                      dc_state == DC_START;

ila_0 u_ila (
	.clk(sram_clk),
	.probe0({
		dc_state,
		asfifo_dout,
		sram_odata,
		sram_ovalid,
		sram_rd_en,
		asfifo_wr_en,
		prog_full,
		prog_empty
	})
);

/*
 *  Delay Controller
 */

localparam NS_FREQ = 10; //ns
localparam MAX_TIMER_CYCLES = MAX_TIMER / NS_FREQ;

always @ (posedge sram_clk) 
	if (sys_rst) begin
		dc_state <= 0;
		waitcnt  <= 0;
	end else begin
		case (dc_state)
			DC_STOP: begin
				if (waitcnt == MAX_TIMER_CYCLES) begin
					waitcnt <= 0;
				end else
					waitcnt <= waitcnt + 1;
			end
			DC_START: ;
		endcase
	end

/*
 * Rate Contoller
 */

reg rd_en_reg, wr_en_reg;

always @ (posedge sram_clk) 
	if (sys_rst) begin
		rd_en_reg <= 0;
		wr_en_reg <= 0;
	end else begin
		if (prog_full)
			rd_en_reg <= 0;
		else
			rd_en_reg <= 1;

		if (prog_empty)
			wr_en_reg <= 0;
		else
			wr_en_reg <= 1;
	end

wire [143:0] tx_dout;
wire tx_rd_en;
wire tx_full, tx_empty;

asfifo_144_1024 u_txfifo (
  .rst    (~sram_init), 
  .wr_clk (sram_clk),  
  .rd_clk (xgemac_clk_156),  
  .din    (sram_odata), 
  .wr_en  (sram_ovalid),
  .rd_en  (tx_rd_en),   
  .dout   (tx_dout),    
  .full   (tx_full),    
  .empty  (tx_empty),    
  .prog_full(prog_full),    // output wire prog_full
  .prog_empty(prog_empty)  // output wire prog_empty
);

reg        rx_state;
reg [71:0] rx_tmp;
assign tx_rd_en = ~tx_empty && rx_state == 0 && dc_state == DC_START;

always @ (posedge sram_clk) begin
	if (sys_rst) begin
		rx_state <= 0;
		rx_tmp   <= 0;
	end else begin
		case (rx_state)
			0 : if (~tx_empty) begin
				rx_state <= 1;
				rx_tmp <= tx_dout[143:72];
			end
			1 : rx_state <= 0;
		endcase
	end
end


/*
 *  Port Assignment
 */

assign xgmii_txd_0 = xgmii_rxd_1;
assign xgmii_txc_0 = xgmii_rxc_1;
assign xgmii_txd_1 = (dc_state == DC_STOP) ? 64'd0 :
                     (rx_state == 0) ? tx_dout[71:8]  : tx_tmp[71:8];
assign xgmii_txc_1 = (dc_state == DC_STOP) ? 8'd0 : 
                     (rx_state == 0) ? tx_dout[7:0]   : tx_tmp[7:0];

endmodule
`default_nettype wire
