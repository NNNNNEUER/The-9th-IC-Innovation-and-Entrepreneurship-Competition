`timescale 1 ps/ 1 ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 05-19-2025 01:39:18
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


module Boxing #(
    parameter	[11:0]	IMG_Width = 12'd1280,	//640*480
    parameter	[11:0]	IMG_High  = 12'd720
)(
    //global clock
    input			clk,  				//cmos video pixel clock
    input			rst_n,				//global reset
    //Image data prepred to be processd
    input			per_frame_vsync,	// ׼��ͼ�����ݳ���Ч�ź�
    input			per_frame_href,		// ׼��ͼ����������Ч�ź�
    input			per_frame_clken,	// ׼��ͼ���������/����ʹ��ʱ��
    input			per_img_Y,			// ׼��ͼ���������� �Ҷ�ֵ
    input          	cmos_frame_clken,	// CMOS ʱ��ʹ���ź�               
    input			cmos_frame_vsync,	// CMOS ֡��Ч�ź�
    input          	cmos_frame_href,	// CMOS ����Ч�ź�    
    input	[15:0]	cmos_frame_data,    // CMOS ��������
    
    //Image data has been processd
    output			post_frame_vsync,	//Processed Image data vsync valid signal
    output			post_frame_href,	//Processed Image data href vaild  signal
    output			post_frame_clken,	//Processed Image data output/capture enable clock
    output	[15:0]  post_img_Y			//Processed Image brightness output
	//output reg      box_exist
);

reg [11:0] edg_up	;		// = 160;
reg [11:0] edg_down	;		// = 240;
reg	[11:0] edg_left	;		// = 160;
reg	[11:0] edg_right ;		// = 240;
reg [11:0] edg_up_d1     ;
reg	[11:0] edg_down_d1   ;
reg	[11:0] edg_left_d1   ;
reg	[11:0] edg_right_d1  ;
reg per_frame_href_r    	;	// ׼��ͼ����������Ч�ź�
reg per_frame_vsync_r   	;	// ׼��ͼ�����ݳ���Ч�ź�
reg per_frame_clken_r		;	// ׼��ͼ���������/����ʹ��ʱ��
reg per_img_data_r			;	// ׼��ͼ����������
reg [11:0]	h_cnt			;	// ˮƽ����
reg [11:0]	v_cnt			;	// ��ֱ����
reg [15:0]	post_cmos_data	;	// �������CMOS����
reg cmos_frame_clken_r;	               
reg cmos_frame_vsync_r;	
reg cmos_frame_href_r;

wire valid_en = 1'b1;		// ��Чʹ���ź�
wire href_falling;			// ����Ч�½���
wire vsync_rising;			// ����Ч������
wire vsync_falling;			// ����Ч�½���

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
           per_frame_href_r	<= 1'd0;
           per_frame_vsync_r	<= 1'd0;
        per_frame_clken_r 	<= 1'b0;
           per_img_data_r 		<= 1'd0;
       end else begin
           per_frame_href_r	<= per_frame_href; 
           per_frame_vsync_r	<= per_frame_vsync; 
           per_img_data_r 		<= per_img_Y;
        per_frame_clken_r 	<= per_frame_clken;
     end
end 
 
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        cmos_frame_href_r  <= 1'd0;
        cmos_frame_vsync_r <= 1'd0;
        cmos_frame_clken_r <= 1'b0;
    end else begin
        cmos_frame_href_r  <= cmos_frame_href;
        cmos_frame_vsync_r <= cmos_frame_vsync;
        cmos_frame_clken_r <= cmos_frame_clken;
    end 
end

// href counter
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        h_cnt <=12'd0;
    end else if(per_frame_href)begin
        if(per_frame_clken) begin
            h_cnt <=h_cnt+1'b1;
        end else begin
            h_cnt <=h_cnt;
        end 
    end else begin
        h_cnt <=12'd0;
    end 
end

// vsync counter
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        v_cnt <=12'd0;
    end else if(per_frame_vsync)begin 
        if(href_falling) begin
            v_cnt <=v_cnt+1'b1;
        end else begin
            v_cnt <=v_cnt;
        end 
    end else begin
        v_cnt <=12'd0;
    end
end
 

// 
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        edg_up    <=  12'd719;
        edg_down  <=  12'd0;
        edg_left  <=  12'd1279;
        edg_right <=  12'd0;
    end else if(vsync_rising) begin
        edg_up    <=  12'd719;
        edg_down  <=  12'd0;
        edg_left  <=  12'd1279;
        edg_right <=  12'd0;
    end else if(per_frame_clken & per_frame_href) begin
        if(per_img_Y == 1'b1) begin
            if(edg_up > v_cnt) begin
                edg_up  <=v_cnt ;
            end else begin
                edg_up  <=edg_up ;	
            end

            if(edg_down < v_cnt) begin
                edg_down  <=v_cnt ;
            end else begin
                edg_down  <= edg_down ;	
            end
             
            if(edg_left > h_cnt) begin
                edg_left  <= h_cnt ;
            end else begin
                edg_left  <= edg_left ;	
            end

            if(edg_right < h_cnt) begin
                edg_right  <=h_cnt ;
            end else begin
                edg_right  <=edg_right ;
            end			 
        end else begin
            edg_up    <=  edg_up;
            edg_down  <=  edg_down;
            edg_left  <=  edg_left;
            edg_right <=  edg_right;
        end
    end
end 
 
always@(posedge clk or negedge rst_n)
begin 
   if(!rst_n) begin
      edg_up_d1    <=  12'd360;
      edg_down_d1  <=  12'd640;
      edg_left_d1  <=  12'd360;
      edg_right_d1 <=  12'd640;
     end
     else if(vsync_falling) begin
       edg_up_d1    <=  edg_up   ;
      edg_down_d1  <=  edg_down ;
      edg_left_d1  <=  edg_left ;
      edg_right_d1 <=  edg_right;
    end
end 
 
always@(posedge  clk or negedge rst_n) begin
    if(~rst_n) begin
        post_cmos_data <= 16'd0; 
    end else if(cmos_frame_vsync) begin 
        if(~(cmos_frame_href & cmos_frame_clken)) begin
            post_cmos_data <= 16'd0;
        end else if(valid_en &&
          ((((( h_cnt >=edg_left_d1)&&(h_cnt <=edg_left_d1+2))||(( h_cnt >=edg_right_d1))&&(h_cnt <=edg_right_d1+2)))&&(v_cnt >=edg_up_d1 && v_cnt <= edg_down_d1))
         ||(((( v_cnt >=edg_up_d1)&&(v_cnt <=edg_up_d1+2))||(( v_cnt >=edg_down_d1)&&(v_cnt <=edg_down_d1+2)))&&(h_cnt >= edg_left_d1 && h_cnt <= edg_right_d1))) begin
            post_cmos_data <={5'b11111,6'd0,5'd0};
        
        end else begin
            post_cmos_data <= cmos_frame_data;
        end 
        
    end else begin
        post_cmos_data <= post_cmos_data;
    end       
end
//always @(posedge clk) begin
//    if (vsync_falling) begin
//        if ((edg_right > edg_left) && (edg_down > edg_up)) begin
//            box_exist <= 1'b1;
//        end else begin
//            box_exist <= 1'b0;
//        end
//    end
//end


assign     vsync_rising    =(~per_frame_vsync_r) & per_frame_vsync ?1'b1:1'b0;
assign     vsync_falling   = per_frame_vsync_r & (~per_frame_vsync)? 1'b1:1'b0;
assign     href_falling    = per_frame_href_r & (~per_frame_href)?1'b1:1'b0;

assign post_frame_vsync  = cmos_frame_vsync_r;
assign post_frame_href   = cmos_frame_href_r;
assign post_frame_clken  = cmos_frame_clken_r;

assign post_img_Y =post_cmos_data;

endmodule
