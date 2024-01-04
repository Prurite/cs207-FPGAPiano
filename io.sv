`include "header.svh"

// Unified input processing func, physical signals => UserInput struct
module unifiedInput (
    input logic clk, prog_clk, sys_rst,
    // PS2 keyboard in
    input logic ps2_clk, ps2_data,
    // Board in
    input logic [3:0] btn_arr, [6:0] btn_notes,
    input logic btn_oct_up, btn_oct_down, [3:0] sw_user_id,
    output UserInput user_in
);
    UserInput keyboard_in, board_in;

    keyboardInput keyboard_handler(
        .clk(clk), .prog_clk(prog_clk), .sys_rst(sys_rst),
        .ps2_clk(ps2_clk), .ps2_data(ps2_data),
        .keyboard_in(keyboard_in)
    );

    boardInput board_handler(
        .clk(clk), .prog_clk(prog_clk), .sys_rst(sys_rst),
        .btn_arr(btn_arr), .btn_notes(btn_notes),
        .btn_oct_up(btn_oct_up), .btn_oct_down(btn_oct_down),
        .sw_user_id(sw_user_id),
        .board_in(board_in)
    );

    always_comb begin
        if (sys_rst)
            user_in = '{default: '0};
        else begin // Merge the two inputs
            // Arrow keys: only 1 key may be pressed, priority: U D L R
            user_in.arrow_keys = keyboard_in.arrow_keys | board_in.arrow_keys;
            casex(user_in.arrow_keys)
                4'bxxx1: user_in.arrow_keys = 4'b0001;
                4'bxx10: user_in.arrow_keys = 4'b0010;
                4'bx100: user_in.arrow_keys = 4'b0100;
                4'b1000: user_in.arrow_keys = 4'b1000;
                default: user_in.arrow_keys = 4'b0000;
            endcase
            // Note keys: or together
            user_in.note_keys = keyboard_in.note_keys | board_in.note_keys;
            // Octave keys: only 1 key may be pressed, priority: +8 -8
            user_in.oct_up = keyboard_in.oct_up | board_in.oct_up;
            user_in.oct_down = (~user_in.oct_up)
                    & (keyboard_in.oct_down | board_in.oct_down);
            // User ID: only from board
            user_in.user_id = board_in.user_id;
        end
    end
endmodule

// Unified output processing func, ProgramOutput struct => physical signals
module unifiedOutput (
    input logic clk, prog_clk, sys_rst,
    input ProgramOutput prog_out,
    // PWM audio out
    output logic audio_pwm, audio_sd,
    // 7-seg display out, 2 groups, each 4 displays
    output logic [7:0] seg [1:0], logic [3:0] seg_sel [1:0],
    // LED out
    output logic [7:0] led,
    // VGA out
    output logic vga_hsync, vga_vsync,
        [3:0] vga_r, [3:0] vga_g, [3:0] vga_b
);
    audioOutput audio_handler(
        .clk(clk), .sys_rst(sys_rst),
        .playing_notes(prog_out.notes),
        .audio_pwm(audio_pwm), .audio_sd(audio_sd)
    );

    segDisplayOutput seg_handler(
        .clk(clk), .sys_rst(sys_rst),
        .text(prog_out.seg),
        .seg(seg), .seg_sel(seg_sel)
    );

    ledOutput led_handler(
        .clk(clk), .sys_rst(sys_rst),
        .led_state(prog_out.led),
        .led(led)
    );

    vgaOutput vga_handler(
        .clk(clk), .prog_clk(prog_clk), .sys_rst(sys_rst),
        .text(prog_out.text),
        .vga_hsync(vga_hsync), .vga_vsync(vga_vsync),
        .vga_r(vga_r), .vga_g(vga_g), .vga_b(vga_b)
    );
endmodule

// Keyboard input processing
module keyboardInput (
    input logic clk, prog_clk, sys_rst,
    input logic ps2_clk, ps2_data,
    output UserInput keyboard_in
);
    // Local parameters for keycodes
    localparam KEY_1 = 8'h16, KEY_2 = 8'h1e, KEY_3 = 8'h26, KEY_4 = 8'h25,
        KEY_5 = 8'h2e, KEY_6 = 8'h36, KEY_7 = 8'h3d, KEY_MINUS = 8'h4e, KEY_PLUS = 8'h55;
    localparam KEY_UP = 8'h75, KEY_DOWN = 8'h72, KEY_LEFT = 8'h6b, KEY_RIGHT = 8'h74;

    // State machine states for PS/2 protocol
    typedef enum { IDLE, READ, PARITY, STOP } PS2State;

    // Registers for handling PS/2 protocol
    logic [7:0] data_reg;
    logic [3:0] bit_count;
    PS2State state;

    // Intermediate signals
    logic [7:0] last_key;
    UserInput keyboard_in_next;

    // The PS/2 clock is much slower than the system clock, so we need to sync it
    // Also for the prog_clk; Use shift-registers to detect edges
    logic ps2_clk_sync [1:0], prog_clk_sync [1:0];
    always_ff @(posedge clk) begin
        ps2_clk_sync <= {ps2_clk_sync[0], ps2_clk};
        prog_clk_sync <= {prog_clk_sync[0], prog_clk};
    end

    // PS/2 data state machine
    always_ff @(posedge clk)
        if (sys_rst) begin
            state <= IDLE; bit_count <= 4'd0; data_reg <= 8'h00; last_key <= 8'h00;
        end else if (ps2_clk_sync[1] && !ps2_clk_sync[0]) // negedge of ps2_clk
            case (state)
                IDLE: begin
                    last_key <= 8'h00;
                    if (!ps2_data) begin
                        state <= READ; bit_count <= 4'd0; data_reg <= 8'h00;
                    end
                end
                READ: begin
                    bit_count <= bit_count + 1;
                    data_reg <= {data_reg[6:0], ps2_data};
                    if (bit_count == 4'd7)
                        state <= PARITY;
                end
                PARITY: state <= STOP;
                STOP: if (ps2_data) begin
                    last_key <= data_reg; state <= IDLE;
                end
                default:
                    state <= IDLE;
            endcase

    // Mapping keycodes to UserInput structure
    always_ff @(posedge clk)
        if (sys_rst) begin
            keyboard_in <= '{default: '0};
            keyboard_in_next <= '{default: '0};
        end else begin
            case (last_key)
                KEY_1: keyboard_in_next.note_keys[0] <= 1'b1;
                KEY_2: keyboard_in_next.note_keys[1] <= 1'b1;
                KEY_3: keyboard_in_next.note_keys[2] <= 1'b1;
                KEY_4: keyboard_in_next.note_keys[3] <= 1'b1;
                KEY_5: keyboard_in_next.note_keys[4] <= 1'b1;
                KEY_6: keyboard_in_next.note_keys[5] <= 1'b1;
                KEY_7: keyboard_in_next.note_keys[6] <= 1'b1;
                KEY_MINUS: keyboard_in_next.oct_down <= 1'b1;
                KEY_PLUS: keyboard_in_next.oct_up <= 1'b1;
                KEY_UP: keyboard_in_next.arrow_keys[0] <= 1'b1;
                KEY_DOWN: keyboard_in_next.arrow_keys[1] <= 1'b1;
                KEY_LEFT: keyboard_in_next.arrow_keys[2] <= 1'b1;
                KEY_RIGHT: keyboard_in_next.arrow_keys[3] <= 1'b1;
            endcase
            if (!prog_clk_sync[1] && prog_clk_sync[0]) begin // posedge of prog_clk
                keyboard_in <= keyboard_in_next;
                keyboard_in_next <= '{default: '0};
            end
        end
endmodule

module boardInput (
    input logic clk, prog_clk, sys_rst,
    input logic [3:0] btn_arr, [6:0] btn_notes,
        btn_oct_up, btn_oct_down, [3:0] sw_user_id,
    output UserInput board_in
);
    always_ff @(posedge prog_clk)
        if (sys_rst)
            board_in <= '{default: '0};
        else begin
            board_in.arrow_keys <= btn_arr;
            board_in.note_keys <= btn_notes;
            board_in.oct_up <= btn_oct_up;
            board_in.oct_down <= btn_oct_down;
            board_in.user_id <= sw_user_id;
        end
endmodule

module audioOutput (
    input logic clk, sys_rst,
    input Notes playing_notes,
    output logic audio_pwm, audio_sd
);
    assign audio_sd = 1'b1;

    // Local parameters for audio
    localparam int NOTES[0:21] = { // C3 to C5
        0,
        131, 147, 165, 175, 196, 220, 247,
        262, 294, 330, 349, 392, 440, 494,
        523, 587, 659, 698, 784, 880, 988
    };
    localparam int BASE = 7;

    byte note;
    int counter;
    
    // Convert Note struct to note from 0 to 20
    // Currently only support 1 note at a time
    always_comb begin
        casex(playing_notes)
            9'bxxxxxxxx1: note = 1;
            9'bxxxxxxx10: note = 2;
            9'bxxxxxx100: note = 3;
            9'bxxxxx1000: note = 4;
            9'bxxxx10000: note = 5;
            9'bxxx100000: note = 6;
            9'bxx1000000: note = 7;
            default: note = 0;
        endcase
        if (!note)
            note = 0;
        else if (playing_notes[7])
            note = note + 2 * BASE;
        else if (playing_notes[8])
            note = note;
        else
            note = note + BASE;
    end

    always @(posedge clk)
        if (sys_rst) begin
            counter <= 0;
            audio_pwm <= 0;
        end else if (!note || counter < `SYS_FREQ / NOTES[note])
            counter <= counter + 1;
        else begin
            counter <= 0;
            audio_pwm <= ~audio_pwm;
        end
