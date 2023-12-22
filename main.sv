`include "header.svh"

module main(
    // Inputs and outputs
);
    // Bind the unified input and output controls
    UserInput user_in;
    ProgramOutput prog_out;
    unifiedInput input_handler(.user_in(user_in), ...);
    unifiedOutput output_handler(.prog_out(prog_out), ...);
    
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
        .clk(clk),
        .read_chart_id(read_chart_id), .write_chart_id(write_chart_id),
        .new_chart_data(write_chart), .current_chart_data(read_chart)
    );
    RecordStorageManager record_storage(
        .clk(clk),
        .read_record_id(read_record_id), .write_record_id(write_record_id),
        .new_record_data(write_record), .current_record_data(read_record)
    );

    logic auto_play; // 0: normal play; 1: auto play

    // Bind the pages
    pageInit page_init(
        .clk(clk), .rst(rst), .user_in(user_in), .init_out(init_out)
    );
    pageMenu page_menu(
        .clk(clk), .rst(rst), .user_in(user_in), .menu_out(menu_out),
        .read_chart_id(read_chart_id), .chart_data(read_chart)
    );
    pageScoreHistory page_history(
        .clk(clk), .rst(rst), .user_in(user_in), .history_out(history_out),
        .read_record_id(read_record_id), .record_data(read_record)
    );
    pagePlayChart page_play(
        .clk(clk), .rst(rst), .user_in(user_in), .play_out(play_out),
        .cur_chart(read_chart),
        .write_chart_id(write_chart_id), .write_chart(write_chart),
        .write_record_id(write_record_id), .write_record(write_record)
    );

    /* State transitions:
     * INIT -> MENU
     * MENU <-> HISTORY
     * MENU -(chart_id, auto_play)-> PLAY -> MENU
     */

    always @(posedge clk or posedge sys_rst)
        if (sys_rst)
            cur_state <= INIT;
        else
            cur_state <= next_state;
    
    always @(*) begin
        case (cur_state)
            INIT: prog_out <= init_out;
            MENU: prog_out <= menu_out;
            HISTORY: prog_out <= history_out;
            PLAY: prog_out <= play_out;
            default: prog_out <= init_out;
        endcase
        next_state <= prog_out.state;
        rst <= next_state != cur_state;
    end
    
endmodule
