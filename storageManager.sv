`include "header.svh"

module ChartStorageManager(
    input logic clk, sys_rst,
    input byte read_chart_id,
    input byte write_chart_id,
    input Chart new_chart_data,
    output Chart current_chart_data
);
    Chart chartStorage [`CHARTS_MAX-1:0] = '{default: '0};

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