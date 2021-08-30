module sregs(
    input wire clk,
    input wire sr_ie,
    input wire [15:0] sr_sel, sr_in,
    input wire [6:0] instr_op,

    //OUTPUT CONTROL SIGNALS
    output wire boot_mode, instr_mem_over
);

reg [1:0] rt_mode = 2'b01; //#1  0-SUP 1-INA 
reg jtr_mode = 1'b1, jtr_mode_buff = 1'b1; //#2 0-BLM

always @(posedge clk) begin
    if(sr_ie) begin
        case(sr_sel)
            16'b1: begin
                if(rt_mode[0]) begin
                    rt_mode = sr_in[1:0];
                end
            end
            16'b10:
                jtr_mode_buff = sr_in[0];
        endcase        
    end

    if (instr_op == 7'b0001110 || instr_op == 7'b0001111 || (instr_op == 7'b0010001 && sr_sel == 16'b0)) begin
        jtr_mode <= jtr_mode_buff;
    end
end

assign boot_mode = jtr_mode;
assign instr_mem_over = rt_mode[1];

endmodule
