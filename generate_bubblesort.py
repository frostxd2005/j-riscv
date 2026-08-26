#!/usr/bin/env python3
"""
RISC-V Bubble Sort - MANUAL VERSION (FIXED)
Array: [64, 34, 25, 12, 22, 11, 90, 45]
Expected: [11, 12, 22, 25, 34, 45, 64, 90]

FIX: beq offset changed from 8 to 12 to correctly skip BOTH store instructions
"""

def reg(name):
    regs = {
        'x0': 0,  'x1': 1,  'x2': 2,  'x3': 3,
        'x4': 4,  'x5': 5,  'x6': 6,  'x7': 7,
        'x8': 8,  'x9': 9,  'x10': 10, 'x11': 11,
        'x12': 12, 'x13': 13
    }
    return regs[name.lower()]

def sign_extend(value, bits):
    sign_bit = 1 << (bits - 1)
    return (value & (sign_bit - 1)) - (value & sign_bit)

def encode_r_type(rd, rs1, rs2, funct3, funct7):
    return (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | \
           (funct3 << 12) | (rd << 7) | 0x33

def encode_i_type(rd, rs1, imm, funct3, opcode):
    imm12 = sign_extend(imm, 12) & 0xFFF
    return (imm12 << 20) | (rs1 << 15) | (funct3 << 12) | \
           (rd << 7) | opcode

def encode_s_type(rs1, rs2, imm, funct3):
    imm12 = sign_extend(imm, 12) & 0xFFF
    imm_11_5 = (imm12 >> 5) & 0x7F
    imm_4_0  = imm12 & 0x1F
    return (imm_11_5 << 25) | (rs2 << 20) | (rs1 << 15) | \
           (funct3 << 12) | (imm_4_0 << 7) | 0x23

def encode_b_type(rs1, rs2, imm, funct3):
    """
    B-type: offset is in bytes, must be even.
    Bits: imm[12|10:5] | rs2 | rs1 | funct3 | imm[4:1|11] | opcode
    """
    imm13 = sign_extend(imm, 13) & 0x1FFF
    imm_12   = (imm13 >> 12) & 0x1
    imm_11   = (imm13 >> 11) & 0x1
    imm_10_5 = (imm13 >> 5)  & 0x3F
    imm_4_1  = (imm13 >> 1)  & 0xF
    return (imm_12 << 31) | (imm_10_5 << 25) | (rs2 << 20) | \
           (rs1 << 15) | (funct3 << 12) | (imm_4_1 << 8) | \
           (imm_11 << 7) | 0x63

# Instruction helpers
def addi(rd, rs1, imm):      return encode_i_type(reg(rd), reg(rs1), imm, 0x0, 0x13)
def add(rd, rs1, rs2):        return encode_r_type(reg(rd), reg(rs1), reg(rs2), 0x0, 0x00)
def slt(rd, rs1, rs2):        return encode_r_type(reg(rd), reg(rs1), reg(rs2), 0x2, 0x00)
def sw(rs2, rs1, imm):        return encode_s_type(reg(rs1), reg(rs2), imm, 0x2)
def lw(rd, rs1, imm):         return encode_i_type(reg(rd), reg(rs1), imm, 0x2, 0x03)
def beq(rs1, rs2, imm):       return encode_b_type(reg(rs1), reg(rs2), imm, 0x0)
def bne(rs1, rs2, imm):       return encode_b_type(reg(rs1), reg(rs2), imm, 0x1)

def compare_and_swap(program, base_reg, offset_a, offset_b):
    """
    Compare array[offset_a/4] and array[offset_b/4].
    Swap if array[offset_a] > array[offset_b].
    
    Uses registers:
      x4  = address of lower element  (base + offset_a)
      x5  = value  of lower element
      x6  = value  of upper element
      x8  = address of upper element  (base + offset_b)
      x9  = comparison result (1 if swap needed)
      x10 = temp for offset_a
      x11 = temp for offset_b

    BEQ offset = 12: skip the 2 store instructions (each 4 bytes)
      beq  (this instr, PC=N)
      sw   x6, 0(x4)   <- PC = N+4  --|
      sw   x5, 0(x8)   <- PC = N+8  --| skip these 2
      next instr       <- PC = N+12 <-- branch target
    """
    program.append(addi('x10', 'x0', offset_a))      # x10 = offset_a
    program.append(add ('x4',  base_reg, 'x10'))      # x4  = &array[a]
    program.append(lw  ('x5',  'x4', 0))              # x5  = array[a]
    program.append(addi('x11', 'x0', offset_b))       # x11 = offset_b
    program.append(add ('x8',  base_reg, 'x11'))      # x8  = &array[b]
    program.append(lw  ('x6',  'x8', 0))              # x6  = array[b]
    program.append(slt ('x9',  'x6', 'x5'))           # x9  = (array[b] < array[a])
    program.append(beq ('x9',  'x0', 12))             # if x9==0: no swap, skip 2 instrs
    program.append(sw  ('x6',  'x4', 0))              # array[a] = array[b]  (smaller)
    program.append(sw  ('x5',  'x8', 0))              # array[b] = array[a]  (larger)
    # next comparison starts here  (PC = beq_PC + 12)

def generate_bubble_sort():
    """
    Fully unrolled bubble sort for 8-element array.
    Pass k does comparisons for indices 0..7-k (7-k comparisons).
    Total comparisons = 7+6+5+4+3+2+1 = 28
    """
    program = []
    array   = [64, 34, 25, 12, 22, 11, 90, 45]
    base    = 0x100   # byte address where array starts
    N       = 8       # number of elements

    # ----------------------------------------------------------------
    # 1. Set x1 = base address of array
    # ----------------------------------------------------------------
    program.append(addi('x1', 'x0', base))   # x1 = 0x100

    # ----------------------------------------------------------------
    # 2. Initialise memory: store each array element
    # ----------------------------------------------------------------
    for i, val in enumerate(array):
        program.append(addi('x2', 'x0', val))      # x2 = array[i]
        program.append(sw  ('x2', 'x1', i * 4))    # mem[base + i*4] = x2

    # ----------------------------------------------------------------
    # 3. Bubble sort passes (fully unrolled)
    #    Pass p (0-indexed): compare pairs (j, j+1) for j = 0 .. N-2-p
    # ----------------------------------------------------------------
    for p in range(N - 1):                    # 7 passes
        for j in range(N - 1 - p):           # decreasing number of comparisons
            offset_a = j * 4
            offset_b = (j + 1) * 4
            compare_and_swap(program, 'x1', offset_a, offset_b)

    # ----------------------------------------------------------------
    # 4. Completion marker  (x13 = 0xFF  →  testbench detects this)
    # ----------------------------------------------------------------
    program.append(addi('x13', 'x0', 0xFF))
    program.append(addi('x0',  'x0', 0))     # NOP / halt

    return program


def verify_sort():
    """Python-level sanity check: simulate the bubble sort."""
    array = [64, 34, 25, 12, 22, 11, 90, 45]
    n = len(array)
    for p in range(n - 1):
        for j in range(n - 1 - p):
            if array[j] > array[j + 1]:
                array[j], array[j + 1] = array[j + 1], array[j]
    return array


def disassemble(program):
    """Print a simple listing so you can double-check offsets."""
    opcode_names = {
        0x33: 'R-type', 0x13: 'I-arith', 0x03: 'LOAD',
        0x23: 'STORE',  0x63: 'BRANCH', 0x37: 'LUI',
        0x17: 'AUIPC',  0x6F: 'JAL',    0x67: 'JALR'
    }
    funct3_r   = {(0x33,0,0x00):'ADD', (0x33,2,0x00):'SLT'}
    funct3_i   = {(0x13,0):'ADDI', (0x03,2):'LW'}
    funct3_s   = {(0x23,2):'SW'}
    funct3_b   = {(0x63,0):'BEQ', (0x63,1):'BNE'}

    print(f"\n{'PC':>8}  {'Hex':>10}  Disassembly")
    print("-" * 60)
    for i, instr in enumerate(program):
        pc      = i * 4
        op      = instr & 0x7F
        rd      = (instr >> 7)  & 0x1F
        funct3  = (instr >> 12) & 0x7
        rs1     = (instr >> 15) & 0x1F
        rs2     = (instr >> 20) & 0x1F
        funct7  = (instr >> 25) & 0x7F
        imm_i   = sign_extend((instr >> 20) & 0xFFF, 12)

        # S-type immediate
        imm_s_raw = ((instr >> 25) << 5) | ((instr >> 7) & 0x1F)
        imm_s     = sign_extend(imm_s_raw & 0xFFF, 12)

        # B-type immediate
        b12  = (instr >> 31) & 1
        b11  = (instr >>  7) & 1
        b105 = (instr >> 25) & 0x3F
        b41  = (instr >>  8) & 0xF
        imm_b_raw = (b12 << 12) | (b11 << 11) | (b105 << 5) | (b41 << 1)
        imm_b     = sign_extend(imm_b_raw, 13)

        if op == 0x33:
            key = (op, funct3, funct7)
            name = funct3_r.get(key, 'R?')
            asm  = f"{name} x{rd}, x{rs1}, x{rs2}"
        elif op == 0x13:
            name = funct3_i.get((op, funct3), 'I?')
            asm  = f"{name} x{rd}, x{rs1}, {imm_i}"
        elif op == 0x03:
            name = funct3_i.get((op, funct3), 'L?')
            asm  = f"{name} x{rd}, {imm_i}(x{rs1})"
        elif op == 0x23:
            name = funct3_s.get((op, funct3), 'S?')
            asm  = f"{name} x{rs2}, {imm_s}(x{rs1})"
        elif op == 0x63:
            name = funct3_b.get((op, funct3), 'B?')
            target = pc + imm_b
            asm  = f"{name} x{rs1}, x{rs2}, {imm_b}  (-> PC 0x{target:04X})"
        else:
            asm  = f"??? (op=0x{op:02X})"

        print(f"0x{pc:04X}  0x{instr:08X}  {asm}")
    print()


def write_program_mem(program, filename='program.mem'):
    expected = verify_sort()

    with open(filename, 'w', newline='\n') as f:
        f.write("// Bubble Sort - FIXED MANUAL VERSION\n")
        f.write("// Array:    [64, 34, 25, 12, 22, 11, 90, 45]\n")
        f.write("// Expected: [11, 12, 22, 25, 34, 45, 64, 90]\n")
        f.write("// Fix: beq offset = 12 (not 8) to skip both SW instructions\n\n")
        for instr in program:
            f.write(f"{instr:08X}\n")

    total_comparisons = sum(range(8))          # 28
    max_swaps         = total_comparisons
    print(f"Generated '{filename}'")
    print(f"  Instructions : {len(program)}")
    print(f"  Program size : {len(program) * 4} bytes  (0x{len(program)*4:04X})")
    print(f"  Comparisons  : {total_comparisons}")
    print(f"  Max stores   : {max_swaps * 2}  (each swap = 2 SWs)")
    print(f"  Expected sort: {expected}")
    print(f"\n  KEY FIX: beq offset = 12 → skips both SW instructions correctly")
    print(f"  Instruction layout per comparison block (10 instructions):")
    print(f"    +0  ADDI x10, x0, offset_a")
    print(f"    +4  ADD  x4,  x1, x10")
    print(f"    +8  LW   x5,  0(x4)")
    print(f"    +12 ADDI x11, x0, offset_b")
    print(f"    +16 ADD  x8,  x1, x11")
    print(f"    +20 LW   x6,  0(x8)")
    print(f"    +24 SLT  x9,  x6, x5")
    print(f"    +28 BEQ  x9,  x0, 12   ← branches to +40 (skips +32 and +36)")
    print(f"    +32 SW   x6,  0(x4)    ← only executed if swap needed")
    print(f"    +36 SW   x5,  0(x8)    ← only executed if swap needed")
    print(f"    +40 next comparison block ...")


if __name__ == '__main__':
    program = generate_bubble_sort()
    write_program_mem(program)
    disassemble(program)