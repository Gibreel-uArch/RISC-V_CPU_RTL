```markdown
# ⚡ Stage 3: Basic 5-Stage Pipeline (`pipeline_no_hazards`)

## 📌 Overview
This stage transitions the core architecture from a Single-Cycle execution model to a **5-Stage Pipelined Processor**. By breaking instruction execution into five discrete stages separated by Pipeline Registers, multiple instructions can be processed concurrently, significantly increasing instruction throughput (IPC).

> **Important Concept:** This is an **unhandled pipeline**. It does **not** yet contain hardware to detect or handle Data or Control Hazards. Instructions with dependencies must be separated by NOPs (`nop` or `addi x0, x0, 0`) in assembly to avoid data corruption.

---

## 🏗️ Pipeline Stages & Pipeline Registers

The datapath is sliced into 5 pipeline stages:

1. **IF (Instruction Fetch):** Fetches instruction from memory using the current PC.
2. **ID (Instruction Decode):** Decodes instruction, generates control signals, and reads register operands.
3. **EX (Execute):** Performs ALU calculations, branch address evaluation, and shift operations.
4. **MEM (Memory Access):** Reads from or writes to Data Memory (`memory.sv`).
5. **WB (Write Back):** Writes the final result back to the Register File (`registers_file.sv`).

Between each stage, pipeline registers store intermediate results and control signals:
- `IF_ID.sv`
- `ID_EX.sv`
- `EX_MEM.sv`
- `MEM_WB.sv`

---

## 🧩 Hardware Datapath Diagram

```text
+------+    IF/ID    +------+    ID/EX    +------+    EX/MEM    +------+    MEM/WB    +------+
|  IF  |=========>|  ID  |=========>|  EX  |==========>| MEM  |=========>|  WB  |
+------+             +------+             +------+              +------+             +------+
   ^                                                                                     |
   +================================ Write Back Loop ====================================+

```

---

## 📁 Included RTL Modules

| Module File | Description |
| --- | --- |
| `IF_ID.sv` | Pipeline register holding PC and raw fetched instruction word. |
| `ID_EX.sv` | Pipeline register propagating decoded operands, immediate values, and control flags. |
| `EX_MEM.sv` | Pipeline register carrying ALU output, store data, destination register address, and memory signals. |
| `MEM_WB.sv` | Pipeline register carrying memory read data or ALU result to Write Back stage. |
| `multiplexer.sv` | Helper multiplexers used across pipeline boundary selections. |
| `rv32_types_pkg.sv` | Package defining pipeline structures, control structs, and RISC-V types. |
| `pc_unit.sv`, `alu.sv`, `registers_file.sv`, `control_unit.sv`, etc. | Core execution units adapted to pipeline register boundaries. |

---

## 🚦 How to Build and Run

To compile and simulate using **Verilator**:

```bash
# Navigate to this stage directory
cd versions/pipeline_no_hazards

# Build and run default test program
make

# Run custom assembly test (Ensure Assembly code includes NOPs between dependent instructions)
make TEST=program.hex

```

```
