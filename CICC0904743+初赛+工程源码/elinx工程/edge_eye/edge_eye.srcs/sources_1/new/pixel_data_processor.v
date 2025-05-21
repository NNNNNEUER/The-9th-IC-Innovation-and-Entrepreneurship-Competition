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
    input              pclk,             // ����ͷ����ʱ��
    input              g_rst_p,          // �첽��λ�źţ��� PLL ����ʱ��λ��
    input              image_data_hs,    // ��ͬ���ź�
    input      [15:0]  image_data,       // ����ͷ�ɼ�����ͼ������
    input              image_data_valid, // ͼ��������Ч�ź�
    input      [11:0]  image_data_yaddr, // ��ǰ�е�ַ
    output reg [15:0]  pixel_data,       // ������������ݣ����кţ�
    output reg         pixel_data_valid  // ����������Ч�ź�
);

    // ��ʱ�Ĵ��������ڲ�׽��һ�ĵ�״̬
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
            // ������ʱ�źţ�ʹ�÷�������ֵ����������ʹ�õ�����һ��ֵ��
            image_data_hs_dly1      <= image_data_hs;
            image_data_dly1         <= image_data;
            image_data_valid_dly1   <= image_data_valid;
            
            // �������ʼ������һ��Ϊ�͡���ǰΪ��ʱ����Ϊ�����п�ʼ��
            // ��ʱ����кţ������1��Ϊ����ԭ����һ�£�
            if (~image_data_hs_dly1 && image_data_hs) begin
                pixel_data       <= image_data_yaddr - 1'b1;
                pixel_data_valid <= 1'b1;
            end 
            // ���������Ч���򴫵���ʱ���ͼ������
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
