`include "header.svh"

module unifiedInput (
    input logic clk, sys_rst,
    // PS2 keyboard in
    input logic ps2_clk, ps2_data,
    // Board in
    input logic btn_arr [3:0], btn_notes [6:0],
        btn_oct_up, btn_oct_down, sw_user_id [3:0],
    output UserInput user_in
);
    UserInput keyboard_in, board_in;

    keyboardInput keyboard_handler(
        .clk(clk), .sys_rst(sys_rst),
        .ps2_clk(ps2_clk), .ps2_data(ps2_data),
        .keyboard_in(keyboard_in)
    );

    boardInput board_handler(
        .clk(clk), .sys_rst(sys_rst),
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

module unifiedOutput (
    input logic clk, sys_rst,
    input ProgramOutput prog_out,
    // PWM audio out
    output logic audio_pwm, audio_sd,
    // 7-seg display out, 2 groups, each 4 displays
    output logic [7:0] seg [1:0], logic [3:0] seg_sel [1:0],
    // LED out
    output logic led [7:0],
    // VGA out
    output logic vga_clk, vga_hsync, vga_vsync,
        vga_r [3:0], vga_g [3:0], vga_b [3:0]
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
        .clk(clk), .sys_rst(sys_rst),
        .text(prog_out.text),
        .vga_clk(vga_clk), .vga_hsync(vga_hsync), .vga_vsync(vga_vsync),
        .vga_r(vga_r), .vga_g(vga_g), .vga_b(vga_b)
    );
endmodule

module keyboardInput (
    input logic clk, sys_rst,
	input logic ps2_clk, ps2_data,
    output UserInput keyboard_in
);
endmodule

module boardInput (
    input logic clk, sys_rst,
	input logic btn_arr [3:0], btn_notes [6:0],
        btn_oct_up, btn_oct_down, sw_user_id [3:0],
    output UserInput board_in
);
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
