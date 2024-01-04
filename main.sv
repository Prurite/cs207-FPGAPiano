`include "header.svh"

module progClkGen (
	input logic clk, sys_rst,
	output logic prog_clk
);
    parameter FREQ_DIV = `SYS_FREQ / `PROG_FREQ;

	shortint cnt;
	always @(posedge clk)
		if (sys_rst || cnt == FREQ_DIV - 1)
			cnt <= 0;
		else
			cnt <= cnt + 1;
	assign prog_clk = cnt == 1;
endmodule

module main(
    // System clock and reset signals
    input logic clk, sys_rst,
    // PS2 keyboard in
    input logic ps2_clk, ps2_data,
    // Board in
    input logic [3:0] btn_arr, [6:0] btn_notes,
    input logic btn_oct_up, btn_oct_down, [3:0] sw_user_id,
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
	// Generate the program clock, used to sync all program logic
	// The system clock is used for IO
	logic prog_clk;
	progClkGen prog_clk_gen(
		.clk(clk), .sys_rst(sys_rst),
		.prog_clk(prog_clk)
	);

    // Bind the unified input and output controls
    UserInput user_in;
    ProgramOutput prog_out;

    unifiedInput input_handler(
        .clk(clk), .prog_clk(prog_clk), .sys_rst(sys_rst),
        .ps2_clk(ps2_clk), .ps2_data(ps2_data),
        .btn_arr(btn_arr), .btn_notes(btn_notes),
        .btn_oct_up(btn_oct_up), .btn_oct_down(btn_oct_down),
        .sw_user_id(sw_user_id),
        .user_in(user_in)
    );
    unifiedOutput output_handler(
        .clk(clk), .prog_clk(prog_clk), .sys_rst(sys_rst),
        .prog_out(prog_out),
        .audio_pwm(audio_pwm), .audio_sd(audio_sd),
        .seg(seg), .seg_sel(seg_sel),
        .led(led),
        .vga_hsync(vga_hsync), .vga_vsync(vga_vsync),
        .vga_r(vga_r), .vga_g(vga_g), .vga_b(vga_b)
    );
    
    // Local variables
    logic rst = 0;
    ProgramOutput init_out, menu_out, history_out, play_out;
    TopState cur_state = INIT, next_state = MENU;
    
    // Chart and play record storage
    byte read_chart_id, write_chart_id;
    byte read_record_id, write_record_id;
    Chart read_chart, write_chart;
    PlayRecord read_record, write_record;

    /* Storage Management:
     * Only pageMenu may read charts,
     * and pass the selected chart to pagePlayChart.
     * Only pageHistory may read records.
     * Only pagePlayChart may write charts or records.
     * When id is not 0, the storage manager will read or write accordingly.
     */

    ChartStorageManager chart_storage(
        .clk(clk), .sys_rst(sys_rst),
        .read_chart_id(read_chart_id), .write_chart_id(write_chart_id),
        .new_chart_data(write_chart), .current_chart_data(read_chart)
    );
    RecordStorageManager record_storage(
        .clk(clk), .sys_rst(sys_rst),
        .read_record_id(read_record_id), .write_record_id(write_record_id),
        .new_record_data(write_record), .current_record_data(read_record)
    );

    logic auto_play; // 0: normal play; 1: auto play

    // Bind the pages
    pageInit page_init(
        .clk(clk), .prog_clk(prog_clk), .rst(rst), .user_in(user_in), .init_out(init_out)
    ); // pageInit resets things, loads charts from ROM then jumps to MENU
    pageMenu page_menu(
        .clk(clk), .prog_clk(prog_clk), .rst(rst), .user_in(user_in), .menu_out(menu_out),
        .read_chart_id(read_chart_id), .chart_data(read_chart),
        .auto_play(auto_play)
    );
    pageScoreHistory page_history(
        .clk(clk), .prog_clk(prog_clk), .rst(rst), .user_in(user_in), .history_out(history_out),
        .read_record_id(read_record_id), .record_data(read_record)
    );
    pagePlayChart page_play(
        .clk(clk), .prog_clk(prog_clk), .rst(rst), .user_in(user_in), .play_out(play_out),
        .read_chart(read_chart), .auto_play(auto_play),
        .write_chart_id(write_chart_id), .write_chart(write_chart),
        .write_record_id(write_record_id), .write_record(write_record)
    );

    /* State transitions:
     * INIT -> MENU
     * MENU <-> HISTORY
     * MENU -(chart_id, auto_play)-> PLAY -> MENU
     */

    always @(posedge prog_clk)
        if (sys_rst)
            cur_state <= INIT;
        else
            cur_state <= next_state;
    
    always_comb begin
        case (cur_state)
            INIT: prog_out = init_out;
            MENU: prog_out = menu_out;
            HISTORY: prog_out = history_out;
            PLAY: prog_out = play_out;
            default: prog_out = init_out;
        endcase
        next_state = prog_out.state;
        rst = next_state != cur_state;
    end
    
endmodule
