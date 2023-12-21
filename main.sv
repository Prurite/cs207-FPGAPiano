`include "header.svh"

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
