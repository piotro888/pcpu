module freqgen (
    input wire clk,
    // bus
    input wire [15:0] addr,
    input wire [15:0] data,
    input wire we,
    input wire cpu_clk,
    input wire rst,

    output reg out
);

reg [31:0] clock_cnt;
reg [15:0] pos_limit, neg_limit, pos_cnt, neg_cnt;
reg [4:0] clk_div;

always @(posedge clk) begin
    clock_cnt <= clock_cnt + 32'b1;
end

always @(posedge clock_cnt[clk_div]) begin
    if(rst) begin
        out <= 1'b0;
        neg_cnt <= 16'b0;
        pos_cnt <= 16'b0;
    end else begin
        if(pos_limit == 16'b0) begin
            out <= 1'b0;
        end else if(out == 1'b0) begin
            if(neg_cnt+16'b1 == neg_limit) begin
                out <= 1'b1;
                neg_cnt <= 16'b0;
            end else
                neg_cnt <= neg_cnt + 16'b1;
        end else begin
            if(pos_cnt+16'b1 == pos_limit) begin
                out <= 1'b0;
                pos_cnt <= 16'b0;
            end else
                pos_cnt <= pos_cnt + 16'b1;
        end
    end
end

always @(posedge cpu_clk) begin
    if(rst) begin
        clk_div <= 5'd0;
        pos_limit <= 16'd0;
        neg_limit <= 16'd0;
    end else if(we) begin
        case (addr[1:0])
            2'b00:
                clk_div <= data[4:0];
            2'b01:
                pos_limit <= data;
            2'b10:
                neg_limit <= data;
            default: begin
                pos_limit <= data;
                neg_limit <= data;
            end
        endcase
    end
end


    
endmodule