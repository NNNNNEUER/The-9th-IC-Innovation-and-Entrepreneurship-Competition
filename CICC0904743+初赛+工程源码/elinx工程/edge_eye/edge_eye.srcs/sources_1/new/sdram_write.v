`timescale 1 ps/ 1 ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 05-12-2025 01:37:15
// Design Name:
// Module Name: sdram_write
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

module  sdram_write
(
    input   wire            sys_clk         ,   //ϵͳʱ��,Ƶ��100MHz
    input   wire            sys_rst_n       ,   //��λ�ź�,�͵�ƽ��Ч
    input   wire            init_end        ,   //��ʼ�������ź�
    input   wire            wr_en           ,   //дʹ��
    input   wire    [23:0]  wr_addr         ,   //дSDRAM��ַ
    input   wire    [15:0]  wr_data         ,   //��д��SDRAM������(дFIFO����)
    input   wire    [9:0]   wr_burst_len    ,   //дͻ��SDRAM�ֽ���

    output  wire            wr_ack          ,   //дSDRAM��Ӧ�ź�
    output  wire            wr_end          ,   //һ��ͻ��д����
    output  reg     [3:0]   write_cmd       ,   //д���ݽ׶�д��sdram��ָ��,{cs_n,ras_n,cas_n,we_n}
    output  reg     [1:0]   write_ba        ,   //д���ݽ׶�Bank��ַ
    output  reg     [12:0]  write_addr      ,   //��ַ����,����Ԥ������,�С��е�ַ,A12-A0,13λ��ַ
    output  reg             wr_sdram_en     ,   //�����������ʹ��
    output  wire    [15:0]  wr_sdram_data       //д��SDRAM������
);

//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//

//parameter     define
parameter   TRCD_CLK    =   10'd3   ,   //��������
            TRP_CLK     =   10'd3   ;   //Ԥ�������
parameter   WR_IDLE     =   4'b0000 ,   //��ʼ״̬
            WR_ACTIVE   =   4'b0001 ,   //����
            WR_TRCD     =   4'b0011 ,   //����ȴ�
            WR_WRITE    =   4'b0010 ,   //д����
            WR_DATA     =   4'b0100 ,   //д����
            WR_PRE      =   4'b0101 ,   //Ԥ���
            WR_TRP      =   4'b0111 ,   //Ԥ���ȴ�
            WR_END      =   4'b0110 ;   //һ��ͻ��д����
parameter   NOP         =   4'b0111 ,   //�ղ���ָ��
            ACTIVE      =   4'b0011 ,   //����ָ��
            WRITE       =   4'b0100 ,   //����дָ��
            B_STOP      =   4'b0110 ,   //ͻ��ָֹͣ��
            P_CHARGE    =   4'b0010 ;   //Ԥ���ָ��

//wire  define
wire            trcd_end    ;   //����ȴ����ڽ���
wire            twrite_end  ;   //ͻ��д����
wire            trp_end     ;   //Ԥ�����Ч���ڽ���

//reg   define
reg     [3:0]   write_state ;   //SDRAMд״̬
reg     [9:0]   cnt_clk     ;   //ʱ�����ڼ���,��¼д���ݽ׶θ�״̬�ȴ�ʱ��
reg             cnt_clk_rst ;   //ʱ�����ڼ�����λ��־

//********************************************************************//
//***************************** Main Code ****************************//
//********************************************************************//

//wr_end:һ��ͻ��д����
assign  wr_end = (write_state == WR_END) ? 1'b1 : 1'b0;

//wr_ack:дSDRAM��Ӧ�ź�
assign  wr_ack = ( write_state == WR_WRITE)
                || ((write_state == WR_DATA) 
                && (cnt_clk <= (wr_burst_len - 2'd2)));

//cnt_clk:ʱ�����ڼ���,��¼��ʼ����״̬�ȴ�ʱ��
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cnt_clk <=  10'd0;
    else    if(cnt_clk_rst == 1'b1)
        cnt_clk <=  10'd0;
    else
        cnt_clk <=  cnt_clk + 1'b1;

//trcd_end,twrite_end,trp_end:�ȴ�������־
assign  trcd_end    =   ((write_state == WR_TRCD)
                        &&(cnt_clk == TRCD_CLK        )) ? 1'b1 : 1'b0;    //�������ڽ���
assign  twrite_end  =   ((write_state == WR_DATA)
                        &&(cnt_clk == wr_burst_len - 1)) ? 1'b1 : 1'b0;    //ͻ��д����
assign  trp_end     =   ((write_state == WR_TRP )
                        &&(cnt_clk == TRP_CLK         )) ? 1'b1 : 1'b0;    //Ԥ���ȴ����ڽ���

//write_state:SDRAM�Ĺ���״̬��
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
            write_state <=  WR_IDLE;
    else
        case(write_state)
            WR_IDLE:
                if((wr_en ==1'b1) && (init_end == 1'b1))
                        write_state <=  WR_ACTIVE;
                else
                        write_state <=  write_state;
            WR_ACTIVE:
                write_state <=  WR_TRCD;
            WR_TRCD:
                if(trcd_end == 1'b1)
                    write_state <=  WR_WRITE;
                else
                    write_state <=  write_state;
            WR_WRITE:
                write_state <=  WR_DATA;
            WR_DATA:
                if(twrite_end == 1'b1)
                    write_state <=  WR_PRE;
                else
                    write_state <=  write_state;
            WR_PRE:
                write_state <=  WR_TRP;
            WR_TRP:
                if(trp_end == 1'b1)
                    write_state <=  WR_END;
                else
                    write_state <=  write_state;

            WR_END:
                write_state <=  WR_IDLE;
            default:
                write_state <=  WR_IDLE;
        endcase

//�����������߼�
always@(*)
    begin
        case(write_state)
            WR_IDLE:    cnt_clk_rst   <=  1'b1;
            WR_TRCD:    cnt_clk_rst   <=  (trcd_end == 1'b1) ? 1'b1 : 1'b0;
            WR_WRITE:   cnt_clk_rst   <=  1'b1;
            WR_DATA:    cnt_clk_rst   <=  (twrite_end == 1'b1) ? 1'b1 : 1'b0;
            WR_TRP:     cnt_clk_rst   <=  (trp_end == 1'b1) ? 1'b1 : 1'b0;
            WR_END:     cnt_clk_rst   <=  1'b1;
            default:    cnt_clk_rst   <=  1'b0;
        endcase
    end

//SDRAM����ָ�����
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        begin
            write_cmd   <=  NOP;
            write_ba    <=  2'b11;
            write_addr  <=  13'h1fff;
        end
    else
        case(write_state)
            WR_IDLE,WR_TRCD,WR_TRP:
                begin
                    write_cmd   <=  NOP;
                    write_ba    <=  2'b11;
                    write_addr  <=  13'h1fff;
                end
            WR_ACTIVE:  //����ָ��
                begin
                    write_cmd   <=  ACTIVE;
                    write_ba    <=  wr_addr[23:22];
                    write_addr  <=  wr_addr[21:9];
                end
            WR_WRITE:   //д����ָ��
                begin
                    write_cmd   <=  WRITE;
                    write_ba    <=  wr_addr[23:22];
                    write_addr  <=  {4'b0000,wr_addr[8:0]};
                end     
            WR_DATA:    //ͻ��������ָֹ��
                begin
                    if(twrite_end == 1'b1)
                        write_cmd <=  B_STOP;
                    else
                        begin
                            write_cmd   <=  NOP;
                            write_ba    <=  2'b11;
                            write_addr  <=  13'h1fff;
                        end
                end
            WR_PRE:     //Ԥ���ָ��
                begin
                    write_cmd   <= P_CHARGE;
                    write_ba    <= wr_addr[23:22];
                    write_addr  <= 13'h0400;
                end
            WR_END:
                begin
                    write_cmd   <=  NOP;
                    write_ba    <=  2'b11;
                    write_addr  <=  13'h1fff;
                end
            default:
                begin
                    write_cmd   <=  NOP;
                    write_ba    <=  2'b11;
                    write_addr  <=  13'h1fff;
                end
        endcase

//wr_sdram_en:�����������ʹ��
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        wr_sdram_en <=  1'b0;
    else
        wr_sdram_en <=  wr_ack;

//wr_sdram_data:д��SDRAM������
assign  wr_sdram_data = (wr_sdram_en == 1'b1) ? wr_data : 16'd0;

endmodule
