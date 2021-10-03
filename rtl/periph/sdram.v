module sdram (
    input wire clk,
    // CPU
    input wire [22:0] c_addr,
    input wire [15:0] c_data_in,
    output reg [31:0] c_data_out,
    input wire c_read_req, c_write_req,
    output reg c_busy, c_read_ready,
    // SDRAM
    output reg dr_dqml, dr_dqmh,
    output wire dr_cs_n, dr_cas_n, dr_ras_n, dr_we_n, dr_cke,
    output reg [1:0] dr_ba,
    output reg  [12:0] dr_a,
    inout [15:0] dr_dq,
	 input wire srclk,
    // instruction support
    input wire instruction_mode
);

localparam CMD_NOP = 3'b111;
localparam CMD_ACTIVE = 3'b011;
localparam CMD_READ = 3'b101;
localparam CMD_WRITE = 3'b100;
localparam CMD_PRECH = 3'b010;
localparam CMD_AREFR = 3'b001;
localparam CMD_LREG = 3'b000;

reg [2:0] ram_cmd = CMD_NOP;
assign {dr_ras_n, dr_cas_n, dr_we_n} = ram_cmd;
assign dr_cke = 1'b1;
assign dr_cs_n = 1'b0;

localparam STATE_INIT_BEGIN = 4'b0000;
localparam STATE_INIT_PRECALL = 4'b0001;
localparam STATE_INIT_AUTOREF1 = 4'b0010;
localparam STATE_INIT_AUTOREF2 = 4'b0011;
localparam STATE_INIT_REGPROG = 4'b0100;
localparam STATE_IDLE = 4'b0101;
localparam STATE_REFR = 4'b0110;
localparam STATE_READ = 4'b0111;
localparam STATE_CASREAD = 4'b1000;
localparam STATE_WRITE = 4'b1001;
localparam STATE_READ_INSTR2 = 4'b1010;
localparam STATE_CASREAD_INSTR2 = 4'b1011;
localparam STATE_WAIT = 4'b1111;
reg [3:0] state = STATE_INIT_BEGIN;

reg [15:0]  wait_reg;
reg [3:0]  wait_next_state;

