`timescale 1 ps/ 1 ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 05-12-2025 01:35:27
// Design Name:
// Module Name: sdram_a_ref
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


module  sdram_a_ref
(
    input   wire            sys_clk     ,   //ϵͳʱ��,Ƶ��100MHz
    input   wire            sys_rst_n   ,   //��λ�ź�,�͵�ƽ��Ч
    input   wire            init_end    ,   //��ʼ�������ź�
    input   wire            aref_en     ,   //�Զ�ˢ��ʹ��

    output  reg             aref_req    ,   //�Զ�ˢ������
    output  reg     [3:0]   aref_cmd    ,   //�Զ�ˢ�½׶�д��sdram��ָ��,{cs_n,ras_n,cas_n,we_n}
    output  reg     [1:0]   aref_ba     ,   //�Զ�ˢ�½׶�Bank��ַ
    output  reg     [12:0]  aref_addr   ,   //��ַ����,����Ԥ������,A12-A0,13λ��ַ
    output  wire            aref_end        //�Զ�ˢ�½�����־
);

//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//

//parameter     define
parameter   CNT_REF_MAX =   10'd749     ;   //�Զ�ˢ�µȴ�ʱ����(7.5us)
parameter   TRP_CLK     =   3'd2        ,   //Ԥ���ȴ�����
            TRC_CLK     =   3'd7        ;   //�Զ�ˢ�µȴ�����
parameter   P_CHARGE    =   4'b0010     ,   //Ԥ���ָ��
            A_REF       =   4'b0001     ,   //�Զ�ˢ��ָ��
            NOP         =   4'b0111     ;   //�ղ���ָ��
parameter   AREF_IDLE   =   3'b000      ,   //��ʼ״̬,�ȴ��Զ�ˢ��ʹ��
            AREF_PCHA   =   3'b001      ,   //Ԥ���״̬
            AREF_TRP    =   3'b011      ,   //Ԥ���ȴ�          tRP
            AUTO_REF    =   3'b010      ,   //�Զ�ˢ��״̬
            AREF_TRF    =   3'b100      ,   //�Զ�ˢ�µȴ�        tRC
            AREF_END    =   3'b101      ;   //�Զ�ˢ�½���

//wire  define
wire            trp_end     ;   //Ԥ���ȴ�������־
wire            trc_end     ;   //�Զ�ˢ�µȴ�������־
wire            aref_ack    ;   //�Զ�ˢ��Ӧ���ź�

//reg   define
reg     [9:0]   cnt_aref        ;   //�Զ�ˢ�¼�����
reg     [2:0]   aref_state      ;   //SDRAM�Զ�ˢ��״̬
reg     [2:0]   cnt_clk         ;   //ʱ�����ڼ���,��¼��ˢ�½׶θ�״̬�ȴ�ʱ��
reg             cnt_clk_rst     ;   //ʱ�����ڼ�����λ��־
reg     [1:0]   cnt_aref_aref   ;   //�Զ�ˢ�´���������

//********************************************************************//
//***************************** Main Code ****************************//
//********************************************************************//

//cnt_ref:ˢ�¼�����
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cnt_aref    <=  10'd0;
    else    if(cnt_aref >= CNT_REF_MAX)
        cnt_aref    <=  10'd0;
    else    if(init_end == 1'b1)
        cnt_aref    <=  cnt_aref + 1'b1;

//aref_req:�Զ�ˢ������
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        aref_req    <=  1'b0;
    else    if(cnt_aref == (CNT_REF_MAX - 1'b1))
        aref_req    <=  1'b1;
    else    if(aref_ack == 1'b1)
        aref_req    <=  1'b0;

//aref_ack:�Զ�ˢ��Ӧ���ź�
assign  aref_ack = (aref_state == AREF_PCHA ) ? 1'b1 : 1'b0;

//aref_end:�Զ�ˢ�½�����־
assign  aref_end = (aref_state == AREF_END  ) ? 1'b1 : 1'b0;

//cnt_clk:ʱ�����ڼ���,��¼��ʼ����״̬�ȴ�ʱ��
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cnt_clk <=  3'd0;
    else    if(cnt_clk_rst == 1'b1)
        cnt_clk <=  3'd0;
    else
        cnt_clk <=  cnt_clk + 1'b1;

//trp_end,trc_end,tmrd_end:�ȴ�������־
assign  trp_end = ((aref_state == AREF_TRP)
                    && (cnt_clk == TRP_CLK )) ? 1'b1 : 1'b0;
assign  trc_end = ((aref_state == AREF_TRF)
                    && (cnt_clk == TRC_CLK )) ? 1'b1 : 1'b0;

//cnt_aref_aref:��ʼ�������Զ�ˢ�´���������
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cnt_aref_aref   <=  2'd0;
    else    if(aref_state == AREF_IDLE)
        cnt_aref_aref   <=  2'd0;
    else    if(aref_state == AUTO_REF)
        cnt_aref_aref   <=  cnt_aref_aref + 1'b1;
    else
        cnt_aref_aref   <=  cnt_aref_aref;

//SDRAM�Զ�ˢ��״̬��
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        aref_state  <=  AREF_IDLE;
    else
        case(aref_state)
            AREF_IDLE:
                if((aref_en == 1'b1) && (init_end == 1'b1))
                    aref_state  <=  AREF_PCHA;
                else
                    aref_state  <=  aref_state;
            AREF_PCHA:
                aref_state  <=  AREF_TRP;
            AREF_TRP:
                if(trp_end == 1'b1)
                    aref_state  <=  AUTO_REF;
                else
                    aref_state  <=  aref_state;
            AUTO_REF:
                aref_state  <=  AREF_TRF;
            AREF_TRF:
                if(trc_end == 1'b1)
                    if(cnt_aref_aref == 2'd2)
                        aref_state  <=  AREF_END;
                    else
                        aref_state  <=  AUTO_REF;
                else
                    aref_state  <=  aref_state;
            AREF_END:
                aref_state  <=  AREF_IDLE;
            default:
                aref_state  <=  AREF_IDLE;
        endcase

//cnt_clk_rst:ʱ�����ڼ�����λ��־
always@(*)
    begin
        case (aref_state)
            AREF_IDLE:  cnt_clk_rst <=  1'b1;   //ʱ�����ڼ���������
            AREF_TRP:   cnt_clk_rst <=  (trp_end == 1'b1) ? 1'b1 : 1'b0;
                                                //�ȴ�������־��Ч,����������
            AREF_TRF:   cnt_clk_rst <=  (trc_end == 1'b1) ? 1'b1 : 1'b0;
                                                //�ȴ�������־��Ч,����������
            AREF_END:   cnt_clk_rst <=  1'b1;
            default:    cnt_clk_rst <=  1'b0;
        endcase
    end

//SDRAM����ָ�����
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        begin
            aref_cmd    <=  NOP;
            aref_ba     <=  2'b11;
            aref_addr   <=  13'h1fff;
        end
    else
        case(aref_state)
            AREF_IDLE,AREF_TRP,AREF_TRF:    //ִ�пղ���ָ��
                begin
                    aref_cmd    <=  NOP;
                    aref_ba     <=  2'b11;
                    aref_addr   <=  13'h1fff;
                end
            AREF_PCHA:  //Ԥ���ָ��
                begin
                    aref_cmd    <=  P_CHARGE;
                    aref_ba     <=  2'b11;
                    aref_addr   <=  13'h1fff;
                end 
            AUTO_REF:   //�Զ�ˢ��ָ��
                begin
                    aref_cmd    <=  A_REF;
                    aref_ba     <=  2'b11;
                    aref_addr   <=  13'h1fff;
                end
            AREF_END:   //һ���Զ�ˢ�����
                begin
                    aref_cmd    <=  NOP;
                    aref_ba     <=  2'b11;
                    aref_addr   <=  13'h1fff;
                end    
            default:
                begin
                    aref_cmd    <=  NOP;
                    aref_ba     <=  2'b11;
                    aref_addr   <=  13'h1fff;
                end    
        endcase

endmodule
