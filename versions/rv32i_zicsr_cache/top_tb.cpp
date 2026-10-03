#include "Vtop.h"
#include <cstdlib>
#include <iostream>
#include <verilated.h>
#include <verilated_vcd_c.h>

#define MAX_SIM_TIME 1000
#define MMIO_EXIT_ADDR 0x40000000
#define SIM_TRACE_FILE "waveform.vcd"

Vtop *top = nullptr;
VerilatedVcdC *trace = nullptr;
vluint64_t sim_time = 0;

// ---------------------------------------------------------------------------
//  Trigger Performance Report
// ---------------------------------------------------------------------------
void trigger_report() {
  if (!top)
    return;

  std::cout << "\n[TB] Triggering performance report..." << std::endl;

  top->report_trigger = 1;

  top->clk = 1;
  top->eval();
  if (trace)
    trace->dump(sim_time);
  sim_time++;

  top->clk = 0;
  top->eval();
  if (trace)
    trace->dump(sim_time);
  sim_time++;

  top->report_trigger = 0;

  top->clk = 1;
  top->eval();
  if (trace)
    trace->dump(sim_time);
  sim_time++;
}

// ---------------------------------------------------------------------------
//  Clean shutdown
// ---------------------------------------------------------------------------
void cleanup_and_exit(int code) {
  trigger_report();

  if (trace) {
    trace->dump(sim_time);
    trace->close();
    delete trace;
    trace = nullptr;
  }

  if (top) {
    top->final();
    delete top;
    top = nullptr;
  }

  std::cout << "Simulation terminated. Exit code: " << code << std::endl;
  exit(code);
}

// ---------------------------------------------------------------------------
//  MMIO Exit check
// ---------------------------------------------------------------------------
void check_mmio_exit() {
  if (top->MemWrite && top->address == MMIO_EXIT_ADDR) {
    uint32_t exit_code = top->WriteData;

    std::cout << "\n========================================" << std::endl;
    if (exit_code == 0x5555) {
      std::cout << "TEST PASSED!" << std::endl;
    } else if (exit_code == 0xDEAD) {
      std::cout << "TEST FAILED!" << std::endl;
    } else {
      std::cout << "UNKNOWN EXIT CODE!" << std::endl;
    }
    std::cout << " Exit code: 0x" << std::hex << exit_code << std::dec
              << std::endl;
    std::cout << " Cycles executed: " << sim_time / 2 << std::endl;
    std::cout << "========================================\n" << std::endl;

    cleanup_and_exit(exit_code == 0x5555 ? 0 : 1);
  }
}

// ---------------------------------------------------------------------------
//  Clock tick
// ---------------------------------------------------------------------------
void tick() {
  // Falling edge
  top->clk = 0;
  top->eval();
  if (trace)
    trace->dump(sim_time);
  sim_time++;

  // Rising edge
  top->clk = 1;
  top->eval();
  if (trace)
    trace->dump(sim_time);
  sim_time++;

  check_mmio_exit();
}

// ---------------------------------------------------------------------------
//  Reset
// ---------------------------------------------------------------------------
void reset() {
  top->rst_n = 0;
  top->report_trigger = 0;
  tick();
  tick();
  top->rst_n = 1;
  std::cout << "Processor reset complete. Starting execution..." << std::endl;
}

// ---------------------------------------------------------------------------
//  Main
// ---------------------------------------------------------------------------
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

  // ----------------- Timeout path -----------------
  std::cout << "\n========================================" << std::endl;
  std::cout << " SIMULATION TIMEOUT!" << std::endl;
  std::cout << " Maximum cycles reached without MMIO exit." << std::endl;
  std::cout << "========================================\n" << std::endl;

  cleanup_and_exit(1);

  return 1;
}
