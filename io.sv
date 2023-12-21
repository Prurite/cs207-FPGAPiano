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
