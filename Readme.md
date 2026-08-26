# J-RISC-V: Junior RISC-V Processor

A multicycle RISC-V RV32I processor implemented in SystemVerilog with extensive performance optimizations.

## Features

- **Complete RV32I Implementation**: All base integer instructions supported
- **Multicycle Architecture**: 8-state optimized FSM with instruction prefetching
- **15+ Custom Modules**: Program counter, register file (32×32), ALU (10 operations), control FSM, and more
- **Harvard-style Memory**: Unified memory with asynchronous reads
- **Performance Optimized**: CPI reduced from 1.80 to 1.33 (26% improvement)

## Optimizations

1. **State Encoding Optimization** - 3-bit instead of 4-bit (25% area reduction)
2. **5-bit Opcode Checking** - Exploits RISC-V opcode pattern (30% smaller comparator)
3. **Merged ALU States** - S_EX_ALU + S_WB → single cycle (25% faster ALU ops)
4. **Merged Load States** - Address calc + read + writeback in one cycle (40% faster loads)
5. **Merged Store States** - Address calc + write in one cycle (25% faster stores)
6. **Merged Branch States** - Branch target + fetch in one cycle (20% faster branches)
7. **Single-bit JAL/JALR Check** - Faster decode logic
8. **Direct ALU Output Bypass** - Eliminates ALUOut register delay
9. **Removed Redundant PC Mux** - Direct ALU-to-PC connection
10. **Integrated LUI Decode** - Cleaner FSM logic
11. **Instruction Prefetch** - 50% faster fetch after first instruction
12. **Removed MDR Register** - Direct memory-to-register path
13. **Simplified Address Mux** - 2-input instead of 3-input

## Project Structure

```
├── src/
│   ├── modules.sv          # All CPU modules (ALU, regfile, FSM, muxes, etc.)
│   └── riscv_top.sv        # Top-level module
├── testbench/
│   └── tb_bubble_sort.sv   # Verification testbench
├── programs/
│   └── program.mem         # Bubble sort test program
└── README.md
```

## Performance

**Benchmark**: Bubble sort of 8 elements
- **Cycles**: 852
- **CPI**: 1.33
- **Improvement**: 26% faster than unoptimized version (1151 cycles, CPI 1.80)

## Getting Started

### Requirements
- Xilinx Vivado (for synthesis) or any SystemVerilog simulator (Verilator, Icarus Verilog, ModelSim)

### Simulation
```bash
# Using Vivado
xvlog --sv src/modules.sv src/riscv_top.sv testbench/tb_bubble_sort.sv
xelab tb_bubble_sort -s sim_top
xsim sim_top -R

# Using Verilator
verilator --cc --exe --build src/modules.sv src/riscv_top.sv testbench/tb_bubble_sort.sv
```

## Supported Instructions

**R-type**: ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU  
**I-type**: ADDI, ANDI, ORI, XORI, SLLI, SRLI, SRAI, SLTI, SLTIU, LB, LH, LW, LBU, LHU, JALR  
**S-type**: SB, SH, SW  
**B-type**: BEQ, BNE, BLT, BGE, BLTU, BGEU  
**U-type**: LUI, AUIPC  
**J-type**: JAL

## Roadmap

- [x] RTL design and verification
- [x] Performance optimization (26% speedup achieved)
- [x] Synthesis with Vivado
- [ ] RTL-to-GDSII flow using OpenLane and SkyWater 130nm PDK
- [ ] Submit to Google MPW shuttle for fabrication

**Status**: ✅ Complete and verified | **Next**: RTL-to-GDSII
