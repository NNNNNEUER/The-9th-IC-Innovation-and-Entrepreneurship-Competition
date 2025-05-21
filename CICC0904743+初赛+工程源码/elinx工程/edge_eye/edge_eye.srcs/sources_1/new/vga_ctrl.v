`timescale 1 ps/ 1 ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 05-16-2025 22:44:22
// Design Name:
// Module Name: vga_ctrl
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

module  vga_ctrl
(
    input   wire            vga_clk     ,   //���빤��ʱ��,Ƶ��25MHz
    input   wire            sys_rst_n   ,   //���븴λ�ź�,�͵�ƽ��Ч
    input   wire    [15:0]  pix_data    ,   //�������ص�ɫ����Ϣ

    output  wire            pix_data_req,
    output  wire            hsync       ,   //�����ͬ���ź�
    output  wire            vsync       ,   //�����ͬ���ź�
    output wire                         de                         ,
    output  wire    [15:0]  rgb             //������ص�ɫ����Ϣ
);

//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//
//parameter define
//1280*720
parameter H_SYNC    =   12'd40  ,   //��ͬ��
          H_BACK    =   12'd220 ,   //��ʱ�����
          H_LEFT    =   12'd0   ,   //��ʱ����߿�
          H_VALID   =   12'd1280,   //����Ч����
          H_RIGHT   =   12'd0   ,   //��ʱ���ұ߿�
          H_FRONT   =   12'd110 ,   //��ʱ��ǰ��
          H_TOTAL   =   12'd1650;   //��ɨ������
parameter V_SYNC    =   12'd5   ,   //��ͬ��
          V_BACK    =   12'd20  ,   //��ʱ�����
          V_TOP     =   12'd0   ,   //��ʱ���ϱ߿�
          V_VALID   =   12'd720 ,   //����Ч����
          V_BOTTOM  =   12'd0   ,   //��ʱ���±߿�
          V_FRONT   =   12'd5   ,   //��ʱ��ǰ��
          V_TOTAL   =   12'd750 ;   //��ɨ������

//wire  define
wire            rgb_valid       ;   //VGA��Ч��ʾ����		  
		  
//reg   define
reg     [11:0]   cnt_h           ;   //��ͬ���źż�����
reg     [11:0]   cnt_v           ;   //��ͬ���źż�����

//********************************************************************//
//***************************** Main Code ****************************//
//********************************************************************//

//cnt_h:��ͬ���źż�����
always@(posedge vga_clk or  negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cnt_h   <=  12'd0   ;
    else    if(cnt_h == H_TOTAL - 1'd1)
        cnt_h   <=  12'd0   ;
    else
        cnt_h   <=  cnt_h + 1'd1   ;

//hsync:��ͬ���ź�
assign  hsync = (cnt_h  <=  H_SYNC - 1'd1) ? 1'b1 : 1'b0  ;

//cnt_v:��ͬ���źż�����
always@(posedge vga_clk or  negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cnt_v   <=  12'd0 ;
    else    if((cnt_v == V_TOTAL - 1'd1) &&  (cnt_h == H_TOTAL-1'd1))
        cnt_v   <=  12'd0 ;
    else    if(cnt_h == H_TOTAL - 1'd1)
        cnt_v   <=  cnt_v + 1'd1 ;
    else
        cnt_v   <=  cnt_v ;

//vsync:��ͬ���ź�
assign  vsync = (cnt_v  <=  V_SYNC - 1'd1) ? 1'b1 : 1'b0  ;

//rgb_valid:VGA��Ч��ʾ����
assign  rgb_valid = (((cnt_h >= H_SYNC + H_BACK + H_LEFT)
                    && (cnt_h < H_SYNC + H_BACK + H_LEFT + H_VALID))
                    &&((cnt_v >= V_SYNC + V_BACK + V_TOP)
                    && (cnt_v < V_SYNC + V_BACK + V_TOP + V_VALID)))
                    ? 1'b1 : 1'b0;

//pix_data_req:���ص�ɫ����Ϣ�����ź�,��ǰrgb_valid�ź�һ��ʱ������
assign  pix_data_req = (((cnt_h >= H_SYNC + H_BACK + H_LEFT - 1'b1)
                    && (cnt_h < H_SYNC + H_BACK + H_LEFT + H_VALID - 1'b1))
                    &&((cnt_v >= V_SYNC + V_BACK + V_TOP)
                    && (cnt_v < V_SYNC + V_BACK + V_TOP + V_VALID)))
                    ? 1'b1 : 1'b0;

//rgb:������ص�ɫ����Ϣ
assign  rgb = (rgb_valid == 1'b1) ? pix_data : 16'b0 ;
    assign                              de                          = rgb_valid;

endmodule
