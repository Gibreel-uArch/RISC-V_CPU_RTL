
#include "Vtop.h"
#include <verilated.h>
#include <verilated_vcd_c.h>

// Global simulation time counter
vluint64_t main_time = 0;

// Called by $time in Verilog (if used)
double sc_time_stamp() { return main_time; }

int main(int argc, char **argv) {
  // Initialize Verilator command arguments
  Verilated::commandArgs(argc, argv);

  // Instantiate the top module
  Vtop *top = new Vtop;

  // Initialize VCD Trace Dump
  Verilated::traceEverOn(true);
  VerilatedVcdC *tfp = new VerilatedVcdC;
  top->trace(tfp, 99); // Trace hierarchy up to 99 levels deep
  tfp->open("waveform.vcd");

  // Initialize inputs
  top->clk = 0;
  top->rst_n = 0;

  // Simulation Loop
  while (main_time < 100 && !Verilated::gotFinish()) {

    // Apply reset release after a few cycles
    if (main_time == 3) {
      top->rst_n = 1;
    }

    // Toggle clock (half-period toggle)
    top->clk = !top->clk;

    // Evaluate model
    top->eval();

    // Dump trace data for this timestamp
    tfp->dump(main_time);

    // Advance time
    main_time++;
  }

  // Finalize simulation and close trace file
  top->final();
  tfp->close();

  // Clean up memory
  delete tfp;
  delete top;

  return 0;
}
