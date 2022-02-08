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
    input wire irq_in, irq_instr,
    input wire [15:0] pc_in,
    output wire irq_en,
    input wire out_addr_ovr, pc_ie, pc_inc,
    input wire [4:0] alu_flags_in,
    output reg [4:0] alu_flags,
    input wire alu_flags_ie,

    // paging
    input wire [15:0] addr_in,
    output reg [19:0] addr_out,
    input wire [15:0] prog_in,
    output reg [19:0] prog_out,
    output reg [7:0] prog_page_out
);

reg [3:0] rt_mode = 4'b0001; //#1  0-SUP 1-INA 2-IRQEN 3-MEMPAGE
reg [1:0] jtr_mode = 2'b01, jtr_mode_buff = 2'b01; //#2 0-BLM 1-PRGPAGE
reg [15:0] irq_pc = 16'b0; // #3 Temporaries for processor handled routines (IRQ - previous pc addr)
reg [3:0] irq_flags = 4'b0; // #5 Flags saved at IRQ: 0-MEMPG 1-PRGPG 2-SUP 3-(IINT - interrupt from 'int' instruction)
reg prev_irq = 1'b0;
reg [15:0] virt_scratch_reg; // #6 Temporary register for use in context switch with virtual memory

// page tables
reg [7:0] mem_page [15:0]; // [0xF] 0xFAA -> 0x01 0xFAA (16(4)->20(8))
reg [7:0] prog_page [15:0];

always @(posedge clk, posedge rst) begin
    if(rst) begin
        rt_mode <= 4'b0001;
        jtr_mode <= 2'b01; jtr_mode_buff <= 2'b01; 
        prev_irq <= 1'b0; irq_pc <= 16'b0;
        alu_flags <= 5'b0;
    end else begin
        if(sr_ie) begin
            case(sr_sel)
                16'b1: begin
                    if(rt_mode[0]) begin // allow modification only if SUP mode is set
                        rt_mode <= sr_in[3:0];
                    end
                end
                16'b10:
                    jtr_mode_buff <= sr_in[1:0];
                16'b11:
                    irq_pc <= sr_in;
                16'b100:
                    alu_flags <= sr_in[4:0];
                16'b110:
                    virt_scratch_reg <= sr_in;
                default: begin end
            endcase
            if(sr_sel >= 16'b10000 && sr_sel <= 16'b11111 && rt_mode[0]) begin
                mem_page[sr_sel-16'b10000] <= sr_in[7:0];
            end
            if(sr_sel >= 16'b100000 && sr_sel <= 16'b101111 && rt_mode[0]) begin
                prog_page[sr_sel-16'b100000] <= sr_in[7:0];
            end
        end

        if (instr_op == 7'b0001110 || instr_op == 7'b0001111 || instr_op == 7'b0011110 || (instr_op == 7'b0010001 && sr_sel == 16'b0)) begin
            jtr_mode <= jtr_mode_buff;
        end

        if(out_addr_ovr) begin
            rt_mode[2] <= 1'b1;
        end
        
        if(irq_in & rt_mode[2]) begin
            // save old flags
            irq_flags[3:0] = {irq_instr, rt_mode[0], jtr_mode[1], rt_mode[3]};

            rt_mode[0] <= 1'b1; // set priviedged mode on interrupt
            // disable paging
            rt_mode[3] <= 1'b0;
            jtr_mode[1] <= 1'b0;
            jtr_mode_buff[1] <= 1'b0; // update of jmp buff is also needed!

            // disable interrrupts (this prevents only setting up irq_p in fetch, this interrrupt is processed ok)
            rt_mode[2] <= 1'b0;

            // save old pc to sr 3 (simultate change to next instruction - no repeat at iret)
            if (pc_ie)
                irq_pc <= sr_in[15:0];
            else if (pc_inc)
                irq_pc <= pc_in + 16'b1;

            // ? interrupt source
            // jump 0x1 in pc module
        end

        if(alu_flags_ie)
            alu_flags <= alu_flags_in;
        prev_irq <= irq_in;
    end
end

assign boot_mode = jtr_mode[0];
assign instr_mem_over = rt_mode[1];
assign irq_en = rt_mode[2];

always @(*) begin
    if(~out_addr_ovr) begin
        case (sr_sel)
            16'b1: sr_out = rt_mode;
            16'b10: sr_out = jtr_mode;
            16'b11: sr_out = irq_pc;
            16'b100: sr_out = alu_flags;
            16'b101: sr_out = irq_flags;
            16'b110: sr_out = virt_scratch_reg;
            default: sr_out = 16'b0;
        endcase
    end else begin
        sr_out = irq_pc;
    end

    if(~rt_mode[3]) 
        addr_out = {4'b0, addr_in};
    else
        addr_out = {mem_page[addr_in[15:12]], addr_in[11:0]};

    if(~jtr_mode[1])  begin
        prog_out = {4'b0, prog_in};
        prog_page_out = 8'b0;
    end else begin
        prog_out = {prog_page[prog_in[15:12]], prog_in[11:0]};
        prog_page_out = prog_page[prog_in[15:12]];
    end
end

endmodule
