module pc (
    input wire [15:0] in,
    output reg [15:0] out,
    input wire clk, inc, ie, rst
);

wire [15:0] inmux;

initial out <= 16'b0;

reg [1:0] initreset = 2'b10;

always @(posedge clk, posedge rst) begin
    if(rst || (|initreset))
        out = 16'b0;
    else begin
        if (ie)
            out = in;

        if (inc)
            out = out + 16'b1;
    end
end

always @(posedge clk) begin
    if(|initreset) initreset <= initreset - 2'b1;
end

endmodule