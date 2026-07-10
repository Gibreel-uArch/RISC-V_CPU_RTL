#include <verilated.h>          // Verilator core library
#include <verilated_vcd_c.h>    // VCD waveform generation
#include "Vcontrol_unit.h"      // Generated from control_unit.sv
#include <iostream>
#include <fstream>
#include <string>
#include <cstdlib>
#include <cstdio>
#include <memory>
#include <chrono>               // For performance timing

vluint64_t main_time = 0;

// دالة مساعدة لطباعة الإشارات بشكل منظم
void print_signals(const std::string& inst_name, Vcontrol_unit* top) {
    std::cout << "Instruction: " << inst_name << "\n";
    std::cout << "  Outputs -> RegWrite: " << (int)top->RegWrite 
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

    // إنشاء كائن الموديل
    Vcontrol_unit* top = new Vcontrol_unit;

    std::cout << "=== Starting Control Unit Simulation ===\n\n";

    // الاختبار الأول: R-type
    top->opcode = 0b0110011;
    top->eval();
    print_signals("R-type (e.g., ADD, SUB)", top);

    // الاختبار الثاني: I-type
    top->opcode = 0b0010011;
    top->eval();
    print_signals("I-type (e.g., ADDI)", top);

    // الاختبار الثالث: Load Word (LW)
    top->opcode = 0b0000011;
    top->eval();
    print_signals("Load Word (LW)", top);

    // الاختبار الرابع: Store Word (SW)
    top->opcode = 0b0100111;
    top->eval();
    print_signals("Store Word (SW)", top);

    // الاختبار الخامس: Branch Equal (BEQ)
    top->opcode = 0b1100011;
    top->eval();
    print_signals("Branch Equal (BEQ)", top);

    // تنظيف الذاكرة
    delete top;
    return 0;
}
