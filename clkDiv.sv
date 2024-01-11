module clkDiv(
    input logic clk, rst,
    input integer divx,
    output reg clk_out
);
    integer cnt = 0;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            clk_out <= 0;
            cnt <= 0;
        end
        else begin
            if (divx == 0) clk_out <= 0;
            else begin
                if (cnt == (divx >> 1) - 1) begin
                    cnt <= 0;
                    clk_out <= ~clk_out;
                end
                else cnt <= cnt + 1;
            end 
        end
    end
endmodule