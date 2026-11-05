`timescale 1ns / 1ps

//CHANGES:
// 1.VERILATOR LINT PRAGMAS (Added for clean synthesis):
// - Added /* verilator lint_off UNUSEDSIGNAL */ to suppress unused signal warnings
// - Added /* verilator lint_off SYNCASYNCNET */ to suppress async reset warnings
// - Added /* verilator lint_off COMBDLY */ to suppress combinational delay warnings

/* verilator lint_off UNUSEDSIGNAL */
/* verilator lint_off SYNCASYNCNET */
/* verilator lint_off COMBDLY */

// RISC-V Multicycle CPU - Top Level Module (Optimized with Prefetch)
// Connects all sub-modules together

module riscv_top (
    input logic clk,
    input logic rst
);

    // ========================================================================
    // Internal wires
    // ========================================================================
    
    // PC signals
    logic [31:0] pc;
    logic [31:0] next_pc;
    
    // Memory signals
    logic [31:0] mem_addr;
    logic [31:0] mem_data_out;
    
    // Instruction signals
    logic [31:0] instruction;
    logic [31:0] instruction_from_mem;
    logic [31:0] instruction_from_prefetch;
    
    // Prefetch signals
    logic prefetch_valid;
    logic prefetch_write;
    logic prefetch_invalidate;
    logic use_prefetch_fetch;
    
    // Register file signals
    logic [31:0] read_data1;
    logic [31:0] read_data2;
    logic [31:0] write_data;
    
    // A and B register signals
    logic [31:0] a_reg_out;
    logic [31:0] b_reg_out;
    
    // ALU signals
    logic [31:0] alu_a;
    logic [31:0] alu_b;
    logic [31:0] alu_out;
    logic alu_zero;
    logic [3:0] alu_control;
    
    // ALUOut register signals
    logic [31:0] aluout_reg_out;
    
    // Immediate signal
    logic [31:0] immediate;
    
    // Branch signal
    logic branch_taken;
    
    // Control signals from FSM
    logic MemRead;
    logic MemWrite;
    logic IRWrite;
    logic AWrite;
    logic BWrite;
    logic ALUOutWrite;
    logic RegWrite;
    logic PCWrite;
    logic PCWriteCond;
    logic mem_addr_src;
    logic alu_src_a;
    logic [1:0] alu_src_b;
    logic [1:0] mem_to_reg;
    logic [1:0] ALUop;
    logic force_rs1_zero;
    logic [1:0] mem_size;   // NEW: Memory size control
    logic mem_sign;          // NEW: Sign extension control

    // ========================================================================
    // Module instantiations
    // ========================================================================
    
    // Program Counter
    program_counter pc_reg (
        .clk(clk),
        .rst(rst),
        .we(PCWrite),
        .addr_in(alu_out),  // Direct ALU output (removed PC source mux)
        .addr_out(pc)
    );
    
    // Memory (unified instruction + data)
    memory #(.DEPTH(1024)) mem (
        .clk(clk),
        .memread(MemRead),
        .memwrite(MemWrite),
        .addr_in(mem_addr),
        .data_in(b_reg_out),
        .data_out(mem_data_out),
        .mem_size(mem_size),    // NEW: Memory size control
        .mem_sign(mem_sign)     // NEW: Sign extension control
    );
    
    // Prefetch Buffer
    prefetch_buffer prefetch_buf (
        .clk(clk),
        .rst(rst),
        .we(prefetch_write),
        .invalidate(prefetch_invalidate),
        .instruction_in(mem_data_out),
        .instruction_out(instruction_from_prefetch),
        .valid(prefetch_valid)
    );
    
    // Instruction Register
    instruction_reg ir (
        .clk(clk),
        .rst(rst),
        .we(IRWrite),
        .instruction_in(use_prefetch_fetch ? instruction_from_prefetch : mem_data_out),
        .instruction_out(instruction)
    );
    
    // Register File
    regfile rf (
        .clk(clk),
        .regwrite(RegWrite),
        .instruction(instruction),
        .force_rs1_zero(force_rs1_zero),
        .write_data(write_data),
        .read_data1(read_data1),
        .read_data2(read_data2)
    );
    
    // A Register (first operand)
    a_reg a_register (
        .clk(clk),
        .rst(rst),
        .we(AWrite),
        .d_in(read_data1),
        .q_out(a_reg_out)
    );
    
    // B Register (second operand)
    b_reg b_register (
        .clk(clk),
        .rst(rst),
        .we(BWrite),
        .d_in(read_data2),
        .q_out(b_reg_out)
    );
    
    // Immediate Generator
    immediate_gen imm_gen (
        .instruction(instruction),
        .immediate(immediate)
    );
    
    // ALU Control
    alu_cntrl alu_ctrl (
        .instruction(instruction),
        .aluop(ALUop),
        .cntrl(alu_control)
    );
    
    // ALU
    alu alu_unit (
        .a(alu_a),
        .b(alu_b),
        .control(alu_control),
        .out(alu_out),
        .zero(alu_zero)
    );
    
    // ALUOut Register
    aluout_reg aluout_register (
        .clk(clk),
        .rst(rst),
        .we(ALUOutWrite),
        .d_in(alu_out),
        .q_out(aluout_reg_out)
    );
    
    // Branch Evaluator
    branch_evaluator branch_eval (
        .PCwriteCond(PCWriteCond),
        .result(alu_out),
        .zero(alu_zero),
        .instruction(instruction),
        .branch_taken(branch_taken)
    );
    
    // ALU Source A Mux
    alu_src_a_mux alu_src_a_mux_inst (
        .a_reg(a_reg_out),
        .pc(pc),
        .alu_src_a(alu_src_a),
        .alu_a(alu_a)
    );
    
    // ALU Source B Mux
    alu_src_b_mux alu_src_b_mux_inst (
        .b_reg(b_reg_out),
        .immediate(immediate),
        .alu_src_b(alu_src_b),
        .alu_b(alu_b)
    );
    
    // Memory to Register Mux
    mem_to_reg_mux mem_to_reg_mux_inst (
        .alu_out(alu_out),
        .mem_data_out(mem_data_out),
        .aluout_reg(aluout_reg_out),
        .mem_to_reg(mem_to_reg),
        .write_data(write_data)
    );
    
    // Memory Address Mux
    mem_addr_mux mem_addr_mux_inst (
        .pc(pc),
        .alu_out(alu_out),
        .mem_addr_src(mem_addr_src),
        .mem_addr(mem_addr)
    );
    
    // Control FSM (Optimized with Prefetch + Byte/Halfword Support)
    control_fsm_optimized_prefetch fsm (
        .clk(clk),
        .rst(rst),
        .instruction(instruction),
        .branch_taken(branch_taken),
        .prefetch_valid(prefetch_valid),
        .prefetch_write(prefetch_write),
        .prefetch_invalidate(prefetch_invalidate),
        .use_prefetch_fetch(use_prefetch_fetch),
        .MemRead(MemRead),
        .MemWrite(MemWrite),
        .IRWrite(IRWrite),
        .AWrite(AWrite),
        .BWrite(BWrite),
        .ALUOutWrite(ALUOutWrite),
        .RegWrite(RegWrite),
        .PCWrite(PCWrite),
        .PCWriteCond(PCWriteCond),
        .mem_addr_src(mem_addr_src),
        .alu_src_a(alu_src_a),
        .alu_src_b(alu_src_b),
        .mem_to_reg(mem_to_reg),
        .ALUop(ALUop),
        .force_rs1_zero(force_rs1_zero),
        .mem_size(mem_size),    // NEW: Memory size control
        .mem_sign(mem_sign)     // NEW: Sign extension control
    );

endmodule
