# 🔰 Stage 1: Simple Single-Cycle Core (`simple_single_cycle`)

## 📌 Overview
This is the **first and most fundamental step** in the processor design journey. The goal of this stage is to construct a working, minimal 32-bit single-cycle processor that executes a core subset of instructions (`ADD`, `ADDI`, `BEQ`, `LW`, `SW`) in a single clock cycle per instruction.

> **Key Concept:** In a Single-Cycle architecture, every instruction executes in exactly **one clock cycle**. The clock period is determined by the total critical path delay (Fetch → Decode → Execute → Memory → Writeback).

---

## 🏗️ Architecture & Supported Features

- **Execution Model:** Single-Cycle Execution.
- **Instruction Memory:** Read-only block loading `.hex` instructions.
- **Register File:** 32 general-purpose 32-bit registers (with `x0` hardwired to `0`).
- **Supported Instructions (Minimal 5-Instruction Subset):**
  - **R-Type:** `ADD` (Addition)
  - **I-Type:** `ADDI` (Add Immediate), `LW` (Load Word)
  - **S-Type:** `SW` (Store Word)
  - **B-Type:** `BEQ` (Branch if Equal)
- **Control Flow:** Sequential execution (`PC + 4`) with conditional branching support via `BEQ`.

---

## 📁 Included RTL Modules

| Module File | Description |
| --- | --- |
| `program_counter.sv` | Simple PC register that updates to `PC + 4` or branch target on every rising edge. |
| `instruction_fetch.sv` | Fetches the 32-bit instruction word from memory based on current PC. |
| `instruction_memory.sv` | Holds instruction code loaded via `$readmemh`. |
| `registers_file.sv` | RISC-V Register File ($32 \times 32$-bit) with 2 read ports and 1 write port. |
| `control_unit.sv` | Decodes the `opcode` to generate global control signals (`RegWrite`, `ALUSrc`, `MemRead`, `MemWrite`, `Branch`). |
| `alu_control_unit.sv` | Decodes `funct3`/`funct7` and control signals into specific ALU control lines. |
| `alu.sv` | Performs arithmetic operations for `ADD`/`ADDI`/Address calculations and zero detection for `BEQ`. |
| `immediate_generator.sv` | Sign-extends instruction immediate fields (I-Type, S-Type, B-Type) to 32 bits. |
| `core_monitor.sv` | Helper module to monitor register states and debug instruction execution. |
| `top.sv` | Top-level module connecting all execution units together. |

---

## 🚦 How to Build and Run

To compile and run the simulation using **Verilator**:

```bash
# Navigate to this stage directory
cd versions/simpe_single_cycle

# Run default test simulation
make

# Run simulation with a specific HEX file
make TEST=program.hex

```

### Expected Output

The testbench (`top_tb.cpp`) will drive the clock and display the register contents, memory updates, and ALU results cycle-by-cycle, verifying that basic operations compute correctly.
