`timescale 1 ps/ 1 ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 05-13-2025 14:06:23
// Design Name:
// Module Name: sdram_ctrl
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


module  sdram_ctrl
(
    input   wire            sys_clk         ,   //ϵͳʱ��
    input   wire            sys_rst_n       ,   //��λ�źţ��͵�ƽ��Ч
//SDRAMд�˿�
    input   wire            sdram_wr_req    ,   //дSDRAM�����ź�
    input   wire    [23:0]  sdram_wr_addr   ,   //SDRAMд�����ĵ�ַ
    input   wire    [9:0]   wr_burst_len    ,   //дsdramʱ����ͻ������
    input   wire    [15:0]  sdram_data_in   ,   //д��SDRAM������
    output  wire            sdram_wr_ack    ,   //дSDRAM��Ӧ�ź�
//SDRAM���˿�
    input   wire            sdram_rd_req    ,   //��SDRAM�����ź�
    input   wire    [23:0]  sdram_rd_addr   ,   //SDRAM�������ĵ�ַ
    input   wire    [9:0]   rd_burst_len    ,   //��sdramʱ����ͻ������
    output  wire    [15:0]  sdram_data_out  ,   //��SDRAM����������
    output  wire            init_end        ,   //SDRAM ��ʼ����ɱ�־
    output  wire            sdram_rd_ack    ,   //��SDRAM��Ӧ�ź�
//FPGA��SDRAMӲ���ӿ�
    output  wire            sdram_cke       ,   // SDRAM ʱ����Ч�ź�
    output  wire            sdram_cs_n      ,   // SDRAM Ƭѡ�ź�
    output  wire            sdram_ras_n     ,   // SDRAM �е�ַѡͨ
    output  wire            sdram_cas_n     ,   // SDRAM �е�ַѡͨ
    output  wire            sdram_we_n      ,   // SDRAM дʹ��
    output  wire    [1:0]   sdram_ba        ,   // SDRAM Bank��ַ
    output  wire    [12:0]  sdram_addr      ,   // SDRAM ��ַ����
    inout   wire    [15:0]  sdram_dq            // SDRAM ��������
);

//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//

//wire  define
//sdram_init
wire    [3:0]   init_cmd    ;   //��ʼ���׶�д��sdram��ָ��
wire    [1:0]   init_ba     ;   //��ʼ���׶�Bank��ַ
wire    [12:0]  init_addr   ;   //��ʼ���׶ε�ַ����,����Ԥ������
//sdram_a_ref
wire            aref_req    ;   //�Զ�ˢ������
wire            aref_end    ;   //�Զ�ˢ�½�����־
wire    [3:0]   aref_cmd    ;   //�Զ�ˢ�½׶�д��sdram��ָ��
wire    [1:0]   aref_ba     ;   //�Զ�ˢ�½׶�Bank��ַ
wire    [12:0]  aref_addr   ;   //��ַ����,����Ԥ������
wire            aref_en     ;   //�Զ�ˢ��ʹ��
//sdram_write
wire            wr_en       ;   //дʹ��
wire            wr_end      ;   //һ��д�����ź�
wire    [3:0]   write_cmd   ;   //д�׶�����
wire    [1:0]   write_ba    ;   //д���ݽ׶�Bank��ַ
wire    [12:0]  write_addr  ;   //д�׶����ݵ�ַ
wire            wr_sdram_en ;   //SDRAMдʹ��
wire    [15:0]  wr_sdram_data;  //д��SDRAM������
//sdram_read
wire            rd_en       ;   //��ʹ��
wire            rd_end      ;   //һ��ͻ��������
wire    [3:0]   read_cmd    ;   //�����ݽ׶�д��sdram��ָ��
wire    [1:0]   read_ba     ;   //���׶�Bank��ַ
wire    [12:0]  read_addr   ;   //���׶����ݵ�ַ

//********************************************************************//
//*************************** Instantiation **************************//
//********************************************************************//
//------------- sdram_init_inst -------------
sdram_init  sdram_init_inst
(
    .sys_clk    (sys_clk    ),  //ϵͳʱ��,Ƶ��100MHz
    .sys_rst_n  (sys_rst_n  ),  //��λ�ź�,�͵�ƽ��Ч

    .init_cmd   (init_cmd   ),  //��ʼ���׶�д��sdram��ָ��
    .init_ba    (init_ba    ),  //��ʼ���׶�Bank��ַ
    .init_addr  (init_addr  ),  //��ʼ���׶ε�ַ����,����Ԥ������
    .init_end   (init_end   )   //��ʼ�������ź�
);

//------------- sdram_arbit_inst -------------
sdram_arbit sdram_arbit_inst
(
    .sys_clk    (sys_clk        ),  //ϵͳʱ��
    .sys_rst_n  (sys_rst_n      ),  //��λ�ź�
//sdram_init
    .init_cmd   (init_cmd       ),  //��ʼ���׶�����
    .init_end   (init_end       ),  //��ʼ��������־
    .init_ba    (init_ba        ),  //��ʼ���׶�Bank��ַ
    .init_addr  (init_addr      ),  //��ʼ���׶����ݵ�ַ
//sdram_auto_ref
    .aref_req   (aref_req       ),  //��ˢ������
    .aref_end   (aref_end       ),  //��ˢ�½���
    .aref_cmd   (aref_cmd       ),  //��ˢ�½׶�����
    .aref_ba    (aref_ba        ),  //�Զ�ˢ�½׶�Bank��ַ
    .aref_addr  (aref_addr      ),  //��ˢ�½׶����ݵ�ַ
//sdram_write
    .wr_req     (sdram_wr_req   ),  //д��������
    .wr_end     (wr_end         ),  //һ��д�����ź�
    .wr_cmd     (write_cmd      ),  //д�׶�����
    .wr_ba      (write_ba       ),  //д�׶�Bank��ַ
    .wr_addr    (write_addr     ),  //д�׶����ݵ�ַ
    .wr_sdram_en(wr_sdram_en    ),  //SDRAMдʹ��
    .wr_data    (wr_sdram_data  ),  //д��SDRAM������
//sdram_read
    .rd_req     (sdram_rd_req   ),  //����������
    .rd_end     (rd_end         ),  //һ�ζ�����
    .rd_cmd     (read_cmd       ),  //���׶�����
    .rd_addr    (read_addr      ),  //���׶����ݵ�ַ
    .rd_ba      (read_ba        ),  //���׶�Bank��ַ

    .aref_en    (aref_en        ),  //��ˢ��ʹ��
    .wr_en      (wr_en          ),  //д����ʹ��
    .rd_en      (rd_en          ),  //������ʹ��

    .sdram_cke  (sdram_cke      ),  //SDRAMʱ��ʹ��
    .sdram_cs_n (sdram_cs_n     ),  //SDRAMƬѡ�ź�
    .sdram_ras_n(sdram_ras_n    ),  //SDRAM�е�ַѡͨ
    .sdram_cas_n(sdram_cas_n    ),  //SDRAM�е�ַѡͨ
    .sdram_we_n (sdram_we_n     ),  //SDRAMдʹ��
    .sdram_ba   (sdram_ba       ),  //SDRAM Bank��ַ
    .sdram_addr (sdram_addr     ),  //SDRAM��ַ����
    .sdram_dq   (sdram_dq       )   //SDRAM��������
);

//------------- sdram_a_ref_inst -------------
sdram_a_ref sdram_a_ref_inst
(
    .sys_clk     (sys_clk   ),  //ϵͳʱ��,Ƶ��100MHz
    .sys_rst_n   (sys_rst_n ),  //��λ�ź�,�͵�ƽ��Ч
    .init_end    (init_end  ),  //��ʼ�������ź�
    .aref_en     (aref_en   ),  //�Զ�ˢ��ʹ��

    .aref_req    (aref_req  ),  //�Զ�ˢ������
    .aref_cmd    (aref_cmd  ),  //�Զ�ˢ�½׶�д��sdram��ָ��
    .aref_ba     (aref_ba   ),  //�Զ�ˢ�½׶�Bank��ַ
    .aref_addr   (aref_addr ),  //��ַ����,����Ԥ������
    .aref_end    (aref_end  )   //�Զ�ˢ�½�����־
);

//------------- sdram_write_inst -------------
sdram_write sdram_write_inst
(
    .sys_clk        (sys_clk        ),  //ϵͳʱ��,Ƶ��100MHz
    .sys_rst_n      (sys_rst_n      ),  //��λ�ź�,�͵�ƽ��Ч
    .init_end       (init_end       ),  //��ʼ�������ź�
    .wr_en          (wr_en          ),  //дʹ��

    .wr_addr        (sdram_wr_addr  ),  //дSDRAM��ַ
    .wr_data        (sdram_data_in  ),  //��д��SDRAM������(дFIFO����)
    .wr_burst_len   (wr_burst_len   ),  //дͻ��SDRAM�ֽ���

    .wr_ack         (sdram_wr_ack   ),  //дSDRAM��Ӧ�ź�
    .wr_end         (wr_end         ),  //һ��ͻ��д����
    .write_cmd      (write_cmd      ),  //д���ݽ׶�д��sdram��ָ��
    .write_ba       (write_ba       ),  //д���ݽ׶�Bank��ַ
    .write_addr     (write_addr     ),  //��ַ����,����Ԥ������
    .wr_sdram_en    (wr_sdram_en    ),  //�����������ʹ��
    .wr_sdram_data  (wr_sdram_data  )   //д��SDRAM������
);

//------------- sdram_read_inst -------------
sdram_read  sdram_read_inst
(
    .sys_clk        (sys_clk        ),  //ϵͳʱ��,Ƶ��100MHz
    .sys_rst_n      (sys_rst_n      ),  //��λ�ź�,�͵�ƽ��Ч
    .init_end       (init_end       ),  //��ʼ�������ź�
    .rd_en          (rd_en          ),  //��ʹ��

    .rd_addr        (sdram_rd_addr  ),  //��SDRAM��ַ
    .rd_data        (sdram_dq       ),  //��SDRAM�ж���������
    .rd_burst_len   (rd_burst_len   ),  //��ͻ��SDRAM�ֽ���

    .rd_ack         (sdram_rd_ack   ),  //��SDRAM��Ӧ�ź�
    .rd_end         (rd_end         ),  //һ��ͻ��������
    .read_cmd       (read_cmd       ),  //�����ݽ׶�д��sdram��ָ��
    .read_ba        (read_ba        ),  //�����ݽ׶�Bank��ַ
    .read_addr      (read_addr      ),  //��ַ����,����Ԥ������
    .rd_sdram_data  (sdram_data_out )   //SDRAM����������
);

endmodule

