`include "header.svh"

module ChartStorageManager(
    input logic clk, sys_rst,
    input byte read_chart_id,
    input byte write_chart_id,
    input Chart new_chart_data,
    output Chart current_chart_data
);
    logic [3:0] addr;
    bit [3599:0] din, dout;
    // assign din = {new_chart_data.info.name, new_chart_data.info.note_cnt, new_chart_data.notes};
    // Use a generated for loop to assign din
    logic [2:0] init_chart_id; // 1 - 2; 0: finished

    Chart init_charts[2:0];

    init_chart1 chart1( .chart1(init_charts[0]) );
    assign init_charts[1].info.name = "Ringing Bloom   ";
    assign init_charts[1].info.note_cnt = 190;
    assign init_charts[1].notes = init_charts[0].notes;

    assign addr = init_chart_id > 0 ? init_chart_id - 1 :
        (write_chart_id > 0 ? write_chart_id - 1 : 
        (read_chart_id > 0 ? read_chart_id - 1 : 0));
    assign din[0 +: 8*`NAME_LEN] = init_chart_id > 0
        ? init_charts[init_chart_id - 1].info.name : new_chart_data.info.name;
    assign din[8*`NAME_LEN +: 16] = init_chart_id > 0
        ? init_charts[init_chart_id - 1].info.note_cnt : new_chart_data.info.note_cnt;
    genvar i;
    for (i = 0; i < `CHART_LEN; i = i + 1)
        assign din[8*`NAME_LEN + 16 + (`NOTE_WIDTH+2) * i +: (`NOTE_WIDTH+2)] =
            init_chart_id > 0 ? init_charts[init_chart_id - 1].notes[i] : new_chart_data.notes[i];
    assign current_chart_data.info.name = dout[0 +: 8*`NAME_LEN];
    assign current_chart_data.info.note_cnt = dout[8*`NAME_LEN +: 16];
    for (i = 0; i < `CHART_LEN; i = i + 1)
        assign current_chart_data.notes[i] = dout[8*`NAME_LEN + 16 + (`NOTE_WIDTH+2) * i +: (`NOTE_WIDTH+2)];
    
    logic [1:0] init_cycle_cnt;

    always @(posedge clk or posedge sys_rst) begin
        if (sys_rst) begin
            init_chart_id <= 1;
            init_cycle_cnt <= 0;
        end else if (init_chart_id > 0 && init_chart_id < 3) begin
            init_chart_id <= init_chart_id + (init_cycle_cnt >= 2);
            init_cycle_cnt <= init_cycle_cnt >= 2 ? 0 : init_cycle_cnt + 1;
        end else
            init_chart_id <= 0;
    end

    blk_mem_gen_0 chart_blk_mem(
        .clka(clk), .ena(addr != 0),
        .addra(addr), .dina(din),
        .douta(dout), .wea(write_chart_id != 0 || init_chart_id != 0)
    );
endmodule

module RecordStorageManager(
    input logic clk, sys_rst,
    input byte read_record_id,
    input byte write_record_id,
    input PlayRecord new_record_data,
    output PlayRecord current_record_data
);  
    //PlayRecord record_storage [`PLAY_RECS_MAX-1:0] = '{default: '0};
    PlayRecord record_storage [`PLAY_RECS_MAX-1:0];
    PlayRecord pr;
    assign pr.user_id = 2;
    assign pr.chart_name = "Little Stars    ";
    assign pr.score = 4406;

    // When id's are not 0, read or write accordingly
    always @(posedge clk or posedge sys_rst)
        if (sys_rst) begin
            record_storage[2].user_id <= 1;
            record_storage[2].chart_name <= "Ringing Bloom   ";
            record_storage[2].score <= 10940;
            record_storage[3] <= pr;
            record_storage[1] <= pr;
        end
        else begin
            if (read_record_id != 0)
                current_record_data <= record_storage[read_record_id];
            else
                current_record_data <= current_record_data;
            if (write_record_id != 0)
                record_storage[write_record_id] <= new_record_data;
            else
                record_storage[write_record_id] <= record_storage[write_record_id];
        end
endmodule

module init_chart1(
    output Chart chart1
);
    localparam NU = 9'b00_0000000;
    localparam C4 = 9'b10_0000001;
    localparam D4 = 9'b10_0000010;
    localparam E4 = 9'b10_0000100;
    localparam F4 = 9'b10_0001000;
    localparam G4 = 9'b10_0010000;
    localparam A5 = 9'b10_0100000;
    localparam B5 = 9'b10_1000000;

    localparam NOTE_CNT = 190;

    assign chart1.info.name = "Little Stars    ";
    assign chart1.info.note_cnt = NOTE_CNT;
    typedef Notes note_t [NOTE_CNT];
    note_t ts_notes = {
        NU, NU, NU, NU,
        // 1
        C4, C4, C4, NU,
        // 1
        C4, C4, C4, NU,
        // 5
        G4, G4, G4, NU,
        // 5
        G4, G4, G4, NU,
        // 6
        A5, A5, A5, NU,
        // 6
        A5, A5, A5, NU,
        // 5 5
        G4, G4, G4,
        G4, G4, G4, NU,
        // 4
        F4, F4, F4, NU,
        // 4
        F4, F4, F4, NU,
        // 3
        E4, E4, E4, NU,
        // 3
        E4, E4, E4, NU,
        // 2
        D4, D4, D4, NU,
        // 2
        D4, D4, D4, NU,
        // 1 1
        C4, C4, C4,
        C4, C4, C4, NU,
        // 5
        G4, G4, G4, NU,
        // 5
        G4, G4, G4, NU,
        // 4
        F4, F4, F4, NU,
        // 4
        F4, F4, F4, NU,
        // 3
        E4, E4, E4, NU,
        // 3
        E4, E4, E4, NU,
        // 2 2
        D4, D4, D4,
        D4, D4, D4, NU,
        // 5
        G4, G4, G4, NU,
        // 5
        G4, G4, G4, NU,
        // 4
        F4, F4, F4, NU,
        // 4
        F4, F4, F4, NU,
        // 3
        E4, E4, E4, NU,
        // 3
        E4, E4, E4, NU,
        // 2 2
        D4, D4, D4,
        D4, D4, D4, NU,
         // 1
        C4, C4, C4, NU,
        // 1
        C4, C4, C4, NU,
        // 5
        G4, G4, G4, NU,
        // 5
        G4, G4, G4, NU,
        // 6
        A5, A5, A5, NU,
        // 6
        A5, A5, A5, NU,
        // 5 5
        G4, G4, G4,
        G4, G4, G4, NU,
        // 4
        F4, F4, F4, NU,
        // 4
        F4, F4, F4, NU,
        // 3
        E4, E4, E4, NU,
        // 3
        E4, E4, E4, NU,
        // 2
        D4, D4, D4, NU,
        // 2
        D4, D4, D4, NU,
        // 1 1
        C4, C4, C4,
        C4, C4, C4, NU
    };
    assign chart1.notes[0:NOTE_CNT-1] = ts_notes;
endmodule