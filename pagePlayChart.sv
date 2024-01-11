`include "header.svh"

// General control module
module pagePlayChart(
    input logic clk, prog_clk, rst,
    input UserInput user_in,
    input Chart read_chart,
    input logic auto_play, free_play,
    output ProgramOutput play_out,
    output byte write_chart_id,
    output Chart write_chart,
    output byte write_record_id,
    output PlayRecord write_record
);
    localparam UP = `UP;
    localparam DOWN = `DOWN;
    localparam LEFT = `LEFT;
    localparam RIGHT = `RIGHT;

    // Status control
    logic play_en, play_st, fin_en;
    assign play_en = play_st & fin_en;
    // play_en: 1: playing; 0: not playing
    // play_st: 1: play has started; 0: play has not started
    // fin_en: 1: play has not finished; 0: play has finished
    
    // Iterate notes 
    shortint note_count; // Current note index
    Notes cur_note;

    // Records score.
    wire [13:0] cur_score;
    ScreenText text;

    // Get screen output
    screenOut screen_out(
        .prog_clk(prog_clk), .rst(rst),
        .chart(read_chart), .note_count(note_count),
        .user_in(user_in), .play_st(play_st), .auto_play(auto_play), .free_play(free_play),
        .score(cur_score), .text(text), .seg_text(play_out.seg), .led(play_out.led)
    );
    
    // Countdown func (3s before start)
    wire [1:0] cnt_dn;
    logic cd_end; // 1: countdown ends
    countDown cd(.prog_clk(prog_clk), .rst(rst), .play_st(cd_end), .cnt_dn(cnt_dn));

    // Status control
    always @(posedge prog_clk) begin
        if (rst) begin
            play_st <= 1'b0;
            fin_en <= 1'b1;
        end else begin
            play_st <= cd_end;
            fin_en <= note_count <= read_chart.info.note_cnt || read_chart.info.note_cnt == 0;
        end
    end

    assign play_out.text[0][0:7] = "0" + play_st;
    assign play_out.text[0][8:15] = "0" + fin_en;
    assign play_out.text[0][24:31] = "0" + play_en;
    assign play_out.text[0][32:39] = "0" + cnt_dn;

    assign play_out.text[`SCREEN_TEXT_HEIGHT-1:2] = text[`SCREEN_TEXT_HEIGHT-1:2];
    
    Chart uinc; // Record chart
    PlayRecord play_record; // Record play data

    // Refresh current note every `NOTE_TIME
    logic clk_notes;
    clkDiv div_note(.clk(prog_clk), .rst(rst), .divx(`NOTE_CLK_DIV), .clk_out(clk_notes));

    Notes user_playing_notes;
    assign user_playing_notes = {user_in.oct_down, user_in.oct_up, user_in.note_keys};

    // Manage current note and record user played chart
    always @(posedge clk_notes or posedge rst) begin
        if (rst) begin
            note_count <= 0;
            play_out.notes <= 9'b00_0000000;
        end else if (play_en) begin
            note_count <= note_count + 1;
            play_out.notes <= auto_play ? read_chart.notes[note_count] : user_playing_notes;
            uinc.notes[note_count] <= user_playing_notes;
        end
    end
    assign uinc.info = read_chart.info;
    assign play_record = '{user_in.user_id, read_chart.info.name, cur_score};

    // Manage user input
    always @(posedge prog_clk) begin
        if (rst) begin
            play_out.state <= PLAY;
            write_chart_id <= 0;
            write_record_id <= 0;
        end else begin
            if (user_in.arrow_keys == LEFT && play_st)
                play_out.state <= MENU;
            else if (user_in.arrow_keys == RIGHT && play_st) begin
                // Save chart
                write_chart_id <= user_in.chart_id;
                write_chart <= uinc;
                // Save score
                write_record_id <= user_in.chart_id;
                write_record <= play_record;
            end else begin
                write_chart_id <= 0;
                write_record_id <= 0;
            end
        end
    end

    // Instanciate score manager
    scoreManager sc_m(
        .prog_clk(prog_clk), .rst(rst),
        .play_en(play_en), .auto_play(auto_play), .free_play(free_play),
        .user_in(user_in), .chart(read_chart), .note_count(note_count),
        .score(cur_score)
    );
endmodule

// Manage total screen output
module screenOut(
    input logic prog_clk, rst,
    input Chart chart,
    input shortint note_count,
    input UserInput user_in,
    input bit [13:0] score,
    input bit [1:0] cnt_dn,
    input logic play_st, auto_play, free_play,
    output ScreenText text,
    output SegDisplayText seg_text,
    output LedState led
);
    ScreenTextRow note_area [`NOTE_AREA_HEIGHT-1:0];
    wire [0:39] sc_str, cnt_str, len_str, uid_raw, cid_raw;

    // Display Info (Line 8, Col 7~10, 14~17, 28~32)    
    binary2Str b2sc(.intx(score), .str(sc_str));
    binary2Str b2sn(.intx(note_count), .str(cnt_str));
    binary2Str b2snc(.intx(chart.info.note_cnt), .str(len_str));
    binary2Str b2suid(.intx(user_in.user_id), .str(uid_raw));
    binary2Str b2scid(.intx(user_in.chart_id), .str(cid_raw));

    always @(posedge prog_clk or posedge rst) begin
        if (rst) begin
            // Title display
            text[2]  <= "=====    Playing Chart    ===== ";
            text[4]  <= "Current User ID: 0              ";
            text[5]  <= "Playing: -                      ";
            text[6]  <= "Save to chart ID:               ";
            // Progress & Score display
            text[8]  <= "Prog.    0 /    0    Score     0";
            // Line 10-25 display notes
            text[27] <= "    C  D  E  F  G  A  B   =     ";
            //              [C][D]                [+][[-]]
            text[29] <= "[+] Hi [-] Lo [<] Exit  [>] Save";
        end else begin
            // Display prog info
            text[8][0:32*8-1] <= {"Prog. ", cnt_str[8:39], " / ", len_str[8:39], "    Score ", sc_str};
            // Display chart info
            if (auto_play) text[4][17*8:21*8-1] <= "Auto";
            else text[4][17*8:21*8-1] <= {uid_raw[3*8:5*8-1], 16'h0000};
            if (free_play) text[5][9*8:(9+`NAME_LEN)*8 - 1] <= "Free Playing... ";
            else text[5][9*8:(9+`NAME_LEN)*8 - 1] <= chart.info.name;
            text[6][17*8:19*8-1] <= cid_raw[3*8:5*8-1];
            text[25:10] <= note_area[15:0];

            // User interaction
            case (user_in.note_keys)
                7'b0000001: text[27][3*8:24*8-1] <= "[C] D  E  F  G  A  B ";
                7'b0000010: text[27][3*8:24*8-1] <= " C [D] E  F  G  A  B ";
                7'b0000100: text[27][3*8:24*8-1] <= " C  D [E] F  G  A  B ";
                7'b0001000: text[27][3*8:24*8-1] <= " C  D  E [F] G  A  B ";
                7'b0010000: text[27][3*8:24*8-1] <= " C  D  E  F [G] A  B ";
                7'b0100000: text[27][3*8:24*8-1] <= " C  D  E  F  G [A] B ";
                7'b1000000: text[27][3*8:24*8-1] <= " C  D  E  F  G  A [B]";
                default: text[27][3*8:24*8-1]    <= " C  D  E  F  G  A  B ";
            endcase
            case ({user_in.oct_down, user_in.oct_up})
                2'b10: text[27][25*8:28*8-1] <= "[-]";
                2'b01: text[27][25*8:28*8-1] <= "[+]";
                default: text[27][25*8:28*8-1] <= " = ";
            endcase
        end
    end

    noteAreaController ctrl(
        .prog_clk(prog_clk), .rst(rst), .en(play_st),
        .cnt_dn(cnt_dn), .note_count(note_count), .notes(chart.notes),
        .text(note_area), .seg(seg_text), .led(led)
    );
endmodule

// Return realtime score according to user input
module scoreManager (
    input logic prog_clk, rst, play_en, auto_play, free_play,
    input UserInput user_in,
    input Chart chart,
    input shortint note_count,
    output reg [13:0] score
);
    // Perfect 50ms 10p, Great 100ms 8p, Good 150ms 5p, Miss 200ms+ 0p.

    // Scan every 50ms
    logic clk50ms;
    clkDiv clk50(.clk(prog_clk), .rst(rst), .divx(3), .clk_out(clk50ms));
    Notes uin [1:0];
    Notes cur_note, cur_in;
    assign cur_in = {user_in.oct_down, user_in.oct_up, user_in.note_keys};

    always @(posedge clk50ms or posedge rst) begin
        if (rst) begin
            score <= 14'd0;
            uin[0] <= 9'b00_0000000;
            uin[1] <= 9'b00_0000000;
        end else if (play_en && !free_play) begin
            if (auto_play) score = score + 4;
            else begin
                uin[0] <= cur_in;
                uin[1] <= uin[0];
                cur_note <= chart.notes[note_count];
                if (cur_note == cur_in) score = score + 5;
                else if (cur_note == uin[0]) score = score + 3;
                else if (cur_note == uin[1]) score = score + 1;
            end
        end
    end
endmodule

// Manage note area output
module noteAreaController(
    input logic prog_clk, rst, en,
    input [1:0] cnt_dn,
    input shortint note_count,
    input Notes notes [`CHART_LEN-1:0],
    // Only [10:25] is modified
    output ScreenTextRow text [`NOTE_AREA_HEIGHT-1:0],
    output SegDisplayText seg,
    output LedState led
);
    ScreenTextRow temp_text [`NOTE_AREA_HEIGHT-1:0];
    const ScreenTextRow text_init [`NOTE_AREA_HEIGHT-1:0] = '{default: '0};
    // Display countdown
    always @(posedge prog_clk) begin
        if (~en) begin
            case (cnt_dn)
                2'b11: begin
                    text[0]  <= "                                ";
                    text[1]  <= "                                ";
                    text[2]  <= "          33333333333           ";
                    text[3]  <= "        333333333333333         ";
                    text[4]  <= "       3333         3333        ";
                    text[5]  <= "                     333        ";
                    text[6]  <= "                    3333        ";
                    text[7]  <= "            33333333333         ";
                    text[8]  <= "            33333333333         ";
                    text[9]  <= "                    3333        ";
                    text[10] <= "                     333        ";
                    text[11] <= "       3333         3333        ";
                    text[12] <= "        333333333333333         ";
                    text[13] <= "          33333333333           ";
                    text[14] <= "                                ";
                    text[15] <= "                                ";
                end
                2'b10: begin
                    text[0]  <= "                                ";
                    text[1]  <= "            22222222            ";
                    text[2]  <= "         2222222222222          ";
                    text[3]  <= "        2222       2222         ";
                    text[4]  <= "        2222        2222        ";
                    text[5]  <= "                    2222        ";
                    text[6]  <= "                   22222        ";
                    text[7]  <= "                 222222         ";
                    text[8]  <= "                22222           ";
                    text[9]  <= "              22222             ";
                    text[10] <= "            22222               ";
                    text[11] <= "          22222                 ";
                    text[12] <= "        22222222222222222       ";
                    text[13] <= "        22222222222222222       ";
                    text[14] <= "                                ";
                    text[15] <= "                                ";
                end
                2'b01: begin
                    text[0]  <= "                                ";
                    text[1]  <= "                                ";
                    text[2]  <= "                111             ";
                    text[3]  <= "            1111111             ";
                    text[4]  <= "            1111111             ";
                    text[5]  <= "                111             ";
                    text[6]  <= "                111             ";
                    text[7]  <= "                111             ";
                    text[8]  <= "                111             ";
                    text[9]  <= "                111             ";
                    text[10] <= "                111             ";
                    text[11] <= "                111             ";
                    text[12] <= "           111111111111         ";
                    text[13] <= "           111111111111         ";
                    text[14] <= "                                ";
                    text[15] <= "                                ";
                end
                default:
                    text <= text_init;
            endcase
        end
        else begin
            text <= temp_text;
        end
    end
    
    shortint note_id; // Make sure it does not go out of bound
    assign note_id = (note_count+15) >= `CHART_LEN ? `CHART_LEN-16 : note_count;

    // Display seg
    always @(posedge prog_clk) begin
        if (rst) seg <= "        ";
        else if (en) case (notes[note_count])
            9'b00_0000001: seg <= "c   1   ";
            9'b00_0000010: seg <= "d   2   ";
            9'b00_0000100: seg <= "e   3   ";
            9'b00_0001000: seg <= "f   4   ";
            9'b00_0010000: seg <= "g   5   ";
            9'b00_0100000: seg <= "a   6   ";
            9'b00_1000000: seg <= "b   7   ";
            9'b01_0000001: seg <= "c u 1   ";
            9'b01_0000010: seg <= "d u 2   ";
            9'b01_0000100: seg <= "e u 3   ";
            9'b01_0001000: seg <= "f u 4   ";
            9'b01_0010000: seg <= "g u 5   ";
            9'b01_0100000: seg <= "a u 6   ";
            9'b01_1000000: seg <= "b u 7   ";
            9'b10_0000001: seg <= "c d 1   ";
            9'b10_0000010: seg <= "d d 2   ";
            9'b10_0000100: seg <= "e d 3   ";
            9'b10_0001000: seg <= "f d 4   ";
            9'b10_0010000: seg <= "g d 5   ";
            9'b10_0100000: seg <= "a d 6   ";
            9'b10_1000000: seg <= "b d 7   ";
            default:       seg <= "        ";
        endcase
    end

    // Display Notes
    displayLine l25(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_id]), .is_line(1'b1), .line(temp_text[15]));
    displayLine l24(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_id + 1]), .is_line(1'b0), .line(temp_text[14]));
    displayLine l23(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_id + 2]), .is_line(1'b0), .line(temp_text[13]));
    displayLine l22(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_id + 3]), .is_line(1'b0), .line(temp_text[12]));
    displayLine l21(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_id + 4]), .is_line(1'b0), .line(temp_text[11]));
    displayLine l20(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_id + 5]), .is_line(1'b0), .line(temp_text[10]));
    displayLine l19(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_id + 6]), .is_line(1'b0), .line(temp_text[9]));
    displayLine l18(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_id + 7]), .is_line(1'b0), .line(temp_text[8]));
    displayLine l17(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_id + 8]), .is_line(1'b0), .line(temp_text[7]));
    displayLine l16(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_id + 9]), .is_line(1'b0), .line(temp_text[6]));
    displayLine l15(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_id + 10]), .is_line(1'b0), .line(temp_text[5]));
    displayLine l14(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_id + 11]), .is_line(1'b0), .line(temp_text[4]));
    displayLine l13(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_id + 12]), .is_line(1'b0), .line(temp_text[3]));
    displayLine l12(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_id + 13]), .is_line(1'b0), .line(temp_text[2]));
    displayLine l11(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_id + 14]), .is_line(1'b0), .line(temp_text[1]));
    displayLine l10(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_id + 15]), .is_line(1'b0), .line(temp_text[0]));
    displayLed dd(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_id]), .led(led));
