`timescale 1 ps/ 1 ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 05-19-2025 00:55:39
// Design Name:
// Module Name: bit_erosion
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// Dependencies:
//
// Revision:
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////


module bit_erosion #(
	parameter	[11:0]	IMG_HDISP = 12'd1280,	
	parameter	[11:0]	IMG_VDISP = 12'd720
)
(
	//global clock
	input				clk,  				//cmos video pixel clock
	input				rst_n,				//global reset

	//Image data prepred to be processd
	input				per_frame_vsync,	//Prepared Image data vsync valid signal
	input				per_frame_href,		//Prepared Image data href vaild  signal
	input				per_frame_clken,	//Prepared Image data output/capture enable clock
	input				per_img_Bit,		//Prepared Image Bit flag outout(1: Value, 0:inValid)
	
	//Image data has been processd
	output				post_frame_vsync,	//Processed Image data vsync valid signal
	output				post_frame_href,	//Processed Image data href vaild  signal
	output				post_frame_clken,	//Processed Image data output/capture enable clock
	output				post_img_Bit		//Processed Image Bit flag outout(1: Value, 0:inValid)
);

//----------------------------------------------------
//Generate 1Bit 3X3 Matrix for Video Image Processor.
//Image data has been processd
wire			matrix_frame_vsync;	//Prepared Image data vsync valid signal
wire			matrix_frame_href;	//Prepared Image data href vaild  signal
wire			matrix_frame_clken;	//Prepared Image data output/capture enable clock	
wire			matrix_p11, matrix_p12, matrix_p13;	//3X3 Matrix output
wire			matrix_p21, matrix_p22, matrix_p23;
wire			matrix_p31, matrix_p32, matrix_p33;
VIPMOD_Matrix_Generate_3X3_1Bit	
#(
	.IMG_HDISP	(IMG_HDISP),	//640*480
	.IMG_VDISP	(IMG_VDISP)
)
VIPMOD_Matrix_Generate_3X3_1Bit
(
	//global clock
	.clk					(clk),  				//cmos video pixel clock
	.rst_n					(rst_n),				//global reset

	//Image data prepred to be processd
	.per_frame_vsync		(per_frame_vsync),		//Prepared Image data vsync valid signal
	.per_frame_href		(per_frame_href),		//Prepared Image data href vaild  signal
	.per_frame_clken		(per_frame_clken),		//Prepared Image data output/capture enable clock
	.per_img_Bit			(per_img_Bit),			//Prepared Image brightness input

	//Image data has been processd
	.matrix_frame_vsync		(matrix_frame_vsync),	//Processed Image data vsync valid signal
	.matrix_frame_href		(matrix_frame_href),	//Processed Image data href vaild  signal
	.matrix_frame_clken		(matrix_frame_clken),	//Processed Image data output/capture enable clock	
	.matrix_p11(matrix_p11),	.matrix_p12(matrix_p12), 	.matrix_p13(matrix_p13),	//3X3 Matrix output
	.matrix_p21(matrix_p21), 	.matrix_p22(matrix_p22), 	.matrix_p23(matrix_p23),
	.matrix_p31(matrix_p31), 	.matrix_p32(matrix_p32), 	.matrix_p33(matrix_p33)
);


//Add you arithmetic here
//----------------------------------------------------------------------------
//----------------------------------------------------------------------------
//----------------------------------------------------------------------------
//-------------------------------------------
//-------------------------------------------
//Eronsion Parameter
//      Original         Dilation			  Pixel
// [   0  0   0  ]   [   1	1   1 ]     [   P1  P2   P3 ]
// [   0  1   0  ]   [   1  1   1 ]     [   P4  P5   P6 ]
// [   0  0   0  ]   [   1  1	1 ]     [   P7  P8   P9 ]
//P = P1 & P2 & P3 & P4 & P5 & P6 & P7 & 8 & 9;
//---------------------------------------
//Eonsion with or operation
//Step1
reg	post_img_Bit1,	post_img_Bit2,	post_img_Bit3;
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		begin
		post_img_Bit1 <= 1'b0;
		post_img_Bit2 <= 1'b0;
		post_img_Bit3 <= 1'b0;
		end
	else
		begin
		post_img_Bit1 <= matrix_p11 & matrix_p12 & matrix_p13;
		post_img_Bit2 <= matrix_p21 & matrix_p22 & matrix_p23;
		post_img_Bit3 <= matrix_p21 & matrix_p32 & matrix_p33;
		end
end

//Step 2
reg	post_img_Bit4;
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		post_img_Bit4 <= 1'b0;
	else
		post_img_Bit4 <= post_img_Bit1 & post_img_Bit2 & post_img_Bit3;
end

//------------------------------------------
//lag 2 clocks signal sync  
reg	[1:0]	per_frame_vsync_r;
reg	[1:0]	per_frame_href_r;	
reg	[1:0]	per_frame_clken_r;
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		begin
		per_frame_vsync_r <= 0;
		per_frame_href_r <= 0;
		per_frame_clken_r <= 0;
		end
	else
		begin
		per_frame_vsync_r 	<= 	{per_frame_vsync_r[0], 	matrix_frame_vsync};
		per_frame_href_r 	<= 	{per_frame_href_r[0], 	matrix_frame_href};
		per_frame_clken_r 	<= 	{per_frame_clken_r[0], 	matrix_frame_clken};
		end
end
assign	post_frame_vsync 	= 	per_frame_vsync_r[1];
assign	post_frame_href 	= 	per_frame_href_r[1];
assign	post_frame_clken 	= 	per_frame_clken_r[1];
assign	post_img_Bit		=	post_frame_href ? post_img_Bit4 : 1'b0;

endmodule

