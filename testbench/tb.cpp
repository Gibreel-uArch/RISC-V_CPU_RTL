// ============================================
// Testbench for RISC-V Processor
// File: tb.cpp
// ============================================
// Description: C++ testbench for Verilator simulation
// Features: VCD tracing, clock generation, reset handling,
//           memory loading, and self-checking
// ============================================

#include <verilated.h>          // Verilator core library
#include <verilated_vcd_c.h>    // VCD waveform generation
#include "Vtop.h"               // Generated from top.sv
#include <iostream>
#include <fstream>
#include <string>
#include <cstdlib>
#include <cstdio>
#include <memory>
#include <chrono>               // For performance timing

// ============================================
// Global Variables
// ============================================
vluint64_t main_time = 0;       // Current simulation time
bool trace_enabled = true;      // Enable/disable waveform tracing

// ============================================
// Function: Load memory from HEX file
// ============================================
bool load_memory(Vtop* top, const std::string& hex_file) {
    std::ifstream file(hex_file);
    if (!file.is_open()) {
        std::cout << " Warning: Could not open " << hex_file 
                  << ". Using default memory." << std::endl;
        return false;
    }
    
    std::string line;
    int addr = 0;
    while (std::getline(file, line)) {
        // Skip comments and empty lines
        if (line.empty() || line[0] == '#') continue;
        
        // Parse hex value (assuming 32-bit words)
        uint32_t value = std::stoul(line, nullptr, 16);
        
        // Write to memory (you need to implement this in your design)
        // top->memory[addr] = value;
        addr++;
    }
    
    file.close();
    std::cout << "Loaded " << addr << " instructions from " << hex_file << std::endl;
    return true;
}

// ============================================
// Function: Check for simulation errors
// ============================================
bool check_errors(Vtop* top) {
    // Example: Check for illegal instruction
    // if (top->illegal_instruction) {
    //     std::cout << "Illegal instruction detected!" << std::endl;
    //     return true;
    // }
    return false;
}

// ============================================
// Main Function
// ============================================
int main(int argc, char** argv) {
    // ============================================
    // 1. Initialize Verilator
    // ============================================
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);     // Enable waveform tracing
    
    // Parse simulation time from command line
    vluint64_t sim_duration = 1000;   // Default
    if (argc > 1) {
        std::string arg = argv[1];
        if (arg.find("sim_time=") == 0) {
            sim_duration = std::stoul(arg.substr(9));
        }
    }
    
    std::cout << "========================================" << std::endl;
    std::cout << "RISC-V Processor Simulation" << std::endl;
    std::cout << "========================================" << std::endl;
    std::cout << "  Simulation time: " << sim_duration << " cycles" << std::endl;
    
    // ============================================
    // 2. Create Design Instance and Waveform Tracing
    // ============================================
    Vtop* top = new Vtop("top");      // Create DUT instance
    
    // Waveform tracing setup
    VerilatedVcdC* tfp = nullptr;
    if (trace_enabled) {
        tfp = new VerilatedVcdC;
        top->trace(tfp, 99);          // Trace depth 99 (full hierarchy)
        tfp->open("sim/waveforms/trace.vcd");
        std::cout << "Waveform tracing enabled: sim/waveforms/trace.vcd" << std::endl;
    }
    
    // ============================================
    // 3. Load Program Memory (if exists)
    // ============================================
    load_memory(top, "tests/hex/program.hex");
    
    // ============================================
    // 4. Initialize Signals
    // ============================================
    top->clk = 0;
    top->rst_n = 0;                 // Active-low reset
    top->test_mode = 0;             // Optional test mode
    
    // ============================================
    // 5. Performance Timing
    // ============================================
    auto start_time = std::chrono::high_resolution_clock::now();
    
    // ============================================
    // 6. Main Simulation Loop
    // ============================================
    std::cout << "========================================" << std::endl;
    std::cout << "Starting simulation..." << std::endl;
    
    while (main_time < sim_duration) {
        // ----------------------------------------
        // Clock Generation (50% duty cycle)
        // ----------------------------------------
        top->clk = !top->clk;       // Toggle clock
        
        // ----------------------------------------
        // Reset Handling (first 10 cycles)
        // ----------------------------------------
        if (main_time < 10) {
            top->rst_n = 0;          // Assert reset
        } else if (main_time == 10) {
            top->rst_n = 1;          // De-assert reset
            std::cout << "Reset released at time " << main_time << std::endl;
        }
        
        // ----------------------------------------
        // Evaluate Design (Critical!)
        // ----------------------------------------
        top->eval();
        
        // ----------------------------------------
        // Dump Waveforms at every time step
        // ----------------------------------------
        if (tfp && trace_enabled) {
            tfp->dump(main_time);
        }
        
        // ----------------------------------------
        // Check for Errors
        // ----------------------------------------
        if (check_errors(top)) {
            std::cout << "Simulation stopped due to error at time " 
                      << main_time << std::endl;
            break;
        }
        
        // ----------------------------------------
        // Print Status at Intervals
        // ----------------------------------------
        if (main_time % 100 == 0 && main_time > 10) {
            std::cout << "Time: " << main_time 
                      << " | PC: 0x" << std::hex << top->pc 
                      << " | Instruction: 0x" << std::hex << top->instruction
                      << std::dec << std::endl;
        }
        
        // ----------------------------------------
        // Check for Program Completion
        // (Example: Stop when PC reaches 0xFFFFFFFF)
        // ----------------------------------------
        if (top->pc == 0xFFFFFFFF) {
            std::cout << "Program completed at time " << main_time << std::endl;
            break;
        }
        
        // ----------------------------------------
        // Advance Time
        // ----------------------------------------
        main_time++;
    }
    
    // ============================================
    // 7. Performance Summary
    // ============================================
    auto end_time = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(
        end_time - start_time
    );
    
    std::cout << "========================================" << std::endl;
    std::cout << " Simulation Summary:" << std::endl;
    std::cout << "   Total time: " << main_time << " cycles" << std::endl;
    std::cout << "   Duration: " << duration.count() << " ms" << std::endl;
    std::cout << "========================================" << std::endl;
    
    // ============================================
    // 8. Final State Dump (for debugging)
    // ============================================
    std::cout << " Final State:" << std::endl;
    std::cout << "   PC: 0x" << std::hex << top->pc << std::endl;
    std::cout << "   Register File:" << std::endl;
    // for (int i = 0; i < 32; i++) {
    //     std::cout << "     x" << i << " = 0x" << std::hex << top->reg_file[i] << std::endl;
    // }
    
    // ============================================
    // 9. Cleanup
    // ============================================
    if (tfp) {
        tfp->close();
        delete tfp;
    }
    
    delete top;
    
    std::cout << "Simulation finished successfully!" << std::endl;
    return 0;
}
