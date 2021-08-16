module sp (
    input wire clk, rst, ie, inc, dec,
    input wire [15:0] d,
    output reg [15:0] q
);

always @(posedge clk, posedge rst) begin
    if(rst) begin
        q = 16'hFFFF;
    end else begin
        if(ie)
            q = d;

        if(inc) begin
            q = q+16'b1;
        end else if(dec) begin
            q = q-16'b1;
        end
    end
end

endmodule