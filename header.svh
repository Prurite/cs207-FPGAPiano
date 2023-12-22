`timescale 1ns / 1ps

`define NAME_LEN 16
`define NOTE_WIDTH 7
`define CHART_LEN 2048
`define CHARTS_MAX 10
`define SCREEN_WIDTH 32
`define SCREEN_HEIGHT 30
`define NOTE_TIME 100 // ms
`define SEG_WIDTH 8
`define PLAY_RECS_MAX 10

typedef bit [0:8*`SCREEN_WIDTH-1] ScreenText [`SCREEN_HEIGHT-1:0];
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

typedef struct {
    ScreenText text;
    Notes notes;
    LedState led;
    SegDisplayText seg;
    TopState state;
} ProgramOutput;

typedef struct {
    bit [0:8*`NAME_LEN-1] name;
	shortint note_cnt;
} ChartInfo;

typedef struct {
    ChartInfo info;
    Note notes [`CHART_LEN-1:0];
} Chart;

typedef struct {
    bit [3:0] user_id;
    bit [0:8*`NAME_LEN-1] chart_name;
    shortint score;
} PlayRecord;