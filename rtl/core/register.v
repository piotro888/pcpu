module register (
    input wire [15:0] d,
    output reg [15:0] q,
    input wire clk, ie, rst
);

initial q <= 0;

always @(posedge clk, posedge rst) begin
    if (rst)
        q <= 0;
    else if (ie)
        q <= d;
end
    
endmodule