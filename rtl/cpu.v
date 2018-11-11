`timescale 1ns / 1ps
`default_nettype wire
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Wenting Zhang
// 
// Create Date:    17:30:26 02/08/2018 
// Module Name:    cpu
// Project Name:   VerilogBoy
// Description: 
//   The Game Boy CPU.
// Dependencies: 
// 
// Additional Comments: 
//   
//////////////////////////////////////////////////////////////////////////////////

module cpu(
    input clk,
    input rst,
    output reg phi,
    output reg [15:0] a,
    output reg [7:0] dout,
    input [7:0] din,
    output reg rd,
    output reg wr
    );

    reg  [7:0]  opcode;
    wire [1:0]  alu_src_a;
    wire [2:0]  alu_src_b;
    wire [1:0]  alu_op_prefix;
    wire [1:0]  alu_op_src;
    wire [1:0]  alu_dst;
    wire [1:0]  pc_src;
    wire        pc_we;
    wire [2:0]  rf_wr_sel;
    wire [2:0]  rf_rd_sel;

    wire [2:0]  rf_rdn;
    wire [7:0]  rf_rd;
    wire [15:0] rf_rdw;
    wire [7:0]  rf_h;
    wire [7:0]  rf_l;
    wire [2:0]  rf_wrn;
    wire [7:0]  rf_wr;
    wire        rf_we;

    wire [7:0]  alu_a;
    wire [7:0]  alu_b;
    wire [7:0]  alu_result;
    wire [3:0]  alu_flags_in;
    wire [3:0]  alu_flags_out;
    wire [4:0]  alu_op;
    wire        alu_carry_out;

    wire [7:0]  acc_wr;
    wire        acc_we;
    wire [7:0]  acc_rd;

    wire [15:0] pc_rd;
    wire [7:0]  pc_rd_b;
    wire        pc_b_sel; // byte select
    wire [15:0] pc_wr;
    wire [7:0]  pc_wr_b;
    wire        pc_we_h;
    wire        pc_we_l;

    wire [15:0] temp_rd; // temp value for 16bit imm

    wire [3:0]  flags_rd;
    wire [3:0]  flags_wr;
    wire        flags_we;
    
    wire [7:0]  db_wr;
    wire [7:0]  db_rd;
    wire        db_we;

    wire [15:0] imm_ext;
    wire [7:0]  imm_ext_high;
    wire [7:0]  imm_ext_low;

    // Control Logic
    // Control Logic is only used in EX stage
    // Signals are gated.
    wire [1:0] alu_src_a_ex;
    wire [2:0] alu_src_b_ex;
    wire [1:0] alu_op_prefix_ex;
    wire [1:0] alu_op_src_ex;
    wire [1:0] alu_dst_ex;

    contorl control(
        .clk(clk),
        .rst(rst),
        .opcode(opcode),
        .alu_src_a(alu_src_a_ex),
        .alu_src_b(alu_src_b_ex),
        .alu_op_prefix(alu_op_prefix_ex),
        .alu_op_src(alu_op_src_ex),
        .alu_dst(alu_dst_ex),
        .pc_src(pc_src),
        .pc_we(pc_we),
        .rf_wr_sel(rf_wr_sel),
        .rf_rd_sel(rf_rd_sel)
    );

    // Data Bus Buffer
    reg [7:0] db_wr_buffer;
    reg [7:0] db_rd_buffer;
    
    always @(posedge clk) begin
        if (db_we)
            db_wr_buffer <= db_wr;
    end
    assign db_rd = db_rd_buffer;

    // Address Bus Buffer
    wire [15:0] ab_wr;
    // TBD

    // Bus Control Signals
    reg [2:0] bus_op; // Generate by control unit

    // Regisiter file
    regfile regfile(
        .clk(clk),
        .rst(rst),
        .rdn(rf_rdn),
        .rd(rf_rd),
        .rdw(rf_rdw),
        .h(rf_h),
        .l(rf_l),
        .wrn(rf_wrn),
        .wr(rf_wr),
        .we(rf_we),
    );
    assign rf_wr = alu_result;
    assign rf_we = (alu_dst == 2'b10);
    assign rf_wrn = rf_wr_sel;
    assign rf_rdn = rf_rd_sel;


    // Register A
    reg8 acc(
        .clk(clk),
        .rst(rst),
        .wr(acc_wr),
        .we(acc_we),
        .rd(acc_rd)
    );
    assign acc_wr = alu_result; 
    assign acc_we = (alu_dst == 2'b00);
    
    // Register PC
    reg [15:0] pc;
    assign pc_rd = pc; 
    assign pc_rd_b = (pc_b_sel == 1'b0) : (pc[7:0]) : (pc[15:8]);
    assign pc_wr_b = alu_result;
    assign pc_wr = (
        (pc_src == 2'b00) ? (rf_rdw) : (
        (pc_src == 2'b01) ? ({2'b00, opcode[7:6], opcode[3], 3'b000}) : (
        (pc_src == 2'b10) ? (temp_rd) : (
        (pc_src == 2'b11) ? (8'b0) : ()))));
    assign pc_we_l = ((alu_dst == 2'b01) && (pc_b_sel == 1'b0)) ? (1) : (0);
    assign pc_we_h = ((alu_dst == 2'b01) && (pc_b_sel == 1'b1)) ? (1) : (0);
    always @(posedge clk, posedge rst) begin
        if (rst)
            pc <= 16'b0;
        else begin
            if (pc_we)
                pc <= pc_wr;
            else if (pc_we_l)
                pc[7:0] <= pc_wr_b;
            else if (pc_we_h)
                pc[15:8] <= pc_wr_b;
        end
    end

    // Register F
    reg8 flags(
        .clk(clk),
        .rst(rst),
        .wr(flags_wr),
        .we(flags_we),
        .rd(flags_rd)
    );
    assign flags_wr = alu_flags_out;
    

    // ALU
    alu alu(
        .alu_a(alu_a),
        .alu_b(alu_b),
        .alu_result(alu_result),
        .alu_flags_in(alu_flags_in),
        .alu_flags_out(alu_flags_out),
        .alu_op(alu_op)
    );
    assign alu_carry_out = alu_flags_out[0];

    assign alu_a = (
        (alu_src_a == 2'b00) ? (acc_rd) : (
        (alu_src_a == 2'b01) ? (pc_rd_b) : (
        (alu_src_a == 2'b10) ? (rf_rd) : (
        (alu_src_a == 2'b11) ? (db_rd) : ()))));

    assign alu_b = (
        (alu_src_b == 3'b000) ? (acc_rd) : (
        (alu_src_b == 3'b001) ? ({7'b0, alu_carry_out}) : (
        (alu_src_b == 3'b010) ? (8'd0) : (
        (alu_src_b == 3'b011) ? (8'd1) : (
        (alu_src_b == 3'b100) ? (rf_h) : (
        (alu_src_b == 3'b101) ? (rf_l) : (
        (alu_src_b == 3'b110) ? (imm_ext_high) : (
        (alu_src_b == 3'b111) ? (imm_ext_low) : ()))))))));

    assign alu_flags_in = flags_rd;
    

    // Imm Sign Extension
    assign imm_ext_high = imm_ext[15:8];
    assign imm_ext_low = imm_ext[7:0];

    // CT FSM
    reg  [1:0] ct_state;
    wire [1:0] ct_next_state;

    assign ct_next_state = ct_state + 2'b01;

    // CT - FSM / Bus Operation 
    always @(posedge clk) begin
        case (ct_state)
        2'b00: begin
            // Bus Idle
            rd <= 0;
            wr <= 0;
            dout <= 8'b0;
        end
        2'b01: begin
            // Setup Address
            a <= ab_wr;
            rd <= ((bus_op == 2'b01)||(bus_op == 2'b11)) ? (1) : (0);
            wr <= 0;
            phi <= 1;
        end
        2'b10: begin
            // Read in progress
        end
        2'b11: begin
            if (bus_op == 2'b10) begin
                // Write cycle
                wr <= 1;
                dout <= db_wr_buffer;
            end
            else if (bus_op == 2'b01) begin
                // Instruction Fetch Cycle
                wr <= 0;
                opcode <= din;
            end
            else if (bus_op == 2'b11) begin
                // Data Read cycle
                wr <= 0;
                db_rd_buffer <= din;
            end
            else begin
                wr <= 0;
            end
            rd <= 0;
            phi <= 0;
        end
        endcase
    end

    // CT - FSM / Instruction Execution
    wire [1:0] alu_src_a_ct = 2'b01;
    reg  [2:0] alu_src_b_ct;
    wire [1:0] alu_op_prefix_ct = 2'b00;
    wire [1:0] alu_op_src_ct = 2'b10;
    reg  [1:0] alu_dst_ct;
    reg        pc_b_sel_ct; 
 
    always @(posedge clk) begin
        case (ct_state)
        2'b00: begin
            // Decoding and Execution
            // Actually cannot control anything
        end
        2'b01: begin
            // Calculate PC low + 1
            pc_b_sel <= 1'b0;
            alu_src_b_ct <= 2'b011;
            alu_dst_ct <= 2'01;
        end
        2'b10: begin
            // Calculate PC high + carry
            pc_b_sel <= 1'b1;
            alu_src_b_ct <= 2'b001;
            alu_dst_ct <= 2'b01;
        end
        2'b11: begin
            // End, it is safe to overwrite DB as doing nothing
            alu_dst_ct <= 2'b11;
        end
    end

    assign alu_src_a = (ct_state == 2'b00) ? (alu_src_a_ex) : (alu_src_a_ct);
    assign alu_src_b = (ct_state == 2'b00) ? (alu_src_b_ex) : (alu_src_b_ct);
    assign alu_op_prefix = (ct_state == 2'b00) ? (alu_op_prefix_ex) : (alu_op_prefix_ct);
    assign alu_op_src = (ct_state == 2'b00) ? (alu_op_src_ex) : (alu_op_src_ct);
    assign alu_dst = (ct_state == 2'b00) ? (alu_dst_ex) : (alu_dst_ct);
    assign pc_b_sel = pc_b_sel_ct;

endmodule