endmodule

module segDisplayOutput (
    input logic clk, sys_rst,
    input SegDisplayText text,
    output logic [7:0] seg [1:0], logic [3:0] seg_sel [1:0]
);
    // Local parameters for 7-seg display
    logic [3:0] i; // 1 to 4; 0 off

    always_comb begin
        // 1st group
        // text is an up vec, use up_vect[msb_base_expr +: width_expr]
        case(text[i*8-1 +: 8])
            "0": seg[0] <= 7'b0111111; "1": seg[0] <= 7'b0000110; "2": seg[0] <= 7'b1011011;
            "3": seg[0] <= 7'b1001111; "4": seg[0] <= 7'b1100110; "5": seg[0] <= 7'b1101101;
            "6": seg[0] <= 7'b1111101; "7": seg[0] <= 7'b0000111; "8": seg[0] <= 7'b1111111;
            "9": seg[0] <= 7'b1101111;
            "a": seg[0] <= 7'b1110111; "b": seg[0] <= 7'b1111100; "c": seg[0] <= 7'b0111001;
            "d": seg[0] <= 7'b1011110; "e": seg[0] <= 7'b1111001; "f": seg[0] <= 7'b1110001;
            "g": seg[0] <= 7'b0111101; "h": seg[0] <= 7'b1110110; "i": seg[0] <= 7'b0000110;
            "j": seg[0] <= 7'b0011110; "k": seg[0] <= 7'b1110101; "l": seg[0] <= 7'b0111000;
            "m": seg[0] <= 7'b0010101; "n": seg[0] <= 7'b1010100; "o": seg[0] <= 7'b1011100;
            "p": seg[0] <= 7'b1110011; "q": seg[0] <= 7'b1100111; "r": seg[0] <= 7'b1010000;
            "s": seg[0] <= 7'b1101101; "t": seg[0] <= 7'b1111000; "u": seg[0] <= 7'b0111110;
            "v": seg[0] <= 7'b0011100; "w": seg[0] <= 7'b0010101; "x": seg[0] <= 7'b1110111;
            "y": seg[0] <= 7'b1101110; "z": seg[0] <= 7'b1011011;
            default: seg[0] <= 7'b0;
        endcase

        // 2nd group
        case(text[4*8 + i*8-1 +: 8])
            "0": seg[1] <= 7'b0111111; "1": seg[1] <= 7'b0000110; "2": seg[1] <= 7'b1011011;
            "3": seg[1] <= 7'b1001111; "4": seg[1] <= 7'b1100110; "5": seg[1] <= 7'b1101101;
            "6": seg[1] <= 7'b1111101; "7": seg[1] <= 7'b0000111; "8": seg[1] <= 7'b1111111;
            "9": seg[1] <= 7'b1101111;
            "a": seg[1] <= 7'b1110111; "b": seg[1] <= 7'b1111100; "c": seg[1] <= 7'b0111001;
            "d": seg[1] <= 7'b1011110; "e": seg[1] <= 7'b1111001; "f": seg[1] <= 7'b1110001;
            "g": seg[1] <= 7'b0111101; "h": seg[1] <= 7'b1110110; "i": seg[1] <= 7'b0000110;
            "j": seg[1] <= 7'b0011110; "k": seg[1] <= 7'b1110101; "l": seg[1] <= 7'b0111000;
            "m": seg[1] <= 7'b0010101; "n": seg[1] <= 7'b1010100; "o": seg[1] <= 7'b1011100;
            "p": seg[1] <= 7'b1110011; "q": seg[1] <= 7'b1100111; "r": seg[1] <= 7'b1010000;
            "s": seg[1] <= 7'b1101101; "t": seg[1] <= 7'b1111000; "u": seg[1] <= 7'b0111110;
            "v": seg[1] <= 7'b0011100; "w": seg[1] <= 7'b0010101; "x": seg[1] <= 7'b1110111;
            "y": seg[1] <= 7'b1101110; "z": seg[1] <= 7'b1011011;
            default: seg[1] <= 7'b0;
        endcase
    end

    always_ff @(posedge clk)
        if (sys_rst) begin
            i <= 1;
            seg_sel[0] <= 4'b0;
            seg_sel[1] <= 4'b0;
        end else begin
            i <= i == 4'd4 ? 4'd1 : i + 1;
            seg_sel[0] <= 1 << (i-1);
            seg_sel[1] <= 1 << (i-1);
        end

