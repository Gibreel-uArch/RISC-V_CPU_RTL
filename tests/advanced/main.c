#include "tests.h"

/* ============================================================================
 * main(): run every entry in the test table.
 *
 *   - All pass  -> 0x5555 at 0x40000000
 *   - Any fail  -> 0xDEAD at 0x40000000
 *   - Diagnostic word at 0x40000004: (test_idx << 16) | rc
 * ============================================================================
 */
int main(void) {
  mmio_write32(MMIO_DIAG, 0);

  for (unsigned i = 0; i < g_test_count; ++i) {
    test_fn_t fn = g_test_table[i].fn;
    int rc = fn();
    if (rc != 0) {
      mmio_write32(MMIO_DIAG, ((uint32_t)i << 16) | ((uint32_t)rc & 0xFFFFU));
      report_fail();
    }
  }

  report_pass();
}
