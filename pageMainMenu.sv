`include "header.svh"

module pageMenu(
    input logic clk, prog_clk, rst,
    input UserInput user_in,
    output ProgramOutput menu_out,
    output byte read_chart_id,
    input Chart chart_data,
    output logic auto_play,
    input TopState cur_state
);
    localparam UP = `UP;
    localparam DOWN = `DOWN;
    localparam LEFT = `LEFT;
    localparam RIGHT = `RIGHT;

    byte cur_pos;
    ScreenText text;
    SegDisplayText seg;
    TopState state;

    byte updating_stay_cnt;
    // read_chart_id is the current chart_id to be read
    // After setting read_chart_id, the chart will be read in the next cycle
    // Use updating_stay_cnt to move to the next chart after 5 cycles
    logic init_finish;

    assign menu_out.text = text;
    assign menu_out.seg = seg;
    assign menu_out.state = state;

    always @(posedge prog_clk) begin
        if (rst) begin
            auto_play <= 0;
            cur_pos <= 0;
            seg <= "        ";
            state <= MENU;
            read_chart_id <= 1;
            updating_stay_cnt <= 0;
            init_finish <= 0;
            text[0] <=  "=======    Main  Menu    =======";
            text[1] <=  "    Score History               ";
            text[2] <=  "-----      Chart List      -----";
            text[3] <=  "    [0]  Free play      .       ";
            text[4] <=  "    [1]                         ";
            text[5] <=  "    [2]                         ";
            text[6] <=  "    [3]                         ";
            text[7] <=  "    [4]                         ";
            text[8] <=  "                                ";
            text[9] <=  "[^][v] Move Up / Down           ";
            text[10] <= "[<] Auto          [>] Play Chart";
        end else if (!init_finish) begin
            // text[11] <= "0" + read_chart_id;
            // text[12] <= "0" + updating_stay_cnt;
            case (read_chart_id)
                1: begin
                    text[4][9*8:9*8+8*`NAME_LEN-1] <= chart_data.info.name;
                    read_chart_id <= read_chart_id + 1;
                end
                2: begin
                    text[5][9*8:9*8+8*`NAME_LEN-1] <= chart_data.info.name;
                    read_chart_id <= read_chart_id + 1;
                end
                3: begin
                    text[6][9*8:9*8+8*`NAME_LEN-1] <= chart_data.info.name;
                    read_chart_id <= read_chart_id + 1;
                end
                4: begin
                    text[7][9*8:9*8+8*`NAME_LEN-1] <= chart_data.info.name;
                    read_chart_id <= read_chart_id + 1;
                    init_finish <= 1;
                end
                default: begin
                    read_chart_id <= 0;
                end
            endcase
            end
        else begin
            // Pointer actions
            text[1][0:3*8-1] <= (cur_pos == 0) ? ">>>" : "   ";
            text[3][0:3*8-1] <= (cur_pos == 1) ? ">>>" : "   ";
            text[4][0:3*8-1] <= (cur_pos == 2) ? ">>>" : "   ";
            text[5][0:3*8-1] <= (cur_pos == 3) ? ">>>" : "   ";
            text[6][0:3*8-1] <= (cur_pos == 4) ? ">>>" : "   ";
            text[7][0:3*8-1] <= (cur_pos == 5) ? ">>>" : "   ";

            // Read chart name
            case (cur_pos)
                0: begin read_chart_id <= 0; seg <= "history "; end
                1: begin read_chart_id <= 0; seg <= "free    "; end
                2: begin read_chart_id <= 2; seg <= "song  01"; end
                3: begin read_chart_id <= 3; seg <= "song  02"; end
                4: begin read_chart_id <= 4; seg <= "song  03"; end
                5: begin read_chart_id <= 5; seg <= "song  04"; end
                default: begin read_chart_id <= 0; seg <= "ykns inu"; end
            endcase

            // Input key actions
            case (user_in.arrow_keys)
                UP: begin
                    if (cur_pos == 0) cur_pos <= 5;
                    else cur_pos <= cur_pos - 1;
                end
                DOWN: begin
                    if (cur_pos == 5) cur_pos <= 0;
                    else cur_pos <= cur_pos + 1;
                end
                LEFT: begin
                    if (cur_pos > 1) begin
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