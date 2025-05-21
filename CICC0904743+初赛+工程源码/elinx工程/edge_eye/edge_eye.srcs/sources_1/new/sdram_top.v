`timescale 1 ps/ 1 ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 05-13-2025 11:56:18
// Design Name:
// Module Name: sdram_top
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


module  sdram_top
(
    input   wire            sys_clk         ,   //ϵͳʱ��
    input   wire            clk_out         ,   //��λƫ��ʱ��
    input   wire            sys_rst_n       ,   //��λ�ź�,����Ч
//дFIFO�ź�
    input   wire            wr_fifo_wr_clk  ,   //дFIFOдʱ��
    input   wire            wr_fifo_wr_req  ,   //дFIFOд����
    input   wire    [15:0]  wr_fifo_wr_data ,   //дFIFOд����
    input   wire    [23:0]  sdram_wr_b_addr ,   //дSDRAM�׵�ַ
    input   wire    [23:0]  sdram_wr_e_addr ,   //дSDRAMĩ��ַ
    input   wire    [9:0]   wr_burst_len    ,   //дSDRAM����ͻ������
    input   wire            wr_rst          ,   //д��λ�ź�
//��FIFO�ź�
    input   wire            rd_fifo_rd_clk  ,   //��FIFO��ʱ��
    input   wire            rd_fifo_rd_req  ,   //��FIFO������
    input   wire    [23:0]  sdram_rd_b_addr ,   //��SDRAM�׵�ַ
    input   wire    [23:0]  sdram_rd_e_addr ,   //��SDRAMĩ��ַ
    input   wire    [9:0]   rd_burst_len    ,   //��SDRAM����ͻ������
    input   wire            rd_rst          ,   //����λ�ź�
    output  wire    [15:0]  rd_fifo_rd_data ,   //��FIFO������
    output  wire    [9:0]   rd_fifo_num     ,   //��fifo�е�������

    input   wire            read_valid      ,   //SDRAM��ʹ��
    input   wire            pingpang_en     ,   //SDRAMƹ�Ҳ���ʹ��
    output  wire            init_end        ,   //SDRAM��ʼ����ɱ�־
//SDRAM�ӿ��ź�
    output  wire            sdram_clk       ,   //SDRAMоƬʱ��
    output  wire            sdram_cke       ,   //SDRAMʱ����Ч�ź�
    output  wire            sdram_cs_n      ,   //SDRAMƬѡ�ź�
    output  wire            sdram_ras_n     ,   //SDRAM�е�ַѡͨ����
    output  wire            sdram_cas_n     ,   //SDRAM�е�ַѡͨ����
    output  wire            sdram_we_n      ,   //SDRAMд����λ
    output  wire    [1:0]   sdram_ba        ,   //SDRAM��L-Bank��ַ��
    output  wire    [12:0]  sdram_addr      ,   //SDRAM��ַ����
    inout   wire    [15:0]  sdram_dq            //SDRAM��������
);

//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//

//wire  define
wire            sdram_wr_req    ;   //sdram д����
wire            sdram_wr_ack    ;   //sdram д��Ӧ
wire    [23:0]  sdram_wr_addr   ;   //sdram д��ַ
wire    [15:0]  sdram_data_in   ;   //д��sdram�е�����

wire            sdram_rd_req    ;   //sdram ������
wire            sdram_rd_ack    ;   //sdram ����Ӧ
wire    [23:0]  sdram_rd_addr   ;   //sdram ����ַ
wire    [15:0]  sdram_data_out  ;   //��sdram�ж���������

//sdram_clk:SDRAMоƬʱ��
assign  sdram_clk = clk_out;

//********************************************************************//
//*************************** Instantiation **************************//
//********************************************************************//

//------------- fifo_ctrl_inst -------------
fifo_ctrl   fifo_ctrl_inst(

//system    signal
    .sys_clk        (sys_clk        ),  //SDRAM����ʱ��
    .sys_rst_n      (sys_rst_n      ),  //��λ�ź�
//write fifo signal
    .wr_fifo_wr_clk (wr_fifo_wr_clk ),  //дFIFOдʱ��
    .wr_fifo_wr_req (wr_fifo_wr_req ),  //дFIFOд����
    .wr_fifo_wr_data(wr_fifo_wr_data),  //дFIFOд����
    .sdram_wr_b_addr(sdram_wr_b_addr),  //дSDRAM�׵�ַ
    .sdram_wr_e_addr(sdram_wr_e_addr),  //дSDRAMĩ��ַ
    .wr_burst_len   (wr_burst_len   ),  //дSDRAM����ͻ������
    .wr_rst         (wr_rst         ),  //д�����ź�
//read fifo signal
    .rd_fifo_rd_clk (rd_fifo_rd_clk ),  //��FIFO��ʱ��
    .rd_fifo_rd_req (rd_fifo_rd_req ),  //��FIFO������
    .rd_fifo_rd_data(rd_fifo_rd_data),  //��FIFO������
    .rd_fifo_num    (rd_fifo_num    ),  //��FIFO�е�������
    .sdram_rd_b_addr(sdram_rd_b_addr),  //��SDRAM�׵�ַ
    .sdram_rd_e_addr(sdram_rd_e_addr),  //��SDRAMĩ��ַ
    .rd_burst_len   (rd_burst_len   ),  //��SDRAM����ͻ������
    .rd_rst         (rd_rst         ),  //�������ź�
//USER ctrl signal
    .read_valid     (read_valid     ),  //SDRAM��ʹ��
    .pingpang_en    (pingpang_en    ),  //SDRAMƹ�Ҳ���ʹ��
    .init_end       (init_end       ),  //SDRAM��ʼ����ɱ�־
//SDRAM ctrl of write
    .sdram_wr_ack   (sdram_wr_ack   ),  //SDRAMд��Ӧ
    .sdram_wr_req   (sdram_wr_req   ),  //SDRAMд����
    .sdram_wr_addr  (sdram_wr_addr  ),  //SDRAMд��ַ
    .sdram_data_in  (sdram_data_in  ),  //д��SDRAM������
//SDRAM ctrl of read
    .sdram_rd_ack   (sdram_rd_ack   ),  //SDRAM������
    .sdram_data_out (sdram_data_out ),  //SDRAM����Ӧ
    .sdram_rd_req   (sdram_rd_req   ),  //SDRAM����ַ
    .sdram_rd_addr  (sdram_rd_addr  )  //����SDRAM����

);

//------------- sdram_ctrl_inst -------------
sdram_ctrl  sdram_ctrl_inst(

    .sys_clk        (sys_clk        ),   //ϵͳʱ��
    .sys_rst_n      (sys_rst_n      ),   //��λ�źţ��͵�ƽ��Ч
//SDRAM ������д�˿�
    .sdram_wr_req   (sdram_wr_req   ),   //дSDRAM�����ź�
    .sdram_wr_addr  (sdram_wr_addr  ),   //SDRAMд�����ĵ�ַ
    .wr_burst_len   (wr_burst_len   ),   //дsdramʱ����ͻ������
    .sdram_data_in  (sdram_data_in  ),   //д��SDRAM������
    .sdram_wr_ack   (sdram_wr_ack   ),   //дSDRAM��Ӧ�ź�
//SDRAM ���������˿�
    .sdram_rd_req   (sdram_rd_req   ),  //��SDRAM�����ź�
    .sdram_rd_addr  (sdram_rd_addr  ),  //SDRAMд�����ĵ�ַ
    .rd_burst_len   (rd_burst_len   ),  //��sdramʱ����ͻ������
    .sdram_data_out (sdram_data_out ),  //��SDRAM����������
    .init_end       (init_end       ),  //SDRAM ��ʼ����ɱ�־
    .sdram_rd_ack   (sdram_rd_ack   ),  //��SDRAM��Ӧ�ź�
//FPGA��SDRAMӲ���ӿ�
    .sdram_cke      (sdram_cke      ),  // SDRAM ʱ����Ч�ź�
    .sdram_cs_n     (sdram_cs_n     ),  // SDRAM Ƭѡ�ź�
    .sdram_ras_n    (sdram_ras_n    ),  // SDRAM �е�ַѡͨ����
    .sdram_cas_n    (sdram_cas_n    ),  // SDRAM �е�ַѡͨ����
    .sdram_we_n     (sdram_we_n     ),  // SDRAM д����λ
    .sdram_ba       (sdram_ba       ),  // SDRAM L-Bank��ַ��
    .sdram_addr     (sdram_addr     ),  // SDRAM ��ַ����
    .sdram_dq       (sdram_dq       )   // SDRAM ��������

);

endmodule
