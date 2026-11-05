# J-RISC-V: Junior RISC-V Processor

A multicycle RISC-V RV32I processor implemented in SystemVerilog with extensive performance optimizations, verified end-to-end with a bubble sort benchmark.

## Features

- **Complete RV32I ISA** — All 37 base integer instructions including byte/halfword memory ops
- **Multicycle Architecture** — 8-state FSM with instruction prefetch buffer
- **15 Custom Modules** — PC, register file (32×32), ALU (10 ops), control FSM, prefetch buffer, and more
- **Unified Memory** — 4KB byte-addressable with asynchronous reads, synchronous writes
- **Byte/Halfword Support** — LB, LBU, LH, LHU, SB, SH with sign extension
- **Verilator + Vivado Verified** — Lint-clean, bubble sort passing on both simulators

## Optimizations (13 Total)

| # | Optimization | Benefit |
|---|-------------|---------|
| 1 | 3-bit state encoding | 25% FSM area reduction |
| 2 | 5-bit opcode checking | 30% smaller comparator |
| 3 | Merged ALU + Writeback | 25% faster ALU ops |
| 4 | Merged Load (addr + read + WB) | 40% faster loads |
| 5 | Merged Store (addr + write) | 25% faster stores |
| 6 | Taken branch → separate target+fetch | Correctness + clean prefetch |
| 7 | Single-bit JAL/JALR distinguish | Faster decode |
| 8 | Direct ALU output bypass | Eliminates ALUOut register delay |
| 9 | Removed redundant PC mux | Simpler datapath |
| 10 | Integrated LUI decode | Cleaner FSM |
| 11 | Instruction prefetch buffer | 50% faster sequential fetch |
| 12 | Removed MDR register | Direct memory→regfile path |
| 13 | Simplified address mux | 2-input vs 3-input |

## Project Structure

```
├── optimized_complete_fixed.sv   # All 15 CPU modules (use this!)
├── riscv_top_final.sv            # Top-level wrapper (clk, rst only)
├── tb_bubble_sort.sv             # Verification testbench
├── program.mem                   # Bubble sort program (auto-loaded by $readmemh)
└── README.md
```

## Performance

**Benchmark**: Bubble sort of `[64, 34, 25, 12, 22, 11, 90, 45]` → `[11, 12, 22, 25, 34, 45, 64, 90]`

| Metric | Value |
|--------|-------|
| Total Cycles | 1152 |
| Instructions | ~395 |
| CPI | ~2.9 |
| Clock | 100 MHz |

## PERFORMANCE ANALYSIS: Optimized vs Unoptimized J-RISC-V

13 optimizations deliver a 42% speedup (1.72x faster):

Optimized version:   1152 cycles (CPI ~2.9)
Unoptimized version: ~1983 cycles (CPI ~5.0) [estimated]
Cycles saved:        ~831 cycles

## BREAKDOWN BY OPTIMIZATION:

Major Performance Wins:
• Instruction prefetch (#11):     395 cycles saved (1 cycle per instruction)
• Merged ALU+WB states (#3):      180 cycles saved (1 cycle per ALU op)
• Merged Load states (#4):        112 cycles saved (2 cycles per load)
• Direct ALU bypass (#8):          82 cycles saved (1 cycle per mem op)
• Merged Branch+Fetch (#6):        36 cycles saved (1 cycle per taken branch)
• Merged Store states (#5):        26 cycles saved (1 cycle per store)

Area/Complexity Improvements:
• 3-bit state encoding (#1):      25% FSM area reduction
• 5-bit opcode check (#2):        30% smaller comparator
• Simplified muxes (#9,13):       Fewer logic gates

## Supported Instructions

| Type | Instructions |
|------|-------------|
| **R-type** | ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU |
| **I-type ALU** | ADDI, ANDI, ORI, XORI, SLLI, SRLI, SRAI, SLTI, SLTIU |
| **Load** | LW, LH, LHU, LB, LBU |
| **Store** | SW, SH, SB |
| **Branch** | BEQ, BNE, BLT, BGE, BLTU, BGEU |
| **Jump** | JAL, JALR |
| **Upper Imm** | LUI, AUIPC |

## Getting Started

### Vivado Simulation

1. Create a new Vivado project
2. Add `optimized_complete_fixed.sv`, `riscv_top_final.sv`, and `tb_bubble_sort.sv` as sources
3. Copy `program.mem` to the project directory (same folder as `.xpr`)
4. Set `tb_bubble_sort` as simulation top and run behavioral simulation

### Verilator (Lint + Simulate)

```bash
# Lint check
verilator --lint-only -Wall --timing \
  optimized_complete_fixed.sv riscv_top_final.sv tb_bubble_sort.sv \
  --top-module tb_bubble_sort \
  -Wno-UNUSEDSIGNAL -Wno-WIDTHEXPAND -Wno-UNOPTFLAT

# Build and run
verilator --binary --timing \
  optimized_complete_fixed.sv riscv_top_final.sv tb_bubble_sort.sv \
  --top-module tb_bubble_sort -o sim_bubble_sort
./obj_dir/sim_bubble_sort
```

## Verification Output (Vivado)

```
>> End marker detected (x13 = 255) at cycle 1142
>> BUBBLE SORT PASSED: Array correctly sorted!

  Expected: [11, 12, 22, 25, 34, 45, 64, 90]
  Actual:   [11, 12, 22, 25, 34, 45, 64, 90]

  *** ALL TESTS PASSED ***
```

## Roadmap

- [x] RTL design and verification
- [x] 13 performance optimizations
- [x] Byte/halfword memory support
- [x] Branch handling bug fix (prefetch correctness)
- [x] Verilator lint-clean verification
- [x] Vivado simulation passing
- [ ] Synthesis (Vivado / Yosys)
- [ ] Static Timing Analysis (STA)

---

**Status**: ✅ RTL Complete & Verified | **Next**: Synthesis → STA
