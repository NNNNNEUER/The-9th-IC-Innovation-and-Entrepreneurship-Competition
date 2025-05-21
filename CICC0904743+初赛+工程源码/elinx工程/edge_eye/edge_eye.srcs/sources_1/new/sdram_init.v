`timescale 1 ps/ 1 ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 05-12-2025 01:32:22
// Design Name:
// Module Name: sdram_init
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

module  sdram_init
(
    input   wire            sys_clk     ,   //ϵͳʱ��,Ƶ��100MHz
    input   wire            sys_rst_n   ,   //��λ�ź�,�͵�ƽ��Ч

    output  reg     [3:0]   init_cmd    ,   //��ʼ���׶�д��sdram��ָ��,{cs_n,ras_n,cas_n,we_n}
    output  reg     [1:0]   init_ba     ,   //��ʼ���׶�Bank��ַ
    output  reg     [12:0]  init_addr   ,   //��ʼ���׶ε�ַ����,����Ԥ������
                                            //������ģʽ�Ĵ�������,A12-A0,��13λ
    output  wire            init_end        //��ʼ�������ź�
);

//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//

// parameter    define
parameter   T_POWER     =   15'd20_000  ;   //�ϵ��ȴ�ʱ����(200us)
//SDRAM��ʼ���õ��Ŀ����ź�����
parameter   P_CHARGE    =   4'b0010     ,   //Ԥ���ָ��
            AUTO_REF    =   4'b0001     ,   //�Զ�ˢ��ָ��
            NOP         =   4'b0111     ,   //�ղ���ָ��
            M_REG_SET   =   4'b0000     ;   //ģʽ�Ĵ�������ָ��
//SDRAM��ʼ�����̸���״̬
parameter   INIT_IDLE   =   3'b000      ,   //��ʼ״̬
            INIT_PRE    =   3'b001      ,   //Ԥ���״̬
            INIT_TRP    =   3'b011      ,   //Ԥ���ȴ�          tRP
            INIT_AR     =   3'b010      ,   //�Զ�ˢ��
            INIT_TRF    =   3'b100      ,   //�Զ�ˢ�µȴ�        tRC
            INIT_MRS    =   3'b101      ,   //ģʽ�Ĵ�������
            INIT_TMRD   =   3'b111      ,   //ģʽ�Ĵ������õȴ�  tMRD
            INIT_END    =   3'b110      ;   //��ʼ�����
parameter   TRP_CLK     =   3'd2        ,   //Ԥ���ȴ�����,20ns
            TRC_CLK     =   3'd7        ,   //�Զ�ˢ�µȴ�,70ns
            TMRD_CLK    =   3'd3        ;   //ģʽ�Ĵ������õȴ�����,30ns

// wire define
wire            wait_end        ;   //�ϵ��200us�ȴ�������־
wire            trp_end         ;   //Ԥ���ȴ�������־
wire            trc_end         ;   //�Զ�ˢ�µȴ�������־
wire            tmrd_end        ;   //ģʽ�Ĵ������õȴ�������־

// reg  define
reg     [14:0]  cnt_200us       ;   //SDRAM�ϵ��200us�ȶ��ڼ�����
reg     [2:0]   init_state      ;   //SDRAM��ʼ��״̬
reg     [2:0]   cnt_clk         ;   //ʱ�����ڼ���,��¼��ʼ����״̬�ȴ�������
reg             cnt_clk_rst     ;   //ʱ�����ڼ�����λ��־
reg     [3:0]   cnt_init_aref   ;   //��ʼ�������Զ�ˢ�´���������

//********************************************************************//
//***************************** Main Code ****************************//
//********************************************************************//

//cnt_200us:SDRAM�ϵ��200us�ȶ��ڼ�����
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cnt_200us   <=  15'd0;
    else    if(cnt_200us == T_POWER)
        cnt_200us   <=  T_POWER;
    else
        cnt_200us   <=  cnt_200us + 1'b1;

//wait_end:�ϵ��200us�ȴ�������־
assign  wait_end = (cnt_200us == (T_POWER - 1'b1)) ? 1'b1 : 1'b0;

//init_end:SDRAM��ʼ������ź�
assign  init_end = (init_state == INIT_END) ? 1'b1 : 1'b0;

//cnt_clk:ʱ�����ڼ���,��¼��ʼ����״̬�ȴ�ʱ��
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cnt_clk <=  3'd0;
    else    if(cnt_clk_rst == 1'b1)
        cnt_clk <=  3'd0;
    else
        cnt_clk <=  cnt_clk + 1'b1;

//cnt_init_aref:��ʼ�������Զ�ˢ�´���������
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cnt_init_aref   <=  4'd0;
    else    if(init_state == INIT_IDLE)
        cnt_init_aref   <=  4'd0;
    else    if(init_state == INIT_AR)
        cnt_init_aref   <=  cnt_init_aref + 1'b1;
    else
        cnt_init_aref   <=  cnt_init_aref;

//trp_end,trc_end,tmrd_end:�ȴ�������־
assign  trp_end     =   ((init_state == INIT_TRP )
                        && (cnt_clk == TRP_CLK )) ? 1'b1 : 1'b0;
assign  trc_end     =   ((init_state == INIT_TRF )
                        && (cnt_clk == TRC_CLK )) ? 1'b1 : 1'b0;
assign  tmrd_end    =   ((init_state == INIT_TMRD)
                        && (cnt_clk == TMRD_CLK)) ? 1'b1 : 1'b0;

//SDRAM�ĳ�ʼ��״̬��
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        init_state  <=  INIT_IDLE;
    else
        case(init_state)
            INIT_IDLE:  //ϵͳ�ϵ��,�ڳ�ʼ״̬�ȴ�200us��ת��Ԥ���״̬
                if(wait_end == 1'b1)
                    init_state  <=  INIT_PRE;
                else
                    init_state  <=  init_state;
            INIT_PRE:   //Ԥ���״̬��ֱ����ת��Ԥ���ȴ�״̬
                init_state  <=  INIT_TRP;
            INIT_TRP:   //Ԥ���ȴ�״̬,�ȴ�����,��ת���Զ�ˢ��״̬
                if(trp_end == 1'b1)
                    init_state  <=  INIT_AR;
                else
                    init_state  <=  init_state;
            INIT_AR :   //�Զ�ˢ��״̬,ֱ����ת���Զ�ˢ�µȴ�״̬
                init_state  <=  INIT_TRF;
            INIT_TRF:   //�Զ�ˢ�µȴ�״̬,�ȴ�����,�Զ���ת��ģʽ�Ĵ�������״̬
                if(trc_end == 1'b1)
                    if(cnt_init_aref == 4'd8)
                        init_state  <=  INIT_MRS;
                    else
                        init_state  <=  INIT_AR;
                else
                    init_state  <=  init_state;
            INIT_MRS:   //ģʽ�Ĵ�������״̬,ֱ����ת��ģʽ�Ĵ������õȴ�״̬
                init_state  <=  INIT_TMRD;
            INIT_TMRD:  //ģʽ�Ĵ������õȴ�״̬,�ȴ�����,������ʼ�����״̬
                if(tmrd_end == 1'b1)
                    init_state  <=  INIT_END;
                else
                    init_state  <=  init_state;
            INIT_END:   //��ʼ�����״̬,���ִ�״̬
                init_state  <=  INIT_END;
            default:    init_state  <=  INIT_IDLE;
        endcase

//cnt_clk_rst:ʱ�����ڼ�����λ��־
always@(*)
    begin
        case (init_state)
            INIT_IDLE:  cnt_clk_rst <=  1'b1;   //ʱ�����ڼ�����λ�ź�,����Ч,ʱ�����ڼ�������
            INIT_TRP:   cnt_clk_rst <= (trp_end == 1'b1) ? 1'b1 : 1'b0;
                                                //�ȴ�������־��Ч,����������
            INIT_TRF:   cnt_clk_rst <=  (trc_end == 1'b1) ? 1'b1 : 1'b0; 
                                                //�ȴ�������־��Ч,����������
            INIT_TMRD:  cnt_clk_rst <=  (tmrd_end == 1'b1) ? 1'b1 : 1'b0;
                                                //�ȴ�������־��Ч,����������
            INIT_END:   cnt_clk_rst <=  1'b1;   //��ʼ�����,����������
            default:    cnt_clk_rst <=  1'b0;
        endcase
    end

//SDRAM����ָ�����
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        begin
            init_cmd    <=  NOP;
            init_ba     <=  2'b11;
            init_addr   <=  13'h1fff;
        end
    else
        case(init_state)
            INIT_IDLE,INIT_TRP,INIT_TRF,INIT_TMRD:  //ִ�пղ���ָ��
                begin
                    init_cmd    <=  NOP;
                    init_ba     <=  2'b11;
                    init_addr   <=  13'h1fff;
                end
            INIT_PRE:   //Ԥ���ָ��
                begin
                    init_cmd    <=  P_CHARGE;
                    init_ba     <=  2'b11;
                    init_addr   <=  13'h1fff;
                end 
            INIT_AR:    //�Զ�ˢ��ָ��
                begin
                    init_cmd    <=  AUTO_REF;
                    init_ba     <=  2'b11;
                    init_addr   <=  13'h1fff;
                end
            INIT_MRS:   //ģʽ�Ĵ�������ָ��
                begin
                    init_cmd    <=  M_REG_SET;
                    init_ba     <=  2'b00;
                    init_addr   <=
                    {    //��ַ��������ģʽ�Ĵ���,������ͬ,���õ�ģʽ��ͬ
                        3'b000,     //A12-A10:Ԥ��
                        1'b0,       //A9=0:��д��ʽ,0:ͻ����&ͻ��д,1:ͻ����&��д
                        2'b00,      //{A8,A7}=00:��׼ģʽ,Ĭ��
                        3'b011,     //{A6,A5,A4}=011:CASǱ����,010:2,011:3,����:����
                        1'b0,       //A3=0:ͻ�����䷽ʽ,0:˳��,1:����
                        3'b111      //{A2,A1,A0}=111:ͻ������,000:���ֽ�,001:2�ֽ�
                                    //010:4�ֽ�,011:8�ֽ�,111:��ҳ,����:����
                    };
                end 
            INIT_END:   //SDRAM��ʼ�����
                begin
                    init_cmd    <=  NOP;
                    init_ba     <=  2'b11;
                    init_addr   <=  13'h1fff;
                end
            default:
                begin
                    init_cmd    <=  NOP;
                    init_ba     <=  2'b11;
                    init_addr   <=  13'h1fff;
                end    
        endcase

endmodule
