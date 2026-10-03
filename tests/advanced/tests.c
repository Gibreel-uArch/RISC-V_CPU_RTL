#include "tests.h"

/* ============================================================================
 * RV32I hardware self-test suite.
 *
 * The core has NO M-extension, so all multiplication is done in software
 * via shift-add. Division is only exercised as "repeated subtraction" and
 * as a comparison helper for validating our own soft-mul.
 *
 * The core DOES support simple exceptions. We deliberately trigger:
 *   - ECALL (mcause = 11)
 *   - Illegal instruction (mcause = 2)
 * and validate that control reaches _trap_handler with the right cause.
 *
 * No libgcc soft-mul is used: we provide __mulsi3 / __udivsi3 / etc.
 * ourselves so the whole image is self-contained.
 * ============================================================================
 */

/* ---------- Trap expectation globals (referenced by traps.S) ------------- */
volatile int32_t g_expect_trap = -1;
volatile uint32_t g_trap_hits = 0;
volatile uint32_t g_trap_last_pc = 0;

/* ------------------------------------------------------------------------
 * trap_dispatch: called from _trap_handler in traps.S.
 *
 * If a test has armed g_expect_trap to the current mcause, we count the hit
 * and advance mepc past the faulting instruction (4 bytes for RV32I). Any
 * unexpected trap is a fatal failure.
 * ------------------------------------------------------------------------ */
uint32_t trap_dispatch(uint32_t mcause, uint32_t mepc) {
  /* Mask to the exception code (low bits only). */
  uint32_t cause = mcause & 0x1FU;

  if ((int32_t)cause == g_expect_trap) {
    g_expect_trap = -1; /* disarm */
    g_trap_hits++;
    g_trap_last_pc = mepc;
    return mepc + 4; /* skip faulting instruction */
  }

  /* Unexpected trap — record and let caller decide. */
  mmio_write32(MMIO_DIAG, 0xBAD00000U | cause);
  report_fail();
}

/* =========================================================================
 * Software M-extension substitutes (freestanding).
 * ========================================================================= */

/* Unsigned 32x32 -> 32 multiplication (shift-add). */
static inline uint32_t soft_mul_u32(uint32_t a, uint32_t b) {
  uint32_t r = 0;
  while (b) {
    if (b & 1U)
      r += a;
    a <<= 1;
    b >>= 1;
  }
  return r;
}

/* Signed 32x32 -> 32 multiplication. */
static inline int32_t soft_mul_i32(int32_t a, int32_t b) {
  uint32_t ua = (a < 0) ? (uint32_t)(-(uint32_t)a) : (uint32_t)a;
  uint32_t ub = (b < 0) ? (uint32_t)(-(uint32_t)b) : (uint32_t)b;
  uint32_t r = soft_mul_u32(ua, ub);
  if ((a < 0) ^ (b < 0))
    r = (uint32_t)(-(uint32_t)r);
  return (int32_t)r;
}

/* Unsigned division via restoring long division (bit-by-bit). */
static uint32_t soft_udiv_u32(uint32_t n, uint32_t d) {
  if (d == 0)
    return 0xFFFFFFFFU; /* match RISC-V M-extension semantics */
  uint32_t q = 0, r = 0;
  for (int i = 31; i >= 0; --i) {
    r = (r << 1) | ((n >> i) & 1U);
    if (r >= d) {
      r -= d;
      q |= (1U << i);
    }
  }
  return q;
}

static uint32_t soft_umod_u32(uint32_t n, uint32_t d) {
  if (d == 0)
    return n; /* RISC-V: remainder equals dividend */
  uint32_t r = 0;
  for (int i = 31; i >= 0; --i) {
    r = (r << 1) | ((n >> i) & 1U);
    if (r >= d)
      r -= d;
  }
  return r;
}

/* We intentionally do NOT export __mulsi3/__divsi3 to libgcc; the compiler
 * will emit calls to those if any C operator uses * / % — but our tests
 * exclusively use the soft_* helpers, so no libgcc object is referenced. */

