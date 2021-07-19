module serialout (
    input wire clk,
    input wire [7:0] data,
    output wire sclk,
    output reg sdata
);

reg[22:0] clk_cnt = 0;
always @(posedge clk) begin
    clk_cnt <= clk_cnt+1;
end

wire ref_clk = clk_cnt[22];
wire ser_clk = clk_cnt[10];

reg ser_bit = 0, tx = 0, rt = 0;

assign sclk = ser_clk & tx;

always @(posedge ser_clk) begin
    case (ser_bit) 
		0: begin
			sdata <= data[0];
			ser_bit <= 1;
			tx <= 1;
		end
		1: begin
			sdata <= data[1];
			ser_bit <= 2;
		end
		2: begin
			sdata <= data[2];
			ser_bit <= 3;
		end
		3: begin
			sdata <= data[3];
			ser_bit <= 4;
		end
		4: begin
			sdata <= data[4];
			ser_bit <= 5;
		end
		5: begin
			sdata <= data[5];
			ser_bit <= 6;
		end
		6: begin
			sdata <= data[6];
			ser_bit <= 7;
		end
		7: begin
			sdata <= data[7];
			ser_bit <= 8;
		end
		8: begin
			tx <= 0;
			if (ref_clk && ~rt) begin
				ser_bit <= 0;
				rt <= 1;
			end else if (~ref_clk) begin
				rt <= 0;
			end
		end
	endcase
    
end

endmodule