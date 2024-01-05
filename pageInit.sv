`include "header.svh"

module pageInit(
    input logic clk, prog_clk, rst,
    input UserInput user_in,
    output ProgramOutput init_out
);
    ScreenText text = '{default: '0};
    TopState state;
    always @(posedge prog_clk) begin
        if (rst) begin
            state <= INIT;
            text[14] <= "            Welcome!            ";
            text[16] <= "    Press [>] to continue...    ";
        end
        else if (state == INIT && user_in.arrow_keys == 4'b0001)
            state <= MENU;
    end
    assign init_out.text = text;
    assign init_out.state = state;
endmodule