#include <iostream>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vsingle_cycle.h"

vluint64_t main_time = 0;

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);

    Vsingle_cycle* top = new Vsingle_cycle;
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("waveform.vcd");

    top->clk = 0;
    top->rst_n = 0;

    for (int i = 0; i < 10; i++) {
        top->clk = !top->clk;
        top->eval();
        tfp->dump(main_time++);
    }

    top->rst_n = 1;

    for (int i = 0; i < 30; i++) {
        top->clk = !top->clk;
        top->eval();
        tfp->dump(main_time++);
    }

    top->final();
    tfp->close();
    delete top;
    delete tfp;
    return 0;
}
