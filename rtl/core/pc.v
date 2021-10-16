module pc (
    input wire [15:0] in,
    output reg [15:0] out,
    input wire clk, inc, ie, irq, rst
);

wire [15:0] inmux;

initial out <= 16'b0;

always @(posedge clk, posedge rst) begin
    if(rst) begin
        out = 16'b0;
    end else begin
        if (ie)
            out = in;

        if (inc)
            out = out + 16'b1;

        if (irq & (ie | inc))
            out = 16'b1;
    end
end

endmodule