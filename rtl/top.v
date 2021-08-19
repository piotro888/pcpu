//`define sim
module top (
    input wire clki,
    output wire [3:0] pc_leds,
    output wire sclk, sdata,
    output wire hsync, vsync, 
	output wire [2:0] r, g, 
	output wire [1:0] b,
	input wire sdatain,
	output wire sdata_pl,
	input wire rst_in,
	input wire usb_rx,
	output wire usb_tx
	
	`ifndef sim
	,
	output wire dr_dqml, dr_dqmh,
  	output wire dr_cs_n, dr_cas_n, dr_ras_n, dr_we_n, dr_cke,
   	output wire [1:0] dr_ba,
	output wire  [12:0] dr_a,
   	inout [15:0] dr_dq,
	output wire dr_clk
	`endif
);


wire cpu_clk;
reg [31:0] clk_cnt = 0;
reg [2:0] rst_cnt = 3'b010;

`ifndef sim
//assign cpu_clk = clk_cnt[17]; // ~190Hz
assign cpu_clk = clk_cnt[5]; 
//assign cpu_clk = clk_cnt[24]; // ~1Hz
`else
assign cpu_clk = clk_cnt[2];
wire dr_dqml, dr_dqmh;
wire dr_cs_n, dr_cas_n, dr_ras_n, dr_we_n, dr_cke;
wire [1:0] dr_ba;
wire  [12:0] dr_a;
wire [15:0] dr_dq;
wire dr_clk;
	 
`define x8
`define den256Mb
sdr sdr (dr_dq, dr_a, dr_ba, dr_clk, dr_cke, dr_cs_n, dr_ras_n, dr_cas_n, dr_we_n, {dr_dqml,dr_dqmh});
`endif

assign dr_clk = ~clki;

always @(posedge clki) begin
    clk_cnt <= clk_cnt + 1;
end

reg rst = 1'b1;
wire cpu_rst = rst | ~rst_in;

always @(posedge cpu_clk) begin // hold reset at startup
	if(|rst_cnt)
		rst_cnt <= rst_cnt - 1'b1;
	else
		rst <= 1'b0;
end

wire ram_read, ram_write;
wire [7:0] reg_leds, btinputreg, rx_data;
wire [15:0] addr_bus, ram_in, prog_addr, sdram_out;
reg [15:0] ram_out;
wire [31:0] instr_out;
wire rx_new, tx_ready;
reg uart_write, uart_read;

wire sdram_busy, sdram_ready;
reg sdram_read, sdram_write, ram_busy, ram_ready, vga_write;

cpu cpu(cpu_clk, cpu_rst, addr_bus, prog_addr, ram_in, ram_out, instr_out, ram_busy, ram_ready, ram_read, ram_write, reg_leds, pc_leds);

sdram sdram(clki, {8'b0, addr_bus-16'h4c00}, ram_in, sdram_out, sdram_read, sdram_write, sdram_busy, sdram_ready, dr_dqml, dr_dqmh, dr_cs_n, dr_cas_n, dr_ras_n, dr_we_n, dr_cke, dr_ba, dr_a, dr_dq, cpu_clk);

serialout regleds(clki, reg_leds, sclk, sdata, sdatain, sdata_pl, btinputreg);

vga gpu(clki, cpu_clk, vsync, hsync, r, g, b, addr_bus-16'h1000, vga_write, ram_in);

prom prom( prog_addr, ~cpu_clk, instr_out);

uart uart(usb_rx, usb_tx, clki, rx_data, ram_in, rx_new, tx_ready, uart_write, uart_read);

// hw memory switching
always @(*) begin
	{sdram_read, sdram_write, ram_busy, vga_write, uart_write, uart_read} = 4'b0;
	ram_ready = 1'b1;
    ram_out = 16'b0;
	if(addr_bus ==  16'h0000) begin
		//read only
		ram_out = {8'b0, btinputreg};
	end else if (addr_bus == 16'h0001) begin
		ram_out = {8'b0, rx_data};
		uart_write = ram_write;
		uart_read = ram_read;
	end else if (addr_bus == 16'h0002) begin
		ram_out = {14'b0, tx_ready, rx_new};
	end else if(addr_bus < 16'h1000) begin
		
	end else if (addr_bus >= 16'h1000 && addr_bus < 16'h4c00) begin
		// vga memory write only
		vga_write = ram_write;
	end
	else begin
		sdram_write = ram_write;
		sdram_read = ram_read;
		ram_busy = sdram_busy;
		ram_ready = sdram_ready;
		ram_out = sdram_out;
	end
end
    
endmodule
