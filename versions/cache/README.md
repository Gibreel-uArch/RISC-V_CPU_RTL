# 🔍 Standalone Cache Implementations (`versions/cache/`)

## 📌 Overview
This directory serves as an **educational playground for Cache Architecture design**. Before integrating caches directly into the processor core, these standalone SystemVerilog modules were developed and tested to explore different organization schemes and write policies.

---

## 🏗️ Implemented Cache Topologies

### 1. Direct-Mapped Cache (`direct_mapped_cache.sv`)
- **Concept:** Each memory address maps to exactly one specific line in the cache.
- **Pros:** Fast hit time, minimal hardware cost, low complexity.
- **Cons:** High risk of conflict misses when two addresses map to the same set.

### 2. 2-Way Set Associative Cache (`2way_associative_cache.sv`)
- **Concept:** Memory addresses map to a set containing 2 cache lines. Uses replacement logic (e.g., LRU - Least Recently Used) to select which line to overwrite.
- **Pros:** Drastically reduces conflict misses compared to direct-mapped caches.
- **Cons:** Slightly higher logic complexity and tag comparison latency.

### 3. Write Policies & Management (`write_policies_cache.sv`)
Demonstrates and compares memory write strategies:
- **Write-Through:** Writes data simultaneously to both cache and main memory.
- **Write-Back:** Writes data only to the cache line and sets a **Dirty Bit**. Memory is updated only when the line is evicted.

---

## 📁 File Summary

| File Name | Key Concept / Description |
| :--- | :--- |
| `direct_mapped_cache.sv` | Single-line mapping cache architecture. |
| `2way_associative_cache.sv` | 2-way set associative cache with tag comparator and way-selection multiplexers. |
| `write_policies_cache.sv` | Implementation logic for Write-Through vs. Write-Back state machines. |

---

## 🎓 Learning Value
Studying these modules independently helps clarify:
- How **Tag**, **Index**, and **Offset** bits are extracted from a 32-bit memory address.
- How finite state machines (FSM) handle `IDLE`, `COMPARE_TAG`, `ALLOCATE`, and `WRITE_BACK` states.
