module uart(
    input wire rxd,
    output reg txd,
    input wire clk,

    output reg [7:0] rx_data_out,
    input wire [7:0] tx_data_in,
    output reg rx_new,
    output reg tx_ready,
    input wire write,
    input wire read
);

initial begin
    txd <= 1'b1;
    tx_ready <= 1'b1;
    rx_new <= 1'b0;
    rx_data_out <= 8'b0;
end

reg baudclk8 = 1'b0; //9600*8=76800 Hz
reg [3:0] txclkcnt = 4'b0;
reg [8:0] clkcnt = 9'b0;
always @(posedge clk) begin
    if(clkcnt == 325) begin
        baudclk8 = ~baudclk8;
        clkcnt <= 0;
    end else begin
        clkcnt <= clkcnt+1;
    end
end

//sync regs
reg prev_write = 1'b0, prev_read = 1'b0;
reg xor_write_pulse = 1'b0, xor_write_ack = 1'b0;
wire write_p = xor_write_pulse ^ xor_write_ack;
reg xor_rx_new = 1'b0, xor_tx_ready = 1'b0, prev_xor_rx_new = 1'b0, prev_xor_tx_ready = 1'b0;

reg [3:0] state = 4'b0;
reg [3:0] sub_clk_cnt = 4'b0;
reg [7:0] rx_data;
always @(posedge baudclk8) begin
    txclkcnt <= txclkcnt + 4'b1;
    case (state)
        4'b0: begin
            // if start bit
            if(rxd == 1'b0) begin
                state <= 1'b1;
            end
        end
        4'b1001: begin
            if(sub_clk_cnt == 4'b0111) begin
                //state <= 4'b1010; //stop bit
                sub_clk_cnt <= 4'b0;
                state <= 4'b0;
                xor_rx_new <= ~xor_rx_new;
                rx_data_out <= rx_data;
            end else begin
                sub_clk_cnt <= sub_clk_cnt+4'b1;
            end
        end
        default: begin // default read bit
            if((state != 4'b1 && sub_clk_cnt == 4'b0111) || sub_clk_cnt == 4'b1010) begin //delay first clock by one and half
//               txd <= ~txd;
                rx_data[state-4'b1] <= rxd;
                state <= state+4'b1;
                sub_clk_cnt <= 4'b0;
            end else begin
                sub_clk_cnt <= sub_clk_cnt+4'b1;
            end
        end
    endcase
end

reg [3:0] txstate = 4'b0;
reg [7:0] tx_data = 8'b0;
always @(posedge txclkcnt[2]) begin
    case (txstate)
        4'b0: begin //start bit
            if(write_p == 1'b1) begin
                txd <= 1'b0;
                txstate <= 4'b0001;
                xor_write_ack <= ~xor_write_ack;
            end else if (tx_ready == 1'b0) begin
                xor_tx_ready <= ~xor_tx_ready;
            end
        end
        4'b1001: begin //stop
            txstate <= 4'b1010;
            txd <= 1'b1;
        end
        4'b1010: begin //reset
            txstate <= 4'b0;
            xor_tx_ready <= ~xor_tx_ready;
            txd <= 1'b1;
        end
        default: begin // tx
            txd <= tx_data[txstate-4'b1];
            txstate <= txstate+4'b1;
        end
    endcase
end

// sync
always @(posedge clk) begin
    if(write != prev_write && write == 1'b1) begin
        xor_write_pulse <= ~xor_write_pulse;
        tx_ready <= 1'b0;
        tx_data <= tx_data_in;
    end
    if(read != prev_read && read == 1'b1) begin
        rx_new <= 1'b0;
    end
    if(xor_rx_new ^ prev_xor_rx_new) begin
        rx_new <= 1'b1;
        prev_xor_rx_new <= ~prev_xor_rx_new;
    end
    if(prev_xor_tx_ready ^ xor_tx_ready) begin
        tx_ready <= 1'b1;
        prev_xor_tx_ready <= ~prev_xor_tx_ready;
    end
    prev_write <= write;
    prev_read <= read;
end
endmodule
