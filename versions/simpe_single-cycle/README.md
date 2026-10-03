```markdown
# 🔰 Stage 1: Simple Single-Cycle Core (`simpe_single_cycle`)

## 📌 Overview
This is the **first and most fundamental step** in the processor design journey. The goal of this stage is to construct a working, minimal 32-bit single-cycle processor that executes basic Arithmetic and Logic operations in a single clock cycle per instruction.

> **Key Concept:** In a Single-Cycle architecture, every instruction executes in exactly **one clock cycle**. The clock period is determined by the total critical path delay (Fetch → Decode → Execute → Memory → Writeback).

---

## 🏗️ Architecture & Supported Features

- **Execution Model:** Single-Cycle Execution.
- **Instruction Memory:** Read-only block loading `.hex` instructions.
- **Register File:** 32 general-purpose 32-bit registers (with `x0` hardwired to `0`).
- **Supported Instructions (Minimal RV32I Subset):**
  - **R-Type:** `ADD`, `SUB`, `AND`, `OR`, `SLT`, `XOR`
  - **I-Type:** `ADDI`, `ANDI`, `ORI`
- **Control Flow:** Sequential execution via PC increments (`PC = PC + 4`). No jumps or branches implemented at this stage.

---

## 🧩 Hardware Block Diagram

```text
       +------------------+
       | Program Counter  |
       +--------+---------+
                | (PC)
                v
       +------------------+
       | Instruction Mem  |
       +--------+---------+
                | (Instruction [31:0])
                v
       +------------------+         +------------------+
       |   Control Unit   | ------->|   ALU Control    |
       +------------------+         +--------+---------+
                | (RegWrite, ALUOp)          | (ALU Control Signals)
                v                            v
       +------------------+         +------------------+
       |  Registers File  |-------> |       ALU        |
       +------------------+ (rs1,2) +------------------+

```

---

## 📁 Included RTL Modules

| Module File | Description |
| --- | --- |
| `program_counter.sv` | Simple PC register that updates to `PC + 4` on every rising edge. |
| `instruction_fetch.sv` | Fetches the 32-bit instruction word from memory based on current PC. |
| `instruction_memory.sv` | Holds instruction code loaded via `$readmemh`. |
| `registers_file.sv` | RISC-V Register File ($32 \times 32$-bit) with 2 read ports and 1 write port. |
| `control_unit.sv` | Decodes the `opcode` to generate global control signals. |
| `alu_control_unit.sv` | Decodes `funct3`/`funct7` and control signals into specific ALU control lines. |
| `alu.sv` | Performs arithmetic/logical operations (`ADD`, `SUB`, `AND`, `OR`, `SLT`, `XOR`). |
| `immediate_generator.sv` | Sign-extends instruction immediate fields to 32 bits. |
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

The testbench (`top_tb.cpp`) will drive the clock and display the register contents and ALU results cycle-by-cycle, verifying that basic operations compute correctly.

```
