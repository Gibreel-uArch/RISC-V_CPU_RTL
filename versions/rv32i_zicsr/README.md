```markdown
# 🏛️ Stage 5: System Control & Traps (`rv32i_zicsr`)

## 📌 Overview
This stage upgrades the 5-stage hazard-aware pipeline by integrating the **RISC-V `Zicsr` Extension** (Control and Status Registers) and hardware **Trap/Exception Handling**. This enables the core to support privileged execution hooks, system calls (`ecall`), software breakpoints (`ebreak`), and hardware exception processing.

---

## 🏗️ Supported CSRs & Exception Handling

### Supported CSR Registers
Implemented inside `cs_registers.sv`:
- `mstatus`: Machine Status Register (tracks global interrupt enables and privilege levels).
- `mcause`: Machine Cause Register (stores the exception code or interrupt reason).
- `mepc`: Machine Exception Program Counter (holds the return address after exception handling).
- `mtvec`: Machine Trap-Vector Base Address Register (holds the entry point for the trap handler).
- `mcycle` / `minstret`: Performance counters tracking elapsed cycles and executed instructions.

### CSR Instructions
- `CSRRW`, `CSRRS`, `CSRRC` (Register-based CSR read/write/set/clear).
- `CSRRWI`, `CSRRSI`, `CSRRCI` (Immediate-based CSR manipulation).

### Trap Execution Flow (`trap_controller.sv`)
1. **Detection:** An exception is triggered (e.g., illegal instruction, misalignment, `ecall`, `ebreak`).
2. **State Saving:** Current `PC` is saved to `mepc`, and the cause code is written to `mcause`.
3. **Control Transfer:** The pipeline is flushed, and `PC` jumps to the address in `mtvec`.
4. **Return:** Executing the `mret` instruction restores state and jumps back to `mepc`.

---

## 📁 Included RTL Modules

| Module File | Description |
| :--- | :--- |
| `cs_registers.sv` | Implements machine-level CSRs with read/write access logic and privilege checks. |
| `trap_controller.sv` | Coordinates exception signals, pipeline flushing during traps, and PC redirection to `mtvec`/`mepc`. |
| `complete_pipeline files` | Pipeline stages (`IF`, `ID`, `EX`, `MEM`, `WB`) modified to propagate trap flags and execution signals. |

---

## 🚦 How to Build and Run

To compile and simulate using **Verilator**:

```bash
# Navigate to this stage directory
cd versions/rv32i_zicsr

# Run default exception tests
make

# Test specific exception or CSR assembly programs
make TEST=../../tests/hex/exceptions.hex

```

```
