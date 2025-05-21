`timescale 1 ps/ 1 ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 05-12-2025 01:42:24
// Design Name:
// Module Name: sdram_read
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

module  sdram_read
(
    input   wire            sys_clk         ,   //ϵͳʱ��,Ƶ��100MHz
    input   wire            sys_rst_n       ,   //��λ�ź�,�͵�ƽ��Ч
    input   wire            init_end        ,   //��ʼ�������ź�
    input   wire            rd_en           ,   //��ʹ��
    input   wire    [23:0]  rd_addr         ,   //��SDRAM��ַ
    input   wire    [15:0]  rd_data         ,   //��SDRAM�ж���������
    input   wire    [9:0]   rd_burst_len    ,   //��ͻ��SDRAM�ֽ���

    output  wire            rd_ack          ,   //��SDRAM��Ӧ�ź�
    output  wire            rd_end          ,   //һ��ͻ��������
    output  reg     [3:0]   read_cmd        ,   //�����ݽ׶�д��sdram��ָ��,{cs_n,ras_n,cas_n,we_n}
    output  reg     [1:0]   read_ba         ,   //�����ݽ׶�Bank��ַ
    output  reg     [12:0]  read_addr       ,   //��ַ����,����Ԥ������,�С��е�ַ,A12-A0,13λ��ַ
    output  wire    [15:0]  rd_sdram_data       //SDRAM����������
);

//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//

//parameter     define
parameter   TRCD_CLK    =   10'd3   ,   //����ȴ�����
            TCL_CLK     =   10'd4   ,   //Ǳ����
            TRP_CLK     =   10'd3   ;   //Ԥ���ȴ�����
parameter   RD_IDLE     =   4'b0000 ,   //����
            RD_ACTIVE   =   4'b0001 ,   //����
            RD_TRCD     =   4'b0011 ,   //����ȴ�
            RD_READ     =   4'b0010 ,   //������
            RD_CL       =   4'b0100 ,   //Ǳ����
            RD_DATA     =   4'b0101 ,   //������
            RD_PRE      =   4'b0111 ,   //Ԥ���
            RD_TRP      =   4'b0110 ,   //Ԥ���ȴ�
            RD_END      =   4'b1100 ;   //һ��ͻ��������
parameter   NOP         =   4'b0111 ,   //�ղ���ָ��
            ACTIVE      =   4'b0011 ,   //����ָ��
            READ        =   4'b0101 ,   //���ݶ�ָ��
            B_STOP      =   4'b0110 ,   //ͻ��ָֹͣ��
            P_CHARGE    =   4'b0010 ;   //Ԥ���ָ��

//wire  define
wire            trcd_end    ;   //����ȴ����ڽ���
wire            trp_end     ;   //Ԥ���ȴ����ڽ���
wire            tcl_end     ;   //Ǳ���ڽ�����־
wire            tread_end   ;   //ͻ��������
wire            rdburst_end ;   //��ͻ����ֹ

//reg   define
reg     [3:0]   read_state  ;   //SDRAMд״̬
reg     [9:0]   cnt_clk     ;   //ʱ�����ڼ���,��¼��ʼ����״̬�ȴ�ʱ��
reg             cnt_clk_rst ;   //ʱ�����ڼ�����λ��־
reg     [15:0]  rd_data_reg ;

//********************************************************************//
//***************************** Main Code ****************************//
//********************************************************************//

//rd_data_reg
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        rd_data_reg <=  16'd0;
    else
        rd_data_reg <=  rd_data;

//rd_end:һ��ͻ��������
assign  rd_end = (read_state == RD_END) ? 1'b1 : 1'b0;

//rd_ack:��SDRAM��Ӧ�ź�
assign  rd_ack = (read_state == RD_DATA)
                && (cnt_clk >= 10'd1)
                && (cnt_clk < (rd_burst_len + 2'd1));

//cnt_clk:ʱ�����ڼ���,��¼��ʼ����״̬�ȴ�ʱ��
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cnt_clk <=  10'd0;
    else    if(cnt_clk_rst == 1'b1)
        cnt_clk <=  10'd0;
    else
        cnt_clk <=  cnt_clk + 1'b1;

//trcd_end,trp_end,tcl_end,tread_end,rdburst_end:�ȴ�������־
assign  trcd_end    =   ((read_state == RD_TRCD)
                        && (cnt_clk == TRCD_CLK        )) ? 1'b1 : 1'b0;    //��ѡͨ���ڽ���
assign  trp_end     =   ((read_state == RD_TRP )
                        && (cnt_clk == TRP_CLK         )) ? 1'b1 : 1'b0;    //Ԥ�����Ч���ڽ���
assign  tcl_end     =   ((read_state == RD_CL  )
                        && (cnt_clk == TCL_CLK - 1     )) ? 1'b1 : 1'b0;    //Ǳ���ڽ���
assign  tread_end   =   ((read_state == RD_DATA)
                        && (cnt_clk == rd_burst_len + 2)) ? 1'b1 : 1'b0;    //ͻ��������
assign  rdburst_end =   ((read_state == RD_DATA)
                        && (cnt_clk == rd_burst_len - 4)) ? 1'b1 : 1'b0;    //��ͻ����ֹ

//read_state:SDRAM�Ĺ���״̬��
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
            read_state  <=  RD_IDLE;
    else
        case(read_state)
            RD_IDLE:
                if((rd_en ==1'b1) && (init_end == 1'b1))
                        read_state <=  RD_ACTIVE;
                else
                        read_state <=  RD_IDLE;
            RD_ACTIVE:
                read_state <=  RD_TRCD;
            RD_TRCD:
                if(trcd_end == 1'b1)
                    read_state <=  RD_READ;
                else
                    read_state <=  RD_TRCD;
            RD_READ:
                read_state <=  RD_CL;
            RD_CL:
                read_state <=  (tcl_end == 1'b1) ? RD_DATA : RD_CL;
            RD_DATA:
                read_state <=  (tread_end == 1'b1) ? RD_PRE : RD_DATA;
            RD_PRE:
                read_state  <=  RD_TRP;
            RD_TRP:
                read_state  <=  (trp_end == 1'b1) ? RD_END : RD_TRP;
            RD_END:
                read_state  <=  RD_IDLE;
            default:
                read_state  <=  RD_IDLE;
        endcase

//�����������߼�
always@(*)
    begin
        case(read_state)
            RD_IDLE:    cnt_clk_rst   <=  1'b1;
            RD_TRCD:    cnt_clk_rst   <=  (trcd_end == 1'b1) ? 1'b1 : 1'b0;
            RD_READ:    cnt_clk_rst   <=  1'b1;
            RD_CL:      cnt_clk_rst   <=  (tcl_end == 1'b1) ? 1'b1 : 1'b0;
            RD_DATA:    cnt_clk_rst   <=  (tread_end == 1'b1) ? 1'b1 : 1'b0;
            RD_TRP:     cnt_clk_rst   <=  (trp_end == 1'b1) ? 1'b1 : 1'b0;
            RD_END:     cnt_clk_rst   <=  1'b1;
            default:    cnt_clk_rst   <=  1'b0;
        endcase
    end

//SDRAM����ָ�����
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        begin
            read_cmd    <=  NOP;
            read_ba     <=  2'b11;
            read_addr   <=  13'h1fff;
        end
    else
        case(read_state)
            RD_IDLE,RD_TRCD,RD_TRP:
                begin
                    read_cmd    <=  NOP;
                    read_ba     <=  2'b11;
                    read_addr   <=  13'h1fff;
                end
            RD_ACTIVE:  //����ָ��
                begin
                    read_cmd    <=  ACTIVE;
                    read_ba     <=  rd_addr[23:22];
                    read_addr   <=  rd_addr[21:9];
                end
            RD_READ:    //������ָ��
                begin
                    read_cmd    <=  READ;
                    read_ba     <=  rd_addr[23:22];
                    read_addr   <=  {4'b0000,rd_addr[8:0]};
                end
            RD_DATA:    //ͻ��������ָֹ��
                begin
                    if(rdburst_end == 1'b1)
                        read_cmd <=  B_STOP;
                    else
                        begin
                            read_cmd    <=  NOP;
                            read_ba     <=  2'b11;
                            read_addr   <=  13'h1fff;
                        end
                end
            RD_PRE:     //Ԥ���ָ��
                begin
                    read_cmd    <= P_CHARGE;
                    read_ba     <= rd_addr[23:22];
                    read_addr   <= 13'h0400;
                end
            RD_END:
                begin
                    read_cmd    <=  NOP;
                    read_ba     <=  2'b11;
                    read_addr   <=  13'h1fff;
                end
            default:
                begin
                    read_cmd    <=  NOP;
                    read_ba     <=  2'b11;
                    read_addr   <=  13'h1fff;
                end
        endcase

//rd_sdram_data:SDRAM����������
assign  rd_sdram_data = (rd_ack == 1'b1) ? rd_data_reg : 16'b0;

endmodule
