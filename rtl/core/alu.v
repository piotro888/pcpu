module alu (
    input wire [15:0] a_in,
    input wire [15:0] b_in,
    output wire [15:0] out,

    input wire [3:0] mode,
    input wire carry_in,
    output reg [4:0] flags_reg_out,
    input wire clk, alu_flags_ie
);

reg [16:0] outc;
reg [4:0] flags;
assign out = outc[15:0];

always @(*) begin
    case (mode) 
        4'b0000: outc <= a_in + b_in + carry_in; //ADD
        4'b0001: outc <= a_in - b_in  - carry_in; //SUB
        4'b0010: outc <= a_in & b_in; //AND
        4'b0011: outc <= a_in | b_in; //OR
        4'b0100: outc <= a_in ^ b_in; //XOR
        4'b0101: outc <= a_in << b_in; //SHR
        4'b0110: outc <= a_in >> b_in; //SHL
        4'b0111: outc <= a_in * b_in; //CHECK MUL & DIV
        4'b1000: outc <= a_in / b_in;
        4'b1001: outc <= a_in; //A PASS
        default: outc <= b_in; //B PASS
    endcase
    flags[0] <= ~(|outc[15:0]); //ZERO
    flags[1] <= (~(|mode[3:1])) & outc[16]; //CARRY
    flags[2] <= outc[15]; //NEG
    flags[3] <= (((a_in[15]^b_in[15])^(~mode[0]))&((b_in[15]^outc[15])^mode[0])); //OVF
    flags[4] <= ^outc[15:0]; //PAR
end

always @(posedge clk) begin
    if(alu_flags_ie)
        flags_reg_out <= flags; 
end

endmodule