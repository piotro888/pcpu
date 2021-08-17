//`default_nettype none

module cpu (
    input wire clk, rst,
    output wire [15:0] e_addr_bus, e_prog_addr, e_data, 
    input wire [15:0] e_mem_bus, 
    input wire [31:0] e_instr,
    input wire e_mem_busy, e_mem_ready,

    output wire ram_read, ram_write,
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
wire [7:0] alu_flags_out;
wire [15:0] prog_addr;

// CONTROL SIGNALS
wire pc_inc, pc_ie, reg_in_mux_ctl, alu_r_mux_ctl, alu_cin, alu_flags_ie;
wire [3:0] alu_mode, reg_l_ctl, reg_r_ctl;
wire [7:0] gp_reg_ie;

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
pc pc(alu_bus, prog_addr, clk, pc_inc, pc_ie, rst);
decoder decoder(instr_bus[15:0], pc_inc, pc_ie, reg_in_mux_ctl, alu_r_mux_ctl, alu_cin,
    ram_write, ram_read, alu_flags_ie, alu_mode, reg_l_ctl, reg_r_ctl, gp_reg_ie,
    e_mem_busy, e_mem_ready, alu_flags_out);

// MUXES DEFINITIONS
assign reg_in_mux = (reg_in_mux_ctl ? mem_bus : alu_bus);
assign alu_r_mux = (alu_r_mux_ctl ? instr_bus[31:16] : reg_r_bus);
assign reg_l_bus = gp_reg_out[reg_l_ctl];
assign reg_r_bus = gp_reg_out[reg_r_ctl];

// EXTERNAL CONNECTIONS
assign e_addr_bus = alu_bus;
assign e_prog_addr = prog_addr;
assign e_data = reg_r_bus;
assign mem_bus = e_mem_bus;
assign instr_bus = e_instr;
assign e_reg_leds = gp_reg_out[0][7:0];
assign e_pc_leds = prog_addr[3:0];



endmodule

`ifndef ALTERA_RESERVED_QIS
`include "alu.v"
`include "pc.v"
`include "register.v"
`include "decoder.v"
`endif