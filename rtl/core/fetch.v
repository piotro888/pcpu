module fetch(
    input wire clk,
    input wire [15:0] pc_in,
    input wire [31:0] ram_data,
    input wire ram_busy, ram_cack, ram_data_ready,
    output reg ram_read,
    output reg [31:0] instr_out,
    output reg [15:0] ram_addr,
    output reg ram_addr_ovr,
    output reg pc_hold,
    input wire flag_boot_mode,
    input wire rst,
    input wire irq_in, irq_en,
    output reg irq_p
);

reg [1:0] state;
reg c_acked;
reg [15:0] prev_pc;
reg [31:0] pref_instr;
reg prev_irq;

initial  state = 2'b0;
initial ram_read = 1'b0;
initial ram_addr_ovr = 1'b0;
initial pc_hold = 1'b0;
initial instr_out = 32'b0;

// Do not prefetch on memory access instructions
wire prefetch_ok = instr_out[6:0] != 7'h02 && instr_out[6:0] != 7'h03 && instr_out[6:0] != 7'h05 && instr_out[6:0] != 7'h06;
wire prefetch_ok_ramd = ram_data[6:0] != 7'h02 && ram_data[6:0] != 7'h03 && ram_data[6:0] != 7'h05 && ram_data[6:0] != 7'h06;
wire prefetch_ok_pref = pref_instr[6:0] != 7'h02 && pref_instr[6:0] != 7'h03 && pref_instr[6:0] != 7'h05 && pref_instr[6:0] != 7'h06;

// Adresses are paged after fetch module, so prefetch may break if jtr to pc+1 and changed prgmem table. Jumping to 0 is recommended

always @(negedge clk, posedge rst) begin
    if(rst) begin
        ram_read <= 1'b0;
        instr_out <= 31'b0;
        ram_addr <= 16'b0;
        ram_addr_ovr <= 1'b0;
        pc_hold <= 1'b0;
        state <= 2'b0;
        prev_pc <= 16'hFFFF;
        c_acked <= 1'b0;
        irq_p <= 1'b0;
        prev_irq <= 1'b0;
    end else begin
        if(~flag_boot_mode) begin
            if(pc_in != prev_pc) begin
                pc_hold <= 1'b1;
                instr_out <= 32'b0; // no-op as hold instr
            end

            case(state)
                2'b0: begin  // IDLE STATE
                    if((pc_in != prev_pc || pc_hold) && ~ram_busy) begin // if pc change fetch new instr
                        ram_read <= 1'b1;
                        ram_addr_ovr <= 1'b1;
                        ram_addr <= pc_in; // fetch instruction pc pointing to
                        state <= 2'b1; // got to next state
                    end else if(prefetch_ok) begin // start prefetch
                        ram_read <= 1'b1;
                        ram_addr_ovr <= 1'b1;
                        state <= 2'b10;
                        // static prediction pc+1
                        ram_addr <= pc_in+16'b1;
                    end
                end
                2'b1: begin // RAM READ STATE
                    if(~ram_cack && ~c_acked) begin // ram didn't registered command, retry
                        ram_read <= 1'b1;
                        ram_addr_ovr <= 1'b1;
                    end else begin
                        ram_read <= 1'b0;
                        c_acked <= 1'b1;
                        if(ram_data_ready) begin // ram read finished
                            ram_read <= 1'b0;
                            c_acked <= 1'b0;
                            pc_hold <= 1'b0;
                            instr_out <= ram_data; // release read
                
                            if(prefetch_ok_ramd) begin  // try starting prefetch (ramd because instr_out not set yet)
                                ram_read <= 1'b1;
                                ram_addr_ovr <= 1'b1;
                                state <= 2'b10;
                                // static prediction pc+1
                                ram_addr <= pc_in+16'b1;
                            end else begin // else go to idle state
                                ram_addr_ovr <= 1'b0;
                                state <= 2'b0;
                            end
                        end else begin // wait for data ready
                            ram_addr_ovr <= 1'b1;
                        end
                    end
                end
                2'b10: begin // PREFETCH STATE
                    if(~ram_cack && ~c_acked) begin // ram didn't registered command, retry
                        ram_read <= 1'b1;
                        ram_addr_ovr <= 1'b1;
                        ram_read <= 1'b1;
                    end else begin
                        ram_read <= 1'b0;
                        c_acked <= 1'b1;

                        if(ram_data_ready && (pc_in != prev_pc || pc_hold)) begin // ram read finished & new instruction arrived
                            if(pc_in == ram_addr) begin // predict hit, return to idle
                                ram_addr_ovr <= 1'b0;
                                c_acked <= 1'b0;
                                pc_hold <= 1'b0; 
                                instr_out <= ram_data;
                                if(prefetch_ok_ramd) begin  // try starting next prefetch
                                    ram_read <= 1'b1;
                                    ram_addr_ovr <= 1'b1;
                                    state <= 2'b10;
                                    // static prediction pc+1
                                    ram_addr <= pc_in+16'b1;
                                end else begin // else go to idle state
                                    ram_addr_ovr <= 1'b0;
                                    state <= 2'b0;
                                end
                            end else begin // predict miss, start normal read
                                c_acked <= 1'b0;
                                ram_read <= 1'b1;
                                ram_addr_ovr <= 1'b1;
                                ram_addr <= pc_in;
                                state <= 2'b1;
                            end
                        end else if(ram_data_ready) begin // ram read finished while instruction is still executing
                            c_acked <= 1'b0;
                            pref_instr <= ram_data;
                            state <= 2'b11;
                        end else begin // wait for data ready
                            ram_addr_ovr <= 1'b1;
                        end
                    end
                end
                2'b11: begin // PREFETCH wait for next pc STATE
                    if(pc_in != prev_pc || pc_hold) begin // new instruction
                        if(pc_in == ram_addr) begin // predict hit, return to idle
                            c_acked <= 1'b0;
                            pc_hold <= 1'b0; 
                            instr_out <= pref_instr;
                            if(prefetch_ok_pref) begin  // try starting next prefetch
                                ram_read <= 1'b1;
                                ram_addr_ovr <= 1'b1;
                                state <= 2'b10;
                                // static prediction pc+1
                                ram_addr <= pc_in+16'b1;
                            end else begin // else go to idle state
                                ram_addr_ovr <= 1'b0;
                                state <= 2'b0;
                            end
                        end else begin // predict miss, start normal read
                            ram_read <= 1'b1;
                            ram_addr_ovr <= 1'b1;
                            ram_addr <= pc_in;
                            state <= 2'b1;
                        end
                    end
                end
            endcase
        end

        if(irq_in != prev_irq && irq_in == 1'b1 && irq_en)
            irq_p <= 1'b1;

        if(pc_in == 16'b1 && irq_p)
            irq_p <= 1'b0;

        prev_pc <= pc_in;
        prev_irq <= irq_in;
    end
end

endmodule