`timescale 1ns / 1ps

// ============================================================================
// J-RISC-V BUBBLE SORT TESTBENCH
// ============================================================================
// Tests the complete bubble sort program loaded from program.mem
// Array: [64, 34, 25, 12, 22, 11, 90, 45] at address 0x200
// Expected: [11, 12, 22, 25, 34, 45, 64, 90]
//
// Program is loaded automatically by memory module via $readmemh("program.mem")
// ============================================================================

module tb_bubble_sort ();

    // ========================================================================
    // SIGNALS
    // ========================================================================
    logic clk;
    logic rst;
    
    integer cycle_count;
    integer test_passed;
    integer test_failed;
    
    // Expected sorted array
    logic [31:0] expected [0:7];
    
    // Array parameters
    parameter ARRAY_BASE = 32'h200;  // 512 decimal
    parameter ARRAY_SIZE = 8;
    parameter MAX_CYCLES = 3000;
    
    // End marker detection: x13 = 255 signals completion
    
    initial begin
        expected[0] = 32'd11;
        expected[1] = 32'd12;
        expected[2] = 32'd22;
        expected[3] = 32'd25;
        expected[4] = 32'd34;
        expected[5] = 32'd45;
        expected[6] = 32'd64;
        expected[7] = 32'd90;
    end
    
    // ========================================================================
    // DUT INSTANTIATION
    // ========================================================================
    riscv_top dut (
        .clk(clk),
        .rst(rst)
    );
    
    // ========================================================================
    // CLOCK GENERATION (100 MHz)
    // ========================================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // ========================================================================
    // CYCLE COUNTER
    // ========================================================================
    always @(posedge clk) begin
        if (!rst)
            cycle_count = cycle_count + 1;
    end
    
    // ========================================================================
    // HELPER: Read 32-bit word from memory
    // ========================================================================
    function logic [31:0] read_word;
        input integer addr;
        begin
            read_word = {dut.mem.memblock[addr + 3],
                        dut.mem.memblock[addr + 2],
                        dut.mem.memblock[addr + 1],
                        dut.mem.memblock[addr]};
        end
    endfunction
    
    // ========================================================================
    // HELPER: Read register value
    // ========================================================================
    function logic [31:0] read_reg;
        input integer regnum;
        begin
            read_reg = dut.rf.regblock[regnum];
        end
    endfunction
    
    // ========================================================================
    // EXECUTION MONITOR (first 20 cycles)
    // ========================================================================
    always @(posedge clk) begin
        if (!rst && cycle_count <= 20) begin
            $display("  [%3d] PC=0x%03h  IR=0x%08h  State=%s",
                     cycle_count,
                     dut.pc_reg.addr_out,
                     dut.ir.instruction_out,
                     dut.fsm.state == 3'd0 ? "FETCH" :
                     dut.fsm.state == 3'd1 ? "DECODE" :
                     dut.fsm.state == 3'd2 ? "EX_ALU_WB" :
                     dut.fsm.state == 3'd3 ? "EX_MEM_READ" :
                     dut.fsm.state == 3'd4 ? "EX_MEM_WRITE" :
                     dut.fsm.state == 3'd5 ? "EX_BRANCH" :
                     dut.fsm.state == 3'd6 ? "EX_JUMP" :
                     dut.fsm.state == 3'd7 ? "BR_TAKEN_FETCH" : "UNKNOWN");
        end
    end
    
    // ========================================================================
    // MAIN TEST SEQUENCE
    // ========================================================================
    initial begin
        // VCD dump for waveform viewing
        $dumpfile("tb_bubble_sort.vcd");
        $dumpvars(0, tb_bubble_sort);
        
        // Initialize
        cycle_count = 0;
        test_passed = 0;
        test_failed = 0;
        
        $display("");
        $display("+============================================================+");
        $display("|       J-RISC-V BUBBLE SORT TESTBENCH                        |");
        $display("|       Program loaded from program.mem via $readmemh         |");
        $display("|       Array at 0x200: [64, 34, 25, 12, 22, 11, 90, 45]    |");
        $display("|       Expected:       [11, 12, 22, 25, 34, 45, 64, 90]    |");
        $display("+============================================================+");
        $display("");
        
        // ==================================================================
        // PHASE 1: RESET
        // ==================================================================
        $display("[PHASE 1] Reset...");
        rst = 1;
        repeat (5) @(posedge clk);
        rst = 0;
        $display("  Reset released at time %0t ns", $time);
        
        // ==================================================================
        // PHASE 2: VERIFY INITIAL ARRAY
        // ==================================================================
        $display("");
        $display("[PHASE 2] Verifying initial array in memory...");
        begin
            integer i;
            logic [31:0] val;
            integer init_values [0:7];
            
            init_values[0] = 64;
            init_values[1] = 34;
            init_values[2] = 25;
            init_values[3] = 12;
            init_values[4] = 22;
            init_values[5] = 11;
            init_values[6] = 90;
            init_values[7] = 45;
            
            for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                val = read_word(ARRAY_BASE + i * 4);
                if (val == init_values[i]) begin
                    $display("  [%0d] addr=0x%03h: %0d (correct)", i, ARRAY_BASE + i*4, val);
                end else begin
                    $display("  [%0d] addr=0x%03h: %0d (ERROR: expected %0d)", i, ARRAY_BASE + i*4, val, init_values[i]);
                    test_failed = test_failed + 1;
                end
            end
        end
        
        // ==================================================================
        // PHASE 3: RUN PROGRAM
        // ==================================================================
        $display("");
        $display("[PHASE 3] Running bubble sort program...");
        $display("  Monitoring execution (first 20 cycles):");
        
        // Wait for completion: x13 == 255 means done
        begin
            integer timeout;
            timeout = 0;
            
            while (timeout < MAX_CYCLES) begin
                @(posedge clk);
                timeout = timeout + 1;
                
                // Check if x13 == 255 (end marker)
                if (dut.rf.regblock[13] == 32'd255) begin
                    $display("");
                    $display("  >> End marker detected (x13 = 255) at cycle %0d", cycle_count);
                    break;
                end
            end
            
            if (timeout >= MAX_CYCLES) begin
                $display("  >> TIMEOUT after %0d cycles!", MAX_CYCLES);
                test_failed = test_failed + 1;
            end
            
            // Run a few more cycles to let it settle into infinite loop
            repeat (10) @(posedge clk);
        end
        
        $display("  Total cycles executed: %0d", cycle_count);
        
        // ==================================================================
        // PHASE 4: VERIFY SORTED ARRAY
        // ==================================================================
        $display("");
        $display("[PHASE 4] Verifying sorted array...");
        begin
            integer i;
            integer errors;
            logic [31:0] val;
            
            errors = 0;
            
            $display("");
            $display("  Expected: [11, 12, 22, 25, 34, 45, 64, 90]");
            $display("  Actual:   [");
            
            for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                val = read_word(ARRAY_BASE + i * 4);
                $display("    [%0d] = %0d", i, val);
                
                if (val !== expected[i]) begin
                    $display("         ERROR: Expected %0d, got %0d", expected[i], val);
                    errors = errors + 1;
                end
            end
            
            $display("  ]");
            $display("");
            
            if (errors == 0) begin
                $display("  >> BUBBLE SORT PASSED: Array correctly sorted!");
                test_passed = test_passed + 1;
            end else begin
                $display("  >> BUBBLE SORT FAILED: %0d errors", errors);
                test_failed = test_failed + 1;
            end
        end
        
        // ==================================================================
        // PHASE 5: REGISTER DUMP
        // ==================================================================
        $display("");
        $display("[PHASE 5] Register file dump:");
        begin
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                $display("  x%-2d = %0d (0x%08h)", i, dut.rf.regblock[i], dut.rf.regblock[i]);
            end
        end
        
        // ==================================================================
        // PHASE 6: PERFORMANCE STATS
        // ==================================================================
        $display("");
        $display("[PHASE 6] Performance Statistics:");
        begin
            real cpi;
            // Approximate instruction count:
            // Init: 3 instructions
            // Outer loop: 7 iterations (i=0..6)
            // Each outer iteration:
            //   - 2 instructions (ADDI n-1, BGE check)
            //   - 1 instruction (ADDI j=0)
            //   - Inner loop: (n-i-1) iterations
            //     Each inner: ~10 instructions (SUB, ADDI, BGE, SLLI, ADD, LW, LW, BGE, [SW, SW], ADDI, JAL)
            //   - 2 instructions (ADDI i++, JAL outer)
            // Done: 2 instructions
            // Total inner iterations: 7+6+5+4+3+2+1 = 28
            // Rough estimate: 3 + 7*(5) + 28*(10) + 2 = 325 instructions
            integer est_instructions;
            est_instructions = 325;
            
            if (cycle_count > 0)
                cpi = real'(cycle_count) / real'(est_instructions);
            else
                cpi = 0;
            
            $display("  Total cycles:        %0d", cycle_count);
            $display("  Est. instructions:   ~%0d", est_instructions);
            $display("  Est. CPI:            %.2f", cpi);
        end
        
        // ==================================================================
        // FINAL SUMMARY
        // ==================================================================
        $display("");
        $display("+============================================================+");
        $display("|                    TEST SUMMARY                             |");
        $display("+============================================================+");
        $display("|  Tests Passed: %0d                                          |", test_passed);
        $display("|  Tests Failed: %0d                                          |", test_failed);
        $display("|  Total Cycles: %0d                                          |", cycle_count);
        $display("+------------------------------------------------------------+");
        if (test_failed == 0)
            $display("|  *** ALL TESTS PASSED ***                                  |");
        else
            $display("|  *** SOME TESTS FAILED ***                                 |");
        $display("+============================================================+");
        $display("");
        
        $finish;
    end

endmodule
