# ⚡ Stage 6: The Complete Core (`rv32i_zicsr_cache`)

## 📌 Overview
This is the **flagship implementation** of the processor. It combines the 5-Stage Pipelined RV32I Datapath, Hazard Handling, `Zicsr` Exception Processing, and a **Dual-Cache Memory Subsystem** (I-Cache and D-Cache). 

Instead of connecting pipeline stages directly to high-latency memory, instructions and data requests pass through high-speed cache controllers, stalling the pipeline only on **Cache Misses**.

---

## 🏗️ Memory Subsystem & Cache Specs

```text
+-------------------+       +-------------------+
| Instruction Fetch |       |   Memory Stage    |
+---------+---------+       +---------+---------+
          |                           |
          v                           v
+-------------------+       +-------------------+
|  I-Cache (icache) |       |  D-Cache (dcache) |
|   Direct-Mapped   |       | 2-Way Associative |
+---------+---------+       +---------+---------+
          |                           |
          +-------------+-------------+
                        | (Cache Miss / Line Refill)
                        v
              +-------------------+
              |   Block Memory    |
              | (block_memory.sv) |
              +-------------------+

```

### Cache Specifications

1. **Instruction Cache (`icache.sv`):**
* **Type:** Direct-Mapped Instruction Cache.
* **Purpose:** Accelerates fetch cycle instruction throughput.


2. **Data Cache (`dcache.sv`):**
* **Type:** 2-Way Set Associative Cache.
* **Write Policy:** **Write-Back** with dirty-bit tracking (minimizes memory writes).
* **Block Size:** **16 Bytes** (4 x 32-bit words per cache line).


3. **Main Memory Interface (`block_memory.sv`):**
* Simulates block-level DRAM/SRAM access with multi-cycle penalties during cache refills.



---

## 📁 Included RTL Modules

| Module File | Description |
| --- | --- |
| `icache.sv` | Direct-mapped instruction cache controller emitting hit/miss stall signals. |
| `dcache.sv` | 2-way set associative data cache with write-back buffer and dirty line replacement logic. |
| `block_memory.sv` | Block-addressable memory module responding to multi-word line reads and writes. |
| `top.sv` | Integrates the pipeline core with I-Cache, D-Cache, and main memory. |

---

## 🚦 How to Build and Run

To compile and simulate using **Verilator**:

```bash
# Navigate to this stage directory
cd versions/rv32i_zicsr_cache

# Build and execute default test program
make

# Run C program binary (e.g., Factorial / Fibonacci)
make TEST=../../tests/hex/factorial.hex

```
