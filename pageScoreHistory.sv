`include "header.svh"

module pageScoreHistory(
    input logic clk, prog_clk, rst,
    input UserInput user_in,
    output ProgramOutput history_out,
    output byte read_record_id,
    input PlayRecord record_data
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
    assign history_out.text = text;
    assign history_out.seg = seg;
    assign history_out.led = led;
    assign history_out.state = state;

    int i;
    
    always @(posedge prog_clk) begin
        if (rst) begin
            read_record_id <= 0;
            state <= HISTORY;
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
                    if (read_record_id == 1) read_record_id <= 9;
                    else read_record_id <= read_record_id - 1;
                DOWN:
                    if (read_record_id == 9) read_record_id <= 1;
                    else read_record_id <= read_record_id + 1;
                LEFT: state <= MENU;
                default: state <= HISTORY;
            endcase
            for (i = 1; i <= 9; i++)
                if (i == read_record_id)
                    text[i][8:15] <= mstr;
                else
                    text[i][8:15] <= "0" + i;
        end
    end
endmodule

module matataku(
    input logic prog_clk, rst,
    input byte digit,
    output reg [7:0] out_str
);
    wire [39:0] raw_str;
    wire loc_clk;
    reg cnt;
    clkDiv clk30Hz(.clk(prog_clk), .rst(rst), .divx(30), .clk_out(loc_clk));
    binary2Str b2s(.intx(digit), .str(raw_str));
    always @(posedge loc_clk) begin
        if (rst || digit == 0) begin
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