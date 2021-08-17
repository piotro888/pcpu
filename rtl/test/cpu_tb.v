`timescale 10ns/1ns

`define sim

module cpu_tb;

reg clk_in = 1'b0;

always begin
    #2 clk_in <= ~clk_in;
end

`break

top top(.clki(clk_in));

endmodule
