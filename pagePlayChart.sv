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
    output PlayRecord write_record
);
    localparam UP = `UP;
    localparam DOWN = `DOWN;
    localparam LEFT = `LEFT;
    localparam RIGHT = `RIGHT;

    // Output sound signal, connected directly to notePlayer
    logic sig = 1'b0;

    // Status control
    logic play_en, play_st, fin_en;
    assign play_en = play_st & fin_en;
    
    // Iterate notes 
    shortint note_count;
    Notes notes [`CHART_LEN-1:0];
    Notes cur_note;

    // Records score.
    wire [13:0] cur_score;
    
    ScreenText text;

    TopState state;

    assign notes = read_chart.notes;

    // Instanciate current player
    notePlayer note_player(.clk(clk), .rst(rst), .note(cur_note), .sig(sig));

    // Get screen output
    screenOut screen_out(.prog_clk(prog_clk), .rst(rst), .chart(read_chart), .note_count(note_count), .user_in(user_in), .score(cur_score), .play_st(play_st), .text(text), .seg_text(play_out.seg), .led(play_out.led));
    
    // Countdown func (3s before start)
    wire [1:0] cnt_dn;
    countDown cd(.clk(clk), .rst(rst), .play_st(play_st), .cnt_dn(cnt_dn));
    
    // Record chart
    Chart uinc;
    Notes un [`CHART_LEN-1:0];
    // Record play status
    PlayRecord play_record;
    // Refresh current note every 100ms
    logic clk_100ms;
    clkDiv div100(.clk(clk), .rst(rst), .divx(10_000_000), .clk_out(clk_100ms));
    always @(posedge clk_100ms or posedge rst) begin
        if (rst) begin
            note_count <= 0;
            cur_note <= 9'b00_0000000;
            sig <= 1'b0;
        end
        else if (play_en) begin
            if (note_count == read_chart.info.note_cnt) fin_en <= 1'b0;
            note_count <= note_count + 1;
            cur_note <= notes[note_count];
            un[note_count] <= {user_in.oct_down, user_in.oct_up, user_in.note_keys};
        end
    end
    assign uinc.info = read_chart.info;
    assign uinc.notes = un; 
    assign play_record = '{user_in.user_id, read_chart.info.name, cur_score};

    // Management after play ends
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= PLAY;
        end
        else begin
            // Exit
            if (user_in.arrow_keys == LEFT) state <= MENU;
            // Save
            if (fin_en) begin
                if (user_in.arrow_keys == RIGHT) begin
                    // Save chart
                    write_chart_id <= 1;
                    write_chart <= uinc;
                    // Save score
                    write_record_id <= 1;
                    write_record <= play_record;
                    state <= MENU;
                end
            end
        end
    end

    // Instanciate score manager
    scoreManager sc_m(.clk(clk), .prog_clk(prog_clk), .rst(rst), .play_en(play_en), .auto_play(auto_play), .user_in(user_in), .chart(read_chart), .note_count(note_count), .score(cur_score));
    
    assign play_out.text = text;
    assign play_out.notes = cur_note;
    assign play_out.state = state;
endmodule

