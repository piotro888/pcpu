//`default_nettype none

module cpu (
    input wire clk, rst,
    output wire [15:0] e_addr_bus, e_prog_addr, e_data, 
    input wire [15:0] e_mem_bus, 
    input wire [31:0] e_instr,
    input wire [31:0] e_sdram_instr,
    input wire e_mem_busy, e_mem_ready, e_mem_cack,

    output wire ram_read_out, ram_write, ram_instr_access, ram_read_done,
    output wire [7:0] e_reg_leds,
    output wire [3:0] e_pc_leds
);

// BUSES
wire [15:0] reg_l_bus, reg_r_bus;
wire [15:0] alu_bus, mem_bus;
wire [31:0] instr_bus;

// MUXES
wire [15:0] reg_in_mux;
wire [15:0] alu_r_mux;

// CONNECTS
wire [5:0] alu_flags_out;
wire [15:0] prog_addr, spec_reg_out;
wire [15:0] fetch_addr;
wire [31:0] fetch_instr_bus;

// CONTROL SIGNALS
wire pc_inc, pc_ie, reg_in_mux_ctl, alu_r_mux_ctl, alu_cin, alu_flags_ie, reg_sr_in, sr_ie, sr_pc_over, ram_read;
wire [3:0] alu_mode, reg_l_ctl, reg_r_ctl;
wire [7:0] gp_reg_ie;
wire fetch_ram_read, fetch_wait, fetch_addr_mux;
wire flag_boot_mode, flag_instr_mem_over;

// REGISTERS r0..r7
wire [15:0] gp_reg_out [7:0];
genvar i;
generate
    for (i=0; i<8; i = i+1) begin : gp_regs
        register gp_reg(reg_in_mux, gp_reg_out[i], clk, gp_reg_ie[i], rst);
    end
endgenerate

// BLOCK ELEMENTS
alu alu(reg_l_bus, alu_r_mux, alu_bus, alu_mode, alu_cin, alu_flags_out, clk, alu_flags_ie);
pc pc(alu_bus, prog_addr, clk, pc_inc & (~fetch_wait | flag_boot_mode), (pc_ie | (sr_ie & instr_bus[31:16] == 16'b0)) & (~fetch_wait | flag_boot_mode), rst);
decoder decoder(instr_bus[15:0], pc_inc, pc_ie, reg_in_mux_ctl, alu_r_mux_ctl, alu_cin,
    ram_write, ram_read, alu_flags_ie, reg_sr_in, sr_ie, sr_pc_over, ram_read_done, alu_mode, reg_l_ctl, reg_r_ctl, gp_reg_ie,
    e_mem_busy, e_mem_ready, alu_flags_out);
fetch fetch(clk, prog_addr, e_sdram_instr, e_mem_busy, e_mem_cack, e_mem_ready, fetch_ram_read, fetch_instr_bus, fetch_addr, fetch_addr_mux, fetch_wait, flag_boot_mode);
sregs sregs(clk, rst, sr_ie, instr_bus[31:16], alu_bus, instr_bus[6:0], flag_boot_mode, flag_instr_mem_over);

// MUXES DEFINITIONS
assign reg_in_mux = (reg_in_mux_ctl | reg_sr_in ? (reg_sr_in ? spec_reg_out : mem_bus) : alu_bus);
assign alu_r_mux = (alu_r_mux_ctl ? instr_bus[31:16] : reg_r_bus);
assign reg_l_bus = gp_reg_out[reg_l_ctl];
assign reg_r_bus = gp_reg_out[reg_r_ctl];
assign spec_reg_out = ((instr_bus[31:16] == 16'b0 || sr_pc_over) ? prog_addr : 16'b0);
assign e_addr_bus = (fetch_addr_mux ? fetch_addr : alu_bus);
assign instr_bus = (flag_boot_mode ? e_instr : fetch_instr_bus);

// EXTERNAL CONNECTIONS
assign e_prog_addr = prog_addr;
assign e_data = reg_r_bus;
assign mem_bus = e_mem_bus;
assign e_reg_leds = gp_reg_out[0][7:0];
assign e_pc_leds = prog_addr[3:0];
assign ram_read_out = ram_read | fetch_ram_read;
assign ram_instr_access = fetch_addr_mux | flag_instr_mem_over;

endmodule