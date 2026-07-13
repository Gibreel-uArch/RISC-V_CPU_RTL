#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vcontrol_unit.h"
#include <iostream>
#include <fstream>
#include <string>
#include <cstdlib>
#include <cstdio>
#include <memory>
#include <chrono>

vluint64_t main_time = 0;

void print_signals(const std::string& inst_name, Vcontrol_unit* top) {
    std::cout << "Instruction: " << inst_name << "\n";
    std::cout << "   Outputs -> RegWrite: " << (int)top->RegWrite 
              << " | AluSrc: "   << (int)top->AluSrc 
              << " | MemRead: "  << (int)top->MemRead
              << " | MemWrite: " << (int)top->MemWrite 
              << " | MemtoReg: " << (int)top->MemtoReg 
              << " | Branch: "   << (int)top->branch 
              << " | AluOp: "    << (int)top->AluOp << "\n";
    std::cout << "---------------------------------------------------------\n";
}

int main (int argc, char** argv) 
{
    Verilated::commandArgs(argc, argv);

    Vcontrol_unit* top = new Vcontrol_unit;

    std::cout << "=== Starting Control Unit Simulation ===\n\n";

    top->opcode = 0b0110011;
    top->eval();
    print_signals("R-type (e.g., ADD, SUB)", top);

    top->opcode = 0b0010011;
    top->eval();
    print_signals("I-type (e.g., ADDI)", top);

    top->opcode = 0b0000011;
    top->eval();
    print_signals("Load Word (LW)", top);

    top->opcode = 0b0100111;
    top->eval();
    print_signals("Store Word (SW)", top);

    top->opcode = 0b1100011;
    top->eval();
    print_signals("Branch Equal (BEQ)", top);

    delete top;
    return 0;
}
