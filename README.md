# 数字逻辑 project specifications

## 输入及输出

输入：
 - 开发板上的开关和按键
 - 键盘输入
输出：
- 3.5mm 接口连接蜂鸣器
- 7 段数码管显示基础信息
- LED 灯指示当前状态
- VGA 线连接屏幕显示细节

## 模块分配

程序采用模块化设计，由一个 main 模块负责调度各页面，各个页面对应的不同状态下接受用户输入，处理，并产生输出。

### 页面层级

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

### 主菜单

- 按键提示：如挑选谱面、进入不同模式等的键位
- 历史分数：显示若干条历史记录，包含用户id、谱面名称和得分
- 自由演奏：可以自由演奏钢琴
- 谱面选择：可以自由选择谱面

```
===== 	Main Menu		=====
>>>	Score History
-----	Chart List	-----
	0	Free Play
	1	little_stars
	2	some_example_chart
	3	recorded_1
	
[^][v]	Move
[<]	Auto	[>]	Play Chart
```

### 历史分数

显示玩家的游玩记录和得分。

```
=====	Score History	=====
	1	user1 | little stars 	   | 9942
	2	user2 | some example chart | 3217

[<] Exit
```

### 游玩页面

- 上面部分：显示谱面名称，当前音符数 */* 总音符数，评级
- 中间部分：显示谱面
- 下面部分：演奏状态显示

非屏幕输出：

- 演奏时谱面用 LED 灯显示
- 主菜单用数码管显示歌曲编号
- 演奏时数码管显示分数

操作录制：默认记录，结束自由模式时，可选择保存并退出 / 不保存退出

```
=====	Playing Chart	=====

Current user id: 1
Playing: Little Stars
Save to chart id: 5

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
>>>	#	.	.	.	.	.	.	.	<<<
	
	C	D	E	F	G	A	B	|
	#							 

[^] High [v] Low [<] Exit [>] Save
```

### 主模块

**主要任务**：输入和输出直接连接到板上各个端口。负责连接各子模块的输入输出，及管理当前的主要系统状态（即在不同的页面间切换）。

**系统状态**：INIT, MENU, HISTORY, PLAY，主模块会在四种状态下分别调用对应的模块处理输入输出。

**时钟**：
- clk 系统时钟 100MHz：用于在一帧之内读取RAM，进行IO等需要串行处理的数据。
- prog_clk 程序时钟 60Hz：系统的通用时钟，包括屏幕操作等一系列操作的同步时钟。
- clk_100ms 演奏时钟 10Hz：演奏时使用的时钟，类似于节拍器的作用。

```
main.sv
```

### 类型及常量的定义

```
header.svh
```


### 各个页面的模块

```
page*.sv
```

每个页面模块下按需设置子模块。子模块定义放在对应页面的文件中。

### IO 模块

IO 模块通过主模块连接到板上各个端口。负责硬件与其他模块间的编解码。

```
io.sv
```

### 谱面存储与读写模块

谱面读写模块从内存中读写谱面，以结构体的形式将谱面传回。

```
storageManager.sv
```

## 字符串的处理

```systemverilog
typedef bit [0:8*`SCREEN_TEXT_WIDTH-1] ScreenText [`SCREEN_TEXT_HEIGHT-1:0];
/* An unpacked array of packed chars in ASCII
 * Note that strings MUST be used with small index to the left
 * ALWAYS pad the string literal to the expected length (32 chars)
 * Example: ScreenText[0] <= "=====	   Main Menu	  ====="
 * Then ScreenText[0][0:7] is "="
 * Otherwise, verilog fills 0 from left (right-aligned)
 *
 * Changing part of a string:
 * ScreenText[2] [5*8 : 10*8 - 1] = "user0"
 */
```