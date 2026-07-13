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

    std::cout << "=== Starting ALU Simulation ===\n\n";

    top->rs1 = 10;
    top->rs2 = 10;

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

    top->alu_control = 2; 
    top->rs1 = -10;       
    top->rs2 = 10;
    top->eval();          
    
    if(top->alu_result == 0 && top->zero_flage == 1)
        std::cout << "[ SUCCESS ] ADD negative operation" << std::endl;
    else 
        std::cout << "[ FAILURE ] ADD negative operation" << std::endl;

    std::cout << "\n=== Simulation Finished ===\n";

    delete top;
    return 0;
}