endmodule


// Display each line in note area
module displayLine(
    input logic prog_clk, rst, en,
    input Notes cur_note,
    input logic is_line,
    output ScreenTextRow line
);
    reg [0 : 23 * 8 - 1] line_notes;

    always @(posedge prog_clk) begin
        if (rst || !en)
            line_notes = ".                 .   .";
        else begin
            case (cur_note)
                //                            C  D  E  F  G  A  B   O
                9'b00_0000001:  line_notes <= "#  .  .  .  .  .  .   .";
                9'b00_0000010:  line_notes <= ".  #  .  .  .  .  .   .";
                9'b00_0000100:  line_notes <= ".  .  #  .  .  .  .   .";
                9'b00_0001000:  line_notes <= ".  .  .  #  .  .  .   .";
                9'b00_0010000:  line_notes <= ".  .  .  .  #  .  .   .";
                9'b00_0100000:  line_notes <= ".  .  .  .  .  #  .   .";
                9'b00_1000000:  line_notes <= ".  .  .  .  .  .  #   .";
                9'b01_0000001:  line_notes <= "#  .  .  .  .  .  .   +";
                9'b01_0000010:  line_notes <= ".  #  .  .  .  .  .   +";
                9'b01_0000100:  line_notes <= ".  .  #  .  .  .  .   +";
                9'b01_0001000:  line_notes <= ".  .  .  #  .  .  .   +";
                9'b01_0010000:  line_notes <= ".  .  .  .  #  .  .   +";
                9'b01_0100000:  line_notes <= ".  .  .  .  .  #  .   +";
                9'b01_1000000:  line_notes <= ".  .  .  .  .  .  #   +";
                9'b10_0000001:  line_notes <= "#  .  .  .  .  .  .   -";
                9'b10_0000010:  line_notes <= ".  #  .  .  .  .  .   -";
                9'b10_0000100:  line_notes <= ".  .  #  .  .  .  .   -";
                9'b10_0001000:  line_notes <= ".  .  .  #  .  .  .   -";
                9'b10_0010000:  line_notes <= ".  .  .  .  #  .  .   -";
                9'b10_0100000:  line_notes <= ".  .  .  .  .  #  .   -";
                9'b10_1000000:  line_notes <= ".  .  .  .  .  .  #   -";
                default:        line_notes <= ".  .  .  .  .  .  .   .";
            endcase
            line[0 : 4 * 8 - 1] <= is_line ? ">>> " : "    ";
            line[4 * 8 : 27 * 8 - 1] <= line_notes;
            line[27 * 8 : 32 * 8 - 1] <= is_line ? " <<< " : "     ";
        end
    end
