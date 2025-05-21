`timescale 1 ps/ 1 ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 05-12-2025 01:33:56
// Design Name:
// Module Name: sdram_arbit
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

module  sdram_arbit
(
    input   wire            sys_clk     ,   //ϵͳʱ��
    input   wire            sys_rst_n   ,   //��λ�ź�
//sdram_init
    input   wire    [3:0]   init_cmd    ,   //��ʼ���׶�����
    input   wire            init_end    ,   //��ʼ��������־
    input   wire    [1:0]   init_ba     ,   //��ʼ���׶�Bank��ַ
    input   wire    [12:0]  init_addr   ,   //��ʼ���׶����ݵ�ַ
//sdram_auto_ref
    input   wire            aref_req    ,   //��ˢ������
    input   wire            aref_end    ,   //��ˢ�½���
    input   wire    [3:0]   aref_cmd    ,   //��ˢ�½׶�����
    input   wire    [1:0]   aref_ba     ,   //�Զ�ˢ�½׶�Bank��ַ
    input   wire    [12:0]  aref_addr   ,   //��ˢ�½׶����ݵ�ַ
//sdram_write
    input   wire            wr_req      ,   //д��������
    input   wire    [1:0]   wr_ba       ,   //д�׶�Bank��ַ
    input   wire    [15:0]  wr_data     ,   //д��SDRAM������
    input   wire            wr_end      ,   //һ��д�����ź�
    input   wire    [3:0]   wr_cmd      ,   //д�׶�����
    input   wire    [12:0]  wr_addr     ,   //д�׶����ݵ�ַ
    input   wire            wr_sdram_en ,
//sdram_read
    input   wire            rd_req      ,   //����������
    input   wire            rd_end      ,   //һ�ζ�����
    input   wire    [3:0]   rd_cmd      ,   //���׶�����
    input   wire    [12:0]  rd_addr     ,   //���׶����ݵ�ַ
    input   wire    [1:0]   rd_ba       ,   //���׶�Bank��ַ

    output  reg             aref_en     ,   //��ˢ��ʹ��
    output  reg             wr_en       ,   //д����ʹ��
    output  reg             rd_en       ,   //������ʹ��

    output  wire            sdram_cke   ,   //SDRAMʱ��ʹ��
    output  wire            sdram_cs_n  ,   //SDRAMƬѡ�ź�
    output  wire            sdram_ras_n ,   //SDRAM�е�ַѡͨ
    output  wire            sdram_cas_n ,   //SDRAM�е�ַѡͨ
    output  wire            sdram_we_n  ,   //SDRAMдʹ��
    output  reg     [1:0]   sdram_ba    ,   //SDRAM Bank��ַ
    output  reg     [12:0]  sdram_addr  ,   //SDRAM��ַ����
    inout   wire    [15:0]  sdram_dq        //SDRAM��������
);

//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//

//parameter define
parameter   IDLE    =   5'b0_0001   ,   //��ʼ״̬
            ARBIT   =   5'b0_0010   ,   //�ٲ�״̬
            AREF    =   5'b0_0100   ,   //�Զ�ˢ��״̬
            WRITE   =   5'b0_1000   ,   //д״̬
            READ    =   5'b1_0000   ;   //��״̬
parameter   CMD_NOP =   4'b0111     ;   //�ղ���ָ��

//reg   define
reg     [3:0]   sdram_cmd   ;   //д��SDRAM����
reg     [4:0]   state       ;   //״̬��״̬

//********************************************************************//
//***************************** Main Code ****************************//
//********************************************************************//

//state��״̬��״̬
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        state   <=  IDLE;
    else    case(state)
        IDLE:   if(init_end == 1'b1)
                    state   <=  ARBIT;
                else
                    state   <=  IDLE;
        ARBIT:if(aref_req == 1'b1)
                    state   <=  AREF;
                else    if(wr_req == 1'b1)
                    state   <=  WRITE;
                else    if(rd_req == 1'b1)
                    state   <=  READ;
                else
                    state   <=  ARBIT;
        AREF:   if(aref_end == 1'b1)
                    state   <=  ARBIT;
                else
                    state   <=  AREF; 
        WRITE:  if(wr_end == 1'b1)
                    state   <=  ARBIT;
                else
                    state   <=  WRITE;
        READ:   if(rd_end == 1'b1)
                    state   <=  ARBIT;
                else
                    state   <=  READ;
        default:state   <=  IDLE;
    endcase

//aref_en���Զ�ˢ��ʹ��
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        aref_en  <=  1'b0;
    else    if((state == ARBIT) && (aref_req == 1'b1))
        aref_en  <=  1'b1;
    else    if(aref_end == 1'b1)
        aref_en  <=  1'b0;

//wr_en��д����ʹ��
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        wr_en   <=  1'b0;
    else    if((state == ARBIT) && (aref_req == 1'b0) && (wr_req == 1'b1))
        wr_en   <=  1'b1;
    else    if(wr_end == 1'b1)
        wr_en   <=  1'b0;

//rd_en��������ʹ��
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        rd_en   <=  1'b0;
    else    if((state == ARBIT) && (aref_req == 1'b0)  && (rd_req == 1'b1))
        rd_en   <=  1'b1;
    else    if(rd_end == 1'b1)
        rd_en   <=  1'b0;

//sdram_cmd:д��SDRAM����;sdram_ba:SDRAM Bank��ַ;sdram_addr:SDRAM��ַ����
always@(*)
    case(state) 
        IDLE: begin
            sdram_cmd   <=  init_cmd;
            sdram_ba    <=  init_ba;
            sdram_addr  <=  init_addr;
        end
        AREF: begin
            sdram_cmd   <=  aref_cmd;
            sdram_ba    <=  aref_ba;
            sdram_addr  <=  aref_addr;
        end
        WRITE: begin
            sdram_cmd   <=  wr_cmd;
            sdram_ba    <=  wr_ba;
            sdram_addr  <=  wr_addr;
        end
        READ: begin
            sdram_cmd   <=  rd_cmd;
            sdram_ba    <=  rd_ba;
            sdram_addr  <=  rd_addr;
        end
        default: begin
            sdram_cmd   <=  CMD_NOP;
            sdram_ba    <=  2'b11;
            sdram_addr  <=  13'h1fff;
        end
    endcase

//SDRAMʱ��ʹ��
assign  sdram_cke = 1'b1;
//SDRAM��������
assign  sdram_dq = (wr_sdram_en == 1'b1) ? wr_data : 16'bz;
//Ƭѡ�ź�,�е�ַѡͨ�ź�,�е�ַѡͨ�ź�,дʹ���ź�
assign  {sdram_cs_n, sdram_ras_n, sdram_cas_n, sdram_we_n} = sdram_cmd;

endmodule
