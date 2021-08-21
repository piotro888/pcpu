module fetch (
    input wire clk,
    input wire [31:0] ram_out,
    output wire [31:0] proc_instr_out,
    input wire [15:0] pc_in,
    output wire ram_read, addr_bus_mux_ctl,
    input wire [31:0] prom_in,
    input wire bootloader_mode
);

reg [3:0] state = 4'b0;
reg waiting = 1'b1;
// wire memop_do_not_overlap = proc_instr[6:0] >= 7'b0000010 &&  proc_instr[6:0] <= 7'b0000110;
reg [15:0] prev_pc = 16'b0; //, predi_pc = 16'b0;
//reg [31:0] keep_instr;

assign proc_instr_out = (bootloader_mode ? prom_in : proc_instr);

always @(negedge clk) begin
    if(~bootloader_mode) begin
        if(waiting) proc_instr <= 32'b0;

        if(pc_in != prev_pc) begin
                waiting <= 1'b1;
                proc_instr <= 32'b0;
        end

        case (state)
            4'b0: begin
                if(~ram_busy && (waiting || pc_in != prev_pc)) begin
                    state <= 4'b1;
                    ram_read <= 1'b1;
                    addr_bus_mux_ctl <= 1'b1;
                // end else if (~ram_busy && ~memop_do_not_overlap) begin
                //     state <= 4'b10;
                //     ram_read <= 1'b1;
                //     //PREDICT TAKEN OR NOT
                //     addr_bus_mux_ctl <= 2'b10;
                //     predi_pc <= pc_in+16'b1;
                end
            end
            default: begin // 4'b1
                if(ram_data_ready) begin
                    proc_instr <= ram_out;
                    waiting <= 1'b0;
                    state <= 4'b0;
                end else begin
                    addr_bus_mux_ctl <= 1'b1;
                end
            end
            // TODO: FETCH & EXECUTE IN THE SAME TIME AND STATIC PREDICT
            // 4'b10: begin
            //     if(ram_data_ready && (waiting || pc_in != prev_pc)) begin 
            //         if(predi_pc == pc_in) begin 
            //             proc_instr <= ram_out;
            //             waiting <= 1'b0; 
            //             state <= 4'b0;
            //         end else begin
            //             state <= 4'b1;
            //             ram_read <= 1'b1;
            //             addr_bus_mux_ctl <= 1'b1;
            //         end
            //     end else if(ram_data_ready) begin // never reached / 1cycleinstr
            //         state <= 4'b11;
            //         keep_instr <= ram_out;
            //     end else begin
            //         addr_bus_mux_ctl <= 1'b1;
            //         //predicty
            //     end
            // end
            // default: begin //4'b11 // never reached / 1cycleinstr
            //     if(pc_in != prev_pc) begin
            //         if(predi_pc == pc_in) begin
            //             proc_instr <= keep_instr;
            //             waiting <= 1'b0;
            //             state <= 4'b0;
            //         end else begin
            //             state <= 4'b1;
            //             ram_read <= 1'b1;
            //             addr_bus_mux_ctl <= 1'b1;
            //         end
            //     end
            // end
        endcase
        
        prev_pc <= pc_in;
    end
end

    
endmodule