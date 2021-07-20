module top (
    input wire clki,
    output wire [3:0] pc_leds,
    output wire sclk, sdata,
    output wire hsync, vsync, 
	 output wire [2:0] r, g, 
	 output wire [1:0] b
);

wire cpu_clk;
reg [31:0] clk_cnt = 0;
reg [2:0] rst_cnt = 3'b010;
//assign cpu_clk = clk_cnt[17]; // ~190Hz
assign cpu_clk = clk_cnt[24];

always @(posedge clki) begin
    clk_cnt <= clk_cnt + 1;
end

reg rst = 1'b1;

always @(posedge cpu_clk) begin // hold reset at startup
	if(|rst_cnt)
		rst_cnt <= rst_cnt - 1'b1;
	else
		rst <= 1'b0;
end

wire ram_read, ram_write;
wire [7:0] reg_leds;
wire [15:0] addr_bus, ram_in, prog_addr;
wire [31:0] instr_out;

cpu cpu(cpu_clk, rst, addr_bus, prog_addr, ram_in, ram_out, instr_out, ram_read, ram_write, reg_leds, pc_leds);


serialout regleds(clki, reg_leds, sclk, sdata);


vga gpu(clki, vsync, hsync, r, g, b, addr_bus, ram_write, ram_in);


prom prom( prog_addr, ~cpu_clk, instr_out);
    
endmodule

//`include "cpu.v"
//`include "serialout.v"
//`include "vga.v"