# 数字逻辑 project specifications

## 输入及输出

输入：板子上开关/按键输入，键盘输入；
输出：3.5mm 输出，7段数码管，LED灯，VGA

## 模块分配

页面层级：

```
1 主菜单
	键位设置
	历史分数
	自由演奏
    谱面选择

2 历史分数
	显示历史 x 条成绩：用户 id，谱面名和得分

3 演奏页面
	上方：谱面名，当前音符数 / 总音符数，评级
	中间：谱面显示区
	下方：演奏状态显示区
```

```
===== 	Main Menu		=====
>>>	Score History
-----	Chart List	-----
	0	Free Play
	1	little_stars
	2	some_example_chart
	3	recorded_1
	
[^][v]	Move
[<]	Auto	[>]	Play Chart	[C] Delete
```

```
=====	Score History	=====
	1	user1 | little stars 	   | 9942
	2	user2 | some example chart | 3217

[<] Exit
```

```
=====	Playing Chart	=====

User id: 1
Playing: Little Stars

Prog.	352	/	460		Score	3527

	.	.	.	.	#	.	.	.
    .	.	.	.	.	.	.	.
	.	.	.	.	#	.	.	.
    .	.	.	.	#	.	.	.
    .	.	.	.	.	.	.	.
    #	.	.	.	.	.	.	.
    #	.	.	.	.	.	.	.
    .	.	.	.	.	.	.	.
    #	.	.	.	.	.	.	.
>>> #	.	.	.	.	.	.	. <<<
	
	C	D	E	F	G	A	B	|
	#							+

[^] High [v] Low [<] Exit [>] Save
```

```
=====	Saving Chart	=====

	Select chart id:	10
	
[^][v] Select	[<]	Cancel	[>] Save
```

非屏幕输出：

- 演奏时谱面用 LED 灯显示
- 主菜单用数码管显示歌曲编号
- 演奏时数码管显示分数

### 主模块

输入和输出直接连接到板上各个端口。负责连接各子模块的输入输出，及管理当前的主要系统状态（即在不同的页面间切换）。

系统状态为：主菜单（选曲，最上段是自由/录制模式）；自由(录制)模式；自动/学习模式；历史演奏记录查看

分别调用对应的模块处理输入输出。

*录制：默认记录，结束自由模式时，可选择保存并退出 / 不保存退出

```systemverilog
`define NAME_LEN 16
`define NOTE_WIDTH 28
`define CHART_LEN 2048
`define SCREEN_WIDTH 32
`define SCREEN_HEIGHT 30
`define NOTE_TIME 100 // ms

typedef bit [0:8*`SCREEN_WIDTH-1] ScreenText [`SCREEN_HEIGHT-1:0];
// An unpacked array of packed chars in ASCII
// Note that strings MUST be used with small index to the left
// ALWAYS pad the string literal to the expected length (32 chars)
// Example: ScreenText[0] <= "=====       Main Menu      ====="
// Then ScreenText[0][0:7] is "="
// Otherwise, verilog fills 0 from left (right-aligned)
typedef bit [7:0] LedState; // A variable for controlling LED light
typedef bit [0:8*8-1] SegDisplayText;
// A packed array of chars for controlling Seg Displays
// Using ASCII Code, Left 7 - 0 Right
typedef bit [`NOTE_WIDTH-1:0] Notes; // A variable for notes
typedef enum { INIT, MENU, HISTORY, PLAY, SAVE } TopState;

typedef struct {
    bit [3:0] arrow_keys; // 0 - 3: U D L R
    bit [6:0] note_keys; // 0 - 6: C D E F G A B
    bit high, low; // +8 / -8
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

```

```systemverilog
module main(...);
    UserInput user_in;
    ProgramOutput prog_out;
    unifiedInput input_handler(.user_in(user_in), ...);
    unifiedOutput output_handler(.prog_out(prog_out), ...);
    // Bind the unified input and output controls
    
    logic rst = 0;
    ProgramOutput menu_out, history_out, play_out, save_out;
    TopState cur_state = INIT, next_state = MENU;
    
    shortint chart_id; // 0: free play; The play will be recorded into chart 0
    logic auto_play; // 0: normal play; 1: auto play
    pageMainMenu page_menu(clk, rst, user_in, menu_out, chart_id, auto_play);
    pageScoreHistory page_history(clk, rst, user_in, history_out);
    pagePlayChart page_play(clk, rst, user_in, play_out, chart_id, auto_play);
    pageSaveChart page_save(clk, rst, user_in, save_out);
    
    always @(posedge clk) begin
        case (cur_state)
            MENU: prog_out <= menu_out;
            // ...
        endcase
        next_state <= prog_out.state;
        rst <= next_state != cur_state;
    end
    
endmodule
```

### 各个页面的模块

```systemverilog
module pageMainMenu(
    input clk,
    input rst,
	input UserInput user_in,
    output ProgramOutput prog_out
);
endmodule
    
// Other page modules are similar
```

每个页面模块下按需设置子模块。

### IO 模块

IO 模块通过主模块连接到板上各个端口。负责硬件与其他模块间的编解码。

输入：键盘，板子上的开关

输出：LED 灯，数码管，显示器，喇叭

分别两个模块把键盘和板子上的开关输入转化为 

音频输出是所有页面共用一个

```systemverilog
module unifiedInput (
	input ...,
    output UserInput user_in
);
endmodule

module unifiedOutput (
    input ProgramOutput prog_out,
    output ...
);
endmodule

// Example of submodules that may be used by unifiedInput

module keyboardInput (
	input ...,
    output UserInput keyboard_in
);
endmodule

module boardInput (
	input ...,
    output UserInput board_in
);
endmodule

// Example of submodules that may be used by unifiedOutput

module audioOutput (
    input Notes playing_notes,
    output ...
);
endmodule

module segDisplayOutput (
	input SegDisplayText text,
    output ...
);
endmodule

module ledOutput (
	input LedState led,
    output ...
);
endmodule

module vgaOutput (
	input ScreenText text,
    output ...
);
endmodule
```

### 谱面存储与读写模块

谱面读写模块从内存中读写谱面，以结构体的形式将谱面传回。

```systemverilog
module saveChart (
    input shortint chart_id,
    input Chart chart
);
endmodule

module readChartInfo (
    input shortint chart_id,
    output ChartInfo info
);
endmodule

module readChartNotes (
	input shortint chart_id,
    output Chart chart
);
endmodule
```
