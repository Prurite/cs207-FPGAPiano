`include "header.svh"

// General control module
module pagePlayChart(
    input logic clk, prog_clk, rst,
    input UserInput user_in,
    input Chart read_chart,
    input logic auto_play,
    output ProgramOutput play_out,
    output byte write_chart_id,
    output Chart write_chart,
    output byte write_record_id,
    output Chart write_record
);
    // Output sound signal, connected directly to notePlayer
    logic sig = 1'b0;

    // Status control
    logic play_en = 1'b0, play_st = 1'b0, fin_en = 1'b1;
    assign play_en = play_st & fin_en;
    
    // Iterate notes 
    shortint note_count;
    Notes notes [`CHART_LEN-1:0];
    Notes cur_note;

    // Records score.
    wire [13:0] cur_score;
    
    ScreenText text;
    assign notes = read_chart.notes;

    // Instanciate current player
    notePlayer note_player(.clk(clk), .rst(rst), .note(cur_note), .sig(sig));

    // Get screen output
    screenOut screen_out(.prog_clk(prog_clk), .rst(rst), .chart(read_chart), .note_count(note_count), .score(cur_score), .play_st(play_st) .text(text));
    
    // Countdown func (3s before start)
    wire [1:0] cnt_dn;
    countDown cd(.clk(clk), .rst(rst), .en(play_st), .cnt_dn(cnt_dn));
    
    // Refresh current note every 100ms
    logic clk_100ms;
    clkDiv div100(.clk(clk), .rst(rst), .divx(10_000_000), .clk_out(clk_100ms));
    always @(posedge clk_100ms or posedge rst) begin
        if (rst) begin
            note_cnt <= 0;
            cur_note <= 9'b00_0000000;
            sig <= 1'b0;
            en <= 1'b0;
            cnt_en <= 1'b0;
            fin_en <= 1'b1;
        end
        else if (play_en) begin
            note_cnt <= note_cnt + 1;
            cur_note <= notes[note_count];
        end
    end

    // Instanciate score manager
    scoreManager sc_m(.clk(clk), .prog_clk(prog_clk), .rst(rst), .play_en(play_en), .user_in(user_in), .chart(read_chart), .note_count(note_count), .score(cur_score));
    integer clk0;
endmodule

// Manage total screen output
module screenOut(
    input logic prog_clk, rst,
    input Chart chart,
    input shortint note_count,
    input [13:0] score,
    input [1:0] cnt_dn,
    input logic play_st,
    output ScreenText text
);
    ScreenText text;
    ScreenText note_area;
    initial begin
        // Title display
        text[2]  = "=====    Playing Chart    ===== ";
        text[4]  = "Current User ID: -              ";
        text[5]  = "Playing: -                      ";
        text[6]  = "Save to chart ID: -             ";
        // Progress & Score display
        text[8]  = "Prog.    0 /    0    Score     0";
        // Line 10-25 display notes
        text[27] = "    C  D  E  F  G  A  B   =     ";
    end
    noteAreaController ctrl(.prog_clk(prog_clk), .rst(rst), .en(play_st), .cnt_dn(cnt_dn), .note_count(note_count), .notes(chart.notes), .play_st(play_st), .text(note_area));
    assign text[10:25] = note_area[0:15];
    // Display Score (Line 8, Col 28~32)
endmodule

// Return realtime score according to user input
module scoreManager (
    input logic clk, prog_clk, rst, play_en,
    input UserInput user_in,
    input Chart chart,
    input shortint note_count,
    output [13:0] score
);
    localparam PR_TIME = 50; //ms
    localparam GR_TIME = 100; //ms
    localparam GD_TIME = 150; //ms
    localparam MS_TIME = 200; //ms
    localparam PR_SCORE = 10;
    localparam GR_SCORE = 8;
    localparam GD_SCORE = 5;
    localparam MS_SCORE = 0;
endmodule

