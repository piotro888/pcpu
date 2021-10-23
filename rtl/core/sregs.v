module sregs(
    input wire clk,
    input wire rst,
    input wire sr_ie,
    input wire [15:0] sr_sel, sr_in,
    input wire [6:0] instr_op,
    output reg [15:0] sr_out,

    //OUTPUT CONTROL SIGNALS
    output wire boot_mode, instr_mem_over,

    // interrupt handling
    input wire irq_in,
    input wire [15:0] pc_in,
    output wire irq_en,
    input wire out_addr_ovr, pc_ie, pc_inc
);

reg [2:0] rt_mode = 3'b001; //#1  0-SUP 1-INA 2-IRQEN
reg jtr_mode = 1'b1, jtr_mode_buff = 1'b1; //#2 0-BLM
reg [15:0] irq_pc = 1'b0; // #3 Temporaries for processor handled routines (IRQ - previous pc addr)
reg prev_irq = 1'b0;

always @(posedge clk, posedge rst) begin
    if(rst) begin
        rt_mode <= 3'b001;
        jtr_mode <= 1'b1; jtr_mode_buff <= 1'b1; 
        prev_irq <= 1'b0;
    end else begin
        if(sr_ie) begin
            case(sr_sel)
                16'b1: begin
                    if(rt_mode[0]) begin // allow modification only if SUP mode is set
                        rt_mode <= sr_in[2:0];
                    end
                end
                16'b10:
                    jtr_mode_buff <= sr_in[0];
                16'b11:
                    irq_pc <= sr_in;
            endcase        
        end

        if (instr_op == 7'b0001110 || instr_op == 7'b0001111 || (instr_op == 7'b0010001 && sr_sel == 16'b0)) begin
            jtr_mode <= jtr_mode_buff;
        end

        if(out_addr_ovr) begin
            rt_mode[2] <= 1'b1;
        end
        
        if(irq_in & rt_mode[2]) begin
            rt_mode[0] <= 1'b1; // set priviedged mode on interrupt

            // save old pc to sr 3 (simultate change to next instruction - no repeat at iret)
            if (pc_ie)
                irq_pc <= sr_in[15:0];
            else if (pc_inc)
                irq_pc <= pc_in + 16'b1;

            // ? interrupt source
            // jump 0x1 in pc module
        end

        if(~irq_in & prev_irq & rt_mode[2]) begin
            // disable interrupts only when pc already changed value (and irq_p cleared).
            // other values must be saved immediately
            rt_mode[2] <= 1'b0; 
        end
    end
    prev_irq <= irq_in;
end

assign boot_mode = jtr_mode;
assign instr_mem_over = rt_mode[1];
assign irq_en = rt_mode[2];

always @(*) begin
    if(~out_addr_ovr) begin
        case (sr_sel)
            16'b11: sr_out = irq_pc;
            default: sr_out = 16'b0;
        endcase
    end else begin
        sr_out = irq_pc;
    end
end

endmodule
