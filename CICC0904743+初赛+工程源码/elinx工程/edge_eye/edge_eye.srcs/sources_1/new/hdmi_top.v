`timescale 1 ps/ 1 ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 05-16-2025 22:35:16
// Design Name:
// Module Name: hdmi_top
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

module hdmi_top
(
// system
    input   wire            sys_clk         ,   //sclk = 50MHz
    input   wire            sys_rst_n       ,   //reset: active low
// vga
    input   wire            vga_clk         ,   //vga clk = 75MHz 
    input   wire    [15:0]  pix_data        ,   

    output  wire            pix_data_req    ,
    output  wire            hsync           ,   
    output  wire            vsync           ,   
    output  wire            de              ,
    output  wire    [15:0]  rgb             ,
// hdmi
    output  wire            cfg_done        ,   
    output  wire            sccb_scl        ,   //SCL
    inout   wire            sccb_sda            //SDA

);


//------------- vga_ctrl_inst -------------
vga_ctrl        vga_ctrl_inst
(
// vga/hdmi
    .vga_clk            (vga_clk        ),   //vga clk = 75MHz
    .sys_rst_n          (sys_rst_n      ),   
    .pix_data           (pix_data	    ),   //pixel data               [15:0]
// vga/hdmi
    .pix_data_req       (pix_data_req   ),   
    .hsync              (hsync          ),   
    .vsync              (vsync          ),   
    .de                 (de             ),
    .rgb                (rgb            )    //output rgb info          [15:0]
);


hdmi_i2c        hdmi_i2c_inst(
    .sys_clk            (sys_clk        ),  
    .sys_rst_n          (sys_rst_n      ),  

    .cfg_done           (cfg_done       ),  //hdmi configuration done
    .sccb_scl           (sccb_scl       ),  //SCL
    .sccb_sda           (sccb_sda       )   //SDA
);

endmodule