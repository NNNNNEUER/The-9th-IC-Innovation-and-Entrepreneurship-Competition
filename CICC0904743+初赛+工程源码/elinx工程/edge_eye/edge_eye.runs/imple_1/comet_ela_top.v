module comet_ela_top(
		sys_clk,
		sys_rst_n,
		ov5640_pclk,
		ov5640_vsync,
		ov5640_href,
		ov5640_data,
		ov5640_rst_n,
		ov5640_pwdn,
		ov5640_xclk,
		sccb_scl,
		sccb_sda,
		gmii_tx_clk,
		gmii_txd,
		gmii_txen,
		sdram_clk,
		sdram_cke,
		sdram_cs_n,
		sdram_ras_n,
		sdram_cas_n,
		sdram_we_n,
		sdram_ba,
		sdram_addr,
		sdram_dq,
		hdmi_hs,
		hdmi_vs,
		hdmi_rgb,
		hdmi_rst_n,
		hdmi_clk,
		hdmi_de,
		hdmi_cfg_done,
		hdmi_scl,
		hdmi_sda,
	COMET_ELA_TCKUTAP,
	COMET_ELA_TDIUTAP,
	COMET_ELA_TMSUTAP,
	COMET_ELA_TDOUSER);
	input 	sys_clk;
	input 	sys_rst_n;
	input 	ov5640_pclk;
	input 	ov5640_vsync;
	input 	ov5640_href;
	input 	[7:0] ov5640_data;
	output 	ov5640_rst_n;
	output 	ov5640_pwdn;
	output 	ov5640_xclk;
	output 	sccb_scl;
	inout 	sccb_sda;
	output 	gmii_tx_clk;
	output 	[7:0] gmii_txd;
	output 	gmii_txen;
	output 	sdram_clk;
	output 	sdram_cke;
	output 	sdram_cs_n;
	output 	sdram_ras_n;
	output 	sdram_cas_n;
	output 	sdram_we_n;
	output 	[1:0] sdram_ba;
	output 	[12:0] sdram_addr;
	inout 	[15:0] sdram_dq;
	output 	hdmi_hs;
	output 	hdmi_vs;
	output 	[23:0] hdmi_rgb;
	output 	hdmi_rst_n;
	output 	hdmi_clk;
	output 	hdmi_de;
	output 	hdmi_cfg_done;
	output 	hdmi_scl;
	inout 	hdmi_sda;
	input COMET_ELA_TCKUTAP;
	input COMET_ELA_TDIUTAP;
	input COMET_ELA_TMSUTAP;
	output COMET_ELA_TDOUSER;
/////////////////////////////////////////////////////////////
	wire 							clk_sample;
	wire 	[12:0] 	trigger_signal;
	wire	[12:0] 		sample_data;
edge_eye_m user_design_inst(
	.sys_clk (sys_clk),
	.sys_rst_n (sys_rst_n),
	.ov5640_pclk (ov5640_pclk),
	.ov5640_vsync (ov5640_vsync),
	.ov5640_href (ov5640_href),
	.ov5640_data (ov5640_data),
	.ov5640_rst_n (ov5640_rst_n),
	.ov5640_pwdn (ov5640_pwdn),
	.ov5640_xclk (ov5640_xclk),
	.sccb_scl (sccb_scl),
	.sccb_sda (sccb_sda),
	.gmii_tx_clk (gmii_tx_clk),
	.gmii_txd (gmii_txd),
	.gmii_txen (gmii_txen),
	.sdram_clk (sdram_clk),
	.sdram_cke (sdram_cke),
	.sdram_cs_n (sdram_cs_n),
	.sdram_ras_n (sdram_ras_n),
	.sdram_cas_n (sdram_cas_n),
	.sdram_we_n (sdram_we_n),
	.sdram_ba (sdram_ba),
	.sdram_addr (sdram_addr),
	.sdram_dq (sdram_dq),
	.hdmi_hs (hdmi_hs),
	.hdmi_vs (hdmi_vs),
	.hdmi_rgb (hdmi_rgb),
	.hdmi_rst_n (hdmi_rst_n),
	.hdmi_clk (hdmi_clk),
	.hdmi_de (hdmi_de),
	.hdmi_cfg_done (hdmi_cfg_done),
	.hdmi_scl (hdmi_scl),
	.hdmi_sda (hdmi_sda),
	.sample_clk (clk_sample),
	.trigger_input (trigger_signal),
	.data_input (sample_data)
);
comet_ela_signaltap signaltap_inst (
	.COMET_ELA_TCKUTAP			( COMET_ELA_TCKUTAP		) ,
	.COMET_ELA_TDIUTAP			( COMET_ELA_TDIUTAP		) ,
	.COMET_ELA_TMSUTAP			( COMET_ELA_TMSUTAP		) ,
	.COMET_ELA_TDOUSER			( COMET_ELA_TDOUSER		) ,
	.clk_sample (clk_sample),
	.trigger_signal (trigger_signal),
	.sample_data (sample_data)
);

endmodule

