module clkDiv(
    input logic clk, rst,
    input integer divx,
    output reg clk_out
);
    integer cnt = 0;
    always @(posedge clk) begin
        if (rst)
            clk_out <= 0;
        else begin
            if (divx == 0) clk_out <= 0;
            else begin
                if (cnt == divx) begin
                    clk_out <= 0;
                    cnt <= 0;
                end
                if (cnt == (divx >> 1) - 1) clk_out <= ~clk_out;
                cnt <= cnt + 1;
            end 
        end
    end
endmodule