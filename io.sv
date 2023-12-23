`include "header.svh"

// Unified input processing func, physical signals => UserInput struct
module unifiedInput (
    input logic clk, prog_clk, sys_rst,
    // PS2 keyboard in
    input logic ps2_clk, ps2_data,
    // Board in
    input logic [3:0] btn_arr, [6:0] btn_notes,
        btn_oct_up, btn_oct_down, [3:0] sw_user_id,
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
            user_id.arrow_keys = keyboard_in.arrow_keys | board_in.arrow_keys;
            casex(user_id.arrow_keys)
                4'bxxx1: user_id.arrow_keys = 4'b0001;
                4'bxx10: user_id.arrow_keys = 4'b0010;
                4'bx100: user_id.arrow_keys = 4'b0100;
                4'b1000: user_id.arrow_keys = 4'b1000;
                default: user_id.arrow_keys = 4'b0000;
            endcase
            // Note keys: or together
            user_id.note_keys = keyboard_in.note_keys | board_in.note_keys;
            // Octave keys: only 1 key may be pressed, priority: +8 -8
            user_id.oct_up = keyboard_in.oct_up | board_in.oct_up;
            user_id.oct_down = (~user_id.oct_up)
                    & (keyboard_in.oct_down | board_in.oct_down);
            // User ID: only from board
            user_id.user_id = board_in.user_id;
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
    output logic vga_clk, vga_hsync, vga_vsync,
        [3:0] vga_r, [3:0] vga_g, [3:0] vga_b
);
    audioOutput audio_handler(
        .clk(clk), .prog_clk(prog_clk), .sys_rst(sys_rst),
        .playing_notes(prog_out.notes),
        .audio_pwm(audio_pwm), .audio_sd(audio_sd)
    );

    segDisplayOutput seg_handler(
        .clk(clk), .prog_clk(prog_clk), .sys_rst(sys_rst),
        .text(prog_out.seg),
        .seg(seg), .seg_sel(seg_sel)
    );

    ledOutput led_handler(
        .clk(clk), .prog_clk(prog_clk), .sys_rst(sys_rst),
        .led_state(prog_out.led),
        .led(led)
    );

    vgaOutput vga_handler(
        .clk(clk), .prog_clk(prog_clk), .sys_rst(sys_rst),
        .text(prog_out.text),
        .vga_clk(vga_clk), .vga_hsync(vga_hsync), .vga_vsync(vga_vsync),
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

    // PS/2 clock sync
    logic ps2_clk_sync;
    always_ff @(posedge clk)
        ps2_clk_sync <= ps2_clk;

    // PS/2 data state machine
    always_ff @(posedge clk or posedge sys_rst)
        if (sys_rst) begin
            state <= IDLE; bit_count <= 4'd0; data_reg <= 8'h00;
        end else if (ps2_clk_sync)
            case (state)
                IDLE: if (!ps2_data) begin
                    state <= READ; bit_count <= 4'd0; data_reg <= 8'h00;
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
            endcase

    // Mapping received data to UserInput structure
    always_ff @(posedge prog_clk or posedge sys_rst)
        if (sys_rst)
            keyboard_in = '{default: '0};
        else begin
            keyboard_in_next = '{default: '0};
            case (last_key)
                KEY_1: keyboard_in_next.note_keys[0] = 1'b1;
                KEY_2: keyboard_in_next.note_keys[1] = 1'b1;
                KEY_3: keyboard_in_next.note_keys[2] = 1'b1;
                KEY_4: keyboard_in_next.note_keys[3] = 1'b1;
                KEY_5: keyboard_in_next.note_keys[4] = 1'b1;
                KEY_6: keyboard_in_next.note_keys[5] = 1'b1;
                KEY_7: keyboard_in_next.note_keys[6] = 1'b1;
                KEY_MINUS: keyboard_in_next.oct_down = 1'b1;
                KEY_PLUS: keyboard_in_next.oct_up = 1'b1;
                KEY_UP: keyboard_in_next.arrow_keys[0] = 1'b1;
                KEY_DOWN: keyboard_in_next.arrow_keys[1] = 1'b1;
                KEY_LEFT: keyboard_in_next.arrow_keys[2] = 1'b1;
                KEY_RIGHT: keyboard_in_next.arrow_keys[3] = 1'b1;
            endcase
            keyboard_in = keyboard_in_next;
        end

endmodule

module boardInput (
    input logic clk, prog_clk, sys_rst,
    input logic [3:0] btn_arr, [6:0] btn_notes,
        btn_oct_up, btn_oct_down, [3:0] sw_user_id,
    output UserInput board_in
);
    always_ff @(posedge prog_clk or posedge sys_rst)
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
endmodule

module segDisplayOutput (
    input logic clk, sys_rst,
    input SegDisplayText text,
    output logic [7:0] seg [1:0], logic [3:0] seg_sel [1:0]
);
endmodule

module ledOutput (
    input logic clk, sys_rst,
    input LedState led_state,
    output logic led [7:0]
);
endmodule

module vgaOutput (
    input logic clk, sys_rst,
    input ScreenText text,
    output logic vga_clk, vga_hsync, vga_vsync,
        vga_r [3:0], vga_g [3:0], vga_b [3:0]
);
endmodule
