module spi (
    output reg sck,
    output reg mosi,
    input wire miso,
    
    input wire cpu_clk,
    input wire rst,
    input wire [7:0] data_in_bus,
    input wire data_send_rq,
    output reg [7:0] data_out,
    output reg tx_ready
);

reg [1:0] state;
reg [3:0] bit_pos;
reg [7:0] data_in;

always @(posedge cpu_clk) begin
    if(rst) begin
        sck <= 1'b0;
        mosi <= 1'b0;

        state <= 2'b0;
        bit_pos <= 4'b0;
        tx_ready <= 1'b1;
    end else begin
        case (state) 
            default: begin
                if(data_send_rq) begin
                    data_in <= data_in_bus;
                    mosi <= data_in[3'b111-bit_pos];
                    state <= 2'b1;
                    tx_ready <= 1'b0;
                end
            end
            2'b1: begin
                sck <= 1'b1;
                data_out[3'b111-bit_pos] <= miso;
                bit_pos <= bit_pos + 4'b1;
                state <= 2'b10;
            end
            2'b10: begin
                sck <= 1'b0;
                if(bit_pos >= 4'b1000) begin
                    state <= 2'b0;
                    bit_pos <= 4'b0;
                    tx_ready <= 1'b1;
                    mosi <= 1'b0;
                end else begin
                    mosi <= data_in[3'b111-bit_pos];
                    state <= 2'b1;
                end
            end
        endcase
    end
end

endmodule