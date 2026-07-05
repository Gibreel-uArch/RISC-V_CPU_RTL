#include <verilated.h>
#include <iostream>
#include <memory>
#include "Vpc.h"

int main(int argc,char** argv)
{

    Verilated::commandArgs(argc,argv);

    Vpc* top = new Vpc ;

    int time = 0;
    top->clk = 0;
    top->rst_n = 0;
    for(int cycle =0 ; cycle < 30 ; cycle++)
    {
        if(cycle > 3) top->rst_n = 1;

        top->clk = 0;
        top->eval();
        top->clk = 1;
        top->eval();
    
        std::cout<< "cycle : " << cycle
                 << " | PC: 0x" << std::hex << top->count 
                 << std::endl;
    }

    
    delete top;
    return 0;
}
