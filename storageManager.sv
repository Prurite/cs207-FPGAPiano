`include "header.svh"

module ChartStorageManager(
    input logic clk, sys_rst,
    input byte read_chart_id,
    input byte write_chart_id,
    input Chart new_chart_data,
    output Chart current_chart_data
);
    Chart chartStorage [`CHARTS_MAX-1:0] = '{default: '0};

    localparam C4 = 9'b00_0000001;
    localparam D4 = 9'b00_0000010;
    localparam E4 = 9'b00_0000100;
    localparam F4 = 9'b00_0001000;
    localparam G4 = 9'b00_0010000;
    localparam A5 = 9'b00_0100000;
    localparam B5 = 9'b00_1000000;

    // When id's are not 0, read or write accordingly
    always @(posedge clk)
        if (sys_rst)
            chartStorage <= '{default: '0};
        else begin
            if (read_chart_id != 0)
                current_chart_data <= chartStorage[read_chart_id-1];
            else
                current_chart_data <= current_chart_data;
            if (write_chart_id != 0)
                chartStorage[write_chart_id] <= new_chart_data;
            else
                chartStorage[write_chart_id] <= chartStorage[write_chart_id];
        end

    Chart ts;
    assign ts.info.name = "Tiny Stars      ";
    assign ts.info.note_cnt = 240;
    assign ts.notes = {
        // 1
        C4, C4, C4, C4, C4,
        // 1
        C4, C4, C4, C4, C4,
        // 5
        G4, G4, G4, G4, G4,
        // 5
        G4, G4, G4, G4, G4,
        // 6
        A5, A5, A5, A5, A5,
        // 6
        A5, A5, A5, A5, A5,
        // 5 5
        G4, G4, G4, G4, G4,
        G4, G4, G4, G4, G4,
        // 4
        F4, F4, F4, F4, F4,
        // 4
        F4, F4, F4, F4, F4,
        // 3
        E4, E4, E4, E4, E4,
        // 3
        E4, E4, E4, E4, E4,
        // 2
        D4, D4, D4, D4, D4,
        // 2
        D4, D4, D4, D4, D4,
        // 1 1
        C4, C4, C4, C4, C4,
        C4, C4, C4, C4, C4,
        // 5
        G4, G4, G4, G4, G4,
        // 5
        G4, G4, G4, G4, G4,
        // 4
        F4, F4, F4, F4, F4,
        // 4
        F4, F4, F4, F4, F4,
        // 3
        E4, E4, E4, E4, E4,
        // 3
        E4, E4, E4, E4, E4,
        // 2 2
        D4, D4, D4, D4, D4,
        D4, D4, D4, D4, D4,
        // 5
        G4, G4, G4, G4, G4,
        // 5
        G4, G4, G4, G4, G4,
        // 4
        F4, F4, F4, F4, F4,
        // 4
        F4, F4, F4, F4, F4,
        // 3
        E4, E4, E4, E4, E4,
        // 3
        E4, E4, E4, E4, E4,
        // 2 2
        D4, D4, D4, D4, D4,
        D4, D4, D4, D4, D4,
         // 1
        C4, C4, C4, C4, C4,
        // 1
        C4, C4, C4, C4, C4,
        // 5
        G4, G4, G4, G4, G4,
        // 5
        G4, G4, G4, G4, G4,
        // 6
        A5, A5, A5, A5, A5,
        // 6
        A5, A5, A5, A5, A5,
        // 5 5
        G4, G4, G4, G4, G4,
        G4, G4, G4, G4, G4,
        // 4
        F4, F4, F4, F4, F4,
        // 4
        F4, F4, F4, F4, F4,
        // 3
        E4, E4, E4, E4, E4,
        // 3
        E4, E4, E4, E4, E4,
        // 2
        D4, D4, D4, D4, D4,
        // 2
        D4, D4, D4, D4, D4,
        // 1 1
        C4, C4, C4, C4, C4,
        C4, C4, C4, C4, C4
    };
    assign chartStorage[0] = ts;
endmodule

module RecordStorageManager(
    input logic clk, sys_rst,
    input byte read_record_id,
    input byte write_record_id,
    input PlayRecord new_record_data,
    output PlayRecord current_record_data
);
    PlayRecord recordStorage [`PLAY_RECS_MAX-1:0] = '{default: '0};

    // When id's are not 0, read or write accordingly
    always @(posedge clk)
        if (sys_rst)
            recordStorage <= '{default: '0};
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
