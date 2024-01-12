`include "header.svh"

module progClkGen (
	input logic clk, sys_rst,
	output logic prog_clk
);
    parameter FREQ_DIV = `SYS_FREQ / `PROG_FREQ;

	int cnt;
	always @(posedge clk)
		if (sys_rst || cnt == FREQ_DIV - 1)
			cnt <= 0;
		else
			cnt <= cnt + 1;
	assign prog_clk = cnt == 1;
endmodule

module main(
    // System clock and reset signals
    input logic clk, sys_rst_n,
    // PS2 keyboard in
    input logic ps2_clk, ps2_data,
    // Board in
    input logic [3:0] btn_arr, [6:0] btn_notes,
    input logic btn_oct_up, btn_oct_down, [1:0] sw_chart_id, [3:0] sw_user_id,
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
    logic[7:0] dummy_led;
    logic sys_rst;
    assign sys_rst = ~sys_rst_n;

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
        .sw_chart_id(sw_chart_id), .sw_user_id(sw_user_id),
        .user_in(user_in)
    );
    unifiedOutput output_handler(
        .clk(clk), .prog_clk(prog_clk), .sys_rst(sys_rst),
        .prog_out(prog_out),
        .audio_pwm(audio_pwm), .audio_sd(audio_sd),
        .seg(seg), .seg_sel(seg_sel),
        .led(dummy_led),
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

    logic [3:0] chart_addr; // DEBUG

    ChartStorageManager chart_storage(
        .clk(clk), .sys_rst(sys_rst),
        .read_chart_id(read_chart_id), .write_chart_id(write_chart_id),
        .new_chart_data(write_chart), .current_chart_data(read_chart),
        .chart_addr(chart_addr) // DEBUG
    );
    RecordStorageManager record_storage(
        .clk(clk), .sys_rst(sys_rst),
        .read_record_id(read_record_id), .write_record_id(write_record_id),
        .new_record_data(write_record), .current_record_data(read_record)
    );

    UserInput edged_user_in;
    edgeDetector edge_detector( .clk(prog_clk), .rst(sys_rst),
        .user_in(user_in), .edge_out(edged_user_in) );

    logic auto_play; // 0: normal play; 1: auto play
    logic free_play; // 0: normal play; 1: free play

    const UserInput default_user_in = '{default: '0};
    UserInput init_in, menu_in, history_in, play_in;
    logic init_rst, menu_rst, history_rst, play_rst;

    // Bind the pages
    pageInit page_init(
        .clk(clk), .prog_clk(prog_clk), .rst(init_rst), .user_in(init_in), .init_out(init_out)
    ); // pageInit resets things, loads charts from ROM then jumps to MENU
    pageMenu page_menu(
        .clk(clk), .prog_clk(prog_clk), .rst(menu_rst), .user_in(menu_in), .menu_out(menu_out),
        .read_chart_id(read_chart_id), .chart_data(read_chart),
        .auto_play(auto_play), .free_play(free_play), .cur_state(next_state)
    );
    pageScoreHistory page_history(
        .clk(clk), .prog_clk(prog_clk), .rst(history_rst), .user_in(history_in), .history_out(history_out),
        .read_record_id(read_record_id), .record_data(read_record)
    );
    pagePlayChart page_play(
        .clk(clk), .prog_clk(prog_clk), .rst(play_rst), .user_in(play_in), .play_out(play_out),
        .read_chart(read_chart), .auto_play(auto_play), .free_play(free_play),
        .write_chart_id(write_chart_id), .write_chart(write_chart),
        .write_record_id(write_record_id), .write_record(write_record)
    );

    /* State transitions:
     * INIT -> MENU
     * MENU <-> HISTORY
     * MENU -(chart_id, auto_play)-> PLAY -> MENU
     */

    always @(posedge prog_clk or posedge sys_rst)
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

        init_in = cur_state == INIT ? edged_user_in : default_user_in;
        menu_in = cur_state == MENU ? edged_user_in : default_user_in;
        history_in = cur_state == HISTORY ? edged_user_in : default_user_in;
        play_in = cur_state == PLAY ? user_in : default_user_in;

        next_state = sys_rst ? INIT : prog_out.state;

        rst = sys_rst || next_state != cur_state;
        init_rst = sys_rst || next_state == INIT ? rst : 0;
        menu_rst = sys_rst || next_state == MENU ? rst : 0;
        history_rst = sys_rst || next_state == HISTORY ? rst : 0;
        play_rst = sys_rst || next_state == PLAY ? rst : 0;

    end

/*
    assign led[0] = cur_state == INIT;
    assign led[1] = cur_state == MENU;
    assign led[2] = cur_state == HISTORY;
    assign led[3] = cur_state == PLAY;
    assign led[6] = rst;
    assign led[7] = sys_rst;
    */
    // assign led = dummy_led | chart_addr;
    assign led[3:0] = chart_addr; // DEBUG
    // I Don't know why but this does make everything WORK
endmodule
