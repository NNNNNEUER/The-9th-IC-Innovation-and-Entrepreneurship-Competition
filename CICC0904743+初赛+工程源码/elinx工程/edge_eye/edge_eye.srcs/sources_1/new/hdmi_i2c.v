`timescale 1 ps/ 1 ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 05-16-2025 22:43:21
// Design Name:
// Module Name: hdmi_i2c
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

module hdmi_i2c
(
    input   wire            sys_clk         ,   
    input   wire            sys_rst_n       ,   

    output  wire            cfg_done        ,   
    output  wire            sccb_scl        ,   
    inout   wire            sccb_sda           
);
    
    
//parameter define
parameter       BIT_CTRL   =  1'b0         ; 
parameter       CLK_FREQ   = 26'd25_000_000; 
parameter       I2C_FREQ   = 18'd250_000   ; 

//wire  define
wire            cfg_end     ;
wire            cfg_start   ;
wire    [31:0]  cfg_data    ;
wire            cfg_clk     ;

hdmi_i2c_ctrl#(
    .SYS_CLK_FREQ   (CLK_FREQ       ),  
    .SCL_FREQ       (I2C_FREQ       )   
)hdmi_i2c_ctrl_inst(
    .sys_clk        (sys_clk        ),   
    .sys_rst_n      (sys_rst_n      ),   
    .wr_en          (1'b1           ),   
    .rd_en          (               ),   
    .i2c_start      (cfg_start      ),   
    .addr_num       (BIT_CTRL       ),   
    .device_addr    (cfg_data[31:24]),
    .byte_addr      (cfg_data[23: 8]),   
    .wr_data        (cfg_data[ 7:0] ),   

    .rd_data        (               ),   
    .i2c_end        (cfg_end        ),   
    .i2c_clk        (cfg_clk        ),   
    .i2c_scl        (sccb_scl       ),   
    .i2c_sda        (sccb_sda       )    
);

//------------- hdmi_cfg_inst -------------
hdmi_cfg  hdmi_cfg_inst
(
    .sys_clk        (cfg_clk        ),   
    .sys_rst_n      (sys_rst_n      ),   
    .cfg_end        (cfg_end        ),   

    .cfg_start      (cfg_start      ),   
    .cfg_data       (cfg_data       ),   
    .cfg_done       (cfg_done       )    
);

endmodule