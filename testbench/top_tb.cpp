#include "Vtop.h"
#include <cstdlib>
#include <iostream>
#include <verilated.h>
#include <verilated_vcd_c.h>

#define MAX_SIM_TIME 1000
#define MMIO_EXIT_ADDR 0x40000000
#define SIM_TRACE_FILE "sim_trace.vcd"

Vtop *top;
VerilatedVcdC *trace;
vluint64_t sim_time = 0;

void check_mmio_exit() {
  if (top->MemWrite && top->address == MMIO_EXIT_ADDR) {
    uint32_t exit_code = top->WriteData;

    if (exit_code == 0x5555) {
      std::cout << "\n========================================" << std::endl;
      std::cout << " TEST PASSED! Factorial result is correct." << std::endl;
      std::cout << " Exit code: 0x" << std::hex << exit_code << std::endl;
      std::cout << " Cycles executed: " << std::dec << sim_time / 2
                << std::endl;
      std::cout << "========================================\n" << std::endl;
    } else if (exit_code == 0xDEAD) {
      std::cout << "\n========================================" << std::endl;
      std::cout << " TEST FAILED! Incorrect factorial result." << std::endl;
      std::cout << " Exit code: 0x" << std::hex << exit_code << std::endl;
      std::cout << "========================================\n" << std::endl;
    } else {
      std::cout << "\n========================================" << std::endl;
      std::cout << " Unknown exit code: 0x" << std::hex << exit_code
                << std::endl;
      std::cout << "========================================\n" << std::endl;
    }

    if (trace) {
      trace->dump(sim_time);
      trace->close();
    }

    std::cout << "Simulation terminated by MMIO write." << std::endl;
    exit(exit_code == 0x5555 ? 0 : 1);
  }
}

void tick() {
  top->clk = 0;
  top->eval();
  if (trace)
    trace->dump(sim_time);
  sim_time++;

  top->clk = 1;
  top->eval();
  if (trace)
    trace->dump(sim_time);
  sim_time++;

  check_mmio_exit();
}

void reset() {
  top->rst_n = 0;
  tick();
  tick();
  top->rst_n = 1;
  std::cout << "Processor reset complete. Starting execution..." << std::endl;
}

int main(int argc, char **argv) {
  Verilated::commandArgs(argc, argv);
  top = new Vtop;

  Verilated::traceEverOn(true);
  trace = new VerilatedVcdC;
  top->trace(trace, 99);
  trace->open(SIM_TRACE_FILE);

  std::cout << "Starting simulation..." << std::endl;
  reset();

  while (sim_time < MAX_SIM_TIME * 2) {
    tick();
  }

  std::cout << "\n========================================" << std::endl;
  std::cout << " SIMULATION TIMEOUT!" << std::endl;
  std::cout << " Maximum cycles reached without MMIO exit." << std::endl;
  std::cout << "========================================\n" << std::endl;

  if (trace) {
    trace->dump(sim_time);
    trace->close();
  }

  delete top;
  delete trace;
  return 1;
}
