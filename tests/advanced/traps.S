/* ============================================================================
 * Trap entry: this is the RV32I trap vector.
 *
 * Only the low 2 bits of mcause are meaningful to this firmware; the
 * exception code for an illegal instruction is 2, for ecall from M-mode is
 * 11, for load misaligned is 4, store misaligned is 6, instruction
 * misaligned is 0. We decode mcause[3:0] in software (C).
 *
 * Register save/restore is minimal — we only need to preserve what the C
 * dispatcher clobbers plus the faulting PC.
 * ============================================================================
 */

    .section .text.trap, "ax", @progbits
    .globl _trap_handler
    .type  _trap_handler, @function

_trap_handler:
    /* Save caller-saved registers we may clobber. */
    addi    sp, sp, -64
    sw      ra,  0(sp)
    sw      t0,  4(sp)
    sw      t1,  8(sp)
    sw      t2, 12(sp)
    sw      a0, 16(sp)
    sw      a1, 20(sp)
    sw      a2, 24(sp)
    sw      a3, 28(sp)
    sw      a4, 32(sp)
    sw      a5, 36(sp)
    sw      a6, 40(sp)
    sw      a7, 44(sp)

    /* Read mcause and mepc; pass them to the C dispatcher. */
    csrr    a0, mcause
    csrr    a1, mepc
    call    trap_dispatch          /* returns new PC in a0 */

    /* Update mepc so MRET resumes at the returned PC. */
    csrw    mepc, a0

    /* Restore caller-saved registers. */
    lw      ra,  0(sp)
    lw      t0,  4(sp)
    lw      t1,  8(sp)
    lw      t2, 12(sp)
    lw      a0, 16(sp)
    lw      a1, 20(sp)
    lw      a2, 24(sp)
    lw      a3, 28(sp)
    lw      a4, 32(sp)
    lw      a5, 36(sp)
    lw      a6, 40(sp)
    lw      a7, 44(sp)
    addi    sp, sp, 64

    mret
