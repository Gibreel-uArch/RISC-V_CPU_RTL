/* ============================================================================
 * _start: C runtime entry point.
 *   1. Install trap vector (mtvec).
 *   2. Set up stack pointer from linker symbol.
 *   3. Zero BSS.
 *   4. Call main(); never returns.
 * ============================================================================
 */

    .section .text.start, "ax", @progbits
    .globl _start
    .type  _start, @function

_start:
    /* Install trap vector BEFORE touching the stack in case of early faults. */
    la      t0, _trap_handler
    csrw    mtvec, t0

    /* Initialize the stack pointer to top of DTCM. */
    la      sp, __stack_top

    /* Clear the global pointer (no small-data relaxation). */
    li      gp, 0

    /* Zero the BSS section so uninitialized globals are deterministic. */
    la      t0, __bss_start
    la      t1, __bss_end
1:
    bgeu    t0, t1, 2f
    sw      zero, 0(t0)
    addi    t0, t0, 4
    j       1b
2:

    /* Run the self-test suite. */
    call    main

    /* main() must never return. If it does, treat it as failure. */
    j       _fail_trap

/* ---------------------------------------------------------------------------
 * _pass: write 0x5555 to MMIO base to signal SUCCESS to the SoC.
 * ------------------------------------------------------------------------- */
    .globl _pass
_pass:
    li      t0, 0x40000000
    li      t1, 0x5555
    sw      t1, 0(t0)
1:
    j       1b                  /* spin forever */

/* ---------------------------------------------------------------------------
 * _fail_trap: write 0xDEAD to MMIO base to signal FAILURE to the SoC.
 * ------------------------------------------------------------------------- */
    .globl _fail_trap
_fail_trap:
    li      t0, 0x40000000
    li      t1, 0xDEAD
    sw      t1, 0(t0)
1:
    j       1b                  /* spin forever */
