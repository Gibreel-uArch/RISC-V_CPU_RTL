# ⚙️ Stage 2: Full Single-Cycle Core (`full_single-cycle`)

## 📌 Overview
Building upon the minimal core in Stage 1, this stage extends the single-cycle design to support the **entire RV32I Base Integer Instruction Set**. This includes Data Memory load/store operations, Unconditional Jumps, Conditional Branches, and all immediate ALU instructions.

> **Key Addition:** This core introduces a unified Memory Subsystem interface capable of reading/writing data bytes/halfwords/words (`LB`, `LH`, `LW`, `SB`, `SH`, `SW`) and branching hardware logic (`branch_unit.sv`).

---

## 🏗️ Architecture & Supported Features

- **Execution Model:** Full Single-Cycle Execution.
- **Instruction Support:** Complete RV32I Base Instruction Set:
  - **Arithmetic & Logic:** R-Type (`ADD`, `SUB`, `SLL`, `SLT`, `SLTU`, `XOR`, `SRL`, `SRA`, `OR`, `AND`) and I-Type immediates (`ADDI`, `SLTI`, etc.).
  - **Memory Access:** Load (`LB`, `LH`, `LW`, `LBU`, `LHU`) and Store (`SB`, `SH`, `SW`).
  - **Conditional Branches:** `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU`.
  - **Unconditional Jumps:** `JAL` (Jump and Link), `JALR` (Jump and Link Register).
  - **Upper Immediates:** `LUI` (Load Upper Immediate), `AUIPC` (Add Upper Immediate to PC).
- **Branch Processing:** Dedicated `branch_unit.sv` evaluating comparison results to update Next-PC logic dynamically.

---

## 📁 Included RTL Modules

| Module File | Description |
| --- | --- |
| `pc_unit.sv` | Upgraded PC unit supporting branches, jumps (`JAL`/`JALR`), and relative offsets. |
| `instruction_fetch.sv` | Fetches instruction based on dynamic PC address. |
| `instruction_memory.sv` | Instruction memory interface. |
| `registers_file.sv` | General-purpose register file with read/write enable controls. |
| `immediate_generator.sv` | Decodes immediate types: I-type, S-type, B-type, U-type, and J-type. |
| `control_unit.sv` | Generates full RV32I control signals (`MemRead`, `MemWrite`, `RegWrite`, `Branch`, `Jump`, `ALUSrc`). |
| `alu_control_unit.sv` | Decodes full ALU opcodes for all logical, arithmetic, and shift commands. |
| `alu.sv` | Full 32-bit ALU supporting all shifts (`SLL`, `SRL`, `SRA`) and comparisons (`SLT`, `SLTU`). |
| `branch_unit.sv` | Computes branch conditions independently of the main ALU for fast control path resolution. |
| `memory.sv` | Data Memory module supporting byte, half-word, and word reads/writes with sign-extension. |
| `core_monitor.sv` | Real-time debugging and signal tracking module. |
| `top.sv` | Top-level module integrating the full RV32I Datapath. |

---

## 🚦 How to Build and Run

To compile and simulate using **Verilator**:

```bash
# Navigate to this stage directory
cd versions/full_single-cycle

# Build and run the testbench with default code
make

# Run simulation with custom HEX code (e.g., control-flow or memory test)
make TEST=program.hex

```

### Verification

You can pass test programs containing jumps, loops, and array manipulation (e.g., bubble-sort) into `program.hex` to confirm proper branch execution and memory interaction.
