`include "header.svh"

module edgeDetector (
    input logic clk, rst,
    input UserInput user_in,
    output UserInput edge_out
);
    UserInput user_in_reg;
    for (genvar i = 0; i < 4; i++)
        assign edge_out.arrow_keys[i] = user_in.arrow_keys[i] & ~user_in_reg.arrow_keys[i] & ~rst;
    for (genvar i = 0; i < 7; i++)
        assign edge_out.note_keys[i] = user_in.note_keys[i] & ~user_in_reg.note_keys[i] & ~rst;
    assign edge_out.oct_up = user_in.oct_up & ~user_in_reg.oct_up & ~rst;
    assign edge_out.oct_down = user_in.oct_down & ~user_in_reg.oct_down & ~rst;
    assign edge_out.user_id = user_in.user_id;
    assign edge_out.chart_id = user_in.chart_id;

    const UserInput default_user_in = '{default: '0};

    always @(posedge clk)
        if (rst) begin
            user_in_reg <= default_user_in;
        end else
            user_in_reg <= user_in;
endmodule

// Unified input processing func, physical signals => UserInput struct
module unifiedInput (
    input logic clk, prog_clk, sys_rst,
    // PS2 keyboard in
    input logic ps2_clk, ps2_data,
    // Board in
    input logic [3:0] btn_arr, [6:0] btn_notes,
    input logic btn_oct_up, btn_oct_down, [1:0] sw_chart_id, [3:0] sw_user_id,
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
        .sw_chart_id(sw_chart_id), .sw_user_id(sw_user_id),
        .board_in(board_in)
    );

    // assign user_in = board_in;

    // Merge the 2 inputs
    always_comb begin
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
        // User ID and Chart ID: only from board
        user_in.user_id = board_in.user_id;
        user_in.chart_id = board_in.chart_id;
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
    localparam CLOCK_DIVX = 70_000;
    logic seg_clk;

    clkDiv seg_clk_gen(
        .clk(clk), .rst(sys_rst),
        .divx(CLOCK_DIVX), .clk_out(seg_clk)
    );

    audioOutput audio_handler(
        .clk(clk), .sys_rst(sys_rst),
        .playing_notes(prog_out.notes),
        .audio_pwm(audio_pwm), .audio_sd(audio_sd)
    );

    segDisplayOutput seg_handler(
        .clk(seg_clk), .sys_rst(sys_rst),
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
module keyboardInput_Old (
    input logic clk, prog_clk, sys_rst,
    input logic ps2_clk, ps2_data,
    output UserInput keyboard_in
);
    // Local parameters for keycodes
    localparam KEY_1 = 8'h16, KEY_2 = 8'h1e, KEY_3 = 8'h26, KEY_4 = 8'h25,
        KEY_5 = 8'h2e, KEY_6 = 8'h36, KEY_7 = 8'h3d, KEY_MINUS = 8'h4e, KEY_PLUS = 8'h55;
    localparam KEY_UP = 8'h75, KEY_DOWN = 8'h72, KEY_LEFT = 8'h6b, KEY_RIGHT = 8'h74;
    localparam KEY_RELEASE = 8'hf0;

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

    logic ps2_clk_n;
    assign ps2_clk_n = ~ps2_clk;

    // PS/2 data state machine
    always @(posedge ps2_clk_n or posedge sys_rst)
        if (sys_rst) begin
            state <= IDLE; bit_count <= 4'd0; data_reg <= 8'h00; last_key <= 8'h00;
        end else
            case (state)
                IDLE: begin
                    last_key <= 8'h00;
                    if (!ps2_data) begin
                        state <= READ; bit_count <= 4'd0; data_reg <= 8'h00;
                    end
                end
                READ: begin
                    bit_count <= bit_count + 1;
                    data_reg <= {ps2_data, data_reg[7:1]};
                    if (bit_count == 4'd7)
                        state <= PARITY;
                end
                PARITY: begin
                    state <= STOP;
                end
                STOP: if (ps2_data) begin
                    last_key <= data_reg; state <= IDLE;
                end
                default:
                    state <= IDLE;
            endcase

    // Mapping keycodes to UserInput structure
    const UserInput default_keyboard_in = '{default: '0};

    always @(posedge clk)
        if (sys_rst) begin
            keyboard_in <= default_keyboard_in;
            keyboard_in_next <= default_keyboard_in;
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
                KEY_RELEASE: keyboard_in_next <= default_keyboard_in;
            endcase
            if (!prog_clk_sync[1] && prog_clk_sync[0]) begin // posedge of prog_clk
                keyboard_in <= keyboard_in_next;
                keyboard_in_next <= '{default: '0};
            end
        end
endmodule

// Keyboard input processing, new version
module keyboardInput (
    input logic clk, prog_clk, sys_rst,
    input logic ps2_clk, ps2_data,
    output UserInput keyboard_in
);
    // Local parameters for keycodes
    localparam KEY_1 = 8'h16, KEY_2 = 8'h1e, KEY_3 = 8'h26, KEY_4 = 8'h25,
        KEY_5 = 8'h2e, KEY_6 = 8'h36, KEY_7 = 8'h3d, KEY_MINUS = 8'h4e, KEY_PLUS = 8'h55;
    localparam KEY_UP = 8'h75, KEY_DOWN = 8'h72, KEY_LEFT = 8'h6b, KEY_RIGHT = 8'h74;
    localparam KEY_RELEASE = 8'hf0;

	reg read;				//this is 1 if still waits to receive more bits 
	reg [11:0] count_reading;		//this is used to detect how much time passed since it received the previous codeword
	reg PREVIOUS_STATE;			//used to check the previous state of the keyboard clock signal to know if it changed
	reg scan_err;				//this becomes one if an error was received somewhere in the packet
	reg [10:0] scan_code;			//this stores 11 received bits
	reg [7:0] CODEWORD;			//this stores only the DATA codeword
	reg TRIG_ARR;				//this is triggered when full 11 bits are received
	reg [3:0]COUNT;				//tells how many bits were received until now (from 0 to 11)
	reg TRIGGER = 0;			//This acts as a 250 times slower than the board clock. 
	reg [7:0]DOWNCOUNTER = 0;		//This is used together with TRIGGER - look the code

	//Set initial values
	initial begin
		PREVIOUS_STATE = 1;		
		scan_err = 0;		
		scan_code = 0;
		COUNT = 0;			
		CODEWORD = 0;
		read = 0;
		count_reading = 0;
	end

	always @(posedge clk) begin				//This reduces the frequency 250 times
		if (DOWNCOUNTER < 249) begin			//and uses variable TRIGGER as the new board clock 
			DOWNCOUNTER <= DOWNCOUNTER + 1;
			TRIGGER <= 0;
		end
		else begin
			DOWNCOUNTER <= 0;
			TRIGGER <= 1;
		end
	end
	
	always @(posedge clk) begin	
		if (TRIGGER) begin
			if (read)				//if it still waits to read full packet of 11 bits, then (read == 1)
				count_reading <= count_reading + 1;	//and it counts up this variable
			else 						//and later if check to see how big this value is.
				count_reading <= 0;			//if it is too big, then it resets the received data
		end
	end


	always @(posedge clk) begin		
	if (TRIGGER) begin						//If the down counter (clk/250) is ready
		if (ps2_clk != PREVIOUS_STATE) begin			//if the state of Clock pin changed from previous state
			if (!ps2_clk) begin				//and if the keyboard clock is at falling edge
				read <= 1;				//mark down that it is still reading for the next bit
				scan_err <= 0;				//no errors
				scan_code[10:0] <= {ps2_data, scan_code[10:1]};	//add up the data received by shifting bits and adding one new bit
				COUNT <= COUNT + 1;			//
			end
		end
		else if (COUNT == 11) begin				//if it already received 11 bits
			COUNT <= 0;
			read <= 0;					//mark down that reading stopped
			TRIG_ARR <= 1;					//trigger out that the full pack of 11bits was received
			//calculate scan_err using parity bit
			if (!scan_code[10] || scan_code[0] || !(scan_code[1]^scan_code[2]^scan_code[3]^scan_code[4]
				^scan_code[5]^scan_code[6]^scan_code[7]^scan_code[8]
				^scan_code[9]))
				scan_err <= 1;
			else 
				scan_err <= 0;
		end	
		else  begin						//if it yet not received full pack of 11 bits
			TRIG_ARR <= 0;					//tell that the packet of 11bits was not received yet
			if (COUNT < 11 && count_reading >= 4000) begin	//and if after a certain time no more bits were received, then
				COUNT <= 0;				//reset the number of bits received
				read <= 0;				//and wait for the next packet
			end
		end
	PREVIOUS_STATE <= ps2_clk;					//mark down the previous state of the keyboard clock
	end
	end

	always @(posedge clk) begin
		if (TRIGGER) begin					//if the 250 times slower than board clock triggers
			if (TRIG_ARR) begin				//and if a full packet of 11 bits was received
				if (scan_err) begin			//BUT if the packet was NOT OK
					CODEWORD <= 8'd0;		//then reset the codeword register
				end
				else begin
					CODEWORD <= scan_code[8:1];	//else drop down the unnecessary  bits and transport the 7 DATA bits to CODEWORD reg
				end				//notice, that the codeword is also reversed! This is because the first bit to received
			end					//is supposed to be the last bit in the codeword…
			else CODEWORD <= 8'd0;				//not a full packet received, thus reset codeword
		end
		else CODEWORD <= 8'd0;					//no clock trigger, no data…
	end

    // Mapping keycodes to UserInput structure
    const UserInput default_keyboard_in = '{default: '0};
    UserInput keyboard_in_next;

    logic prog_clk_sync[1:0];
    always_ff @(posedge clk) begin
        prog_clk_sync <= {prog_clk_sync[0], prog_clk};
    end

    reg [7:0] last_key; 

    always @(posedge prog_clk)
        if (sys_rst) begin
            keyboard_in <= default_keyboard_in;
            keyboard_in_next <= default_keyboard_in;
        end else if (TRIGGER && TRIG_ARR) begin
            last_key <= CODEWORD;
            if (last_key != KEY_RELEASE)
                case (CODEWORD)
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
                    KEY_RELEASE: keyboard_in_next <= default_keyboard_in;
                endcase
            if (!prog_clk_sync[1] && prog_clk_sync[0]) begin // posedge of prog_clk
                keyboard_in <= keyboard_in_next;
                keyboard_in_next <= default_keyboard_in;
            end
        end
endmodule


module boardInput (
    input logic clk, prog_clk, sys_rst,
    input logic [3:0] btn_arr, [6:0] btn_notes,
        btn_oct_up, btn_oct_down, [1:0] sw_chart_id, [3:0] sw_user_id,
    output UserInput board_in
);
    const UserInput default_board_in = '{default: '0};

    always @(posedge prog_clk)
        if (sys_rst)
            board_in <= default_board_in;
        else begin
            board_in.arrow_keys <= btn_arr;
            board_in.note_keys <= btn_notes;
            board_in.oct_up <= btn_oct_up;
            board_in.oct_down <= btn_oct_down;
            board_in.chart_id <= sw_chart_id + 2;
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

    always_ff @(posedge clk) begin
        // 1st group
        // text is an up vec, use up_vect[lsb_base_expr +: width_expr]
        case(text[(i-1)*8 +: 8])
            "0": seg[0] <= 8'b00111111; "1": seg[0] <= 8'b00000110; "2": seg[0] <= 8'b01011011;
            "3": seg[0] <= 8'b01001111; "4": seg[0] <= 8'b01100110; "5": seg[0] <= 8'b01101101;
            "6": seg[0] <= 8'b01111101; "7": seg[0] <= 8'b00000111; "8": seg[0] <= 8'b01111111;
            "9": seg[0] <= 8'b01101111;
            "a": seg[0] <= 8'b01110111; "b": seg[0] <= 8'b01111100; "c": seg[0] <= 8'b00111001;
            "d": seg[0] <= 8'b01011110; "e": seg[0] <= 8'b01111001; "f": seg[0] <= 8'b01110001;
            "g": seg[0] <= 8'b00111101; "h": seg[0] <= 8'b01110110; "i": seg[0] <= 8'b00000110;
            "j": seg[0] <= 8'b00011110; "k": seg[0] <= 8'b01110101; "l": seg[0] <= 8'b00111000;
            "m": seg[0] <= 8'b00010101; "n": seg[0] <= 8'b01010100; "o": seg[0] <= 8'b01011100;
            "p": seg[0] <= 8'b01110011; "q": seg[0] <= 8'b01100111; "r": seg[0] <= 8'b01010000;
            "s": seg[0] <= 8'b01101101; "t": seg[0] <= 8'b01111000; "u": seg[0] <= 8'b00111110;
            "v": seg[0] <= 8'b00011100; "w": seg[0] <= 8'b00010101; "x": seg[0] <= 8'b01110111;
            "y": seg[0] <= 8'b01101110; "z": seg[0] <= 8'b01011011;
            default: seg[0] <= 8'b10000000;
        endcase

        // 2nd group
        case(text[(4+i-1)*8 +: 8])
            "0": seg[1] <= 8'b00111111; "1": seg[1] <= 8'b00000110; "2": seg[1] <= 8'b01011011;
            "3": seg[1] <= 8'b01001111; "4": seg[1] <= 8'b01100110; "5": seg[1] <= 8'b01101101;
            "6": seg[1] <= 8'b01111101; "7": seg[1] <= 8'b00000111; "8": seg[1] <= 8'b01111111;
            "9": seg[1] <= 8'b01101111;
            "a": seg[1] <= 8'b01110111; "b": seg[1] <= 8'b01111100; "c": seg[1] <= 8'b00111001;
            "d": seg[1] <= 8'b01011110; "e": seg[1] <= 8'b01111001; "f": seg[1] <= 8'b01110001;
            "g": seg[1] <= 8'b00111101; "h": seg[1] <= 8'b01110110; "i": seg[1] <= 8'b00000110;
            "j": seg[1] <= 8'b00011110; "k": seg[1] <= 8'b01110101; "l": seg[1] <= 8'b00111000;
            "m": seg[1] <= 8'b00010101; "n": seg[1] <= 8'b01010100; "o": seg[1] <= 8'b01011100;
            "p": seg[1] <= 8'b01110011; "q": seg[1] <= 8'b01100111; "r": seg[1] <= 8'b01010000;
            "s": seg[1] <= 8'b01101101; "t": seg[1] <= 8'b01111000; "u": seg[1] <= 8'b00111110;
            "v": seg[1] <= 8'b00011100; "w": seg[1] <= 8'b00010101; "x": seg[1] <= 8'b01110111;
            "y": seg[1] <= 8'b01101110; "z": seg[1] <= 8'b01011011;
            default: seg[1] <= 8'b10000000;
        endcase
    end

    always @(posedge clk)
        if (sys_rst) begin
            i <= 4'd1;
            seg_sel[0] <= 4'b0;
            seg_sel[1] <= 4'b0;
        end else begin
            i <= i == 4'd4 ? 4'd1 : i + 4'd1;
            case(i)
                4'd1: seg_sel[0] <= 4'b0001;
                4'd2: seg_sel[0] <= 4'b0010;
                4'd3: seg_sel[0] <= 4'b0100;
                4'd4: seg_sel[0] <= 4'b1000;
                default: seg_sel[0] <= 4'b0000;
            endcase
            case(i)
                4'd1: seg_sel[1] <= 4'b0001;
                4'd2: seg_sel[1] <= 4'b0010;
                4'd3: seg_sel[1] <= 4'b0100;
                4'd4: seg_sel[1] <= 4'b1000;
                default: seg_sel[1] <= 4'b0000;
            endcase
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
    // Screen coordinates
    shortint pos_x, pos_y;
    ScreenText displayText;
    wire pixel_on;
    logic [11:0] color;

    // Pixel_On_Text2 instantiation
    Pixel_On_Text2_sv text_pixel (
        .clk(clk),
        .displayText(displayText),
        .positionX(0),  // Assuming text starts from the top-left corner
        .positionY(0),
        .horzCoord(pos_x),
        .vertCoord(pos_y),
        .pixel(pixel_on)
    );

    assign color = pixel_on ? 12'hfff : 12'h000;

    VGA_DRIVER(
        .clk(clk), .rst_n(sys_rst),
        .v_data(color),
        .red(vga_r), .green(vga_g), .blue(vga_b),
        .hsync(vga_hsync), .vsync(vga_vsync),
        .pos_x(pos_x), .pos_y(pos_y)
    );

    always @(posedge prog_clk)
        if (sys_rst)
            displayText <= '{default: '0};
        else
            displayText <= text;

endmodule