// Manage note area output
module noteAreaController(
    input logic prog_clk, rst, en,
    input [1:0] cnt_dn,
    input shortint note_count,
    input Notes [0:`MAX_DISPLAY_HEIGHT - 1] notes,
    input logic play_st,
    // Only [10:25] is modified
    output ScreenText text
);
    // Display countdown
    always @(posedge prog_clk or posedge rst) begin
        if (~en) begin
            case (cnt_dn)
                2'b11: begin
                    text[10] = "                                ";
                    text[11] = "                                ";
                    text[12] = "          33333333333           ";
                    text[13] = "        333333333333333         ";
                    text[14] = "       3333         3333        ";
                    text[15] = "                     333        ";
                    text[16] = "                    3333        ";
                    text[17] = "            33333333333         ";
                    text[18] = "            33333333333         ";
                    text[19] = "                    3333        ";
                    text[20] = "                     333        ";
                    text[21] = "       3333         3333        ";
                    text[22] = "        333333333333333         ";
                    text[23] = "          33333333333           ";
                    text[24] = "                                ";
                    text[25] = "                                ";
                end
                2'b10: begin
                    text[10] = "                                ";
                    text[11] = "            22222222            ";
                    text[12] = "         2222222222222          ";
                    text[13] = "        2222       2222         ";
                    text[14] = "        2222        2222        ";
                    text[15] = "                    2222        ";
                    text[16] = "                   22222        ";
                    text[17] = "                 222222         ";
                    text[18] = "                22222           ";
                    text[19] = "              22222             ";
                    text[20] = "            22222               ";
                    text[21] = "          22222                 ";
                    text[22] = "        22222222222222222       ";
                    text[23] = "        22222222222222222       ";
                    text[24] = "                                ";
                    text[25] = "                                ";
                end
                2'b01: begin
                    text[10] = "                                ";
                    text[11] = "                                ";
                    text[12] = "                111             ";
                    text[13] = "            1111111             ";
                    text[14] = "            1111111             ";
                    text[15] = "                111             ";
                    text[16] = "                111             ";
                    text[17] = "                111             ";
                    text[18] = "                111             ";
                    text[19] = "                111             ";
                    text[20] = "                111             ";
                    text[21] = "                111             ";
                    text[22] = "           111111111111         ";
                    text[23] = "           111111111111         ";
                    text[24] = "                                ";
                    text[25] = "                                ";
                end
                default:
                    text = 0;
            endcase
        end
    end
    // Display Notes
    displayLine l25(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_cnt + 15]), .is_line(1'b1), .line(text[25]));
    displayLine l24(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_cnt + 14]), .is_line(1'b0), .line(text[24]));
    displayLine l23(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_cnt + 13]), .is_line(1'b0), .line(text[23]));
    displayLine l22(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_cnt + 12]), .is_line(1'b0), .line(text[22]));
    displayLine l21(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_cnt + 11]), .is_line(1'b0), .line(text[21]));
    displayLine l20(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_cnt + 10]), .is_line(1'b0), .line(text[20]));
    displayLine l19(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_cnt + 9]), .is_line(1'b0), .line(text[19]));
    displayLine l18(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_cnt + 8]), .is_line(1'b0), .line(text[18]));
    displayLine l17(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_cnt + 7]), .is_line(1'b0), .line(text[17]));
    displayLine l16(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_cnt + 6]), .is_line(1'b0), .line(text[16]));
    displayLine l15(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_cnt + 5]), .is_line(1'b0), .line(text[15]));
    displayLine l14(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_cnt + 4]), .is_line(1'b0), .line(text[14]));
    displayLine l13(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_cnt + 3]), .is_line(1'b0), .line(text[13]));
    displayLine l12(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_cnt + 2]), .is_line(1'b0), .line(text[12]));
    displayLine l11(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_cnt + 1]), .is_line(1'b0), .line(text[11]));
    displayLine l10(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_cnt]), .is_line(1'b0), .line(text[10]));
endmodule

module displayLine(
    input logic prog_clk, rst, en,
    input Notes cur_note,
    input logic is_line,
    output [0:`SCREEN_WIDTH * 8 - 1] line
);
    always @(posedge prog_clk or posedge rst) begin
        if (rst)
            line = "                                ";
        else begin
            if (en) begin
                case (cur_note)
                    //                          C  D  E  F  G  A  B   O
                    9'b00_0000001:  line = "    #  .  .  .  .  .  .   .     ";
                    9'b00_0000010:  line = "    .  #  .  .  .  .  .   .     ";
                    9'b00_0000100:  line = "    .  .  #  .  .  .  .   .     ";
                    9'b00_0001000:  line = "    .  .  .  #  .  .  .   .     ";
                    9'b00_0010000:  line = "    .  .  .  .  #  .  .   .     ";
                    9'b00_0100000:  line = "    .  .  .  .  .  #  .   .     ";
                    9'b00_1000000:  line = "    .  .  .  .  .  .  #   .     ";
                    9'b01_0000001:  line = "    #  .  .  .  .  .  .   +     ";
                    9'b01_0000010:  line = "    .  #  .  .  .  .  .   +     ";
                    9'b01_0000100:  line = "    .  .  #  .  .  .  .   +     ";
                    9'b01_0001000:  line = "    .  .  .  #  .  .  .   +     ";
                    9'b01_0010000:  line = "    .  .  .  .  #  .  .   +     ";
                    9'b01_0100000:  line = "    .  .  .  .  .  #  .   +     ";
                    9'b01_1000000:  line = "    .  .  .  .  .  .  #   +     ";
                    9'b10_0000001:  line = "    #  .  .  .  .  .  .   -     ";
                    9'b10_0000010:  line = "    .  #  .  .  .  .  .   -     ";
                    9'b10_0000100:  line = "    .  .  #  .  .  .  .   -     ";
                    9'b10_0001000:  line = "    .  .  .  #  .  .  .   -     ";
                    9'b10_0010000:  line = "    .  .  .  .  #  .  .   -     ";
                    9'b10_0100000:  line = "    .  .  .  .  .  #  .   -     ";
                    9'b10_1000000:  line = "    .  .  .  .  .  .  #   -     ";
                    default:        line = "    .  .  .  .  .  .  .   .     ";
                endcase
            end
            else
                line = "                                ";
            // Add marks at the last line
            if (is_line) begin
                line[0:3*8 - 1] = ">>>";
                line[30 * 8:32 * 8 - 1] = "<<<";
            end
        end
    end