endmodule

// Control led output
module displayLed(
    input logic prog_clk, rst, en,
    input Notes cur_note,
    output LedState led
);
    always @(posedge prog_clk) begin
        if (rst) led <= 8'b0000_0000;
        else if (en) begin
            case (cur_note[8:7])
                2'b00:      led[0] <= 1'b0;
                2'b01:      led[0] <= 1'b1;
                2'b10:      led[0] <= 1'b1;
                default:    led[0] <= 1'b0;
            endcase
            case (cur_note[6:0])
                7'b0000001: led[7:1] <= 7'b1000000;
                7'b0000010: led[7:1] <= 7'b0100000;
                7'b0000100: led[7:1] <= 7'b0010000;
                7'b0001000: led[7:1] <= 7'b0001000;
                7'b0010000: led[7:1] <= 7'b0000100;
                7'b0100000: led[7:1] <= 7'b0000010;
                7'b1000000: led[7:1] <= 7'b0000001;
                default:    led[7:1] <= 7'b0000000;
            endcase
        end
    end
endmodule

// Perform countdown before a chart starts
module countDown (
    input logic prog_clk, rst,
    output reg play_st,
    output reg [1:0] cnt_dn
);
    byte cnt;
    logic en;
    always @(posedge prog_clk) begin
        if (rst) begin
            cnt <= 0;
            en <= 1'b0;
            cnt_dn <= 2'b11;
        end
        else if (~en) begin
            if (cnt == 60) begin
                cnt <= 0;
                case (cnt_dn)
                    2'b11: cnt_dn <= 2'b10;
                    2'b10: cnt_dn <= 2'b01;
                    2'b01: cnt_dn <= 2'b00;
                    2'b00: en <= 1'b1;
                endcase
            end
            else cnt <= cnt + 1;
        end
    end
    assign play_st = en;
endmodule

/*
// Play notes(Generate square waves)
module notePlayer(
    input logic clk, rst,
    input Notes note,
    output logic sig
);
    integer wav_len;
    clkDiv wave_div(.clk(clk), .rst(rst), .divx(wav_len), .clk_out(sig));
    always @(posedge clk) begin
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
*/