endmodule

module ledOutput (
    input logic clk, sys_rst,
    input LedState led_state,
    output logic [7:0] led
);
    for (genvar i = 0; i < 8; i++)
        assign led[i] = led_state[i];
endmodule

module vgaOutput (
    input logic clk, prog_clk, sys_rst,
    input ScreenText text,
    output logic vga_hsync, vga_vsync,
        [3:0] vga_r, [3:0] vga_g, [3:0] vga_b
);
    // VGA timing constants
    localparam H_SYNC_PULSE = 96;
    localparam H_BACK_PORCH = 48;
    localparam H_DISPLAY_TIME = `VGA_WIDTH;
    localparam H_FRONT_PORCH = 16;
    localparam H_LINE_TOTAL = H_SYNC_PULSE + H_BACK_PORCH + H_DISPLAY_TIME + H_FRONT_PORCH;

    localparam V_SYNC_PULSE = 2;
    localparam V_BACK_PORCH = 33;
    localparam V_DISPLAY_TIME = `VGA_HEIGHT;
    localparam V_FRONT_PORCH = 10;
    localparam V_FRAME_TOTAL = V_SYNC_PULSE + V_BACK_PORCH + V_DISPLAY_TIME + V_FRONT_PORCH;

    // Screen coordinates
    int h_count = 0;
    int v_count = 0;
    
    ScreenText displayText;

    // Pixel_On_Text2 instantiation
    wire pixel_on;
    
    Pixel_On_Text2_sv text_pixel (
        .clk(clk),
        .displayText(displayText),
        .positionX(0),  // Assuming text starts from the top-left corner
        .positionY(0),
        .horzCoord(h_count),
        .vertCoord(v_count),
        .pixel(pixel_on)
    );
    
    always_ff @(posedge prog_clk)
        if (sys_rst)
            displayText <= '{default: '0};
        else
            displayText <= text;

    always_ff @(posedge clk) begin
        if (sys_rst) begin
            h_count <= 0;
            v_count <= 0;
        end else begin
            // Horizontal count logic
            if (h_count < H_LINE_TOTAL - 1) begin
                h_count <= h_count + 1;
            end else begin
                h_count <= 0;
                // Vertical count logic
                if (v_count < V_FRAME_TOTAL - 1) begin
                    v_count <= v_count + 1;
                end else begin
                    v_count <= 0;
                end
            end

            // Generating sync signals
            vga_hsync <= (h_count >= H_SYNC_PULSE);
            vga_vsync <= (v_count >= V_SYNC_PULSE);

            // Generating RGB output
            if (h_count < H_DISPLAY_TIME && v_count < V_DISPLAY_TIME) begin
                if (pixel_on) begin
                    // White text
                    vga_r <= 4'b1111;
                    vga_g <= 4'b1111;
                    vga_b <= 4'b1111;
                end else begin
                    // Black background
                    vga_r <= 4'b0000;
                    vga_g <= 4'b0000;
                    vga_b <= 4'b0000;
                end
            end else begin
                // Black during blanking interval
                vga_r <= 4'b0000;
                vga_g <= 4'b0000;
                vga_b <= 4'b0000;
            end
        end
    end

endmodule