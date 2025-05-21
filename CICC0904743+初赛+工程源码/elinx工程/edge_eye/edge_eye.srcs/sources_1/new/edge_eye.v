`timescale 1 ps/ 1 ps
//////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
//
// Create Date: 05-18-2025 15:53:44
// Design Name: edge_eye (Edge Detection and Video Transmission Top-Level Module)
// Module Name: edge_eye
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description:
//   Top-level module for camera data acquisition, SDRAM buffering,
//   Ethernet transmission, and HDMI/GMII output.
//
// Dependencies:
//   - camera_init: Camera initialization via SCCB (I2C)
//   - DVP_Capture: Camera pixel data capture
//   - pixel_data_processor: Pixel data processing (e.g., edge detection)
//   - eth_top: Ethernet packetization and transmission
//   - sdram_top: SDRAM controller for read/write buffering
//   - hdmi_top: HDMI/VGA video output controller
//
// Revision:
//   V1.0 Initial release
// Additional Comments:
//   - Two PLL instances used for clock generation (clk_gen, clk_gen2)
//   - Supports OV5640 camera interface with RGB565 data format
//   - Uses ping-pong buffering in SDRAM for frame storage
//   - HDMI output timing: 1280x720 @ 75MHz 
//////////////////////////////////////////////////////////////////////////////////



module edge_eye(
	input   wire            sys_clk     ,  // System main clock (e.g., 50 MHz)
    input   wire            sys_rst_n   ,  // System reset, active low
    // Camera interface (OV5640)
    input   wire            ov5640_pclk ,  // Camera pixel clock (24 MHz input)
    input   wire            ov5640_vsync,  // Vertical sync signal
    input   wire            ov5640_href ,  // Horizontal reference signal (line valid)
    input   wire    [7:0]   ov5640_data ,  // 8-bit parallel camera data
    output  wire            ov5640_rst_n,  // Camera reset, active low
    output  wire            ov5640_pwdn ,  // Camera power-down control
    output  wire            ov5640_xclk ,  // Camera external clock output (XCLK)
    output  wire            sccb_scl    ,  // SCCB (I2C) clock
    inout   wire            sccb_sda    ,  // SCCB (I2C) data
	
	// Gigabit Ethernet GMII interface
	output  wire       		gmii_tx_clk,   // GMII transmit clock
	output  wire	[7:0] 	gmii_txd,	   // GMII transmit data
	output  wire      		gmii_txen,	   // GMII transmit enable
	
	// SDRAM interface (16-bit data bus)
    output  wire            sdram_clk       ,   //SDRAM clock
    output  wire            sdram_cke       ,   //SDRAM clock enable
    output  wire            sdram_cs_n      ,   //SDRAM chip selection(active low)
    output  wire            sdram_ras_n     ,   //SDRAM row address selection(active low)
    output  wire            sdram_cas_n     ,   //SDRAM column address selection(active low)
    output  wire            sdram_we_n      ,   //SDRAM write:1'b0/read:1'b1 
    output  wire    [ 1:0]  sdram_ba        ,   //SDRAM bank address
    output  wire    [12:0]  sdram_addr      ,   //SDRAM row/column address
    inout   wire    [15:0]  sdram_dq        ,   //SDRAM data

	// HDMI / VGA video output (RGB565)
    output  wire            hdmi_hs         ,   //hdmi hsync
    output  wire            hdmi_vs         ,   //hdmi vsync
    output  wire    [23:0]  hdmi_rgb        ,   //hdmi data_rgb
    output  wire            hdmi_rst_n      ,   //hdmi reset(active low)
    output  wire            hdmi_clk        ,   //hdmi clock
    output  wire            hdmi_de         ,   //hdmi data enable

	// HDMI SCCB configuration interface
    output wire             hdmi_cfg_done   ,   //hdmi configration done
    output wire             hdmi_scl        ,   //hdmi serial clock
    inout                   hdmi_sda          //hdmi serial data
	//output wire             box_exist
    );
	
   // Image resolution parameters
  parameter IMAGE_WIDTH  = 1280;
  parameter IMAGE_HEIGHT = 720;
  
  // Ethernet packet parameters
  parameter DST_MAC   = 48'hFF_FF_FF_FF_FF_FF;	// Destination MAC (broadcast)
  parameter SRC_MAC   = 48'h00_0a_35_01_fe_c0;	// Source MAC
  parameter DST_IP    = 32'hc0_a8_00_03;		// Destination IP 192.168.0.3
  parameter SRC_IP    = 32'hc0_a8_00_02;		// Source IP 192.168.0.2
  parameter DST_PORT  = 16'd6102;				// Destination UDP port
  parameter SRC_PORT  = 16'd5000;				// Source UDP port
  
  // Internal clock and reset signals
  wire            clk_50m,clk_125m, locked,pclk_bufg_o;
  wire            cfg_done;
  wire            rst_n,g_rst_p;
  wire			pixel_data_valid;
  wire            wr_en;
  wire   [15:0]   wr_data; 
  wire          image_data_valid;
  wire          image_data_hs;
  wire          image_data_vs;
  wire [11:0]   image_data_xaddr;
  wire [11:0]   image_data_yaddr;
  wire [15:0]	pixel_data; 

  wire        post0_frame_vsync ;	
  wire        post0_frame_href  ;	
  wire        post0_frame_clken ;	
  wire [7:0]  data_Y   ;
  wire [7:0]  data_CB   ;
  wire [7:0]  data_CR   ;
  wire [4:0] gray_r;      // 5
  wire [5:0] gray_g;      // 6
  wire [4:0] gray_b;      // 5
  wire [15:0] gray_rgb565;
  //=====================================================================
  // SDRAM and HDMI related signals
	wire            clk_125m_shift  ;
	wire            clk_25m         ;
	wire            clk_75m         ;
	wire            locked3         ;
	wire			rst_n_sdram		;
	wire    [15:0]  rd_data         ;
	wire            rdreq           ;
	wire            sdram_init_done ;
	wire            sys_init_done   ;
	wire    [15:0]  rgb_565         ;
	wire			ov5640_xclk_1	;

  // System reset: released after primary PLL locks
  assign rst_n = sys_rst_n & locked;
  // Buffer camera pixel clock through BUFG
  assign pclk_bufg_o = ov5640_pclk;
  // Global reset for camera capture logic (active when PLL unlocked)
  assign g_rst_p = (~locked);
  
  // sdram assignment
  // SDRAM reset: released after both PLLs lock
  assign rst_n_sdram = (locked & locked3);
  // System initialization complete when SDRAM init and camera config done
  assign sys_init_done   = sdram_init_done & cfg_done;
  
  // HDMI reset, pixel clock, and RGB data assignment
  assign          hdmi_rst_n      = rst_n_sdram;
  assign          hdmi_clk        = clk_75m;
  // Convert RGB565 to 24-bit: expand bits and pad LSBs with zeros
  assign          hdmi_rgb        = {rgb_565[15:11],3'b0,rgb_565[10:5],2'b0,rgb_565[4:0],3'b0};

  
//********************************************************************//
//**************************** Instantiate ***************************//
//********************************************************************//
//=====================================================================
// Clock generation: instantiate two PLLs
//=====================================================================
clk_gen clk_gen(
    .inclk0     (sys_clk),
    .c0         (clk_125m),
    .c1         (clk_125m_shift),
    .c2         (clk_25m),
	.c3			(clk_50m),
	.c4			(ov5640_xclk_1),
    .locked     (locked)
  );
  
clk_gen2    	clk_gen2_inst
(
    .inclk0             (sys_clk        ),
	.c3                 (ov5640_xclk	), 
    .c4                 (clk_75m        ),
    .locked             (locked3        )
);
 
 //=====================================================================
 // Camera configuration and capture
 //=====================================================================
 // camera_init: configure OV5640 via SCCB (I2C)
  camera_init
  #(
    .CAMERA_TYPE  ( "ov5640"            ),//"ov5640"
    .IMAGE_TYPE     ( 0            ),// 0: RGB; 1: JPEG
    .IMAGE_WIDTH ( IMAGE_WIDTH  ),
    .IMAGE_HEIGHT( IMAGE_HEIGHT ),
    .IMAGE_FLIP_EN  ( 1            ),// 1: no vertical flip; 0: vertical flip
    .IMAGE_MIRROR_EN( 1            ) // 1: horizontal mirror; 0: no mirror
  )camera_init_inst
  (
    .Clk         (clk_50m       ),
    .Rst_n       (sys_rst_n          ),
    .Init_Done   (cfg_done ),
    .camera_rst_n(ov5640_rst_n),
    .camera_pwdn (ov5640_pwdn),
    .i2c_sclk    (sccb_scl      ),
    .i2c_sdat    (sccb_sda      )
  );
  // DVP_Capture: capture pixel data, output 16-bit RGB565
    DVP_Capture DVP_Capture_inst(
    .Rst_p      (g_rst_p          ),//input
    .PCLK       (pclk_bufg_o      ),//input
    .Vsync      (ov5640_vsync     ),//input
    .Href       (ov5640_href      ),//input
    .Data       (ov5640_data      ),//input     [7:0]

    .ImageState (                 ),//output reg
    .DataValid  (wr_en ),//output
    .DataPixel  (wr_data       ),//output    [15:0]
    .DataHs     (image_data_hs    ),//output
    .DataVs     (image_data_vs    ),//output
    .Xaddr      (image_data_xaddr ),//output    [11:0]
    .Yaddr      (image_data_yaddr ) //output    [11:0]
  );
  //============================ RGB to YCbCr Conversion ==========================
  rgb2ycbcr	rgb2ycbcr_u0(
					.clk   (ov5640_pclk),				// Input pixel clock from the OV5640 camera
					.i_r_8b({wr_data[15:11],3'b111}),	// Extends the higher 5 bits of the red component to 8 bits and passes to the module
					.i_g_8b({wr_data[10:5] ,2'b11}),	// Extends the higher 6 bits of the green component to 8 bits and passes to the module
					.i_b_8b({wr_data[4:0],3'b111}),		// Extends the higher 5 bits of the blue component to 8 bits and passes to the module

					.i_h_sync (image_data_hs),			// Horizontal sync signal, indicating valid data rows
					.i_v_sync (image_data_vs),			// Vertical sync signal, indicating valid data frames
					.i_data_en(wr_en),					// Data enable signal, indicating data is valid

					.o_y_8b(data_Y),					// Output luminance component Y (8 bits)
					.o_cb_8b(data_CB),					// Output chroma component Cb (8 bits)
					.o_cr_8b(data_CR),					// Output chroma component Cr (8 bits)

					.o_h_sync(post0_frame_href),		// Output processed image horizontal sync signal
					.o_v_sync(post0_frame_vsync),       // Output processed image vertical sync signal                                           
					.o_data_en(post0_frame_clken)   	// Output processed image data enable signal
	);
  //============================ Skin Detection ==============================
  assign is_skin = data_CB > 80 && data_CB < 115 && data_CR > 135 && data_CR < 175;
  // Skin detection based on the range of the CB and CR chroma components.
// If CB is between 80 and 115, and CR is between 135 and 175, the pixel is considered as part of skin.

  //============================ Erosion Operation ==========================
  bit_erosion
  #(
    .IMG_HDISP	(12'd1280),							// Horizontal resolution of the image (1280)
    .IMG_VDISP	(12'd720)							// Vertical resolution of the image (720)
  )
  bit_erosion_inst
  (
    //global clock
    .clk					(ov5640_pclk),  		// Input clock signal from OV5640 camera
    .rst_n					(sys_rst_n),			// System reset signal

    //Image data prepred to be processd
    .per_frame_vsync		(post0_frame_vsync),	//Prepared Image data vsync valid signal
    .per_frame_href			(post0_frame_href),		//Prepared Image data href vaild  signal
    .per_frame_clken		(post0_frame_clken),	//Prepared Image data output/capture enable clock
    .per_img_Bit			(is_skin),				//Processed Image Bit flag outout(1: Value, 0:inValid)

    //Image data has been processd
    .post_frame_vsync		(post1_frame_vsync),	//Processed Image data vsync valid signal
    .post_frame_href		(post1_frame_href),		//Processed Image data href vaild  signal
    .post_frame_clken		(post1_frame_clken),	//Processed Image data output/capture enable clock
    .post_img_Bit			(post1_img_Bit)			//Processed Image Bit flag outout(1: Value, 0:inValid)
  );
  //============================ Dilation Operation ==========================
  bit_dilation
#(
	.IMG_HDISP	(12'd1280),							// Horizontal resolution of the image (1280)
	.IMG_VDISP	(12'd720)							// Horizontal resolution of the image (720)
)
bit_dilation_inst
(
	//global clock
	.clk					(ov5640_pclk),  		// Input clock signal from OV5640 camera
	.rst_n					(sys_rst_n),			// System reset signal

	//Image data prepred to be processd
	.per_frame_vsync		(post1_frame_vsync),	//Prepared Image data vsync valid signal
	.per_frame_href			(post1_frame_href),		//Prepared Image data href vaild  signal
	.per_frame_clken		(post1_frame_clken),	//Prepared Image data output/capture enable clock
	.per_img_Bit			(post1_img_Bit),		//Processed Image Bit flag outout(1: Value, 0:inValid)

	//Image data has been processd
	.post_frame_vsync		(post2_frame_vsync),	//Processed Image data vsync valid signal
	.post_frame_href		(post2_frame_href),		//Processed Image data href vaild  signal
	.post_frame_clken		(post2_frame_clken),	//Processed Image data output/capture enable clock
	.post_img_Bit			(post2_img_Bit)			//Processed Image Bit flag outout(1: Value, 0:inValid)
);
wire post_frame_vsync;
wire post_frame_href;
wire post_frame_clken;
wire [15:0] post_img_data;

//============================ Object Box Detection ==========================
Boxing	
#(
	.IMG_Width	(12'd1280),							// Image width
	.IMG_High	(12'd720)							// Image height
)
Boxing_inst
(
	//global clock
	.clk					(ov5640_pclk),  		//cmos video pixel clock
	.rst_n					(rst_n),			//global reset

	//Image data prepred to be processd
	.per_frame_vsync		(post1_frame_vsync),	//Prepared Image data vsync valid signal
	.per_frame_href		(post1_frame_href),			//Prepared Image data href vaild  signal
	.per_frame_clken		(post1_frame_clken),	//Prepared Image data output/capture enable clock
	.per_img_Y		      (post1_img_Bit),			//Prepared Image brightness input

	.cmos_frame_clken		(wr_en), 				//Prepared Image data vsync valid signal
	.cmos_frame_vsync		(image_data_vs), 		//Prepared Image data href vaild  signal
	.cmos_frame_href		(image_data_hs), 		//Prepared Image data output/capture enable clock
	.cmos_frame_data     (wr_data),					//Prepared Image brightness input

	//Image data has been processd
	.post_frame_vsync		(post_frame_vsync),		//Processed Image data vsync valid signal
	.post_frame_href		(post_frame_href),		//Processed Image data href vaild  signal
	.post_frame_clken		(post_frame_clken),		//Processed Image data output/capture enable clock
	.post_img_Y    	   (post_img_data)
	//.box_exist			(box_exist)
	//Processed Image brightness output
);
	// assign gray_r = post2_img_Bit ? 5'b11111 :0; 
	// assign gray_g = post2_img_Bit ? 6'b111111 : 0;
	// assign gray_b = post2_img_Bit ? 5'b11111 : 0;
	// assign gray_rgb565 = {gray_r, gray_g, gray_b};


  //===================================================================

//=====================================================================
// Pixel Data Processor Instantiation
//=====================================================================
  pixel_data_processor pixel_data_processor_inst(
    .pclk(pclk_bufg_o),             	 // Camera pixel clock
    .g_rst_p(g_rst_p),          		 // Asynchronous reset (active low when PLL unlocked)
    .image_data_hs(image_data_hs),  	 // Horizontal sync (line valid)
    .image_data(wr_data),       		 // Raw image data from camera
    .image_data_valid(wr_en), 			 // Image data valid flag
    .image_data_yaddr(image_data_yaddr), // Current row address
    .pixel_data(pixel_data),       		 // Output pixel data
    .pixel_data_valid(pixel_data_valid)  // Processed pixel data valid flag
    );
	
  //=====================================================================
  // Ethernet transmission (eth_top)
  //=====================================================================
  eth_top
  #(
	.IMAGE_WIDTH	   (IMAGE_WIDTH	),
    .PAYLOAD_DATA_BYTE (2              ),
    .PAYLOAD_LENGTH    (IMAGE_WIDTH +1 ),
	.DST_MAC 		   ( DST_MAC 	),
	.SRC_MAC 			(SRC_MAC 	),
	.DST_IP  			(DST_IP  	),
	.SRC_IP  			(SRC_IP  	),
	.DST_PORT			(DST_PORT	),
	.SRC_PORT			(SRC_PORT	)	
  )eth_top_inst
  (
    .reset_p          (g_rst_p          ),

    .clk              (pclk_bufg_o      ),
    .data_i           ({pixel_data[7:0],pixel_data[15:8]}),
    .data_valid_i     (pixel_data_valid ),

    .eth_txfifo_rd_clk(clk_125m	      ),

	.gmii_tx_clk  (gmii_tx_clk           ),
    .gmii_txen    (gmii_txen             ),
    .gmii_txd     (gmii_txd              )
  );
  
//=====================================================================
// SDRAM buffering (sdram_top)
//=====================================================================
sdram_top       sdram_top_inst
(
// system 
    .sys_clk            (clk_125m     ),   //sdram clk
    .clk_out            (clk_125m_shift ),   //26.25 degree shifted
    .sys_rst_n          (rst_n_sdram    ),   
// wfifo 
    .wr_fifo_wr_clk     (ov5640_pclk    ),   
    .wr_fifo_wr_req     (post_frame_clken  ),   
    .wr_fifo_wr_data    (post_img_data    ),   //write data               [15:0]
    .sdram_wr_b_addr    (24'd0          ),   //write begin address      [23:0]
    .sdram_wr_e_addr    (IMAGE_HEIGHT*IMAGE_WIDTH),   //write end address        [23:0]
    .wr_burst_len       (10'd512        ),   //write burst length       [ 9:0]
    .wr_rst             (~rst_n_sdram   ),   //write rst(active high)
// rfifo 
    .rd_fifo_rd_clk     (clk_75m        ),   
    .rd_fifo_rd_req     (rdreq          ),   
    .sdram_rd_b_addr    (24'd0          ),   //read begin address       [23:0]
    .sdram_rd_e_addr    (IMAGE_HEIGHT*IMAGE_WIDTH),   //read end address         [23:0]
    .rd_burst_len       (10'd512        ),   //read burst length        [ 9:0]
    .rd_rst             (~rst_n_sdram   ),   //read rst(active high)

    .rd_fifo_num        (               ),   //data number in rfifo
    .rd_fifo_rd_data    (rd_data        ),   //read data                [15:0]
// user control
    .read_valid         (1'b1           ),   
    .pingpang_en        (1'b1           ),

    .init_end           (sdram_init_done),   
// SDRAM 
    .sdram_clk          (sdram_clk      ),   //SDRAM clk
    .sdram_cke          (sdram_cke      ),   //SDRAM clk enable
    .sdram_cs_n         (sdram_cs_n     ),   //SDRAM clk selection(active low)
    .sdram_ras_n        (sdram_ras_n    ),   //SDRAM row address selection(active low)
    .sdram_cas_n        (sdram_cas_n    ),   //SDRAM column address selection(active low)
    .sdram_we_n         (sdram_we_n     ),   //SDRAM write:1'b0/read:1'b1
    .sdram_ba           (sdram_ba       ),   //SDRAM bank address       [ 1:0]
    .sdram_addr         (sdram_addr     ),   //SDRAM row/column address [12:0]
    .sdram_dq           (sdram_dq       )    //SDRAM data(inout signal) [15:0]
);

//=====================================================================
// HDMI/VGA output (hdmi_top)
//=====================================================================
hdmi_top        hdmi_top_inst    
(
// system
    .sys_clk            (sys_clk        ),   //sclk = 50MHz
    .sys_rst_n          (rst_n_sdram          ),   //reset: active low
// vga
    .vga_clk            (clk_75m        ),   //vga clk = 75MHz 
    .pix_data           (rd_data	    ),   //pixel data               [15:0]

    .pix_data_req       (rdreq          ),
    .hsync              (hdmi_hs        ),   //hdmi hsync
    .vsync              (hdmi_vs        ),   //hdmi vsync
    .de                 (hdmi_de        ),   //hdmi data enable
    .rgb                (rgb_565        ),   //hdmi data_rgb
// hdmi
    .cfg_done           (hdmi_cfg_done  ),   
    .sccb_scl           (hdmi_scl       ),   //SCL
    .sccb_sda           (hdmi_sda       )    //SDA

);
	
endmodule
