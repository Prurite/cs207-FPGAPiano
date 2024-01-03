module pageScoreHistory(
    input logic clk, prog_clk, rst,
    input UserInput user_in,
    output ProgramOutput history_out,
    output byte read_chart_id,
    output Chart read_chart
);
    localparam UP = 4'b1000;
    localparam DOWN = 4'b0100;
    localparam LEFT = 4'b0010;
    localparam RIGHT = 4'b0001;

    ScreenText text;
    SegDisplayText seg;
    LedState led;
    TopState state;
    bit [7:0] mstr;
    matataku m(.prog_clk(prog_clk), .rst(rst), .digit(read_chart_id), .out_str(mstr));
    always @(posedge prog_clk or posedge rst) begin
        if (rst) begin
            read_chart_id <= 0;
            state <= HISTORY;
            pos <= 0;
            // Initialize text
            text[0] <=  "======    Score  History    ======";
            text[1] <=  "                                  ";
            text[2] <=  " 1| User1 | Tiny Stars      | 4487";
            text[3] <=  " 2|       |                 |     ";
            text[4] <=  " 3|       |                 |     ";
            text[5] <=  " 4|       |                 |     ";
            text[6] <=  " 5|       |                 |     ";
            text[7] <=  " 6|       |                 |     ";
            text[8] <=  " 7|       |                 |     ";
            text[9] <=  " 8|       |                 |     ";
            text[10] <= " 9|       |                 |     ";
            text[11] <= "                                  ";
            text[12] <= " [<] Back                         ";
        end
        else begin
            case (user_in.arrow_keys)
                UP:
                    if (read_chart_id == 1) read_chart_id <= 9;
                    else read_chart_id <= read_chart_id - 1;
                DOWN:
                    if (read_chart_id == 9) read_chart_id <= 1;
                    else read_chart_id <= read_chart_id + 1;
                LEFT: state <= MENU;
                default: state <= HISTORY;
            endcase
            if (read_chart_id != 1) text[1][8:15] <= "1";
            if (read_chart_id != 2) text[1][8:15] <= "2";
            if (read_chart_id != 3) text[1][8:15] <= "3";
            if (read_chart_id != 4) text[1][8:15] <= "4";
            if (read_chart_id != 5) text[1][8:15] <= "5";
            if (read_chart_id != 6) text[1][8:15] <= "6";
            if (read_chart_id != 7) text[1][8:15] <= "7";
            if (read_chart_id != 8) text[1][8:15] <= "8";
            if (read_chart_id != 9) text[1][8:15] <= "9";
            text[read_chart_id][8:15] <= mstr;
        end
    end
endmodule

module matataku(
    input logic prog_clk, rst,
    input byte digit,
    output [7:0] out_str
);
    wire [39:0] raw_str;
    wire loc_clk;
    wire cnt;
    clkDiv clk30Hz(.clk(prog_clk), .rst(rst), .divx(30), .clk_out(loc_clk));
    binary2Str b2s(.intx(digit), .str(raw_str));
    always @(posedge loc_clk or posedge rst) begin
        if (rst | digit == 0) begin
            out_str <= " ";
            cnt <= 0;
        end
        else begin
            cnt <= ~cnt;
            if (cnt == 1'b1) out_str <= raw_str[7:0];
            else out_str <= " ";
        end
    end
endmodule