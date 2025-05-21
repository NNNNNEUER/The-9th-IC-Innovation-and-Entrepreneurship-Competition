`timescale 1 ps/ 1 ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 05-14-2025 02:43:27
// Design Name:
// Module Name: Boxing
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

module  fifo_ctrl
(
    input   wire            sys_clk         ,   //ϵͳʱ��
    input   wire            sys_rst_n       ,   //��λ�ź�
//дfifo�ź�
    input   wire            wr_fifo_wr_clk  ,   //дFIFOдʱ��
    input   wire            wr_fifo_wr_req  ,   //дFIFOд����
    input   wire    [15:0]  wr_fifo_wr_data ,   //дFIFOд����
    input   wire    [23:0]  sdram_wr_b_addr ,   //дSDRAM�׵�ַ
    input   wire    [23:0]  sdram_wr_e_addr ,   //дSDRAMĩ��ַ
    input   wire    [9:0]   wr_burst_len    ,   //дSDRAM����ͻ������
    input   wire            wr_rst          ,   //д��λ�ź�
//��fifo�ź�
    input   wire            rd_fifo_rd_clk  ,   //��FIFO��ʱ��
    input   wire            rd_fifo_rd_req  ,   //��FIFO������
    input   wire    [23:0]  sdram_rd_b_addr ,   //��SDRAM�׵�ַ
    input   wire    [23:0]  sdram_rd_e_addr ,   //��SDRAMĩ��ַ
    input   wire    [9:0]   rd_burst_len    ,   //��SDRAM����ͻ������
    input   wire            rd_rst          ,   //����λ�ź�
    output  wire    [15:0]  rd_fifo_rd_data ,   //��FIFO������
    output  wire    [9:0]   rd_fifo_num     ,   //��fifo�е�������

    input   wire            read_valid      ,   //SDRAM��ʹ��
    input   wire            init_end        ,   //SDRAM��ʼ����ɱ�־
    input   wire            pingpang_en     ,   //SDRAMƹ�Ҳ���ʹ��
//SDRAMд�ź�
    input   wire            sdram_wr_ack    ,   //SDRAMд��Ӧ
    output  reg             sdram_wr_req    ,   //SDRAMд����
    output  reg     [23:0]  sdram_wr_addr   ,   //SDRAMд��ַ
    output  wire    [15:0]  sdram_data_in   ,   //д��SDRAM������
//SDRAM���ź�
    input   wire            sdram_rd_ack    ,   //SDRAM����Ӧ
    input   wire    [15:0]  sdram_data_out  ,   //����SDRAM����
    output  reg             sdram_rd_req    ,   //SDRAM������
    output  reg     [23:0]  sdram_rd_addr       //SDRAM����ַ
);

//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//

//wire define
wire            wr_ack_fall ;   //д��Ӧ�ź��½���
wire            rd_ack_fall ;   //����Ӧ�ź��½���
wire    [9:0]   wr_fifo_num ;   //дfifo�е�������

//reg define
reg        wr_ack_dly       ;   //д��Ӧ����
reg        rd_ack_dly       ;   //����Ӧ����
reg        bank_en          ;   //Bank�л�ʹ���ź�
reg        bank_flag        ;   //Bank�ĵ�ַ�л���־

//********************************************************************//
//***************************** Main Code ****************************//
//********************************************************************//

//wr_ack_dly:д��Ӧ�źŴ���
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        wr_ack_dly  <=  1'b0;
    else
        wr_ack_dly  <=  sdram_wr_ack;

//rd_ack_dly:����Ӧ�źŴ���
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        rd_ack_dly  <=  1'b0;
    else
        rd_ack_dly <=  sdram_rd_ack;


//wr_ack_fall,rd_ack_fall:����д��Ӧ�ź��½���
assign  wr_ack_fall = (wr_ack_dly & ~sdram_wr_ack);
assign  rd_ack_fall = (rd_ack_dly & ~sdram_rd_ack);

//bank_en,bank_flag:BANK�л�ʹ��,��дBank��־
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        begin
            bank_en     <=  1'b0;
            bank_flag   <=  1'b0;
        end
    else    if((wr_ack_fall == 1'b1) && (pingpang_en ==1'b1))
        begin
            if(sdram_wr_addr[21:0] < (sdram_wr_e_addr - wr_burst_len))
                begin
                    bank_en     <=  bank_en;
                    bank_flag   <=  bank_flag;
                end
            else
                begin
                    bank_flag   <=  ~bank_flag;
                    bank_en     <=  1'b1;
                end
        end
    else    if(bank_en == 1'b1)
        begin
            bank_en  <=  1'b0;
            bank_flag   <=  bank_flag;
        end

//sdram_wr_addr:sdramд��ַ
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        sdram_wr_addr   <=  24'd0;
    else    if(wr_rst == 1'b1)
        sdram_wr_addr   <=  sdram_wr_b_addr;
    else    if(wr_ack_fall == 1'b1) //һ��ͻ��д����,����д��ַ
        begin
            if((pingpang_en ==1'b1) && (sdram_wr_addr[21:0] < (sdram_wr_e_addr - wr_burst_len)))
                                    //ʹ��ƹ�Ҳ���,д��ַδ�ﵽĩ��ַ,д��ַ�ۼ�
                sdram_wr_addr   <=  sdram_wr_addr + wr_burst_len;
            else    if(sdram_wr_addr < (sdram_wr_e_addr - wr_burst_len))
                        //��ʹ��ƹ�Ҳ���,һ��ͻ��д����,����д��ַ,δ�ﵽĩ��ַ,д��ַ�ۼ�
                sdram_wr_addr   <=  sdram_wr_addr + wr_burst_len;
            else        //��ʹ��ƹ�Ҳ���,����ĩ��ַ,�ص�д��ʼ��ַ
                sdram_wr_addr   <=  sdram_wr_b_addr;
        end
    else    if(bank_en == 1'b1)      //�л�Bankʹ���ź���Ч
        begin
            if(bank_flag == 1'b0)    //�л�Bank��ַ
                sdram_wr_addr   <=  {2'b00,sdram_wr_b_addr[21:0]};
            else
                sdram_wr_addr   <=  {2'b01,sdram_wr_b_addr[21:0]};
        end

//sdram_rd_addr:sdram����ַ
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        sdram_rd_addr   <=  24'd0;
    else    if(rd_rst == 1'b1)
        sdram_rd_addr   <=  sdram_rd_b_addr;
    else    if(rd_ack_fall == 1'b1) //һ��ͻ��������,���Ķ���ַ
        begin
            if(pingpang_en == 1'b1) //ʹ��ƹ�Ҳ���,����ַδ�ﵽĩ��ַ,����ַ�ۼ�
                begin
                    if(sdram_rd_addr[21:0] < (sdram_rd_e_addr - rd_burst_len))
                        sdram_rd_addr   <=  sdram_rd_addr + rd_burst_len;
                    else
                        begin
                            if(bank_flag == 1'b0)    //�л�Bank��ַ
                                sdram_rd_addr   <=  {2'b01,sdram_rd_b_addr[21:0]};
                            else
                                sdram_rd_addr   <=  {2'b00,sdram_rd_b_addr[21:0]};
                        end
                end
            else    if(sdram_rd_addr < (sdram_rd_e_addr - rd_burst_len))
                    //��ʹ��ƹ�Ҳ���,����ַδ�ﵽĩ��ַ,����ַ�ۼ�
                sdram_rd_addr   <=  sdram_rd_addr + rd_burst_len;
            else    //����ĩ��ַ,�ص��׵�ַ
                sdram_rd_addr   <=  sdram_rd_b_addr;
        end

//sdram_wr_req,sdram_rd_req:��д�����ź�
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        begin
            sdram_wr_req    <=  1'b0;
            sdram_rd_req    <=  1'b0;
        end
    else    if(init_end == 1'b1)   //��ʼ����ɺ���Ӧ��д����
        begin   //����ִ��д��������ֹд��SDRAM�е����ݶ�ʧ
            if(wr_fifo_num >= wr_burst_len)
                begin   //дFIFO�е��������ﵽдͻ������
                    sdram_wr_req    <=  1'b1;   //д������Ч
                    sdram_rd_req    <=  1'b0;
                end
            else    if((rd_fifo_num < rd_burst_len) && (read_valid == 1'b1))
                begin //��FIFO�е�������С�ڶ�ͻ������,�Ҷ�ʹ���ź���Ч
                    sdram_wr_req    <=  1'b0;
                    sdram_rd_req    <=  1'b1;   //��������Ч
                end
            else
                begin
                    sdram_wr_req    <=  1'b0;
                    sdram_rd_req    <=  1'b0;
                end
        end
    else
        begin
            sdram_wr_req    <=  1'b0;
            sdram_rd_req    <=  1'b0;
        end

//********************************************************************//
//*************************** Instantiation **************************//
//********************************************************************//

//------------- wr_fifo_data -------------
fifo_data   wr_fifo_data(
    //�û��ӿ�
    .wrclk      (wr_fifo_wr_clk ),  //дʱ��
    .wrreq      (wr_fifo_wr_req ),  //д����
    .data       (wr_fifo_wr_data),  //д����
    //SDRAM�ӿ�
    .rdclk      (sys_clk        ),  //��ʱ��
    .rdreq      (sdram_wr_ack   ),  //������
    .q          (sdram_data_in  ),  //������

    .rdusedw    (wr_fifo_num    ),  //FIFO�е�������
    .wrusedw    (               ),
    .aclr       (~sys_rst_n || wr_rst)  //�����ź�
    );

//------------- rd_fifo_data -------------
fifo_data   rd_fifo_data(
    //sdram�ӿ�
    .wrclk      (sys_clk        ),  //дʱ��
    .wrreq      (sdram_rd_ack   ),  //д����
    .data       (sdram_data_out ),  //д����
    //�û��ӿ�
    .rdclk      (rd_fifo_rd_clk ),  //��ʱ��
    .rdreq      (rd_fifo_rd_req ),  //������
    .q          (rd_fifo_rd_data),  //������

    .rdusedw    (               ),
    .wrusedw    (rd_fifo_num    ),  //FIFO�е�������
    .aclr       (~sys_rst_n || rd_rst)  //�����ź�
    );

endmodule
