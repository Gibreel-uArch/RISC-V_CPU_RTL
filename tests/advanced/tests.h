#ifndef TESTS_H
#define TESTS_H

#include <stdint.h>

#define MMIO_BASE 0x40000000UL
#define MMIO_PASS_VALUE 0x5555U
#define MMIO_FAIL_VALUE 0xDEADU
#define MMIO_DIAG (MMIO_BASE + 4)

static inline void mmio_write32(uint32_t addr, uint32_t val) {
  *(volatile uint32_t *)addr = val;
}

/* NOTE: no 'inline' here — it would conflict with 'noinline'. */
__attribute__((noreturn, noinline, unused)) static void report_pass(void) {
  mmio_write32(MMIO_BASE, MMIO_PASS_VALUE);
  for (;;) {
    __asm__ volatile("nop");
  }
}

__attribute__((noreturn, noinline, unused)) static void report_fail(void) {
  mmio_write32(MMIO_BASE, MMIO_FAIL_VALUE);
  for (;;) {
    __asm__ volatile("nop");
  }
}

extern volatile int32_t g_expect_trap;
extern volatile uint32_t g_trap_hits;
extern volatile uint32_t g_trap_last_pc;

uint32_t trap_dispatch(uint32_t mcause, uint32_t mepc);

typedef int (*test_fn_t)(void);
typedef struct {
  const char *name;
  test_fn_t fn;
} test_case_t;

extern const test_case_t g_test_table[];
extern const unsigned g_test_count;

#endif
