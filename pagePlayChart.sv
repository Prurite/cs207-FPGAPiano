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
    // Output sound signal, connected directly to notePlayer
    logic sig = 1'b0;

    // Status control
    logic play_en;
    logic play_st = 1'b0, fin_en = 1'b1;
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
    screenOut screen_out(.prog_clk(prog_clk), .rst(rst), .chart(read_chart), .note_count(note_count), .score(cur_score), .play_st(play_st), .text(text), .seg_text(play_out.seg), .led(play_out.led));
    
    // Countdown func (3s before start)
    wire [1:0] cnt_dn;
    countDown cd(.clk(clk), .rst(rst), .en(play_st), .cnt_dn(cnt_dn));
    
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
            play_st <= 1'b0;
            fin_en <= 1'b1;
        end
        else if (play_en) begin
            if (note_count == read_chart.info.note_count) fin_en <= 1'b0;
            note_count <= note_count + 1;
            cur_note <= notes[note_count];
            un[note_count] <= {user_in.oct_down, user_in.oct_up, user_in.note_keys};
        end
    end
    assign uinc = '{read_chart.info, un};
    assign play_record = '{user_in.user_id, read_chart.info.name, cur_score};

    // Management after play ends
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= PLAY;
        end
        else begin
            // Exit
            if (user_in.arrow_keys == 4'b0010) state <= MENU;
            if (fin_en) begin
                if (user_in.arrow_keys == 4'b0001) begin
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
    scoreManager sc_m(.clk(clk), .prog_clk(prog_clk), .rst(rst), .play_en(play_en), .user_in(user_in), .chart(read_chart), .note_count(note_count), .score(cur_score));
    
    assign play_out.text = text;
    assign play_out.notes = cur_note;
    assign play_out.state = state;
endmodule

// Manage total screen output
module screenOut(
    input logic prog_clk, rst,
    input Chart chart,
    input shortint note_count,
    input [13:0] score,
    input [1:0] cnt_dn,
    input logic play_st,
    output ScreenText text,
    output SegDisplayText seg_text,
    output LedState led
);
    ScreenText note_area;
    SegDisplayText seg;
    initial begin
        // Title display
        text[2]  = "=====    Playing Chart    ===== ";
        text[4]  = "Current User ID: 0              ";
        text[5]  = "Playing: -                      ";
        text[6]  = "Save to chart ID: 0             ";
        // Progress & Score display
        text[8]  = "Prog.    0 /    0    Score     0";
        // Line 10-25 display notes
        text[27] = "    C  D  E  F  G  A  B   =     ";
        text[29] = "[^] Hi [v] Lo [<] Exit  [>] Save";
    end
    noteAreaController ctrl(.prog_clk(prog_clk), .rst(rst), .en(play_st), .cnt_dn(cnt_dn), .note_count(note_count), .notes(chart.notes), .play_st(play_st), .text(note_area), .led(led));
    assign text[10:25] = note_area[0:15];
    // Display Info (Line 8, Col 7~10, 14~17, 28~32)
    wire [39:0] sc_str, cnt_str, len_str;
    binary2Str b2sc(.intx(score), .str(sc_str));
    binary2Str b2sn(.intx(note_count), .str(cnt_str));
    binary2Str b2snc(.intx(chart.note_count), .str(len_str));
    assign text[8][27*8:32*8 - 1] = sc_str;
    assign text[8][13*8:17*8 - 1] = len_str[31:0];
    assign text[8][6*8:10*8 - 1] = cnt_str[31:0];
    assign seg[0:2*8 - 1] = "SC";
    assign seg[3*8:8*8 - 1] = sc_str;
    assign seg_text = seg;
    //Display chart name
    assign text[5][9*8:(9+`NAME_LEN)*8 - 1] = chart.info.name;
endmodule

// Return realtime score according to user input
module scoreManager (
    input logic clk, prog_clk, rst, play_en,
    input UserInput user_in,
    input Chart chart,
    input shortint note_count,
    output reg [13:0] score
);
    // Perfect 50ms 10p, Great 100ms 8p, Good 150ms 5p, Miss 200ms+ 0p.

    // Scan every 50ms
    logic clk50ms = 1'b0;
    clkDiv clk50(.clk(clk), .rst(rst), .divx(5_000_000), .clk_out(clk50ms));
    Notes uin [chart.info.note_cnt * 2 - 1:0];
    Notes cur_note, cur_in;
    shortint uc;
    always @(posedge clk50ms or posedge rst) begin
        if (rst) begin
            clk50ms = 1'b0;
            score = 14'd0;
            uc = 0;
        end
        else if (play_en) begin
            cur_in = {user_in.oct_down, user_in.oct_up, user_in.note_keys};
            cur_note = chart.notes[note_count];
            if (cur_note == cur_in | cur_note == uin[uc - 1]) score = score + 10;
            else if (cur_note == uin[uc - 2]) score = score + 8;
            else if (cur_note == uin[uc - 3]) score = score + 5;
            uin[uc] = cur_in;
            uc = uc + 1;
        end
    end
endmodule

// Manage note area output
module noteAreaController(
    input logic prog_clk, rst, en,
    input [1:0] cnt_dn,
    input shortint note_count,
    input Notes [0:`MAX_DISPLAY_HEIGHT - 1] notes,
    input logic play_st,
    // Only [10:25] is modified
    output ScreenText text,
    output LedState led
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
                    text = "";
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
    displayLed dd(.prog_clk(prog_clk), .rst(rst), .en(en), .cur_note(notes[cnt]), .led(led));
endmodule

// Display each line in note area
module displayLine(
    input logic prog_clk, rst, en,
    input Notes cur_note,
    input logic is_line,
    output reg [0:`SCREEN_TEXT_WIDTH * 8 - 1] line
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

// Control led output
module displayLed(
    input logic prog_clk, rst, en,
    input Notes cur_note,
    output LedState led
);
    always @(posedge prog_clk or posedge rst) begin
        if (rst) led = 8'b0000_0000;
        else if (en) begin
            case (cur_note)
                9'b00_xxxxxxx: led[0] = 1'b0;
                9'b01_xxxxxxx: led[0] = 1'b1;
                9'b10_xxxxxxx: led[0] = 1'b1;
                default: led[0] = 1'b0;
            endcase
            case (cur_note)
                9'bxx_0000001: led[7:1] = 7'b1000000;
                9'bxx_0000010: led[7:1] = 7'b0100000;
                9'bxx_0000100: led[7:1] = 7'b0010000;
                9'bxx_0001000: led[7:1] = 7'b0001000;
                9'bxx_0010000: led[7:1] = 7'b0000100;
                9'bxx_0100000: led[7:1] = 7'b0000010;
                9'bxx_1000000: led[7:1] = 7'b0000010;
            endcase
        end
    end
endmodule

// Perform countdown before a chart starts
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
                    2'b11: cnt_dn <= 2'b10;
                    2'b10: cnt_dn <= 2'b01;
                    2'b01: cnt_dn <= 2'b00;
                    2'b00: en <= 1'b1;
                endcase
            end
        end
    end
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