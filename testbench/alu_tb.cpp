
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

int main (int argc, char** argv) {
    
    Verilated::commandArgs(argc,argv);
//    Verilated::traceEvenOn(true);

    Valu* top = new Valu;
    int time = 0;

    top->alu_control = 0;
    top->rs1 = 10;
    top->rs2 = 10;
    top->eval();

    if(top->alu_result == (10 & 10) && top->zero_flage == 0)
        std::cout<< "AND sucessed"  << std::endl;
    else 
        std::cout<< "AND failured" << std::endl;

    top->alu_control = 1;
    top->eval();
    if(top->alu_result == (10 | 10) && top->zero_flage == 0)
        std::cout<< "OR  sucessed"  << std::endl;
    else 
        std::cout<< "OR  failured" << std::endl;


    top->alu_control = 2;
    top->eval();
    if(top->alu_result == (10 + 10) && top->zero_flage == 0)
        std::cout<< "ADD sucessed"  << std::endl;
    else 
        std::cout<< "ADD failured" << std::endl;


    
    top->alu_control = 6;
    top->eval();
    if(top->alu_result == (10 - 10) && top->zero_flage == 1)
        std::cout<< "SUB sucessed"  << std::endl;
    else 
        std::cout<< "SUB failured" << std::endl;

    top->rs1 = -10;
    if(top->alu_result == (10 + -10) && top->zero_flage == 1)
        std::cout<< "ADD negative sucessed"  << std::endl;
    else 
        std::cout<< "ADD negative failured" << std::endl;
    

    delete top;
    return 0;
}
