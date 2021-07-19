module pc (
    input wire [15:0] in,
    output reg [15:0] out,
    input wire clk, inc, ie
);

wire [15:0] inmux;

initial out <= 0;

always @(posedge clk) begin
    if (ie)
        out = in;

    if (inc)
        out = out + 16'b1;
end

endmodule