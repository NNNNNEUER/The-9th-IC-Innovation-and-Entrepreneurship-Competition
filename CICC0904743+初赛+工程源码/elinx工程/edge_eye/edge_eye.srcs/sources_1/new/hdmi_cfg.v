`timescale 1 ps/ 1 ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 05-16-2025 22:47:55
// Design Name:
// Module Name: hdmi_cfg
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


module  hdmi_cfg
(
    input   wire            sys_clk     ,   //ϵͳʱ��,��iicģ�鴫��
    input   wire            sys_rst_n   ,   //ϵͳ��λ,����Ч
    input   wire            cfg_end     ,   //�����Ĵ����������

    output  reg             cfg_start   ,   //�����Ĵ������ô����ź�
    output  wire    [31:0]  cfg_data    ,   //ID,REG_ADDR,REG_VAL
    output  reg             cfg_done        //�Ĵ����������
);

//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//

//parameter define
parameter   REG_NUM         =   7'd10   ;   //�ܹ���Ҫ���õļĴ�������
parameter   CNT_WAIT_MAX    =   10'd1023;   //�Ĵ������õȴ��������ֵ

//wire  define
wire    [31:0]  cfg_data_reg[REG_NUM-1:0]   ;   //�Ĵ������������ݴ�

//reg   define
reg     [9:0]   cnt_wait    ;   //�Ĵ������õȴ�������
reg     [6:0]   reg_num     ;   //���üĴ�������

//********************************************************************//
//***************************** Main Code ****************************//
//********************************************************************//

//cnt_wait:�Ĵ������õȴ�������
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cnt_wait    <=  15'd0;
    else    if(cnt_wait < CNT_WAIT_MAX)
        cnt_wait    <=  cnt_wait + 1'b1;

//reg_num:���üĴ�������
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        reg_num <=  7'd0;
    else    if(cfg_end == 1'b1)
        reg_num <=  reg_num + 1'b1;

//cfg_start:�����Ĵ������ô����ź�
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cfg_start   <=  1'b0;
    else    if(cnt_wait == (CNT_WAIT_MAX - 1'b1))
        cfg_start   <=  1'b1;
    else    if((cfg_end == 1'b1) && (reg_num < REG_NUM))
        cfg_start   <=  1'b1;
    else
        cfg_start   <=  1'b0;

//cfg_done:�Ĵ����������
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cfg_done    <=  1'b0;
    else    if((reg_num == REG_NUM) && (cfg_end == 1'b1))
        cfg_done    <=  1'b1;

//cfg_data:ID,REG_ADDR,REG_VAL
assign  cfg_data = (cfg_done == 1'b1) ? 32'h0000 : cfg_data_reg[reg_num];

//----------------------------------------------------
//cfg_data_reg���Ĵ������������ݴ�  ID   REG_ADDR REG_VAL
//assign  cfg_data_reg[00]  =       {8'h12,  8'h80};
assign  cfg_data_reg[0]  ={8'h76,16'h05,8'h01};
assign  cfg_data_reg[1]  ={8'h76,16'h05,8'h00};
assign  cfg_data_reg[2]  ={8'h76,16'h08,8'h35};
assign  cfg_data_reg[3]  ={8'h76,16'h49,8'h00};
assign  cfg_data_reg[4]  ={8'h76,16'h4a,8'h00};
assign  cfg_data_reg[5]  ={8'h76,16'h82,8'h25};
assign  cfg_data_reg[6]  ={8'h76,16'h83,8'h1b};
assign  cfg_data_reg[7]  ={8'h76,16'h84,8'h30};
assign  cfg_data_reg[8]  ={8'h76,16'h85,8'h02};
assign  cfg_data_reg[9]  ={8'h7e,16'h2f,8'h00};


//-------------------------------------------------------

endmodule

