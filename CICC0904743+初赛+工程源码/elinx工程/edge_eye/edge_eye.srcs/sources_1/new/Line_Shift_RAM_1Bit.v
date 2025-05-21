`timescale 1 ps/ 1 ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 05-19-2025 01:11:36
// Design Name:
// Module Name: Line_Shift_RAM_1Bit
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


module Line_Shift_RAM_1Bit (
    input               clock,      // pixel clock
    input               clken,      // enable signal
    input               shiftin,    // current line pixel input (row3_data)
    output              taps0x,     // row2_data
    output              taps1x,     // row1_data
    output              shiftout    // unused in this case
);

parameter IMG_HDISP = 1280;         // Horizontal resolution (pixels per line)

// Two line buffers (as shift registers)
reg [IMG_HDISP-1:0] line_buffer1 = 0;  // Latest completed line (row2)
reg [IMG_HDISP-1:0] line_buffer2 = 0;  // One line before that (row1)

reg [$clog2(IMG_HDISP)-1:0] write_ptr = 0;  // pixel column pointer

// Outputs from current columns
assign taps0x = line_buffer1[IMG_HDISP-1];  // Most significant bit is the oldest pixel
assign taps1x = line_buffer2[IMG_HDISP-1];
assign shiftout = 1'b0; // Not used in this module

always @(posedge clock) begin
    if (clken) begin
        // Shift buffers left and insert new pixel
        line_buffer2 <= {line_buffer2[IMG_HDISP-2:0], line_buffer1[IMG_HDISP-1]};
        line_buffer1 <= {line_buffer1[IMG_HDISP-2:0], shiftin};
    end
end

endmodule

