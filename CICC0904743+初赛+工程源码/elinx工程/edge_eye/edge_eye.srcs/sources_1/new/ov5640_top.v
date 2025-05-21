`timescale 1 ps/ 1 ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 05-18-2025 16:02:22
// Design Name:
// Module Name: ov5640_top
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


module ov5640_top #(
  parameter CAMERA_TYPE     = "ov5640", //"ov5640" or "ov7725"
  parameter IMAGE_TYPE      = 0,        //0:RGB 1:JPEG
  parameter IMAGE_WIDTH     = 1280,
  parameter IMAGE_HEIGHT    = 720,
  parameter IMAGE_FLIP_EN   = 1,
  parameter IMAGE_MIRROR_EN = 0
)
(
  input      Clk,
  input      Rst_n,
  input		 Rst_p,
  input		 PCLK,
  input		 Vsync,
  input		 Href,
  input		 Data,

  output 	 Init_Done,
  output     camera_rst_n,
  output     camera_pwdn,

  output     i2c_sclk,
  inout      i2c_sda,
  
  output DataValid,
  output [15:0] DataPixel,
  output DataHs,
  output DataVs,
  output [11:0] Xaddr,
  output [11:0] Yaddr
);

  camera_init
  #(
    .CAMERA_TYPE  ( CAMERA_TYPE    ),//"ov5640" or "ov7725"
    .IMAGE_TYPE  ( IMAGE_TYPE   ),// 0: RGB; 1: JPEG
    .IMAGE_WIDTH ( IMAGE_WIDTH  ),// 图片宽度
    .IMAGE_HEIGHT( IMAGE_HEIGHT ),// 图片高度
    .IMAGE_FLIP_EN  ( IMAGE_FLIP_EN),// 1: 不翻转，0: 上下翻转
    .IMAGE_MIRROR_EN( IMAGE_MIRROR_EN ) // 0: 不镜像，1: 左右镜像
  )camera_init_1
  (
    .Clk         (Clk       ),
    .Rst_n       (Rst_n          ),
    .Init_Done   (Init_Done ),
    .camera_rst_n(camera_rst_n),
    .camera_pwdn (camera_pwdn),
    .i2c_sclk    (i2c_sclk      ),
    .i2c_sdat    (i2c_sda      )
  );
  
    DVP_Capture DVP_Capture_inst_1(
    .Rst_p      (Rst_p          ),//input
    .PCLK       (PCLK      ),//input
    .Vsync      (Vsync     ),//input
    .Href       (Href      ),//input
    .Data       (Data      ),//input     [7:0]

    .ImageState (			),//output reg
    .DataValid  (DataValid ),//output
    .DataPixel  (DataPixel       ),//output    [15:0]
    .DataHs     (DataHs    ),//output
    .DataVs     (DataVs    ),//output
    .Xaddr      (Xaddr ),//output    [11:0]
    .Yaddr      (Yaddr ) //output    [11:0]
  );
endmodule