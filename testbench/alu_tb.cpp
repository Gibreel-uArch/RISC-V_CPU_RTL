#include <verilated.h>          
#include <verilated_vcd_c.h>    
#include "Valu.h"               
#include <iostream>
#include <fstream>
#include <string>
#include <cstdlib>
#include <cstdio>
#include <memory>
#include <chrono>                

vluint64_t main_time = 0;

int main (int argc, char** argv) 
{
    Verilated::commandArgs(argc, argv);

    Valu* top = new Valu;

    std::cout << "=== Starting ALU Full Simulation ===\n\n";

    top->src1 = 10;
    top->src2 = 10;

    top->alu_control = 0;
    top->eval();
    if(top->alu_result == (10 & 10) && top->zero_flage == 0)
        std::cout << "[ SUCCESS ] AND operation" << std::endl;
    else 
        std::cout << "[ FAILURE ] AND operation" << std::endl;

    top->alu_control = 1;
    top->eval();
    if(top->alu_result == (10 | 10) && top->zero_flage == 0)
        std::cout << "[ SUCCESS ] OR operation" << std::endl;
    else 
        std::cout << "[ FAILURE ] OR operation" << std::endl;

    top->alu_control = 2;
    top->eval();
    if(top->alu_result == (10 + 10) && top->zero_flage == 0)
        std::cout << "[ SUCCESS ] ADD operation" << std::endl;
    else 
        std::cout << "[ FAILURE ] ADD operation" << std::endl;

    top->alu_control = 6;
    top->eval();
    if(top->alu_result == (10 - 10) && top->zero_flage == 1)
        std::cout << "[ SUCCESS ] SUB operation (Zero Flag active)" << std::endl;
    else 
        std::cout << "[ FAILURE ] SUB operation" << std::endl;

    top->src1 = 12; 
    top->src2 = 5;  
    top->alu_control = 3;
    top->eval();
    if(top->alu_result == (12 ^ 5))
        std::cout << "[ SUCCESS ] XOR operation" << std::endl;
    else 
        std::cout << "[ FAILURE ] XOR operation" << std::endl;

    top->src1 = 5;
    top->src2 = 2; 
    top->alu_control = 4;
    top->eval();
    if(top->alu_result == (5 << 2))
        std::cout << "[ SUCCESS ] SLL operation" << std::endl;
    else 
        std::cout << "[ FAILURE ] SLL operation" << std::endl;

    top->src1 = 20;
    top->src2 = 2; 
    top->alu_control = 5;
    top->eval();
    if(top->alu_result == (20 >> 2))
        std::cout << "[ SUCCESS ] SRL operation" << std::endl;
    else 
        std::cout << "[ FAILURE ] SRL operation" << std::endl;

    top->src1 = -20; 
    top->src2 = 2;
    top->alu_control = 8;
    top->eval();
    if((int32_t)top->alu_result == (-20 >> 2))
        std::cout << "[ SUCCESS ] SRA operation (Negative preserved)" << std::endl;
    else 
        std::cout << "[ FAILURE ] SRA operation" << std::endl;

    top->src1 = -5;
    top->src2 = 3; 
    top->alu_control = 7;
    top->eval();
    if(top->alu_result == 1)
        std::cout << "[ SUCCESS ] SLT operation (Signed)" << std::endl;
    else 
        std::cout << "[ FAILURE ] SLT operation" << std::endl;

    top->src1 = -5; 
    top->src2 = 3;  
    top->alu_control = 12;
    top->eval();
    if(top->alu_result == 0)
        std::cout << "[ SUCCESS ] SLTU operation (Unsigned)" << std::endl;
    else 
        std::cout << "[ FAILURE ] SLTU operation" << std::endl;

    top->alu_control = 2; 
    top->src1 = -10;       
    top->src2 = 10;
    top->eval();          
    
    if(top->alu_result == 0 && top->zero_flage == 1)
        std::cout << "[ SUCCESS ] ADD negative operation" << std::endl;
    else 
        std::cout << "[ FAILURE ] ADD negative operation" << std::endl;

    std::cout << "\n=== Full Simulation Finished ===\n";

    delete top;
    return 0;
}
