module timer (
    input wire bus_clk,
    input wire rst,
    output reg irq,

    input wire [1:0] addr,
    input wire write,
    input wire [15:0] bus_in
);

reg [15:0] timer_cnt;

reg [15:0] pre_div_cnt;
reg [3:0] clk_div;

reg [15:0] reset_val;

always @(posedge bus_clk) begin
    if(rst) begin
        timer_cnt <= 16'b0;
        pre_div_cnt <= 16'b0;
    end else if(write && addr == 2'b0) begin
        timer_cnt <= bus_in;
    end else begin
        pre_div_cnt <= pre_div_cnt + 16'b1;
        
        if(pre_div_cnt >= (1<<clk_div) - 16'b1) begin
            timer_cnt <= timer_cnt + 16'b1;
            pre_div_cnt <= 16'b0;
        end

        if(timer_cnt == 16'hffff) begin
            timer_cnt <= reset_val;
        end
    end
end

always @(posedge bus_clk) begin
    irq <= (timer_cnt == 16'hffff);
end

always @(posedge bus_clk) begin
    if(rst) begin
        reset_val <= 16'b0;
        clk_div <= 4'b0;
    end else if(write && addr == 2'b1) begin
        clk_div <= bus_in[3:0];
    end else if (write && addr == 2'b10) begin
        reset_val <= bus_in;
    end
end

endmodule
