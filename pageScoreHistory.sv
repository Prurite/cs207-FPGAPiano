`include "header.svh"

module pageScoreHistory(
    input logic clk, prog_clk, rst,
    input UserInput user_in,
    output ProgramOutput history_out,
    output byte read_record_id,
    input PlayRecord record_data
);
    localparam UP = `UP;
    localparam DOWN = `DOWN;
    localparam LEFT = `LEFT;
    localparam RIGHT = `RIGHT;

    bit [0:39] user_id_text;
    bit [0:39] score_text;

    binary2Str user_id_text_gen( .intx(record_data.user_id),
        .str(user_id_text) );
    binary2Str score_text_gen( .intx(record_data.score),
        .str(score_text) );

    byte updating_record_id;

    always @(posedge prog_clk)
        if (rst) begin
            read_record_id <= 0;
            updating_record_id <= 0;
            //history_out.state <= HISTORY;
            history_out.text[0] <=  "=====    Score History    ===== ";
            history_out.text[1] <=  "                                ";
            history_out.text[2] <=  " 1|User  |                |     ";
            history_out.text[3] <=  " 2|User  |                |     ";
            history_out.text[4] <=  " 3|User  |                |     ";
            history_out.text[5] <=  " 4|User  |                |     ";
            history_out.text[6] <=  " 5|User  |                |     ";
            history_out.text[7] <=  " 6|User  |                |     ";
            history_out.text[8] <=  " 7|User  |                |     ";
            history_out.text[9] <=  " 8|User  |                |     ";
            history_out.text[10] <= " 9|User  |                |     ";
            history_out.text[11] <= "                                ";
            history_out.text[12] <= " [<] Back                       ";
            // Initialize history_out.text
            for (int i = 13; i < `SCREEN_TEXT_HEIGHT; i = i + 1)
                history_out.text[i] <= "                                ";
            history_out.seg <= "rec     ";
        end else if (updating_record_id <= 11) begin
            read_record_id <= updating_record_id;
            updating_record_id <= updating_record_id + 1;
            // Current record data is for read_record_id - 1
            if (read_record_id >= 1 && read_record_id <= 9) begin
                history_out.text[read_record_id + 1][7*8 : 9*8 - 1] <= user_id_text[3*8 : 5*8 - 1];
                history_out.text[read_record_id + 1][10*8 : 10*8 + `NAME_LEN*8 - 1] <= record_data.chart_name;
                history_out.text[read_record_id + 1][11*8 + `NAME_LEN*8 : 16*8 + `NAME_LEN*8 - 1] <= score_text;
            end
        end

    // Individual state control
    always @(posedge prog_clk)
        if (!rst)
            if (user_in.arrow_keys == LEFT)
                history_out.state <= MENU;
            else
                history_out.state <= HISTORY; 
endmodule
