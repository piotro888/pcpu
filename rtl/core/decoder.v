module decoder (
    input wire [15:0] instr,

    output reg pc_inc, pc_ie, reg_in_mux_ctl, alu_r_mux_ctl, alu_cin, ram_write, ram_read, alu_flags_ie, reg_sr_in, sr_ie, sr_pc_over,
    output reg [3:0] alu_mode, reg_l_ctl, reg_r_ctl,
    output reg [7:0] gp_reg_ie,
    input wire mem_busy, mem_ready,
    input wire [4:0] flags
);

wire [6:0] opcode = instr[6:0];
wire [2:0] tg_reg = instr[9:7];
wire [2:0] fo_reg = instr[12:10];
wire [2:0] so_reg = instr[15:13];

reg jmp_en;

always @(*) begin
    //defaults
    pc_inc <= 1;
    {pc_ie, reg_in_mux_ctl, alu_r_mux_ctl, alu_cin, alu_mode, reg_l_ctl, reg_r_ctl, gp_reg_ie, ram_write, ram_read, alu_flags_ie, reg_sr_in, sr_ie, sr_pc_over} <= 0;
    case (opcode)
        7'b0000001: begin //mov
            alu_mode            <= 4'b1001;
            gp_reg_ie[tg_reg]   <= 1'b1;
            reg_l_ctl           <= fo_reg;
        end
        7'b0000010: begin //ldd
            if(mem_busy) begin
                pc_inc          <= 1'b0;
					 // keep addr for mem switcher
					 alu_mode        <= 4'b1010; 
                alu_r_mux_ctl   <= 1'b1;
            end else if (mem_ready) begin
                alu_mode        <= 4'b1010;
                alu_r_mux_ctl   <= 1'b1;
                reg_in_mux_ctl  <= 1'b1;
                gp_reg_ie[tg_reg]<= 1'b1;
            end else begin
                alu_mode        <= 4'b1010;
                alu_r_mux_ctl   <= 1'b1;
                reg_in_mux_ctl  <= 1'b1;
                ram_read        <= 1'b1;
                pc_inc          <= 1'b0;
            end
        end
        7'b0000011: begin //ldo 
            if(mem_busy) begin
                pc_inc          <= 1'b0;
					 // keep addr for mem switcher
					 alu_mode        <= 4'b0000;
                reg_l_ctl       <= fo_reg;
                alu_r_mux_ctl   <= 1'b1;
            end else if (mem_ready) begin
                alu_mode        <= 4'b0000;
                reg_l_ctl       <= fo_reg;
                alu_r_mux_ctl   <= 1'b1;
                reg_in_mux_ctl  <= 1'b1;
                gp_reg_ie[tg_reg]<= 1'b1;
            end else begin    
                alu_mode        <= 4'b0000;
                reg_l_ctl       <= fo_reg;
                alu_r_mux_ctl   <= 1'b1;
                reg_in_mux_ctl  <= 1'b1;
                ram_read        <= 1'b1;
                pc_inc          <= 1'b0;
            end
        end
        7'b0000100: begin //ldi 
            alu_mode            <= 4'b1010;
            alu_r_mux_ctl       <= 1'b1;
            gp_reg_ie[tg_reg]   <= 1'b1;
        end
        7'b0000101: begin //std
            if(mem_busy) begin
                pc_inc          <= 1'b0;
					 // keep addr for mem switcher
					 alu_mode        <= 4'b1010;
                alu_r_mux_ctl   <= 1'b1;
            end else begin
                alu_mode        <= 4'b1010;
                alu_r_mux_ctl   <= 1'b1;
                reg_r_ctl       <= fo_reg;
                ram_write       <= 1'b1;
            end
        end
        7'b0000110: begin //sto
            if(mem_busy) begin
                pc_inc          <= 1'b0;
					 // keep addr for mem switcher
					 alu_mode        <= 4'b1010; 
                alu_r_mux_ctl   <= 1'b1;
                reg_in_mux_ctl  <= 1'b1;
            end else begin
                alu_mode        <= 4'b0000;
                alu_r_mux_ctl   <= 1'b1;
                reg_r_ctl       <= fo_reg;
                reg_l_ctl       <= so_reg;
                ram_write       <= 1'b1;           
            end
        end
        7'b0000111: begin //add
            alu_mode            <= 4'b0000;
            reg_l_ctl           <= fo_reg;
            reg_r_ctl           <= so_reg;
            gp_reg_ie[tg_reg]   <= 1'b1;
            alu_flags_ie        <= 1'b1;
        end
        7'b0001000: begin //adi
            alu_mode            <= 4'b0000;
            reg_l_ctl           <= fo_reg;
            alu_r_mux_ctl       <= 1'b1;
            gp_reg_ie[tg_reg]   <= 1'b1;
            alu_flags_ie        <= 1'b1;
        end
        7'b0001001: begin //adc
            alu_mode            <= 4'b0000;
            reg_l_ctl           <= fo_reg;
            reg_r_ctl           <= so_reg;
            alu_cin             <= flags[1];
            gp_reg_ie[tg_reg]   <= 1'b1;
            alu_flags_ie        <= 1'b1;
        end
        7'b0001010: begin //sub
            alu_mode            <= 4'b0001;
            reg_l_ctl           <= fo_reg;
            reg_r_ctl           <= so_reg;
            gp_reg_ie[tg_reg]   <= 1'b1;
            alu_flags_ie        <= 1'b1;
        end
        7'b0001011: begin //suc
            alu_mode            <= 4'b0001;
            reg_l_ctl           <= fo_reg;
            reg_r_ctl           <= so_reg;
            alu_cin             <= flags[1];
            gp_reg_ie[tg_reg]   <= 1'b1;
            alu_flags_ie        <= 1'b1;
        end
        7'b0001100: begin //cmp
            alu_mode            <= 4'b0001;
            reg_l_ctl           <= fo_reg;
            reg_r_ctl           <= so_reg;
            alu_flags_ie        <= 1'b1;
        end
        7'b0001101: begin //cmi
            alu_mode            <= 4'b0001;
            alu_r_mux_ctl       <= 1'b1;
            reg_l_ctl           <= fo_reg;
            alu_flags_ie        <= 1'b1;
        end
        7'b0001110: begin //jmp
            alu_mode            <= 4'b1010;
            alu_r_mux_ctl       <= 1'b1;
            pc_ie               <= jmp_en;
            pc_inc              <= ~jmp_en;
        end
        7'b0001111: begin //jal
            alu_mode            <= 4'b1010;
            alu_r_mux_ctl       <= 1'b1;
            pc_ie               <= 1'b1;
            pc_inc              <= 1'b0;
            reg_sr_in           <= 1'b1;
            gp_reg_ie[tg_reg]   <= 1'b1;
            sr_pc_over          <= 1'b1;
        end
        7'b0010000: begin //srl
            reg_sr_in           <= 1'b1;
            gp_reg_ie[tg_reg]   <= 1'b1;
        end
        7'b0010001: begin //srs
            alu_mode            <= 4'b1010;
            reg_r_ctl           <= fo_reg;
            sr_ie               <= 1'b1;
        end
        7'b0010011: begin //and
            alu_mode            <= 4'b0010;
            reg_l_ctl           <= fo_reg;
            reg_r_ctl           <= so_reg;
            gp_reg_ie[tg_reg]   <= 1'b1;
            alu_flags_ie        <= 1'b1;
        end
        7'b0010100: begin //orr
            alu_mode            <= 4'b0011;
            reg_l_ctl           <= fo_reg;
            reg_r_ctl           <= so_reg;
            gp_reg_ie[tg_reg]   <= 1'b1;
            alu_flags_ie        <= 1'b1;
        end
        7'b0010101: begin //xor
            alu_mode            <= 4'b0100;
            reg_l_ctl           <= fo_reg;
            reg_r_ctl           <= so_reg;
            gp_reg_ie[tg_reg]   <= 1'b1;
            alu_flags_ie        <= 1'b1;
        end
        7'b0010110: begin //ani
            alu_mode            <= 4'b0010;
            reg_l_ctl           <= fo_reg;
            alu_r_mux_ctl       <= 1'b1;
            gp_reg_ie[tg_reg]   <= 1'b1;
            alu_flags_ie        <= 1'b1;
        end
        7'b0010111: begin //ori
            alu_mode            <= 4'b0011;
            reg_l_ctl           <= fo_reg;
            alu_r_mux_ctl       <= 1'b1;
            gp_reg_ie[tg_reg]   <= 1'b1;
            alu_flags_ie        <= 1'b1;
        end
        7'b0011000: begin //xoi
            alu_mode            <= 4'b0100;
            reg_l_ctl           <= fo_reg;
            alu_r_mux_ctl       <= 1'b1;
            gp_reg_ie[tg_reg]   <= 1'b1;
            alu_flags_ie        <= 1'b1;
        end
        7'b0011001: begin //shl
            alu_mode            <= 4'b0101;
            reg_l_ctl           <= fo_reg;
            reg_r_ctl           <= so_reg;
            gp_reg_ie[tg_reg]   <= 1'b1;
            alu_flags_ie        <= 1'b1;
        end
        7'b0011010: begin //shr
            alu_mode            <= 4'b0110;
            reg_l_ctl           <= fo_reg;
            reg_r_ctl           <= so_reg;
            gp_reg_ie[tg_reg]   <= 1'b1;
            alu_flags_ie        <= 1'b1;
        end
        7'b0011011: begin //cai
            alu_mode            <= 4'b0010;
            reg_l_ctl           <= fo_reg;
            alu_r_mux_ctl       <= 1'b1;
            alu_flags_ie        <= 1'b1;
        end
        7'b0011100: begin //mul
            alu_mode            <= 4'b0111;
            reg_l_ctl           <= fo_reg;
            reg_r_ctl           <= so_reg;
            gp_reg_ie[tg_reg]   <= 1'b1;
            alu_flags_ie        <= 1'b1;
        end
        7'b0011101: begin //div
            alu_mode            <= 4'b1000;
            reg_l_ctl           <= fo_reg;
            reg_r_ctl           <= so_reg;
            gp_reg_ie[tg_reg]   <= 1'b1;
            alu_flags_ie        <= 1'b1;
        end
        
        default:  //nop
            pc_inc              <= 1'b1;
    endcase
end

always @(*) begin
        case (instr[10:7])
        4'b0001: //jca
            jmp_en <= flags[1];
        4'b0010: //jeq
            jmp_en <= flags[0];
        4'b0011: //jlt
            jmp_en <= flags[2];
        4'b0100: //jgt
            jmp_en <= ~(flags[2] | flags[0]);
        4'b0101: //jle
            jmp_en <= flags[0] | flags[2];
        4'b0110: //jge
            jmp_en <= ~flags[2];
        4'b0111: //jne
            jmp_en <= ~flags[0];
        4'b1000: jmp_en <= flags[3];
        4'b1001: jmp_en <= flags[3];
        default: //jmp
            jmp_en <= 1; 
    endcase
end
endmodule