# ⚙️ Stage 4: Full 5-Stage Pipeline with Hazard Handling (`complete_pipeline`)

## 📌 Overview
Building upon the basic pipeline in Stage 3, this version integrates complete **Hardware Hazard Management**. It automatically resolves Data Hazards and Control Hazards in hardware, allowing standard compiled C or Assembly code to execute correctly **without requiring artificial NOP insertions**.

---

## 🛡️ Hazard Resolution Mechanisms

### 1. Data Hazards & Data Forwarding (`forwarding_unit.sv`)
When an instruction in `EX` needs a result from an earlier instruction currently in `MEM` or `WB`, the **Forwarding Unit** reroutes the data directly from `EX/MEM` or `MEM/WB` pipeline registers back to the ALU inputs, bypassing the Register File.

### 2. Load-Use Hazards & Pipeline Stalls (`hazard_detection_unit.sv`)
For `LOAD` instructions followed immediately by a dependent instruction, forwarding alone is insufficient because memory data is not ready until the `MEM` stage. The **Hazard Detection Unit** detects this scenario and:
- Inserts a 1-cycle **Stall** (bubbles) into `ID/EX`.
- Freezes updates to the `PC` register and `IF/ID` pipeline register.

### 3. Control Hazards & Branch Flushing
When a conditional branch or jump is taken in the `EX` stage, instructions fetched during speculative execution (`IF` and `ID`) are invalidated by **Flushing** the `IF/ID` and `ID/EX` registers (converting them to NOPs).

---

## 🧩 Hazard Control Logic Flow

```text
                         +------------------------+
                         | Forwarding Unit        |
                         +-----------+------------+
                                     | Selects ALU Operands (Bypassing)
                                     v
+-------------+    +-------------+   |   +-------------+   +-------------+   +-------------+
|     IF      |===>|     ID      |======>|     EX      |===>|     MEM     |===>|     WB      |
+-------------+    +-------------+       +-------------+   +-------------+   +-------------+
       ^                  ^
       | Stall / Freeze   | Flush on Branch
+------+------------------+-------+
| Hazard Detection & Branch Logic |
+---------------------------------+

```

---

## 📁 Included RTL Modules

| Module File | Description |
| --- | --- |
| `forwarding_unit.sv` | Compares source registers (`rs1`, `rs2`) with destination registers (`rd`) in `EX/MEM` and `MEM/WB` to drive ALU input multiplexers. |
| `hazard_detection_unit.sv` | Detects Load-Use hazards and generates stall signals for `PC` and `IF_ID` pipeline registers. |
| `branch_unit.sv` | Evaluates branch conditions and triggers pipeline register flushes on branch mispredictions. |
| `core_monitor.sv` | Debug unit tracking active pipeline stages, stalls, flushes, and execution state. |

---

## 🚦 How to Build and Run

To compile and simulate using **Verilator**:

```bash
# Navigate to this stage directory
cd versions/complete_pipeline

# Build and run default simulation
make

# Execute real compiled algorithms (e.g., bubble sort, fibonacci)
make TEST=program.hex

```

### Verification

You can load binaries generated from C programs (`c_programs`) into `program.hex` to confirm that loops, function calls, and pointer arithmetic run seamlessly without pipeline hazards.
