module top (
    input wire clki,
    output wire [3:0] pc_leds,
    output wire sclk, sdata,
    output wire hsync, vsync, r, g, b
);

wire cpu_clk;
reg [31:0] clk_cnt = 0;
assign cpu_clk = clk_cnt[17]; // ~190Hz

always @(posedge clki) begin
    clk_cnt <= clk_cnt + 1;
end

//reg busy = 0;
wire rst = 0;


cpu cpu(cpu_clk, rst, addr_bus, prog_addr, ram_in, ram_out, instr_out, reg_leds, pc_leds);

wire [7:0] reg_leds;
serialout regleds(clki, reg_leds, sclk, sdata);

vga gpu(clk, vsync, hsync, r, g, b, addr_bus, vga_we, ram_in);
    
endmodule

`include "cpu.v"
`include "serialout.v"
`include "vga.v"