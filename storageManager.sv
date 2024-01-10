`include "header.svh"

module ChartStorageManager(
    input logic clk, sys_rst,
    input byte read_chart_id,
    input byte write_chart_id,
    input Chart new_chart_data,
    output Chart current_chart_data
);
    Chart chartStorage [`CHARTS_MAX-1:0] = '{default: '0};

    localparam NU = 9'b00_0000000;
    localparam C4 = 9'b00_0000001;
    localparam D4 = 9'b00_0000010;
    localparam E4 = 9'b00_0000100;
    localparam F4 = 9'b00_0001000;
    localparam G4 = 9'b00_0010000;
    localparam A5 = 9'b00_0100000;
    localparam B5 = 9'b00_1000000;

    localparam NOTE_CNT = 282;
    ChartInfo ts_info;
    assign ts_info.name = "Little Stars    ";
    assign ts_info.note_cnt = NOTE_CNT;
    typedef Notes note_t [NOTE_CNT];
    note_t ts_notes = {
        // 1
        C4, C4, C4, C4, C4, NU,
        // 1
        C4, C4, C4, C4, C4, NU,
        // 5
        G4, G4, G4, G4, G4, NU,
        // 5
        G4, G4, G4, G4, G4, NU,
        // 6
        A5, A5, A5, A5, A5, NU,
        // 6
        A5, A5, A5, A5, A5, NU,
        // 5 5
        G4, G4, G4, G4, G4,
        G4, G4, G4, G4, G4, NU,
        // 4
        F4, F4, F4, F4, F4, NU,
        // 4
        F4, F4, F4, F4, F4, NU,
        // 3
        E4, E4, E4, E4, E4, NU,
        // 3
        E4, E4, E4, E4, E4, NU,
        // 2
        D4, D4, D4, D4, D4, NU,
        // 2
        D4, D4, D4, D4, D4, NU,
        // 1 1
        C4, C4, C4, C4, C4,
        C4, C4, C4, C4, C4, NU,
        // 5
        G4, G4, G4, G4, G4, NU,
        // 5
        G4, G4, G4, G4, G4, NU,
        // 4
        F4, F4, F4, F4, F4, NU,
        // 4
        F4, F4, F4, F4, F4, NU,
        // 3
        E4, E4, E4, E4, E4, NU,
        // 3
        E4, E4, E4, E4, E4, NU,
        // 2 2
        D4, D4, D4, D4, D4,
        D4, D4, D4, D4, D4, NU,
        // 5
        G4, G4, G4, G4, G4, NU,
        // 5
        G4, G4, G4, G4, G4, NU,
        // 4
        F4, F4, F4, F4, F4, NU,
        // 4
        F4, F4, F4, F4, F4, NU,
        // 3
        E4, E4, E4, E4, E4, NU,
        // 3
        E4, E4, E4, E4, E4, NU,
        // 2 2
        D4, D4, D4, D4, D4,
        D4, D4, D4, D4, D4, NU,
         // 1
        C4, C4, C4, C4, C4, NU,
        // 1
        C4, C4, C4, C4, C4, NU,
        // 5
        G4, G4, G4, G4, G4, NU,
        // 5
        G4, G4, G4, G4, G4, NU,
        // 6
        A5, A5, A5, A5, A5, NU,
        // 6
        A5, A5, A5, A5, A5, NU,
        // 5 5
        G4, G4, G4, G4, G4,
        G4, G4, G4, G4, G4, NU,
        // 4
        F4, F4, F4, F4, F4, NU,
        // 4
        F4, F4, F4, F4, F4, NU,
        // 3
        E4, E4, E4, E4, E4, NU,
        // 3
        E4, E4, E4, E4, E4, NU,
        // 2
        D4, D4, D4, D4, D4, NU,
        // 2
        D4, D4, D4, D4, D4, NU,
        // 1 1
        C4, C4, C4, C4, C4,
        C4, C4, C4, C4, C4, NU
    };

    // When id's are not 0, read or write accordingly
    always @(posedge clk or posedge sys_rst)
        if (sys_rst) begin
            chartStorage[1].info <= ts_info;
            for (int i = 0; i < NOTE_CNT; i++)
                chartStorage[1].notes[i] <= ts_notes[i];
        end else begin
            if (read_chart_id != 0)
                current_chart_data <= chartStorage[read_chart_id-1];
            else
                current_chart_data <= current_chart_data;
            if (write_chart_id != 0)
                chartStorage[write_chart_id] <= new_chart_data;
            else
                chartStorage[write_chart_id] <= chartStorage[write_chart_id];
        end

endmodule

module RecordStorageManager(
    input logic clk, sys_rst,
    input byte read_record_id,
    input byte write_record_id,
    input PlayRecord new_record_data,
    output PlayRecord current_record_data
);
    PlayRecord pr;
    assign pr.user_id = 1;
    assign pr.chart_name = "Little Stars    ";
    assign pr.score = 4487;
    
    PlayRecord recordStorage [`PLAY_RECS_MAX-1:0] = '{default: '0};

    // When id's are not 0, read or write accordingly
    always @(posedge clk or posedge sys_rst)
        if (sys_rst) begin
            recordStorage[1] <= pr;
            recordStorage[2] <= pr;
        end
        else begin
            if (read_record_id != 0)
                current_record_data <= recordStorage[read_record_id];
            else
                current_record_data <= current_record_data;
            if (write_record_id != 0)
                recordStorage[write_record_id] <= new_record_data;
            else
                recordStorage[write_record_id] <= recordStorage[write_record_id];
        end
endmodule
