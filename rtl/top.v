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
	output wire usb_tx,
	input wire irq,
	input wire ps2_clk, ps2_data,
	output wire spi_clk, mosi, spi_cs,
	input wire miso
	
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
assign cpu_clk = clk_cnt[4];
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

assign dr_clk = ~clk_cnt[0];

always @(posedge clki) begin
    clk_cnt <= clk_cnt + 1;
end

reg rst = 1'b1;
`ifdef sim
wire cpu_rst = rst;
`else
wire cpu_rst = rst | ~rst_in;
`endif

always @(posedge cpu_clk) begin // hold reset at startup
	if(|rst_cnt)
		rst_cnt <= rst_cnt - 1'b1;
	else
		rst <= 1'b0;
end

wire ram_read, ram_write, ram_instr, ram_read_done, key_irq, spi_ready;
wire [7:0] reg_leds, btinputreg, rx_data, ps2_scancode, spi_rx;
wire [15:0] addr_bus, ram_in, prog_addr;
wire [31:0] sdram_out;
reg [15:0] ram_out;
wire [31:0] instr_out;
wire rx_new, tx_ready;
reg uart_write, uart_read, spi_write, spi_write_cs;

wire sdram_busy, sdram_ready, sdram_cack;
reg sdram_read, sdram_write, ram_busy, ram_ready, vga_write, ram_cack;

cpu cpu(cpu_clk, cpu_rst, addr_bus, prog_addr, ram_in, ram_out, instr_out, sdram_out, ram_busy, ram_ready, sdram_cack, key_irq, ram_read, ram_write, ram_instr, ram_read_done, reg_leds, pc_leds);

sdram sdram(clk_cnt[0], {7'b0, addr_bus}, ram_in, sdram_out, sdram_read, sdram_write, sdram_busy, sdram_ready, sdram_cack, dr_dqml, dr_dqmh, dr_cs_n, dr_cas_n, dr_ras_n, dr_we_n, dr_cke, dr_ba, dr_a, dr_dq, cpu_clk, ram_instr);

serialout regleds(clki, reg_leds, sclk, sdata, sdatain, sdata_pl, btinputreg);

vga gpu(clki, cpu_clk, vsync, hsync, r, g, b, addr_bus-16'h1000, vga_write, ram_in);

prom prom( prog_addr, ~cpu_clk, instr_out);

uart uart(usb_rx, usb_tx, clki, rx_data, ram_in[7:0], rx_new, tx_ready, uart_write, uart_read);

ps_keyboard ps2k(ps2_clk, ps2_data, ps2_scancode, clki, cpu_clk, key_irq);

spi spi_master(spi_clk, mosi, miso, clk_cnt[5], cpu_clk, rst, ram_in[7:0], spi_write, spi_rx, spi_ready, spi_write_cs, spi_cs);

// hw memory switching
always @(*) begin
	{sdram_read, sdram_write, ram_busy, vga_write, uart_write, uart_read, spi_write, spi_write_cs} = 8'b0;
	ram_ready = 1'b1; ram_cack = 1'b1;
    ram_out = 16'b0;
	if(addr_bus ==  16'h0000 && ~ram_instr) begin
		//read only
		ram_out = {8'b0, btinputreg};
	end else if (addr_bus == 16'h0001 && ~ram_instr) begin
		ram_out = {8'b0, rx_data};
		uart_write = ram_write;
		uart_read = ram_read_done; // special signal when ram_ready is set, do not emit ram_read again for sdram
	end else if (addr_bus == 16'h0002 && ~ram_instr) begin
		ram_out = {14'b0, tx_ready, rx_new};
	end else if (addr_bus == 16'h0003 && ~ram_instr) begin
		ram_out = {8'b0, ps2_scancode};
	end else if (addr_bus == 16'h0004 && ~ram_instr) begin
		ram_out = {spi_ready, 7'b0, spi_rx};
		spi_write = ram_write;
	end else if (addr_bus == 16'h0005 && ~ram_instr) begin
		ram_out = {16'b0};
		spi_write_cs = ram_write;
	end else if(addr_bus < 16'h1000 && ~ram_instr) begin
		
	end else if (addr_bus >= 16'h1000 && addr_bus < 16'h4c00 && ~ram_instr) begin
		// vga memory write only
		vga_write = ram_write;
	end
	else begin
		sdram_write = ram_write;
		sdram_read = ram_read;
		ram_busy = sdram_busy;
		ram_ready = sdram_ready;
		ram_out = sdram_out[15:0];
		ram_cack = sdram_cack;
	end
end
    
endmodule
