`include "header.svh"

module pageInit(
    input logic clk, prog_clk, rst,
    input UserInput user_in,
    output ProgramOutput init_out
);
    localparam RIGHT = `RIGHT;
    ScreenText text = '{default: '0};
    TopState state;
    always @(posedge prog_clk) begin
        if (rst) begin
            state <= INIT;
            text[14] <= "            Welcome!            ";
            text[16] <= "  Press any key to continue...  ";
        end
        else if (state == INIT && user_in.arrow_keys != 4'b0000)
            state <= MENU;
    end
    assign init_out.text = text;
    assign init_out.state = state;
    assign init_out.seg = "12345678";
endmodule