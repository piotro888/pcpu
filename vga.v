module vga (
	input wire clk,
	output reg hsync, vsync,
	output reg [2:0] r, g,
	output reg [1:0] b,
	input wire	[14:0]  addra,
	input wire	wea,
	input wire [15:0]  data
);

reg pclk;

initial begin
	pclk = 0;
	r = 0;
	g = 0;
	b = 0;
end

reg [14:0] addrb;
wire [15:0]  qa, qb;

vgaram vgram(
	addra,
    addrb,
    clk,
    data,
    15'b0,
    wea,
	1'b0,
	qa,
	qb
);

always @(posedge clk) begin
	pclk <= ~pclk;
end

reg [10:0] hcnt, vcnt;

always @(posedge pclk) begin
	if(hcnt >= 640 || vcnt >= 480 || addrb > 4015 ) begin 
		r = 3'b000;
		g = 3'b000;
		b = 2'b00;
	end else begin // 8-bit color 160x120
		if(hcnt[2]) begin 
			r = qb[10:8];
			g = qb[13:11];
			b = qb[15:14];
		end else begin
			r = qb[2:0];
			g = qb[5:3];
			b = qb[7:6];
		end
		if (&hcnt[2:0])
			addrb = addrb+1;
	end
	
	if(hcnt >= 656 && hcnt <= 752)
		hsync = 1'b0;
	else
		hsync = 1'b1;
	
	if(vcnt >= 490 && vcnt <= 492)
		vsync = 1'b0;
	else
		vsync = 1'b1;
	
	hcnt = hcnt+1;
	if(hcnt == 801) begin
		hcnt = 0;
		if((~(&vcnt[1:0])) && vcnt <= 480)
			addrb = addrb - 80;
		vcnt = vcnt+1; 
	end
	if(vcnt > 480)
		addrb = 0;
	if(vcnt == 526) begin
		vcnt = 0;
	end
end

endmodule

`include "oldtmp/vgaram.v"