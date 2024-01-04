`include "header.svh"

module pageMenu(
    input logic clk, prog_clk, rst,
    input UserInput user_in,
    output ProgramOutput menu_out,
    output byte read_chart_id,
    output Chart chart_data,
    output logic auto_play
);
    localparam UP = 4'b1000;
    localparam DOWN = 4'b0100;
    localparam LEFT = 4'b0010;
    localparam RIGHT = 4'b0001;
    byte cur_pos;
    byte chart_id;
    ScreenText text;
    Notes notes [`CHART_LEN-1:0];
    SegDisplayText seg;
    TopState state;
    ChartStorageManager chart_storage(.clk(clk), .read_chart_id(chart_id), .write_chart_id(0), .read_chart(chart_data));
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            auto_play <= 0;
            cur_pos <= 0;
            chart_id <= 0;
            seg <= "";
            state <= MENU;
            text[0] <=  "=======    Main  Menu    =======";
            text[1] <=  ">>> Score History               ";
            text[2] <=  "-----      Chart List      -----";
            text[3] <=  "    [0]  Free Play              ";
            text[4] <=  "    [1]  Tiny Stars             ";
            text[5] <=  "    [2]  Song 1                 ";
            text[6] <=  "    [3]  Song 2                 ";
            text[7] <=  "    [4]  Recorded Song          ";
            text[8] <=  "                                ";
            text[9] <=  "[^][v] Move Up / Down           ";
            text[10] <= "[<] Auto          [>] Play Chart";
        end
        else begin
        // Pointer actions
            case (cur_pos)
                0: begin
                    read_chart_id <= 0;
                    seg <= "HIS     ";
                    text[1][0 * 8 : 3 * 8 - 1] <= ">>>";
                    text[3][0 * 8 : 3 * 8 - 1] <= "   ";
                    text[4][0 * 8 : 3 * 8 - 1] <= "   ";
                    text[5][0 * 8 : 3 * 8 - 1] <= "   ";
                    text[6][0 * 8 : 3 * 8 - 1] <= "   ";
                    text[7][0 * 8 : 3 * 8 - 1] <= "   ";
                end
                1: begin
                    read_chart_id <= 0;
                    seg <= "FREE    ";
                    text[1][0 * 8 : 3 * 8 - 1] <= "   ";
                    text[3][0 * 8 : 3 * 8 - 1] <= ">>>";
                    text[4][0 * 8 : 3 * 8 - 1] <= "   ";
                    text[5][0 * 8 : 3 * 8 - 1] <= "   ";
                    text[6][0 * 8 : 3 * 8 - 1] <= "   ";
                    text[7][0 * 8 : 3 * 8 - 1] <= "   ";
                end
                2: begin
                    read_chart_id <= 1;
                    seg <= "SO    01";
                    text[1][0 * 8 : 3 * 8 - 1] <= "   ";
                    text[3][0 * 8 : 3 * 8 - 1] <= "   ";
                    text[4][0 * 8 : 3 * 8 - 1] <= ">>>";
                    text[5][0 * 8 : 3 * 8 - 1] <= "   ";
                    text[6][0 * 8 : 3 * 8 - 1] <= "   ";
                    text[7][0 * 8 : 3 * 8 - 1] <= "   ";
                end
                3: begin
                    read_chart_id <= 2;
                    seg <= "SO    02";
                    text[1][0 * 8 : 3 * 8 - 1] <= "   ";
                    text[3][0 * 8 : 3 * 8 - 1] <= "   ";
                    text[4][0 * 8 : 3 * 8 - 1] <= "   ";
                    text[5][0 * 8 : 3 * 8 - 1] <= ">>>";
                    text[6][0 * 8 : 3 * 8 - 1] <= "   ";
                    text[7][0 * 8 : 3 * 8 - 1] <= "   ";
                end
                4: begin
                    read_chart_id <= 3;
                    seg <= "SO    03";
                    text[1][0 * 8 : 3 * 8 - 1] <= "   ";
                    text[3][0 * 8 : 3 * 8 - 1] <= "   ";
                    text[4][0 * 8 : 3 * 8 - 1] <= "   ";
                    text[5][0 * 8 : 3 * 8 - 1] <= "   ";
                    text[6][0 * 8 : 3 * 8 - 1] <= ">>>";
                    text[7][0 * 8 : 3 * 8 - 1] <= "   ";
                end
                5: begin
                    read_chart_id <= 4;
                    seg <= "SO    04";
                    text[1][0 * 8 : 3 * 8 - 1] <= "   ";
                    text[3][0 * 8 : 3 * 8 - 1] <= "   ";
                    text[4][0 * 8 : 3 * 8 - 1] <= "   ";
                    text[5][0 * 8 : 3 * 8 - 1] <= "   ";
                    text[6][0 * 8 : 3 * 8 - 1] <= "   ";
                    text[7][0 * 8 : 3 * 8 - 1] <= ">>>";
                end
                default: begin
                    read_chart_id <= 5;
                    seg <= "SO    05";
                    text[1][0 * 8 : 3 * 8 - 1] <= "   ";
                    text[3][0 * 8 : 3 * 8 - 1] <= "   ";
                    text[4][0 * 8 : 3 * 8 - 1] <= "   ";
                    text[5][0 * 8 : 3 * 8 - 1] <= "   ";
                    text[6][0 * 8 : 3 * 8 - 1] <= "   ";
                    text[7][0 * 8 : 3 * 8 - 1] <= "   ";
                end
            endcase
        end
    end
    // Input key actions
    always @(posedge clk) begin
        case (user_in.arrow_keys)
            UP: begin
                if (cur_pos == 0) cur_pos <= 5;
                else cur_pos <= cur_pos - 1;
            end
            DOWN: begin
                if (cur_pos == 5) cur_pos <= 1;
                else cur_pos <= cur_pos + 1;
            end
            LEFT: begin
                state <= PLAY;
                auto_play <= 1'b1;
            end
            RIGHT: begin
                if (cur_pos == 0) state = HISTORY;
                else begin
                    state <= PLAY;
                    auto_play <= 1'b0;
                end
            end
        endcase
    end
    assign menu_out = '{text, chart_data.notes, 8'd0, seg, state};
endmodule