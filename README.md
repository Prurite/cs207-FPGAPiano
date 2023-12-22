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
[<]	Auto	[>]	Play Chart
```

```
=====	Score History	=====
	1	user1 | little stars 	   | 9942
	2	user2 | some example chart | 3217

[<] Exit
```

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
>>> #	.	.	.	.	.	.	. <<<
	
	C	D	E	F	G	A	B	|
	#							+

[^] High [v] Low [<] Exit [>] Save
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

```
header.svh
```

```
main.sv
```

### 各个页面的模块

```
page*.sv
```

每个页面模块下按需设置子模块。子模块定义放在对应页面的文件中。

### IO 模块

IO 模块通过主模块连接到板上各个端口。负责硬件与其他模块间的编解码。

输入：键盘，板子上的开关

输出：LED 灯，数码管，显示器，喇叭

分别两个模块把键盘和板子上的开关输入转化为打包好的输入输出结构体。

音频输出是所有页面共用一个

```
io.sv
```

### 谱面存储与读写模块

谱面读写模块从内存中读写谱面，以结构体的形式将谱面传回。

```
memory.sv
```