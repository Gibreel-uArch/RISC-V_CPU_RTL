#include <verilated.h>
#include <iostream>
#include <iomanip>
#include "Vinstruction_fetch.h"

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vinstruction_fetch* top = new Vinstruction_fetch;

    top->clk = 0;
    top->rst_n = 0;
    top->branch = 0;
    top->imm = 0;

    for(int ticks = 0; ticks < 30; ticks++) {
        
        if (ticks > 2) top->rst_n = 1;

        if (ticks % 2 == 0) {
            top->clk = 0;
            top->eval();
        } else {
            top->clk = 1;
            top->eval();

            std::cout << "Cycle: " << (ticks / 2) 
                      << " | Instruction: 0x" 
                      << std::hex << std::setw(8) << std::setfill('0') << top->instruction 
                      << std::dec << std::endl;

            if ((top->instruction & 0xFF) == 0xE3 || (top->instruction >> 24) == 0xE3) {
                std::cout << " -> [Branch Detected! Jumping back...]" << std::endl;
                top->branch = 1;
                top->imm = -20;
            } else {
                top->branch = 0;
                top->imm = 0;
            }

        }
    }

    delete top;
    return 0;
}