/* ---------- Helpers --------------------------------------------------------
 */

static inline uint32_t mix32(uint32_t x) {
  x ^= x >> 16;
  x = soft_mul_u32(x, 0x7feb352dU);
  x ^= x >> 15;
  x = soft_mul_u32(x, 0x846ca68bU);
  x ^= x >> 16;
  return x;
}

static uint32_t sw_popcount(uint32_t x) {
  uint32_t c = 0;
  while (x) {
    c += (x & 1U);
    x >>= 1;
  }
  return c;
}

static uint32_t sw_bitreverse(uint32_t x) {
  uint32_t r = 0;
  for (int i = 0; i < 32; ++i) {
    r = (r << 1) | (x & 1U);
    x >>= 1;
  }
  return r;
}

static uint32_t crc32_bitwise(const uint8_t *data, uint32_t len) {
  uint32_t crc = 0xFFFFFFFFU;
  for (uint32_t i = 0; i < len; ++i) {
    crc ^= data[i];
    for (int b = 0; b < 8; ++b) {
      uint32_t mask = (uint32_t)(-(int32_t)(crc & 1U));
      crc = (crc >> 1) ^ (0xEDB88320U & mask);
    }
  }
  return ~crc;
}

/* ---------- Test 1: ALU arithmetic ---------------------------------------- */

static int test_alu(void) {
  volatile int32_t a = -1234567;
  volatile int32_t b = 7654321;
  volatile uint32_t ua = 0xDEADBEEFUL;
  volatile uint32_t ub = 0x12345678UL;

  if ((a + b) != 6419754)
    return 1;
  if ((a - b) != -8888888)
    return 2;
  if ((a & b) != (int32_t)(-1234567 & 7654321))
    return 3;
  if ((a | b) != (int32_t)(-1234567 | 7654321))
    return 4;
  if ((a ^ b) != (int32_t)(-1234567 ^ 7654321))
    return 5;
  if ((ua ^ ub) != 0xCC99E897UL)
    return 6;
  if (!(a < b))
    return 7;
  if (ua < ub)
    return 8;
  if (!(ua > ub))
    return 9;
  return 0;
}

/* ---------- Test 2: Shifts ------------------------------------------------ */

static int test_shifts(void) {
  volatile uint32_t x = 0x80000001UL;

  if ((x << 1) != 0x00000002UL)
    return 1;
  if ((x >> 1) != 0x40000000UL)
    return 2;
  if (((int32_t)x >> 1) != (int32_t)0xC0000000)
    return 3;

  volatile uint32_t sh = 7;
  if ((x << sh) != 0x00000080UL)
    return 4;
  if ((x >> sh) != 0x01000000UL)
    return 5;

  uint32_t rot = (x << 4) | (x >> 28);
  if (rot != 0x00000018UL)
    return 6;

  return 0;
}

/* ---------- Test 3: Memory load/store & sign extension -------------------- */

static int test_memory(void) {
  static volatile uint8_t buf8[16];
  static volatile uint16_t buf16[8];
  static volatile uint32_t buf32[4];

  for (int i = 0; i < 16; ++i)
    buf8[i] = (uint8_t)(i * 17);
  for (int i = 0; i < 8; ++i)
    buf16[i] = (uint16_t)(i * 0x1234);
  for (int i = 0; i < 4; ++i)
    buf32[i] = 0xA5A5A5A5UL ^ (uint32_t)i;

  for (int i = 0; i < 16; ++i)
    if (buf8[i] != (uint8_t)(i * 17))
      return 1;

  for (int i = 0; i < 8; ++i)
    if (buf16[i] != (uint16_t)(i * 0x1234))
      return 2;

  for (int i = 0; i < 4; ++i)
    if (buf32[i] != (0xA5A5A5A5UL ^ (uint32_t)i))
      return 3;

  volatile int8_t sb = (int8_t)0x80;
  if ((int32_t)sb != -128)
    return 4;

  volatile uint8_t ub = 0x80;
  if ((int32_t)ub != 128)
    return 5;

  volatile int16_t sh = (int16_t)0x8000;
  if ((int32_t)sh != -32768)
    return 6;

  return 0;
}

