`include "header.svh"

module pageInit(
    input logic clk, prog_clk, rst,
    input UserInput user_in,
    output ProgramOutput init_out
);
    localparam RIGHT = `RIGHT;
    ScreenText text;
    TopState state;
    always @(posedge prog_clk) begin
        if (rst) begin
            state <= INIT;
            text[14] <= "            Welcome!            ";
            text[16] <= "  Press [>] to continue...  ";
        end else if (state == INIT && user_in.arrow_keys == RIGHT)
            state <= MENU;
    end
    assign text[18][0 +: 8] = user_in.arrow_keys == `UP ? " " : "^";
    assign text[18][8 +: 8] = user_in.arrow_keys == `DOWN ? " " : "v";
    assign text[18][16 +: 8] = user_in.arrow_keys == `LEFT ? " " : "<";
    assign text[18][24 +: 8] = user_in.arrow_keys == `RIGHT ? " " : ">";
    assign text[19][0 +: 8] = user_in.note_keys[0] ? "C" : "c";
    assign text[19][8 +: 8] = user_in.note_keys[1] ? "D" : "d";
    assign text[19][16 +: 8] = user_in.note_keys[2] ? "E" : "e";
    assign text[19][24 +: 8] = user_in.note_keys[3] ? "F" : "f";
    assign text[19][32 +: 8] = user_in.note_keys[4] ? "G" : "g";
    assign text[19][40 +: 8] = user_in.note_keys[5] ? "A" : "a";
    assign text[19][48 +: 8] = user_in.note_keys[6] ? "B" : "b";
    assign text[20][0 +: 8] = user_in.oct_up ? " " : "+";
    assign text[20][8 +: 8] = user_in.oct_down ? " " : "-";

    assign init_out.text = text;
    assign init_out.state = state;
    assign init_out.seg = "start   ";
endmodule