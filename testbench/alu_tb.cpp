#include <verilated.h>          // Verilator core library
#include <verilated_vcd_c.h>    // VCD waveform generation
#include "Valu.h"               // Generated from alu.sv
#include <iostream>
#include <fstream>
#include <string>
#include <cstdlib>
#include <cstdio>
#include <memory>
#include <chrono>               // For performance timing

vluint64_t main_time = 0;

int main (int argc, char** argv) 
{
    Verilated::commandArgs(argc, argv);

    Valu* top = new Valu;

    std::cout << "=== Starting ALU Simulation ===\n\n";

    // قيم ابتدائية
    top->rs1 = 10;
    top->rs2 = 10;

    // 1. اختبار عملية AND (0000)
    top->alu_control = 0;
    top->eval();
    if(top->alu_result == (10 & 10) && top->zero_flage == 0)
        std::cout << "[ SUCCESS ] AND operation" << std::endl;
    else 
        std::cout << "[ FAILURE ] AND operation" << std::endl;

    // 2. اختبار عملية OR (0001)
    top->alu_control = 1;
    top->eval();
    if(top->alu_result == (10 | 10) && top->zero_flage == 0)
        std::cout << "[ SUCCESS ] OR operation" << std::endl;
    else 
        std::cout << "[ FAILURE ] OR operation" << std::endl;

    // 3. اختبار عملية ADD (0010)
    top->alu_control = 2;
    top->eval();
    if(top->alu_result == (10 + 10) && top->zero_flage == 0)
        std::cout << "[ SUCCESS ] ADD operation" << std::endl;
    else 
        std::cout << "[ FAILURE ] ADD operation" << std::endl;

    // 4. اختبار عملية SUB (0110) النتيجة صفر والـ flag يجب أن يكون 1
    top->alu_control = 6;
    top->eval();
    if(top->alu_result == (10 - 10) && top->zero_flage == 1)
        std::cout << "[ SUCCESS ] SUB operation (Zero Flag active)" << std::endl;
    else 
        std::cout << "[ FAILURE ] SUB operation" << std::endl;

    // 5. اختبار الجمع بقيمة سالبة (تحتاج إعادة eval بعد تغيير المدخلات)
    top->alu_control = 2; // عملية ADD
    top->rs1 = -10;       // سيتم تحويلها لـ تكميل اثنين (2's complement) تلقائياً
    top->rs2 = 10;
    top->eval();          // تحديث المحاكاة بالقيم الجديدة!
    
    if(top->alu_result == 0 && top->zero_flage == 1)
        std::cout << "[ SUCCESS ] ADD negative operation" << std::endl;
    else 
        std::cout << "[ FAILURE ] ADD negative operation" << std::endl;

    std::cout << "\n=== Simulation Finished ===\n";

    delete top;
    return 0;
}