endmodule

module countDown (
    input logic clk, rst,
    output logic en = 1'b0,
    output reg [1:0] cnt_dn
);
    byte cnt;
    logic clk_100ms;
    clkDiv div100(.clk(clk), .rst(rst), .divx(10_000_000), .clk_out(clk_100ms));
    always @(posedge clk_100ms or posedge rst) begin
        if (rst) begin
            cnt <= 0;
            en <= 1'b0;
            cnt_dn <= 2'b11;
        end
        else if (~en) begin
            cnt <= cnt + 1;
            if (cnt == 10) begin
                cnt <= 0;
                case (cnt_dn)
                    1'b11: cnt_dn <= 1'b10;
                    1'b10: cnt_dn <= 1'b01;
                    1'b01: cnt_dn <= 1'b00;
                    1'b00: en <= 1'b1;
                endcase
            end
        end
    end
endmodule

module notePlayer(
    input logic clk, rst,
    input Notes note,
    output logic sig
);
    integer wav_len;
    clkDiv wave_div(.clk(clk), .rst(rst), .divx(wav_len), .clk_out(sig))
    always @(posedge clk or posedge rst) begin
        if (rst)
            sig <= 0;
        else begin
            case (note)
                9'b01_0000001: wav_len <= `C3;
                9'b01_0000010: wav_len <= `D3;
                9'b01_0000100: wav_len <= `E3;
                9'b01_0001000: wav_len <= `F3;
                9'b01_0010000: wav_len <= `G3;
                9'b01_0100000: wav_len <= `A4;
                9'b01_1000000: wav_len <= `B4;
                9'b00_0000001: wav_len <= `C4;
                9'b00_0000010: wav_len <= `D4;
                9'b00_0000100: wav_len <= `E4;
                9'b00_0001000: wav_len <= `F4;
                9'b00_0010000: wav_len <= `G4;
                9'b00_0100000: wav_len <= `A5;
                9'b00_1000000: wav_len <= `B5;
                9'b10_0000001: wav_len <= `C5;
                9'b10_0000010: wav_len <= `D5;
                9'b10_0000100: wav_len <= `E5;
                9'b10_0001000: wav_len <= `F5;
                9'b10_0010000: wav_len <= `G5;
                9'b10_0100000: wav_len <= `A6;
                9'b10_1000000: wav_len <= `B6;
                default: wav_len <= 0;
            endcase
        end
    end
endmodule