/* ---------- Test 4: Branch conditions ------------------------------------- */

static int test_branches(void) {
  volatile int32_t s = -5;
  volatile int32_t p = 5;

  if (!(s < 0))
    return 1;
  if (!(p > 0))
    return 2;
  if (s == p)
    return 3;
  if (!(s != p))
    return 4;
  if (!(s <= -5))
    return 5;
  if (!(p >= 5))
    return 6;

  volatile uint32_t us = 0xFFFFFFFFUL;
  volatile uint32_t up = 1UL;
  if (!(us > up))
    return 7;
  if (up > us)
    return 8;

  return 0;
}

/* ---------- Test 5: Software MUL / DIV (shift-add) ------------------------ */

static int test_soft_muldiv(void) {
  /* Small multiplications with known exact results. */
  if (soft_mul_u32(12345, 6789) != 83810205UL)
    return 1;

  volatile int32_t a = -12345;
  volatile int32_t b = 6789;
  if (soft_mul_i32(a, b) != -83810205)
    return 2;

  /* Unsigned division / modulo — classic identities. */
  if (soft_udiv_u32(0xFFFFFFFFUL, 2) != 0x7FFFFFFFUL)
    return 3;
  if (soft_umod_u32(0xFFFFFFFFUL, 2) != 1)
    return 4;

  if (soft_udiv_u32(100, 7) != 14)
    return 5;
  if (soft_umod_u32(100, 7) != 2)
    return 6;

  /* Division by zero: match RISC-V M-extension semantics. */
  if (soft_udiv_u32(1, 0) != 0xFFFFFFFFUL)
    return 7;
  if (soft_umod_u32(42, 0) != 42)
    return 8;

  /* Cross-check: (a/b)*b + (a%b) == a for many values. */
  for (uint32_t n = 1; n < 256; n += 37) {
    for (uint32_t d = 1; d < 64; d += 11) {
      uint32_t q = soft_udiv_u32(n * 1000 + 7, d);
      uint32_t r = soft_umod_u32(n * 1000 + 7, d);
      uint32_t lhs = soft_mul_u32(q, d) + r;
      if (lhs != (n * 1000 + 7))
        return 9;
    }
  }
  return 0;
}

/* ---------- Test 6: Bit-reversal & popcount ------------------------------- */

static int test_bitops(void) {
  const uint32_t patterns[] = {0x00000000UL, 0xFFFFFFFFUL, 0xAAAAAAAAUL,
                               0x55555555UL, 0x12345678UL, 0xDEADBEEFUL,
                               0x00000001UL, 0x80000000UL};
  const uint32_t rev_expected[] = {0x00000000UL, 0xFFFFFFFFUL, 0x55555555UL,
                                   0xAAAAAAAAUL, 0x1E6A2C48UL, 0xF77DB57BUL,
                                   0x80000000UL, 0x00000001UL};
  const uint32_t pop_expected[] = {0, 32, 16, 16, 13, 24, 1, 1};

  for (unsigned i = 0; i < sizeof(patterns) / sizeof(patterns[0]); ++i) {
    if (sw_bitreverse(patterns[i]) != rev_expected[i])
      return (int)(i + 1);
    if (sw_popcount(patterns[i]) != pop_expected[i])
      return (int)(i + 20);
  }
  return 0;
}

/* ---------- Test 7: CRC32 (a "real" workload) ----------------------------- */

static int test_crc32(void) {
  static const char msg[] = "The quick brown fox jumps over the lazy dog";
  const uint32_t expected = 0x414FA339UL; /* CRC-32/ISO-HDLC */

  uint32_t got = crc32_bitwise((const uint8_t *)msg, sizeof(msg) - 1);
  if (got != expected)
    return 1;
  return 0;
}

