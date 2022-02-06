module irq_ctrl (
    input wire clk,

    input wire [15:0] irq_in,

    input wire bus_clk,
    input wire bus_write,
    output reg irq_out,
    input wire [1:0] bus_addr,
    input wire [15:0] bus_data,
    output reg [15:0] bus_out
);

reg [15:0] r_enable;
reg [15:0] r_pending;
reg [15:0] prev_irq_in;

initial begin
    r_enable = 16'hffff;
    r_pending = 16'b0;
    irq_out = 1'b0;
end

always @(posedge bus_clk) begin
    if(|(r_pending & r_enable)) begin
        irq_out <= ~irq_out;
    end else begin
        irq_out <= 1'b0;
    end
end

always @(*) begin
    case (bus_addr)
        2'b0: bus_out = r_pending; 
        2'b1: bus_out = r_enable;
        default: bus_out = 16'b0;
    endcase
end

always @(posedge bus_clk) begin
    // only on pos edge
    r_pending = r_pending | ((prev_irq_in ^ irq_in) & irq_in);
    prev_irq_in = irq_in;

    if(bus_write) begin
        case (bus_addr)
        2'b0: r_pending = bus_data; // unsafe: use addr 10 
        2'b1: r_enable = bus_data;
        2'b10: r_pending = r_pending & (~bus_data); // for clearing pending irqs
        default: begin end
    endcase
    end
end


endmodule