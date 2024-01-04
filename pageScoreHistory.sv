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

    ScreenText his_text;
    SegDisplayText seg;
    LedState led;
    TopState state;
    
    assign history_out.text = his_text;
    assign history_out.seg = seg;
    assign history_out.led = led;
    assign history_out.state = state;

    int i;
    
    assign his_text[0] =  "=====    Score History    ===== ";
    assign his_text[1] =  "                                ";
    assign his_text[11] = "                                ";
    assign his_text[12] = " [<] Back                       ";

    always @(posedge prog_clk)
        if (rst) begin
            read_record_id <= 0;
            state <= HISTORY;
            // Initialize his_text
        end else
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

    displayHisLine d1(.clk(prog_clk), .rst(rst), .rec_id(1), .active(read_record_id), .line(his_text[2]));
    displayHisLine d2(.clk(prog_clk), .rst(rst), .rec_id(2), .active(read_record_id), .line(his_text[3]));
    displayHisLine d3(.clk(prog_clk), .rst(rst), .rec_id(3), .active(read_record_id), .line(his_text[4]));
    displayHisLine d4(.clk(prog_clk), .rst(rst), .rec_id(4), .active(read_record_id), .line(his_text[5]));
    displayHisLine d5(.clk(prog_clk), .rst(rst), .rec_id(5), .active(read_record_id), .line(his_text[6]));
    displayHisLine d6(.clk(prog_clk), .rst(rst), .rec_id(6), .active(read_record_id), .line(his_text[7]));
    displayHisLine d7(.clk(prog_clk), .rst(rst), .rec_id(7), .active(read_record_id), .line(his_text[8]));
    displayHisLine d8(.clk(prog_clk), .rst(rst), .rec_id(8), .active(read_record_id), .line(his_text[9]));
    displayHisLine d9(.clk(prog_clk), .rst(rst), .rec_id(9), .active(read_record_id), .line(his_text[10]));
endmodule

module displayHisLine(
    input logic clk, rst,
    input byte rec_id, active,
    output reg [0:32*8-1] line
);
    PlayRecord rec;
    bit [39:0] uid_raw, score_raw;
    RecordStorageManager rec_m(.clk(clk), .sys_rst(rst), .read_record_id(rec_id), .write_record_id(0), .current_record_data(rec));
    binary2Str b2(.intx(rec.score), .str(score_raw));
    binary2Str b3(.intx(rec.user_id), .str(uid_raw));

    bit [7:0] mstr;
    matataku m(.prog_clk(prog_clk), .rst(rst), .digit(rec_id), .out_str(mstr));

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            case (rec_id)
                1: line <=  " 1|User1 | Tiny Stars     | 4487";
                2: line <=  " 2|      |                |     ";
                3: line <=  " 3|      |                |     ";
                4: line <=  " 4|      |                |     ";
                5: line <=  " 5|      |                |     ";
                6: line <=  " 6|      |                |     ";
                7: line <=  " 7|      |                |     ";
                8: line <=  " 8|      |                |     ";
                9: line <=  " 9|      |                |     ";
                default:
                    line <= "  |      |                |     ";
            endcase
        end
        else begin
            line[1*8:2*8-1] <= rec_id == active ? mstr : "0" + rec_id;
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