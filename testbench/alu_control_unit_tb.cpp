#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Valu_control_unit.h"
#include <iostream>
#include <fstream>
#include <string>
#include <cstdlib>
#include <cstdio>
#include <memory>
#include <chrono>

vluint64_t main_time = 0;

void print_alu_signals(const std::string& test_name, Valu_control_unit* top) {
    std::cout << "Test: " << test_name << "\n";
    std::cout << "  Inputs  -> AluOp: " << (int)top->AluOp 
              << " | func3: " << (int)top->func3 
              << " | func7[5]: " << ((top->func7 >> 5) & 1) << "\n";
    std::cout << "  Outputs -> alu_control: 4'b";
    
    for (int i = 3; i >= 0; i--) {
        std::cout << ((top->alu_control >> i) & 1);
    }
    std::cout << "\n---------------------------------------------------------\n";
}

int main (int argc, char** argv) 
{
    Verilated::commandArgs(argc, argv);

    Valu_control_unit* top = new Valu_control_unit;

    std::cout << "=== Starting ALU Control Unit Simulation ===\n\n";

    top->AluOp = 0b00; top->func3 = 0b000; top->func7 = 0b0000000;
    top->eval();
    print_alu_signals("Load/Store Operation (Expect ADD)", top);

    top->AluOp = 0b01; top->func3 = 0b000; top->func7 = 0b0000000;
    top->eval();
    print_alu_signals("Branch Operation (Expect SUB)", top);

    top->AluOp = 0b10; top->func3 = 0b000; top->func7 = 0b0000000;
    top->eval();
    print_alu_signals("R-type ADD (Expect ADD)", top);

    top->AluOp = 0b10; top->func3 = 0b000; top->func7 = 0b0100000;
    top->eval();
    print_alu_signals("R-type SUB (Expect SUB)", top);

    top->AluOp = 0b10; top->func3 = 0b111; top->func7 = 0b0000000;
    top->eval();
    print_alu_signals("R-type AND (Expect AND)", top);

    top->AluOp = 0b11; top->func3 = 0b110; top->func7 = 0b0000000;
    top->eval();
    print_alu_signals("I-type ORI (Expect OR)", top);

    delete top;
    return 0;
}