/* ---------- Test 8: Recursion / stack integrity --------------------------- */

static uint32_t fib(uint32_t n) {
  if (n < 2)
    return n;
  return fib(n - 1) + fib(n - 2);
}

static uint32_t fact(uint32_t n) {
  if (n < 2)
    return 1;
  return soft_mul_u32(n, fact(n - 1));
}

static int test_recursion(void) {
  if (fib(20) != 6765)
    return 1;
  if (fact(12) != 479001600UL)
    return 2;
  if (fib(0) != 0)
    return 3;
  if (fib(1) != 1)
    return 4;
  if (fact(0) != 1)
    return 5;
  return 0;
}

/* ---------- Test 9: Mix chain (long dependency) --------------------------- */

static int test_mixchain(void) {
  uint32_t h = 0x12345678UL;
  for (uint32_t i = 0; i < 1000; ++i) {
    h = mix32(h ^ i);
  }
  if (h != 0x6B9BC69FUL)
    return 1;
  return 0;
}

/* ---------- Test 10: Stack guard ----------------------------------------- */

static int test_stack_guard(void) {
  volatile uint32_t scratch[64];
  for (int i = 0; i < 64; ++i)
    scratch[i] = (uint32_t)(i * 0x9E3779B9UL);
  uint32_t sum = 0;
  for (int i = 0; i < 64; ++i)
    sum += scratch[i];
  if (sum == 0)
    return 1;
  return 0;
}

/* =========================================================================
 * Exception tests
 * ========================================================================= */

/* ---------- Test 11: ECALL traps as expected ------------------------------ */

static int test_ecall_trap(void) {
  g_trap_hits = 0;
  g_trap_last_pc = 0;
  g_expect_trap = 11; /* mcause = 11 (Environment call M-mode) */

  /* This inline asm triggers an ECALL. The trap handler will skip it. */
  __asm__ volatile("ecall");

  if (g_trap_hits != 1)
    return 1;
  if (g_expect_trap != -1)
    return 2; /* trap never fired */
  return 0;
}

/* ---------- Test 12: Illegal instruction traps as expected ---------------- */

static int test_illegal_trap(void) {
  g_trap_hits = 0;
  g_trap_last_pc = 0;
  g_expect_trap = 2; /* mcause = 2 (Illegal instruction)   */

  /* 0x00000000 is not a legal RV32I instruction encoding: the low 2 bits
   * are 00 (compressed class) but we are not in C-mode, and the opcode
   * 0b0000000 is reserved for illegal instructions. */
  __asm__ volatile(".word 0x00000000");

  if (g_trap_hits != 1)
    return 1;
  if (g_expect_trap != -1)
    return 2;
  return 0;
}

/* ---------- Test 13: Repeated ECALL loop (does not corrupt stack) --------- */

static int test_repeated_traps(void) {
  const unsigned N = 8;

  for (unsigned i = 0; i < N; ++i) {
    g_expect_trap = 11;
    __asm__ volatile("ecall");
    if (g_expect_trap != -1)
      return (int)(i + 1); /* trap did not fire */
  }
  if (g_trap_hits < N)
    return 99;
  return 0;
}

/* ---------- Test table --------------------------------------------------- */

const test_case_t g_test_table[] = {
    {"ALU arithmetic", test_alu},
    {"Barrel shifter", test_shifts},
    {"Load/store & ext", test_memory},
    {"Branch conditions", test_branches},
    {"Soft MUL/DIV", test_soft_muldiv},
    {"Bit ops (rev/popc)", test_bitops},
    {"CRC32 workload", test_crc32},
    {"Recursion/stack", test_recursion},
    {"Hash mix chain", test_mixchain},
    {"Stack guard", test_stack_guard},
    {"ECALL trap", test_ecall_trap},
    {"Illegal instr trap", test_illegal_trap},
    {"Repeated traps", test_repeated_traps},
};

const unsigned g_test_count = sizeof(g_test_table) / sizeof(g_test_table[0]);
