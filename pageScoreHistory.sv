module pageScoreHistory(
    input logic clk, prog_clk, rst,
    input UserInput user_in,
    output ProgramOutput history_out,
    output byte read_chart_id,
    output Chart read_chart
);
    shortint score;
    always @(posedge prog_clk or posedge rst) begin
        if (rst) begin
            read_chart_id <= 0;
            score <= 0;
        end
        else begin
            history_out.state <= TopState.HISTORY;
            case (user_in.arrow_keys)
                `UP:
                    if (read_chart_id == 0) read_chart_id = `CHARTS_MAX;
            endcase
        end
    end
endmodule