// Manage total screen output
module screenOut(
    input logic prog_clk, rst,
    input Chart chart,
    input shortint note_count,
    input UserInput user_in,
    input [13:0] score,
    input [1:0] cnt_dn,
    input logic play_st,
    output ScreenText text,
    output SegDisplayText seg_text,
    output LedState led
);
    ScreenText note_area;
    
    wire [39:0] sc_str, cnt_str, len_str, uid_raw;
    // Display Info (Line 8, Col 7~10, 14~17, 28~32)    
    binary2Str b2sc(.intx(score), .str(sc_str));
    binary2Str b2sn(.intx(note_count), .str(cnt_str));
    binary2Str b2snc(.intx(chart.info.note_cnt), .str(len_str));
    binary2Str b2suid(.intx(user_in.user_id), .str(uid_raw));
    always @(posedge prog_clk or posedge rst) begin
        if (rst) begin
            // Title display
            text[2]  = "=====    Playing Chart    ===== ";
            text[4]  = "Current User ID: 0              ";
            text[5]  = "Playing: -                      ";
            text[6]  = "Save to chart ID: 1             ";
            // Progress & Score display
            text[8]  = "Prog.    0 /    0    Score     0";
            // Line 10-25 display notes
            text[27] = "    C  D  E  F  G  A  B   =     ";
            text[29] = "[+] Hi [-] Lo [<] Exit  [>] Save";
        end
        else begin
            // Display prog info
            text[8][0:32*8-1] = {"Prog. ", cnt_str[31:0], " / ", len_str[31:0], "    Score ", sc_str};
            // Display chart info
            text[4][17*8:18*8-1] = uid_raw[7:0];
            text[5][9*8:(9+`NAME_LEN)*8 - 1] = chart.info.name;
        end
    end
    noteAreaController ctrl(.prog_clk(prog_clk), .rst(rst), .en(play_st), .cnt_dn(cnt_dn), .note_cnt(note_count), .notes(chart.notes), .play_st(play_st), .text(note_area), .seg(seg_text), .led(led));
    assign text[10:25] = note_area[10:25];
endmodule

// Return realtime score according to user input
module scoreManager (
    input logic clk, prog_clk, rst, play_en, auto_play,
    input UserInput user_in,
    input Chart chart,
    input shortint note_count,
    output reg [13:0] score
);
    // Perfect 50ms 10p, Great 100ms 8p, Good 150ms 5p, Miss 200ms+ 0p.

    // Scan every 50ms
    logic clk50ms = 1'b0;
    clkDiv clk50(.clk(clk), .rst(rst), .divx(5_000_000), .clk_out(clk50ms));
    Notes uin [`CHART_LEN - 1:0];
    Notes cur_note, cur_in;
    shortint uc;
    always @(posedge clk50ms or posedge rst) begin
        if (rst) begin
            clk50ms = 1'b0;
            score = 14'd0;
            uc = 0;
        end
        else if (play_en) begin
            if (auto_play) score = score + 10;
            else begin
                cur_in = {user_in.oct_down, user_in.oct_up, user_in.note_keys};
                cur_note = chart.notes[note_count];
                if (cur_note == cur_in | cur_note == uin[uc - 1]) score = score + 10;
                else if (cur_note == uin[uc - 2]) score = score + 8;
                else if (cur_note == uin[uc - 3]) score = score + 5;
                uin[uc] = cur_in;
                uc = uc + 1;
            end
        end
    end
endmodule

// Manage note area output
module noteAreaController(
    input logic prog_clk, rst, en,
    input [1:0] cnt_dn,
    input shortint note_cnt,
    input Notes notes [`CHART_LEN-1:0],
    input logic play_st,
    // Only [10:25] is modified
    output ScreenText text,
    output SegDisplayText seg,
    output LedState led
);
    ScreenText temp_text;
    const ScreenText text_init = '{default: '0};
    // Display countdown
    always @(posedge prog_clk) begin
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
                    text = text_init;
            endcase
        end
        else begin
            text[10:25] = temp_text[10:25];
        end
    end
    
    shortint note_id; // Make sure it does not go out of bound
    assign note_id = (note_cnt+15) >= `CHART_LEN ? `CHART_LEN-16 : note_cnt;

    // Display seg
    always @(posedge prog_clk or posedge rst) begin
        if (rst) seg <= "        ";
        else if (en) case (notes[note_cnt])
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
    displayLine l25(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_id + 15]), .is_line(1'b1), .line(temp_text[25]));
    displayLine l24(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_id + 14]), .is_line(1'b0), .line(temp_text[24]));
    displayLine l23(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_id + 13]), .is_line(1'b0), .line(temp_text[23]));
    displayLine l22(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_id + 12]), .is_line(1'b0), .line(temp_text[22]));
    displayLine l21(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_id + 11]), .is_line(1'b0), .line(temp_text[21]));
    displayLine l20(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_id + 10]), .is_line(1'b0), .line(temp_text[20]));
    displayLine l19(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_id + 9]), .is_line(1'b0), .line(temp_text[19]));
    displayLine l18(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_id + 8]), .is_line(1'b0), .line(temp_text[18]));
    displayLine l17(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_id + 7]), .is_line(1'b0), .line(temp_text[17]));
    displayLine l16(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_id + 6]), .is_line(1'b0), .line(temp_text[16]));
    displayLine l15(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_id + 5]), .is_line(1'b0), .line(temp_text[15]));
    displayLine l14(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_id + 4]), .is_line(1'b0), .line(temp_text[14]));
    displayLine l13(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_id + 3]), .is_line(1'b0), .line(temp_text[13]));
    displayLine l12(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_id + 2]), .is_line(1'b0), .line(temp_text[12]));
    displayLine l11(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_id + 1]), .is_line(1'b0), .line(temp_text[11]));
    displayLine l10(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_id]), .is_line(1'b0), .line(temp_text[10]));
    displayLed dd(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[note_id]), .led(led));
endmodule


// Display each line in note area
module displayLine(
    input logic prog_clk, rst, en,
    input Notes cur_note,
    input logic is_line,
    output reg [0:`SCREEN_TEXT_WIDTH * 8 - 1] line
);
    reg [0 : 23 * 8 - 1] line_notes;

    always @(posedge prog_clk or posedge rst) begin
        if (rst || !en)
            line_notes = "                       ";
        else begin
            case (cur_note)
                //                            C  D  E  F  G  A  B   O
                9'b00_0000001:  line_notes = "#  .  .  .  .  .  .   .";
                9'b00_0000010:  line_notes = ".  #  .  .  .  .  .   .";
                9'b00_0000100:  line_notes = ".  .  #  .  .  .  .   .";
                9'b00_0001000:  line_notes = ".  .  .  #  .  .  .   .";
                9'b00_0010000:  line_notes = ".  .  .  .  #  .  .   .";
                9'b00_0100000:  line_notes = ".  .  .  .  .  #  .   .";
                9'b00_1000000:  line_notes = ".  .  .  .  .  .  #   .";
                9'b01_0000001:  line_notes = "#  .  .  .  .  .  .   +";
                9'b01_0000010:  line_notes = ".  #  .  .  .  .  .   +";
                9'b01_0000100:  line_notes = ".  .  #  .  .  .  .   +";
                9'b01_0001000:  line_notes = ".  .  .  #  .  .  .   +";
                9'b01_0010000:  line_notes = ".  .  .  .  #  .  .   +";
                9'b01_0100000:  line_notes = ".  .  .  .  .  #  .   +";
                9'b01_1000000:  line_notes = ".  .  .  .  .  .  #   +";
                9'b10_0000001:  line_notes = "#  .  .  .  .  .  .   -";
                9'b10_0000010:  line_notes = ".  #  .  .  .  .  .   -";
                9'b10_0000100:  line_notes = ".  .  #  .  .  .  .   -";
                9'b10_0001000:  line_notes = ".  .  .  #  .  .  .   -";
                9'b10_0010000:  line_notes = ".  .  .  .  #  .  .   -";
                9'b10_0100000:  line_notes = ".  .  .  .  .  #  .   -";
                9'b10_1000000:  line_notes = ".  .  .  .  .  .  #   -";
                default:        line_notes = ".  .  .  .  .  .  .   .";
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
    always @(posedge prog_clk or posedge rst) begin
        if (rst) led = 8'b0000_0000;
        else if (en) begin
            case (cur_note[8:7])
                2'b00:      led[0] = 1'b0;
                2'b01:      led[0] = 1'b1;
                2'b10:      led[0] = 1'b1;
                default:    led[0] = 1'b0;
            endcase
            case (cur_note[6:0])
                7'b0000001: led[7:1] = 7'b1000000;
                7'b0000010: led[7:1] = 7'b0100000;
                7'b0000100: led[7:1] = 7'b0010000;
                7'b0001000: led[7:1] = 7'b0001000;
                7'b0010000: led[7:1] = 7'b0000100;
                7'b0100000: led[7:1] = 7'b0000010;
                7'b1000000: led[7:1] = 7'b0000001;
                default:    led[7:1] = 7'b0000000;
            endcase
        end
    end
endmodule

// Perform countdown before a chart starts
module countDown (
    input logic clk, rst,
    output reg play_st,
    output reg [1:0] cnt_dn
);
    byte cnt;
    logic clk_100ms, en;
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
                    2'b11: cnt_dn <= 2'b10;
                    2'b10: cnt_dn <= 2'b01;
                    2'b01: cnt_dn <= 2'b00;
                    2'b00: en <= 1'b1;
                endcase
            end
        end
    end
    assign play_st = en;
endmodule

// Play notes(Generate square waves)
module notePlayer(
    input logic clk, rst,
    input Notes note,
    output logic sig
);
    integer wav_len;
    clkDiv wave_div(.clk(clk), .rst(rst), .divx(wav_len), .clk_out(sig));
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