reg [15:0] dr_dq_reg;
reg dr_dq_oe = 1'b0;
assign dr_dq = (dr_dq_oe ? dr_dq_reg : 16'bz);

// refr 7.183 us -> 355 clock -8/10/15 PRECHARGE ALL BEFORE RESET
reg [8:0] autorefr_cnt = 9'd55;

initial c_busy <= 1'b1;
initial c_read_ready <= 1'b0;

reg [22:0] i_addr;
reg [15:0] i_data_in;

reg sync_xory_read = 1'b0;
always @(posedge srclk)begin
	if(c_read_req & ~c_busy)
		sync_xory_read <= sync_xory_read^1;
end
reg sync_x_read_done = 1'b0;
wire pulse_c_read = (sync_xory_read ^ sync_x_read_done) & ~c_read_ready;

reg sync_xory_write = 1'b0;
always @(posedge srclk)begin
	if(c_write_req & ~c_busy)
		sync_xory_write <= sync_xory_write^1;
end
reg sync_x_write_done = 1'b0;
wire pulse_c_write = sync_xory_write ^ sync_x_write_done;

reg l_instruction_mode = 1'b0;

reg prev_srclk = 1'b0;
// 50 Mhz -> 20 ns
// RP 18ns RFC 60ns
always @(posedge clk) begin
    {dr_dqml, dr_dqmh} <= 2'b11; dr_dq_oe <= 1'b0; dr_a <= 13'b0; dr_ba <= 2'b0; 
	 prev_srclk <= srclk;
	 if((prev_srclk ^ srclk) & srclk & ~l_instruction_mode)
		c_read_ready <= 1'b0;
     if(prev_srclk != srclk && srclk == 1'b0 && l_instruction_mode == 1'b1) 
        c_read_ready <= 1'b0;
	 
    case (state)
        STATE_INIT_BEGIN: begin
            ram_cmd <= CMD_NOP;
            state <= STATE_WAIT;
            wait_next_state <= STATE_INIT_PRECALL;
            //wait_reg <= 16'd5000; 
				wait_reg <= 16'd10; 
        end
        STATE_INIT_PRECALL: begin
            ram_cmd <= CMD_PRECH;
            dr_a[10] <= 1'b1; // all banks
            state <= STATE_WAIT;
            wait_next_state <= STATE_INIT_AUTOREF1;
            wait_reg <= 16'd1;
        end
        STATE_INIT_AUTOREF1: begin
            ram_cmd <= CMD_AREFR;
            state <= STATE_WAIT;
            wait_next_state  <= STATE_INIT_AUTOREF2;
            wait_reg <= 16'd4; // 80 ns
        end
        STATE_INIT_AUTOREF2: begin
            ram_cmd <= CMD_AREFR;
            state <= STATE_WAIT;
            wait_next_state  <= STATE_INIT_REGPROG;
            wait_reg <= 16'd4; // 80 ns
        end
        STATE_INIT_REGPROG: begin
            ram_cmd <= CMD_LREG;
            dr_a <= 13'b0001000100000;
            // CAS 2 BURST R1 W1 SEQ
            // CAS 1 CORRECT? DATASHEET
            dr_ba <= 2'b00;
            state <= STATE_WAIT;
            wait_next_state  <= STATE_IDLE;
            wait_reg <= 16'd4; // 80 ns
        end
        STATE_IDLE: begin
           // c_busy <= 1'b1; //default if not staying in idle
            if(pulse_c_read) begin
                ram_cmd <= CMD_ACTIVE; //CHECK IF NOT ACTIVATED ALREADY
                //STORE PROG AND DATA IN DIFFERENT BANKS TO NOT PRECHARGE EVERY COMMAND
                //8192 rows x 512 col x 16 bit x 4 banks
                // 13 b     +  9 b    + 16 b   + 2b
                i_addr <= c_addr;
                i_data_in <= c_data_in;
                dr_ba <= {instruction_mode, c_addr[22]}; // lower max ram addr and set banks to msb???
                if(instruction_mode)
                    dr_a <= c_addr[20:8]; // read instr addresses are shifted by 1
                else
                    dr_a <= c_addr[21:9];
                state <= STATE_WAIT;
                wait_next_state <= STATE_READ;
                wait_reg <= 16'd1;
                l_instruction_mode <= instruction_mode;
					 c_busy <= 1'b1;
					 sync_x_read_done <= sync_x_read_done^1;
            end else if(pulse_c_write) begin
                ram_cmd <= CMD_ACTIVE;
                i_addr <= c_addr;
                i_data_in <= c_data_in;
                dr_ba <= {instruction_mode, c_addr[22]};
                dr_a <= c_addr[21:9];
                state <= STATE_WAIT;
                wait_next_state <= STATE_WRITE;
                l_instruction_mode <= instruction_mode;
                wait_reg <= 16'd1;
					 c_busy <= 1'b1;
					 sync_x_write_done <= sync_x_write_done^1;
            end else if(~(|autorefr_cnt)) begin
                ram_cmd <= CMD_PRECH;
                dr_a[10] <= 1'b1; //ALL BANKS
                state <= STATE_WAIT;
                wait_next_state <= STATE_REFR;
                wait_reg <= 16'd1;
					 c_busy <= 1'b1;
            end else begin
                ram_cmd <= CMD_NOP;
                state <= STATE_IDLE;
                c_busy <= 1'b0;
            end
        end
        STATE_WRITE: begin
            ram_cmd <= CMD_WRITE;
            {dr_dqml, dr_dqmh} <= 2'b00;
            dr_ba <= {instruction_mode, i_addr[22]};
            dr_a[8:0] <= i_addr[8:0];
            dr_a[9] <= 1'b0; dr_a[12:11] <= 1'b0;
            dr_a[10] <= 1'b1; //auto precharge
            dr_dq_reg <= i_data_in;
            dr_dq_oe <= 1'b1;
            state <= STATE_WAIT;
            wait_next_state <= STATE_IDLE;
            wait_reg <= 16'd1;
        end
        STATE_REFR: begin
            ram_cmd <= CMD_AREFR;
            state <= STATE_WAIT;
            wait_next_state <= STATE_IDLE;
            wait_reg <= 16'd4;
            autorefr_cnt <= 9'd355;
        end
        STATE_READ: begin
            ram_cmd <= CMD_READ;
            {dr_dqml, dr_dqmh} <= 2'b00;
            //don't use burst but two subseq reads for instr
            dr_ba <= {instruction_mode, i_addr[22]};
            if(l_instruction_mode) begin
                //!!!! addr bit 9 is out of range for coulumn address
                dr_a[8:0] <= {i_addr[7:0], 1'b0};
                dr_a[9] <= 1'b0;
                dr_a[12:11] <= 1'b0;
                dr_a[10] <= 1'b0; //disable auto precharge for second read
                state <= STATE_READ_INSTR2;
            end else begin
                dr_a[8:0] <= i_addr[8:0];
                dr_a[9] <= 1'b0; dr_a[12:11] <= 1'b0;
                dr_a[10] <= 1'b1; //auto precharge
                state <= STATE_WAIT;
                wait_next_state <= STATE_CASREAD;
                wait_reg <= 16'd1;
            end
        end
        STATE_CASREAD: begin
            state <= STATE_IDLE; //no wait needed
            ram_cmd <= CMD_NOP;
            c_data_out <= {16'b0, dr_dq};
            if(l_instruction_mode) begin
                state <= STATE_CASREAD_INSTR2;
            end else begin
                c_read_ready <= 1'b1;
                c_busy <= 1'b0;
            end
        end
        STATE_READ_INSTR2: begin //instead of wait for first, pipeline second read
            ram_cmd <= CMD_READ;
            {dr_dqml, dr_dqmh} <= 2'b00;
            dr_ba <= {instruction_mode, i_addr[22]};
            dr_a[8:0] <= {i_addr[7:0], 1'b1};
            dr_a[9] <= 1'b0; // column addr width [8:0]
            dr_a[12:11] <= 1'b0;
            dr_a[10] <= 1'b1; //auto precharge
            state <= STATE_CASREAD;
        end
        STATE_CASREAD_INSTR2: begin
            state <= STATE_IDLE; 
            ram_cmd <= CMD_NOP;
            c_data_out[31:16] <= dr_dq; // fill upper instr from pipelined request
            state <= STATE_IDLE;
            c_read_ready <= 1'b1;
            c_busy <= 1'b0;
        end
        default: begin // STATE_WAIT
            ram_cmd <= CMD_NOP;
            if(wait_reg == 16'b01) begin
                state <= wait_next_state;
                if (wait_next_state == STATE_IDLE) c_busy <= 1'b0;
                else c_busy <= 1'b1;
            end
            wait_reg <= wait_reg-1;
        end
    endcase

    if(|autorefr_cnt) autorefr_cnt <= autorefr_cnt-1;
end
    
endmodule