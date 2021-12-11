module spi (
    output reg sck,
    output reg mosi,
    input wire miso,
    
    input wire clki,
    input wire cpu_clk,
    input wire rst,
    input wire [7:0] data_in_bus,
    input wire data_send_rq,
    output reg [7:0] data_out,
    output wire tx_ready_out,
    input wire spi_write_cs,
    output reg spi_cs
);

reg tx_ready;
reg [1:0] state;
reg [3:0] bit_pos;
reg [7:0] data_in;

reg tx_signal;
reg prev_tx_signal;
initial tx_signal = 1'b0;
assign tx_ready_out = tx_ready & (~(tx_signal ^ prev_tx_signal));

always @(posedge clki) begin
    if(rst) begin
        sck <= 1'b0;
        mosi <= 1'b0;

        state <= 2'b0;
        bit_pos <= 4'b0;
        tx_ready <= 1'b1;
        prev_tx_signal <= tx_signal;
    end else begin
        case (state) 
            default: begin
                if(prev_tx_signal ^ tx_signal) begin
                    mosi <= data_in[3'b111-bit_pos];
                    state <= 2'b1;
                    tx_ready <= 1'b0;
                    prev_tx_signal <= tx_signal;
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

always @(posedge cpu_clk) begin
    if(data_send_rq) begin
        data_in <= data_in_bus;
        tx_signal <= ~tx_signal;
    end else if(spi_write_cs) begin
        spi_cs <= data_in_bus[0];
    end
end

endmodule