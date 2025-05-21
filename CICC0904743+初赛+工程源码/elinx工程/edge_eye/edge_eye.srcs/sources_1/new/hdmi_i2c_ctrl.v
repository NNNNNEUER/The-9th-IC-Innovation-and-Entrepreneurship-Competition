`timescale 1 ps/ 1 ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 05-16-2025 22:37:18
// Design Name:
// Module Name: hdmi_i2c_ctrl
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

module  hdmi_i2c_ctrl
#(
    parameter   SYS_CLK_FREQ    =   26'd50_000_000  ,   //����ϵͳʱ��Ƶ��
    parameter   SCL_FREQ        =   18'd250_000         //i2c�豸sclʱ��Ƶ��
)
(
    input   wire            sys_clk     ,   //����ϵͳʱ��,50MHz
    input   wire            sys_rst_n   ,   //���븴λ�ź�,�͵�ƽ��Ч
    input   wire            wr_en       ,   //����дʹ���ź�
    input   wire            rd_en       ,   //�����ʹ���ź�
    input   wire            i2c_start   ,   //����i2c�����ź�
    input   wire            addr_num    ,   //����i2c�ֽڵ�ַ�ֽ���
    input   wire    [7:0]   device_addr ,
    input   wire    [15:0]  byte_addr   ,   //����i2c�ֽڵ�ַ
    input   wire    [7:0]   wr_data     ,   //����i2c�豸����

    output  reg             i2c_clk     ,   //i2c����ʱ��
    output  reg             i2c_end     ,   //i2cһ�ζ�/д�������
    output  reg     [7:0]   rd_data     ,   //���i2c�豸��ȡ����
    output  reg             i2c_scl     ,   //�����i2c�豸�Ĵ���ʱ���ź�scl
    inout   wire            i2c_sda         //�����i2c�豸�Ĵ��������ź�sda
);

//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//
// parameter define
parameter   CNT_CLK_MAX     =   (SYS_CLK_FREQ/SCL_FREQ) >> 2'd3   ;   //cnt_clk�������������ֵ

parameter   CNT_START_MAX   =   8'd100; //cnt_start�������������ֵ

parameter   IDLE            =   4'd00,  //��ʼ״̬
            START_1         =   4'd01,  //��ʼ״̬1
            SEND_D_ADDR     =   4'd02,  //�豸��ַд��״̬ + ����д
            ACK_1           =   4'd03,  //Ӧ��״̬1
            SEND_B_ADDR_H   =   4'd04,  //�ֽڵ�ַ�߰�λд��״̬
            ACK_2           =   4'd05,  //Ӧ��״̬2
            SEND_B_ADDR_L   =   4'd06,  //�ֽڵ�ַ�Ͱ�λд��״̬
            ACK_3           =   4'd07,  //Ӧ��״̬3
            WR_DATA         =   4'd08,  //д����״̬
            ACK_4           =   4'd09,  //Ӧ��״̬4
            START_2         =   4'd10,  //��ʼ״̬2
            SEND_RD_ADDR    =   4'd11,  //�豸��ַд��״̬ + ���ƶ�
            ACK_5           =   4'd12,  //Ӧ��״̬5
            RD_DATA         =   4'd13,  //������״̬
            N_ACK           =   4'd14,  //��Ӧ��״̬
            STOP            =   4'd15;  //����״̬

// wire  define
wire            sda_in          ;   //sda�������ݼĴ�
wire            sda_en          ;   //sda����д��ʹ���ź�
wire    [6:0]   device_addr_i;
// reg   define
reg     [7:0]   cnt_clk         ;   //ϵͳʱ�Ӽ�����,��������clk_i2cʱ���ź�
reg     [3:0]   state           ;   //״̬��״̬
reg             cnt_i2c_clk_en  ;   //cnt_i2c_clk������ʹ���ź�
reg     [1:0]   cnt_i2c_clk     ;   //clk_i2cʱ�Ӽ�����,��������cnt_bit�ź�
reg     [2:0]   cnt_bit         ;   //sda���ؼ�����
reg             ack             ;   //Ӧ���ź�
reg             i2c_sda_reg     ;   //sda���ݻ���
reg     [7:0]   rd_data_reg     ;   //��i2c�豸��������

//********************************************************************//
//***************************** Main Code ****************************//
//********************************************************************//

assign device_addr_i=device_addr[7:1];
// cnt_clk:ϵͳʱ�Ӽ�����,��������clk_i2cʱ���ź�
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cnt_clk <=  8'd0;
    else    if(cnt_clk == CNT_CLK_MAX - 1'b1)
        cnt_clk <=  8'd0;
    else
        cnt_clk <=  cnt_clk + 1'b1;

// i2c_clk:i2c����ʱ��
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        i2c_clk <=  1'b1;
    else    if(cnt_clk == CNT_CLK_MAX - 1'b1)
        i2c_clk <=  ~i2c_clk;

// cnt_i2c_clk_en:cnt_i2c_clk������ʹ���ź�
always@(posedge i2c_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cnt_i2c_clk_en  <=  1'b0;
    else    if((state == STOP) && (cnt_bit == 3'd3) &&(cnt_i2c_clk == 3))
        cnt_i2c_clk_en  <=  1'b0;
    else    if(i2c_start == 1'b1)
        cnt_i2c_clk_en  <=  1'b1;

// cnt_i2c_clk:i2c_clkʱ�Ӽ�����,��������cnt_bit�ź�
always@(posedge i2c_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cnt_i2c_clk <=  2'd0;
    else    if(cnt_i2c_clk_en == 1'b1)
        cnt_i2c_clk <=  cnt_i2c_clk + 1'b1;

// cnt_bit:sda���ؼ�����
always@(posedge i2c_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cnt_bit <=  3'd0;
    else    if((state == IDLE) || (state == START_1) || (state == START_2)
                || (state == ACK_1) || (state == ACK_2) || (state == ACK_3)
                || (state == ACK_4) || (state == ACK_5) || (state == N_ACK))
        cnt_bit <=  3'd0;
    else    if((cnt_bit == 3'd7) && (cnt_i2c_clk == 2'd3))
        cnt_bit <=  3'd0;
    else    if((cnt_i2c_clk == 2'd3) && (state != IDLE))
        cnt_bit <=  cnt_bit + 1'b1;

// state:״̬��״̬��ת
always@(posedge i2c_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        state   <=  IDLE;
    else    case(state)
        IDLE:
            if(i2c_start == 1'b1)
                state   <=  START_1;
            else
                state   <=  state;
        START_1:
            if(cnt_i2c_clk == 3)
                state   <=  SEND_D_ADDR;
            else
                state   <=  state;
        SEND_D_ADDR:
            if((cnt_bit == 3'd7) &&(cnt_i2c_clk == 3))
                state   <=  ACK_1;
            else
                state   <=  state;
        ACK_1:
            if((cnt_i2c_clk == 3) && (ack == 1'b0))
                begin
                    if(addr_num == 1'b1)
                        state   <=  SEND_B_ADDR_H;
                    else
                        state   <=  SEND_B_ADDR_L;
                end
             else
                state   <=  state;
        SEND_B_ADDR_H:
            if((cnt_bit == 3'd7) &&(cnt_i2c_clk == 3))
                state   <=  ACK_2;
            else
                state   <=  state;
        ACK_2:
            if((cnt_i2c_clk == 3) && (ack == 1'b0))
                state   <=  SEND_B_ADDR_L;
            else
                state   <=  state;
        SEND_B_ADDR_L:
            if((cnt_bit == 3'd7) && (cnt_i2c_clk == 3))
                state   <=  ACK_3;
            else
                state   <=  state;
        ACK_3:
            if((cnt_i2c_clk == 3) && (ack == 1'b0))
                begin
                    if(wr_en == 1'b1)
                        state   <=  WR_DATA;
                    else    if(rd_en == 1'b1)
                        state   <=  START_2;
                    else
                        state   <=  state;
                end
             else
                state   <=  state;
        WR_DATA:
            if((cnt_bit == 3'd7) &&(cnt_i2c_clk == 3))
                state   <=  ACK_4;
            else
                state   <=  state;
        ACK_4:
            if((cnt_i2c_clk == 3) && (ack == 1'b0))
                state   <=  STOP;
            else
                state   <=  state;
        START_2:
            if(cnt_i2c_clk == 3)
                state   <=  SEND_RD_ADDR;
            else
                state   <=  state;
        SEND_RD_ADDR:
            if((cnt_bit == 3'd7) &&(cnt_i2c_clk == 3))
                state   <=  ACK_5;
            else
                state   <=  state;
        ACK_5:
            if((cnt_i2c_clk == 3) && (ack == 1'b0))
                state   <=  RD_DATA;
            else
                state   <=  state;
        RD_DATA:
            if((cnt_bit == 3'd7) &&(cnt_i2c_clk == 3))
                state   <=  N_ACK;
            else
                state   <=  state;
        N_ACK:
            if(cnt_i2c_clk == 3)
                state   <=  STOP;
            else
                state   <=  state;
        STOP:
            if((cnt_bit == 3'd3) &&(cnt_i2c_clk == 3))
                state   <=  IDLE;
            else
                state   <=  state;
        default:    state   <=  IDLE;
    endcase

// ack:Ӧ���ź�
always@(*)
    case    (state)
        IDLE,START_1,SEND_D_ADDR,SEND_B_ADDR_H,SEND_B_ADDR_L,
        WR_DATA,START_2,SEND_RD_ADDR,RD_DATA,N_ACK:
            ack <=  1'b1;
        ACK_1,ACK_2,ACK_3,ACK_4,ACK_5:
            if(cnt_i2c_clk == 2'd0)
                ack <=  sda_in;//1'b0;//
            else
                ack <=  ack;
        default:    ack <=  1'b1;
    endcase

// i2c_scl:�����i2c�豸�Ĵ���ʱ���ź�scl
always@(*)
    case    (state)
        IDLE:
            i2c_scl <=  1'b1;
        START_1:
            if(cnt_i2c_clk == 2'd3)
                i2c_scl <=  1'b0;
            else
                i2c_scl <=  1'b1;
        SEND_D_ADDR,ACK_1,SEND_B_ADDR_H,ACK_2,SEND_B_ADDR_L,
        ACK_3,WR_DATA,ACK_4,START_2,SEND_RD_ADDR,ACK_5,RD_DATA,N_ACK:
            if((cnt_i2c_clk == 2'd1) || (cnt_i2c_clk == 2'd2))
                i2c_scl <=  1'b1;
            else
                i2c_scl <=  1'b0;
        STOP:
            if((cnt_bit == 3'd0) &&(cnt_i2c_clk == 2'd0))
                i2c_scl <=  1'b0;
            else
                i2c_scl <=  1'b1;
        default:    i2c_scl <=  1'b1;
    endcase

// i2c_sda_reg:sda���ݻ���
always@(*)
    case    (state)
        IDLE:
            begin
                i2c_sda_reg <=  1'b1;
                rd_data_reg <=  8'd0;
            end
        START_1:
            if(cnt_i2c_clk <= 2'd0)
                i2c_sda_reg <=  1'b1;
            else
                i2c_sda_reg <=  1'b0;
        SEND_D_ADDR:
            if(cnt_bit <= 3'd6)
                i2c_sda_reg <=  device_addr_i[6 - cnt_bit];
            else
                i2c_sda_reg <=  1'b0;
        ACK_1:
            i2c_sda_reg <=  1'b1;
        SEND_B_ADDR_H:
            i2c_sda_reg <=  byte_addr[15 - cnt_bit];
        ACK_2:
            i2c_sda_reg <=  1'b1;
        SEND_B_ADDR_L:
            i2c_sda_reg <=  byte_addr[7 - cnt_bit];
        ACK_3:
            i2c_sda_reg <=  1'b1;
        WR_DATA:
            i2c_sda_reg <=  wr_data[7 - cnt_bit];
        ACK_4:
            i2c_sda_reg <=  1'b1;
        START_2:
            if(cnt_i2c_clk <= 2'd1)
                i2c_sda_reg <=  1'b1;
            else
                i2c_sda_reg <=  1'b0;
        SEND_RD_ADDR:
            if(cnt_bit <= 3'd6)
                i2c_sda_reg <=  device_addr_i[6 - cnt_bit];
            else
                i2c_sda_reg <=  1'b1;
        ACK_5:
            i2c_sda_reg <=  1'b1;
        RD_DATA:
            if(cnt_i2c_clk  == 2'd2)
                rd_data_reg[7 - cnt_bit]    <=  sda_in;
            else
                rd_data_reg <=  rd_data_reg;
        N_ACK:
            i2c_sda_reg <=  1'b1;
        STOP:
            if((cnt_bit == 3'd0) && (cnt_i2c_clk < 2'd3))
                i2c_sda_reg <=  1'b0;
            else
                i2c_sda_reg <=  1'b1;
        default:
            begin
                i2c_sda_reg <=  1'b1;
                rd_data_reg <=  rd_data_reg;
            end
    endcase

// rd_data:��i2c�豸��������
always@(posedge i2c_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        rd_data <=  8'd0;
    else    if((state == RD_DATA) && (cnt_bit == 3'd7) && (cnt_i2c_clk == 2'd3))
        rd_data <=  rd_data_reg;

// i2c_end:һ�ζ�/д�����ź�
always@(posedge i2c_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        i2c_end <=  1'b0;
    else    if((state == STOP) && (cnt_bit == 3'd3) &&(cnt_i2c_clk == 3))
        i2c_end <=  1'b1;
    else
        i2c_end <=  1'b0;

// sda_in:sda�������ݼĴ�
assign  sda_in = i2c_sda;
// sda_en:sda����д��ʹ���ź�
assign  sda_en = ((state == RD_DATA) || (state == ACK_1) || (state == ACK_2)
                    || (state == ACK_3) || (state == ACK_4) || (state == ACK_5))
                    ? 1'b0 : 1'b1;
// i2c_sda:�����i2c�豸�Ĵ��������ź�sda
assign  i2c_sda = (sda_en == 1'b1) ? i2c_sda_reg : 1'bz;

endmodule
