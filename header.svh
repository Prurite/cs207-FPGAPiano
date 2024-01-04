`ifndef HEADER_SVH
`define HEADER_SVH

`timescale 1ns / 1ps

`define SYS_FREQ 100_000_000 // Hz
`define PROG_FREQ 60 // Hz

`define NAME_LEN 16
`define NOTE_WIDTH 7
`define CHART_LEN 2048
`define CHARTS_MAX 10
`define SCREEN_TEXT_WIDTH 60 // Shift right a bit, by 20 chars
`define SCREEN_TEXT_HEIGHT 30
`define NOTE_TIME 100 // ms
`define SEG_WIDTH 8
`define PLAY_RECS_MAX 10
`define MAX_DISPLAY_HEIGHT 16

`define VGA_WIDTH 640
`define VGA_HEIGHT 480

// Arrow keys
`define UP 4'b1000;
`define DOWN 4'b0100;
`define LEFT 4'b0010;
`define RIGHT 4'b0001;

// Wavelength of diffrent notes
`define C3  764467
`define C3s	721552
`define D3	681060
`define D3s 642839
`define E3	606759
`define F3	572704
`define F3s	540541
`define G3	510204
`define G3s	481580
`define A4	454545
`define A4s	429037
`define B4	404957

`define C4	382219
`define C4s	360776
`define D4	340530
`define D4s 321409
`define E4	303370
`define F4	286344
`define F4s	270278
`define G4	255102
`define G4s	240790
`define A5	227273
`define A5s	214519
`define B5	202478
 
`define C5	191113
`define C5s	180385
`define D5	170262
`define D5s 160707
`define E5	151685
`define F5	143172
`define F5s	135137
`define G5	127553
`define G5s	120393
`define A6	113636
`define A6s	107258
`define B6	101238

typedef bit [0:8*`SCREEN_TEXT_WIDTH-1] ScreenText [`SCREEN_TEXT_HEIGHT-1:0];
// An unpacked array of packed chars in ASCII
// Note that strings MUST be used with small index to the left
// ALWAYS pad the string literal to the expected length (32 chars)
// Example: ScreenText[0] <= "=====       Main Menu      ====="
// Then ScreenText[0][0:7] is "="
// Otherwise, verilog fills 0 from left (right-aligned)

typedef bit [7:0] LedState;
// A variable for controlling LED light

typedef bit [0:8*`SEG_WIDTH-1] SegDisplayText;
// A packed array of chars for controlling Seg Displays
// Using ASCII Code, Left 7 - 0 Right

typedef bit [`NOTE_WIDTH+1:0] Notes; 
// A packed array for notes
// [6:0] High to low, [7] octave up, [8] octave down

typedef enum { INIT, MENU, HISTORY, PLAY } TopState;
// An enum for top level state machine

typedef struct {
    bit [3:0] arrow_keys; // 0 - 3: U D L R
    bit [6:0] note_keys; // 0 - 6: C D E F G A B
    bit oct_up, oct_down; // +8 / -8
    bit [3:0] user_id; // Controlled by on board switches
} UserInput;
// Processed input from keyboard and board

typedef struct {
    ScreenText text;
    Notes notes;
    LedState led;
    SegDisplayText seg;
    TopState state;
} ProgramOutput;
// Output to all peripherals

typedef struct {
    bit [0:8*`NAME_LEN-1] name;
	shortint note_cnt;
} ChartInfo;

typedef struct {
    ChartInfo info;
    Notes notes [`CHART_LEN-1:0];
} Chart;

typedef struct {
    bit [3:0] user_id;
    bit [0:8*`NAME_LEN-1] chart_name;
    shortint score;
} PlayRecord;

`endif