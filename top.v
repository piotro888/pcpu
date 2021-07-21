module top (
    input wire clki,
    output wire [3:0] pc_leds,
    output wire sclk, sdata,
    output wire hsync, vsync, 
	output wire [2:0] r, g, 
	output wire [1:0] b,
	output reg dr_dqml, dr_dqmh,
    output wire dr_cs_n, dr_cas_n, dr_ras_n, dr_we_n, dr_cke,
    output reg [1:0] dr_ba,
    output reg  [12:0] dr_a,
    inout [15:0] dr_dq	
);

wire cpu_clk;
reg [31:0] clk_cnt = 0;
reg [2:0] rst_cnt = 3'b010;
//assign cpu_clk = clk_cnt[17]; // ~190Hz
assign cpu_clk = clk_cnt[24]; // ~1Hz
//assign cpu_clk = clki;


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

wire ram_read, ram_write, dram_busy, dram_ready;
wire [7:0] reg_leds;
wire [15:0] addr_bus, ram_in, ram_out, prog_addr;
wire [31:0] instr_out;

cpu cpu(cpu_clk, rst, addr_bus, prog_addr, ram_in, ram_out, instr_out, ram_read, ram_write, reg_leds, pc_leds);

sdram sdram(addr_bus, ram_in, ram_out, ram_read, ram_write, dram_busy, dram_ready, dr_dqml, dr_dqmh, dr_cs_n, dr_cas_n, dr_ras_n, dr_we_n, dr_cke, dr_ba, dr_a, dr_dq);

serialout regleds(clki, reg_leds, sclk, sdata);

vga gpu(clki, vsync, hsync, r, g, b, addr_bus, ram_write, ram_in);

prom prom( prog_addr, ~cpu_clk, instr_out);
    
endmodule

// `include "cpu.v"
// `include "serialout.v"
// `include "vga.v"
// `include "sdram.v"