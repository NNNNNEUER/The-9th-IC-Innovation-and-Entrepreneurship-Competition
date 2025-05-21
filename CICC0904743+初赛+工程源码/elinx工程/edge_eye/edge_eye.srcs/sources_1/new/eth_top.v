`timescale 1 ps/ 1 ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 05-18-2025 16:21:07
// Design Name:
// Module Name: eth_top
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


module eth_top
#(
  parameter IMAGE_WIDTH		  = 1280,
  parameter PAYLOAD_DATA_BYTE = 2,
  parameter PAYLOAD_LENGTH    = IMAGE_WIDTH +1,
  
  parameter DST_MAC   = 48'hFF_FF_FF_FF_FF_FF,
  parameter SRC_MAC   = 48'h00_0a_35_01_fe_c0,
  parameter DST_IP    = 32'hc0_a8_00_03,
  parameter SRC_IP    = 32'hc0_a8_00_02,
  parameter DST_PORT  = 16'd6102,
  parameter SRC_PORT  = 16'd5000
)
(
  input                            reset_p          ,

  input                            clk              ,
  input  [PAYLOAD_DATA_BYTE*8-1:0] data_i           ,
  input                            data_valid_i     ,

  input                            eth_txfifo_rd_clk,
 
  output  wire       		gmii_tx_clk,
  output  wire	[7:0] 		gmii_txd,
  output  wire      		gmii_txen
);

  wire            tx_en_pulse;
  wire            tx_done;
  wire            fifo_rd;
  wire   [7:0]    fifo_dout;

eth_tx_ctrl
  #(
    .PAYLOAD_DATA_BYTE (PAYLOAD_DATA_BYTE),
    .PAYLOAD_LENGTH    (PAYLOAD_LENGTH )
  )eth_tx_ctrl_inst
  (
    .reset_p          (reset_p          ),

    .clk              (clk      ),
    .data_i           (data_i),
    .data_valid_i     (data_valid_i ),

    .eth_txfifo_rd_clk(eth_txfifo_rd_clk),
    .tx_en_pulse      (tx_en_pulse      ),
    .tx_done          (tx_done          ),
    .eth_txfifo_rden  (fifo_rd  ),
    .eth_txfifo_dout  (fifo_dout  )
  );
  
  eth_udp_tx_gmii eth_udp_tx_gmii_inst(
    .clk125m      (eth_txfifo_rd_clk     ),
    .reset_p      (reset_p               ),

    .tx_en_pulse  (tx_en_pulse           ),
    .tx_done      (tx_done               ),
    
    .dst_mac      (DST_MAC               ),
    .src_mac      (SRC_MAC               ),
    .dst_ip       (DST_IP                ),
    .src_ip       (SRC_IP                ),
    .dst_port     (DST_PORT              ),
    .src_port     (SRC_PORT              ),
    
    .data_length  (IMAGE_WIDTH*2+2       ),
    
    .payload_req_o(fifo_rd       ),
    .payload_dat_i(fifo_dout             ),

    .gmii_tx_clk  (gmii_tx_clk           ),
    .gmii_txen    (gmii_txen             ),
    .gmii_txd     (gmii_txd              )
  );
  
endmodule
