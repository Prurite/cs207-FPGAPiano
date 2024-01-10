`include "header.svh"

module pageMenu(
    input logic clk, prog_clk, rst,
    input UserInput user_in,
    output ProgramOutput menu_out,
    output byte read_chart_id,
    input Chart chart_data,
    output logic auto_play
);
    localparam UP = `UP;
    localparam DOWN = `DOWN;
    localparam LEFT = `LEFT;
    localparam RIGHT = `RIGHT;

    byte cur_pos;
    UserInput edged_user_in;
    ScreenText text;
    SegDisplayText seg;
    TopState state;
    byte updating_chart_id;
    // Everytime a reset happens, it loops back to the first chart

    assign menu_out.text = text;
    assign menu_out.seg = seg;
    assign menu_out.state = state;

    edgeDetector edge_detector( .clk(prog_clk), .rst(rst),
        .user_in(user_in), .edge_out(edged_user_in) );
    
    always @(posedge prog_clk) begin
        if (rst) begin
            auto_play <= 0;
            cur_pos <= 0;
            seg <= "        ";
            state <= MENU;
            read_chart_id <= 0;
            updating_chart_id <= 0;
            text[0] <=  "=======    Main  Menu    =======";
            text[1] <=  ">>> Score History               ";
            text[2] <=  "-----      Chart List      -----";
            text[3] <=  "    [0]  Free play      .       ";
            text[4] <=  "    [1]                         ";
            text[5] <=  "    [2]                         ";
            text[6] <=  "    [3]                         ";
            text[7] <=  "    [4]                         ";
            text[8] <=  "                                ";
            text[9] <=  "[^][v] Move Up / Down           ";
            text[10] <= "[<] Auto          [>] Play Chart";
        end
        else begin
            // Pointer actions
            text[1][0:3*8-1] <= (cur_pos == 0) ? ">>>" : "   ";
            text[3][0:3*8-1] <= (cur_pos == 1) ? ">>>" : "   ";
            text[4][0:3*8-1] <= (cur_pos == 2) ? ">>>" : "   ";
            text[5][0:3*8-1] <= (cur_pos == 3) ? ">>>" : "   ";
            text[6][0:3*8-1] <= (cur_pos == 4) ? ">>>" : "   ";
            text[7][0:3*8-1] <= (cur_pos == 5) ? ">>>" : "   ";

            if (updating_chart_id <= 5) begin
                read_chart_id <= updating_chart_id;
                updating_chart_id <= updating_chart_id + 1;
                if (read_chart_id - 1 >= 1) // Current chart_data's id is read_chart_id - 1
                    text[2+read_chart_id][9*8:9*8+8*`NAME_LEN-1] <= chart_data.info.name;
            end else case (cur_pos)
                0: begin
                    read_chart_id <= 0;
                    seg <= "HIS     ";
                end
                1: begin
                    read_chart_id <= 0;
                    seg <= "FREE    ";
                end
                2: begin
                    read_chart_id <= 1;
                    seg <= "SO    01";
                end
                3: begin
                    read_chart_id <= 2;
                    seg <= "SO    02";
                end
                4: begin
                    read_chart_id <= 3;
                    seg <= "SO    03";
                end
                5: begin
                    read_chart_id <= 4;
                    seg <= "SO    04";
                end
                default: begin
                    read_chart_id <= 5;
                    seg <= "SO    05";
                end
            endcase
            
            // Input key actions
            case (edged_user_in.arrow_keys)
                UP: begin
                    if (cur_pos == 0) cur_pos <= 5;
                    else cur_pos <= cur_pos - 1;
                end
                DOWN: begin
                    if (cur_pos == 5) cur_pos <= 0;
                    else cur_pos <= cur_pos + 1;
                end
                LEFT: begin
                    if (cur_pos != 0) begin
                        state <= PLAY; auto_play <= 1'b1;
                    end
                end
                RIGHT: begin
                    if (cur_pos == 0) state <= HISTORY;
                    else begin
                        state <= PLAY; auto_play <= 1'b0;
                    end
                end
            endcase
        end
    end
endmodule