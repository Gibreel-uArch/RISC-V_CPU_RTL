#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vregisters_file.h"
#include <iostream>
#include <memory>

vluint64_t main_time = 0;

void tick(Vregisters_file* top, VerilatedVcdC* tfp) {
    top->clk = 0;
    top->eval();
    if (tfp) tfp->dump(main_time++);
    
    top->clk = 1;
    top->eval();
    if (tfp) tfp->dump(main_time++);
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    
    Vregisters_file* top = new Vregisters_file;
    VerilatedVcdC* tfp = nullptr;

    // Optional VCD Tracing Setup
    Verilated::traceEverOn(true);
    tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("waveform.vcd");

    std::cout << "=== Starting Register File Simulation ===" << std::endl;

    // 1. System Reset
    top->rst_n = 0;
    top->RegWrite = 0;
    top->rd = 0;
    top->rs1 = 0;
    top->rs2 = 0;
    top->WriteData = 0;
    tick(top, tfp);
    
    top->rst_n = 1; // Release reset
    tick(top, tfp);

    // 2. Test Rule: Register x0 must remain 0
    std::cout << "\nTesting Write to x0 (Should fail)..." << std::endl;
    top->RegWrite = 1;
    top->rd = 0;
    top->WriteData = 0xDEADBEEF;
    tick(top, tfp);

    top->RegWrite = 0;
    top->rs1 = 0;
    top->eval();
    std::cout << "Read x0 Content: 0x" << std::hex << top->ReadData1 << " (Expected: 0x0)" << std::endl;

    // 3. Test Normal Write and Read: Write 0xABCDEFFF to x5
    std::cout << "\nTesting Write to x5..." << std::endl;
    top->RegWrite = 1;
    top->rd = 5;
    top->WriteData = 0xABCDEFFF;
    tick(top, tfp);

    // 4. Test Normal Write and Read: Write 0x12345678 to x10
    std::cout << "Testing Write to x10..." << std::endl;
    top->RegWrite = 1;
    top->rd = 10;
    top->WriteData = 0x12345678;
    tick(top, tfp);

    // 5. Read back both x5 and x10 simultaneously
    std::cout << "\nReading back x5 and x10 simultaneously..." << std::endl;
    top->RegWrite = 0;
    top->rs1 = 5;
    top->rs2 = 10;
    top->eval(); // Combinational read evaluation
    
    std::cout << "ReadData1 (x5) : 0x" << std::hex << top->ReadData1 << " (Expected: 0xabcdefff)" << std::endl;
    std::cout << "ReadData2 (x10): 0x" << std::hex << top->ReadData2 << " (Expected: 0x12345678)" << std::endl;

    std::cout << "\n=== Simulation Finished Successfully ===" << std::endl;

    if (tfp) {
        tfp->close();
        delete tfp;
    }
    delete top;
    return 0;
}
