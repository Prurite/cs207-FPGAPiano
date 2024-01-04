`include "header.svh"

module pageScoreHistory(
    input logic clk, prog_clk, rst,
    input UserInput user_in,
    output ProgramOutput history_out,
    output byte read_record_id,
    input PlayRecord record_data
);
    localparam UP       = 4'b1000;
    localparam DOWN     = 4'b0100;
    localparam LEFT     = 4'b0010;
    localparam RIGHT    = 4'b0001;

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
            text[2] <=  " 1|User1 | Tiny Stars     | 4487";
            text[3] <=  " 2|      |                |     ";
            text[4] <=  " 3|      |                |     ";
            text[5] <=  " 4|      |                |     ";
            text[6] <=  " 5|      |                |     ";
            text[7] <=  " 6|      |                |     ";
            text[8] <=  " 7|      |                |     ";
            text[9] <=  " 8|      |                |     ";
            text[10] <= " 9|      |                |     ";
            text[11] <= "                                ";
            text[12] <= " [<] Back                       ";
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

    displayHisLine d1(.clk(prog_clk), .rst(rst), .rec_id(1), .line(text[2]));
    displayHisLine d2(.clk(prog_clk), .rst(rst), .rec_id(2), .line(text[3]));
    displayHisLine d3(.clk(prog_clk), .rst(rst), .rec_id(3), .line(text[4]));
    displayHisLine d4(.clk(prog_clk), .rst(rst), .rec_id(4), .line(text[5]));
    displayHisLine d5(.clk(prog_clk), .rst(rst), .rec_id(5), .line(text[6]));
    displayHisLine d6(.clk(prog_clk), .rst(rst), .rec_id(6), .line(text[7]));
    displayHisLine d7(.clk(prog_clk), .rst(rst), .rec_id(7), .line(text[8]));
    displayHisLine d8(.clk(prog_clk), .rst(rst), .rec_id(8), .line(text[9]));
    displayHisLine d9(.clk(prog_clk), .rst(rst), .rec_id(9), .line(text[10]));
endmodule

module displayHisLine(
    input logic clk, rst,
    input byte rec_id,
    output reg [0:32*8-1] line
);
    PlayRecord rec;
    bit [39:0] uid_raw, score_raw;
    RecordStorageManager rec_m(.clk(clk), .sys_rst(rst), .read_record_id(rec_id), .write_record_id(0), .current_record_data(rec));
    binary2Str b2(.intx(rec.score), .str(score_raw));
    binary2Str b3(.intx(rec.user_id), .str(uid_raw));
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            line[2*8:3*8-1] <= "|";
            line[9*8:10*8-1] <= "|";
            line[26*8:27*8-1] <= "|";
        end
        else begin
            line[3*8:8*8-1] <= {"User", uid_raw[7:0]};
            line[10*8:26*8-1] <= rec.chart_name;
            line[27*8:32*8-1] <= score_raw;
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