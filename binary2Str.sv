// 14 bits binary to BCD converter
// Digit String = {4'h3, BCD Code}
// Move left and use adder3 module to calculate BCD code.
// The HSB~ part that exceeds strlen will be cut off.
module binary2Str(
    // Input up to 16384
    input [13:0] intx,
    output reg [0*8:5*8 - 1] str
);
    bit [3:0] t [10:0];
    // 00 0000 0000 0xxx
    adder3 add01(.x({1'b0, intx[13:11]}), .y(t[0]));
    // 00 0000 0000 xxxx
    adder3 add02(.x({t[0][2:0], intx[10]}), .y(t[1]));
    // 00 0000 000x xxxx
    adder3 add03(.x({t[1][2:0], intx[9]}), .y(t[2]));
    // 00 0000 00xx xxxx
    adder3 add04(.x({t[2][2:0], intx[8]}), .y(t[3]));
    // 00 0000 0xxx xxxx
    adder3 add05(.x({t[3][2:0], intx[7]}), .y(t[4]));
    // 00 0000 xxxx xxxx
    adder3 add06(.x({t[4][2:0], intx[6]}), .y(t[5]));
    // 00 000x xxxx xxxx
    adder3 add07(.x({t[5][2:0], intx[5]}), .y(t[6]));
    // 00 00xx xxxx xxxx
    adder3 add08(.x({t[6][2:0], intx[4]}), .y(t[7]));
    // 00 0xxx xxxx xxxx
    adder3 add09(.x({t[7][2:0], intx[3]}), .y(t[8]));
    // 00 xxxx xxxx xxxx
    adder3 add10(.x({t[8][2:0], intx[2]}), .y(t[9]));
    // 0x xxxx xxxx xxxx
    adder3 add11(.x({t[9][2:0], intx[1]}), .y(t[10]));
    // The last digit doesn't need judgement
    // Operate the higher bits
    bit [3:0] th [7:0];
    adder3 add21(.x({1'b0, t[0][3], t[1][3], t[2][3]}), .y(th[0]));
    adder3 add22(.x({th[0][2:0], t[3][3]}), .y(th[1]));
    adder3 add23(.x({th[1][2:0], t[4][3]}), .y(th[2]));
    adder3 add24(.x({th[2][2:0], t[5][3]}), .y(th[3]));
    adder3 add25(.x({th[3][2:0], t[6][3]}), .y(th[4]));
    adder3 add26(.x({th[4][2:0], t[7][3]}), .y(th[5]));
    adder3 add27(.x({th[5][2:0], t[8][3]}), .y(th[6]));
    adder3 add28(.x({th[6][2:0], t[9][3]}), .y(th[7]));
    bit [3:0] thh [4:0];
    adder3 add31(.x({1'b0, th[0][3], th[1][3], th[2][3]}), .y(thh[0]));
    adder3 add32(.x({thh[0][2:0], th[3][3]}), .y(thh[1]));
    adder3 add33(.x({thh[1][2:0], th[4][3]}), .y(thh[2]));
    adder3 add34(.x({thh[2][2:0], th[5][3]}), .y(thh[3]));
    adder3 add35(.x({thh[3][2:0], th[6][3]}), .y(thh[4]));
    bit [3:0] thhh [1:0];
    adder3 add41(.x({1'b0, thh[0][3], thh[1][3], thh[2][3]}), .y(thhh[0]));
    adder3 add42(.x({thhh[0][2:0], thh[3][3]}), .y(thhh[1]));
    // Convert to BCD code
    bit [19:0] bcd;
    assign bcd = {2'b0, thhh[0][3], thhh[1], thh[4], th[7], t[10], intx[0]};
    // Convert to string
    always_comb begin
        str = {4'h3, bcd[19:16], 4'h3, bcd[15:12], 4'h3, bcd[11:8], 4'h3, bcd[7:4], 4'h3, bcd[3:0]};
        if (bcd[19:16] == 4'h0) begin
            str[0:7] = 8'h00;
            if (bcd[15:12] == 4'h0) begin
                str[8:15] = 8'h00;
                if (bcd[11:8] == 4'h0) begin
                    str[16:23] = 8'h00;
                    if (bcd[7:4] == 4'h0) begin
                        str[24:31] = 8'h00;
                    end
                end
            end
        end
    end
endmodule

// Add 3 when x exceeds 4.
module adder3(
    input bit [3:0] x,
    output reg [3:0] y
);
    always_comb begin
        case (x)
            4'b0000: y = 4'b0000;
            4'b0001: y = 4'b0001;
            4'b0010: y = 4'b0010;
            4'b0011: y = 4'b0011;
            4'b0100: y = 4'b0100;
            4'b0101: y = 4'b1000;
            4'b0110: y = 4'b1001;
            4'b0111: y = 4'b1010;
            4'b1000: y = 4'b1011;
            4'b1001: y = 4'b1100;
            default: y = 4'b0000;
        endcase
    end
endmodule