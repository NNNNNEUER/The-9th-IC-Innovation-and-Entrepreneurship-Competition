`timescale 1 ps/ 1 ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 05-19-2025 01:39:18
// Design Name:
// Module Name: pixel_data_processor
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


module pixel_data_processor(
    input              pclk,             // 摄像头像素时钟
    input              g_rst_p,          // 异步复位信号（低 PLL 锁定时复位）
    input              image_data_hs,    // 行同步信号
    input      [15:0]  image_data,       // 摄像头采集到的图像数据
    input              image_data_valid, // 图像数据有效信号
    input      [11:0]  image_data_yaddr, // 当前行地址
    output reg [15:0]  pixel_data,       // 输出的像素数据（含行号）
    output reg         pixel_data_valid  // 像素数据有效信号
);

    // 延时寄存器，用于捕捉上一拍的状态
    reg        image_data_hs_dly1;
    reg [15:0] image_data_dly1;
    reg        image_data_valid_dly1;

    always @(posedge pclk or posedge g_rst_p) begin
        if (g_rst_p) begin
            image_data_hs_dly1      <= 1'b0;
            image_data_dly1         <= 16'd0;
            image_data_valid_dly1   <= 1'b0;
            pixel_data              <= 16'd0;
            pixel_data_valid        <= 1'b0;
        end else begin
            // 更新延时信号（使用非阻塞赋值，后续计算使用的是上一拍值）
            image_data_hs_dly1      <= image_data_hs;
            image_data_dly1         <= image_data;
            image_data_valid_dly1   <= image_data_valid;
            
            // 检测行起始：当上一拍为低、当前为高时，认为是新行开始，
            // 此时输出行号（这里减1是为了与原代码一致）
            if (~image_data_hs_dly1 && image_data_hs) begin
                pixel_data       <= image_data_yaddr - 1'b1;
                pixel_data_valid <= 1'b1;
            end 
            // 如果数据有效，则传递延时后的图像数据
            else if (image_data_valid_dly1) begin
                pixel_data       <= image_data_dly1;
                pixel_data_valid <= 1'b1;
            end 
            else begin
                pixel_data_valid <= 1'b0;
            end
        end
    end

endmodule
