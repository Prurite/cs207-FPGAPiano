
/* https://github.com/Derek-X-Wang/VGA-Text-Generator/blob/master/VGA-Text-Generator.srcs/sources_1/new/Pixel_On_Text2.vhd

 * Pixel_On_Text2 determines if the current pixel is on text and make it easiler to call from verilog
 * param:
 *   display text
 * input: 
 *   VGA clock(the clk you used to update VGA)
 *   top left corner of the text area -- positionX, positionY
 *   current X and Y position
 * output:
 *   a bit that represent whether is the pixel in text
 */
`include "header.svh"

module Pixel_On_Text2_sv #(
) (
    input logic clk,
    input ScreenText displayText,
    input int positionX,
    input int positionY,
    input int horzCoord,
    input int vertCoord,
    output logic pixel
);

    localparam int FONT_WIDTH = 8;  // Assuming a specific font width
    localparam int FONT_HEIGHT = 16; // Assuming a specific font height

    int fontAddress;
    logic [FONT_WIDTH-1:0] charBitInRow;
    int charCode;
    int charRow, charCol, charPosition, bitPosition;
    int lineBase;

    // Instantiate the Font ROM (assumed to be a SystemVerilog module or an imported VHDL entity)
    Font_Rom fontRom (
        .clk(clk),
        .addr(fontAddress),
        .fontRow(charBitInRow)
    );

    always_ff @(posedge clk) begin
        charRow = (vertCoord - positionY) / FONT_HEIGHT;
        charCol = (horzCoord - positionX) / FONT_WIDTH;
        bitPosition = (horzCoord - positionX) % FONT_WIDTH;

        charCode = displayText[charRow][charCol*8 + 8 - 1 +: 8];

        // Calculating the font address based on the character and its position
        lineBase = charRow * FONT_HEIGHT + positionY;
        fontAddress = charCode * 16 + (vertCoord - lineBase);

        // Resetting the pixel output
        pixel = 0;

        // Check if the current pixel is within the horizontal and vertical range of the text
        if (horzCoord >= positionX && horzCoord < positionX + FONT_WIDTH * `SCREEN_TEXT_WIDTH) begin
            if (vertCoord >= positionY && vertCoord < positionY + FONT_HEIGHT * `SCREEN_TEXT_HEIGHT) begin
                // Checking if the pixel is on for the text
                if (charBitInRow[FONT_WIDTH - 1 - bitPosition]) begin
                    pixel = 1;
                end
            end
        end
    end

endmodule
