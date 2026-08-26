`timescale 1ns / 1ps

module riscv_top_optimized_prefetch (
    input logic clk,
    input logic rst
);

    // Internal wires
    logic [31:0] pc, next_pc;
    logic [31:0] mem_addr, mem_data_out;
    logic [31:0] instruction, instruction_from_memory, instruction_from_prefetch;
    logic [31:0] instruction_to_ir;  // NEW: Input to instruction register
    logic prefetch_valid, prefetch_write, prefetch_invalidate;
    logic use_prefetch_fetch;
    logic [31:0] read_data1, read_data2, write_data;
    logic [31:0] a_reg_out, b_reg_out;
    logic [31:0] alu_a, alu_b, alu_out;
    logic alu_zero;
    logic [3:0] alu_control;
    logic [31:0] aluout_reg_out;
    logic [31:0] immediate;
    logic branch_taken;
    logic MemRead, MemWrite, IRWrite, AWrite, BWrite, ALUOutWrite, RegWrite;
    logic PCWrite, PCWriteCond;
    logic mem_addr_src, alu_src_a;
    logic [1:0] alu_src_b, mem_to_reg, ALUop;
    logic force_rs1_zero;

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
    
    // During S_FETCH: load from memory (mem_data_out)
    // During prefetch hit: load from prefetch buffer
    // Otherwise: hold current value (IRWrite=0)
    assign instruction_to_ir = use_prefetch_fetch ? instruction_from_prefetch : mem_data_out;
    
    // The instruction being executed is always from the instruction register
    assign instruction = instruction_from_memory;

    // Program Counter
    program_counter pc_reg (
        .clk(clk), .rst(rst), .we(PCWrite),
        .addr_in(next_pc), .addr_out(pc)
    );
    
    // Memory
    memory #(.DEPTH(1024)) mem (
        .clk(clk), .memread(MemRead), .memwrite(MemWrite),
        .addr_in(mem_addr), .data_in(b_reg_out), .data_out(mem_data_out)
    );
    
    // Instruction Register - FIXED: Input from mux, not from itself
    instruction_reg ir (
        .clk(clk), .rst(rst), .we(IRWrite),
        .instruction_in(instruction_to_ir),  // ← FIXED: Use muxed input
        .instruction_out(instruction_from_memory)
    );
    
    // Register File
    regfile rf (
        .clk(clk), .regwrite(RegWrite), .instruction(instruction),
        .force_rs1_zero(force_rs1_zero), .write_data(write_data),
        .read_data1(read_data1), .read_data2(read_data2)
    );
    
    // A and B Registers
    a_reg a_register (.clk(clk), .rst(rst), .we(AWrite), .d_in(read_data1), .q_out(a_reg_out));
    b_reg b_register (.clk(clk), .rst(rst), .we(BWrite), .d_in(read_data2), .q_out(b_reg_out));
    
    // Immediate Generator
    immediate_gen imm_gen (.instruction(instruction), .immediate(immediate));
    
    // ALU Control
    alu_cntrl alu_ctrl (.instruction(instruction), .aluop(ALUop), .cntrl(alu_control));
    
    // ALU
    alu alu_unit (.a(alu_a), .b(alu_b), .control(alu_control), .out(alu_out), .zero(alu_zero));
    
    // ALUOut Register
    aluout_reg aluout_register (.clk(clk), .rst(rst), .we(ALUOutWrite), .d_in(alu_out), .q_out(aluout_reg_out));
    
    // Branch Evaluator
    branch_evaluator branch_eval (
        .PCwriteCond(PCWriteCond), .result(alu_out), .zero(alu_zero),
        .instruction(instruction), .branch_taken(branch_taken)
    );
    
    // Multiplexers
    mem_addr_mux mem_addr_mux_inst (.pc(pc), .alu_out(alu_out), .mem_addr_src(mem_addr_src), .mem_addr(mem_addr));
    alu_src_a_mux alu_src_a_mux_inst (.a_reg(a_reg_out), .pc(pc), .alu_src_a(alu_src_a), .alu_a(alu_a));
    alu_src_b_mux alu_src_b_mux_inst (.b_reg(b_reg_out), .immediate(immediate), .alu_src_b(alu_src_b), .alu_b(alu_b));
    mem_to_reg_mux mem_to_reg_mux_inst (.alu_out(alu_out), .mem_data_out(mem_data_out), .aluout_reg(aluout_reg_out), .mem_to_reg(mem_to_reg), .write_data(write_data));
    
    // Direct connection from ALU to PC
    assign next_pc = alu_out;
    
    // Control FSM
    control_fsm_optimized_prefetch fsm (
        .clk(clk), .rst(rst), .instruction(instruction), .branch_taken(branch_taken),
        .prefetch_valid(prefetch_valid), .prefetch_write(prefetch_write),
        .prefetch_invalidate(prefetch_invalidate), .use_prefetch_fetch(use_prefetch_fetch),
        .MemRead(MemRead), .MemWrite(MemWrite), .IRWrite(IRWrite),
        .AWrite(AWrite), .BWrite(BWrite), .ALUOutWrite(ALUOutWrite),
        .RegWrite(RegWrite), .PCWrite(PCWrite), .PCWriteCond(PCWriteCond),
        .mem_addr_src(mem_addr_src), .alu_src_a(alu_src_a), .alu_src_b(alu_src_b),
        .mem_to_reg(mem_to_reg), .ALUop(ALUop), .force_rs1_zero(force_rs1_zero)
    );

endmodule