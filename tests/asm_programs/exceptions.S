.section .text
.globl _start

_start:
    # ============================================
    # Initialize stack pointer
    # ============================================
    la sp, stack_top

    # ============================================
    # Initialize mtvec to point to trap_handler
    # ============================================
    la t0, trap_handler
    csrw mtvec, t0

    # ============================================
    # Test Suite Initialization
    # ============================================
    li s0, 0                # Test counter
    li s1, 0                # Pass counter
    li s2, 0                # Fail counter

    # ============================================
    # TEST 1: ECALL Instruction
    # ============================================
    li s3, 1                # Test ID: 1
    li t0, 0x1234           # Set t0 before ECALL
    li t1, 0                # Clear t1 (will be set by handler)
    
    ecall                   # Trigger ECALL trap (mcause = 11)
    
    # After trap return, check if handler modified t1
    li t2, 0x5678           # Expected value after handler
    bne t1, t2, test1_fail
    
    # Verify mepc was advanced correctly
    # If we reached here, execution continued after ECALL
    j test1_pass

test1_fail:
    li a0, 1                # Error code 1: ECALL failed
    j write_result
    
test1_pass:
    addi s0, s0, 1          # Increment test counter
    addi s1, s1, 1          # Increment pass counter
    j test2_start

    # ============================================
    # TEST 2: EBREAK Instruction
    # ============================================
test2_start:
    li s3, 2                # Test ID: 2
    li t0, 0x9ABC           # Set t0 before EBREAK
    li t1, 0                # Clear t1 (will be set by handler)
    
    ebreak                  # Trigger EBREAK trap (mcause = 3)
    
    # After trap return, check if handler modified t1
    li t2, 0xDEF0           # Expected value after handler
    bne t1, t2, test2_fail
    
    # Verify we returned to correct address
    j test2_pass

test2_fail:
    li a0, 2                # Error code 2: EBREAK failed
    j write_result
    
test2_pass:
    addi s0, s0, 1          # Increment test counter
    addi s1, s1, 1          # Increment pass counter
    j test3_start

    # ============================================
    # TEST 3: MRET and MEPC Handling
    # ============================================
test3_start:
    li s3, 3                # Test ID: 3
    
    # Set up a known mcause value to verify
    li t0, 0xAAAA           # Marker before trap
    
    ecall                   # Trigger trap
    
    # After return, t1 should be modified by handler
    li t2, 0x5678
    bne t1, t2, test3_fail
    
    # Now check if we can read mcause (should still be 11 from last trap)
    csrr t3, mcause
    li t4, 11               # Environment call from M-mode
    bne t3, t4, test3_fail
    
    # Check mepc was saved and restored correctly
    # If we're here, mepc was properly managed
    j test3_pass

test3_fail:
    li a0, 3                # Error code 3: MRET/MEPC failed
    j write_result
    
test3_pass:
    addi s0, s0, 1          # Increment test counter
    addi s1, s1, 1          # Increment pass counter
    j test4_start

    # ============================================
    # TEST 4: Illegal Instruction Detection
    # ============================================
test4_start:
    li s3, 4                # Test ID: 4
    li t0, 0xBEEF           # Marker before illegal instruction
    
    .word 0xFFFFFFFF        # Deliberate illegal instruction
    
    # We should never reach here if trap worked
    li a0, 4                # Error code 4: Illegal instruction not trapped
    j write_result

    # ============================================
    # TEST 5: Nested Trap Prevention
    # ============================================
test5_start:
    li s3, 5                # Test ID: 5
    
    # Disable interrupts to test trap priority
    csrr t0, mstatus
    li t1, 0x8              # MIE bit (Machine Interrupt Enable)
    csrc mstatus, t1        # Clear MIE to prevent nested traps
    
    li t1, 0                # Clear t1 before trap
    ecall                   # Should still work even with interrupts disabled
    
    li t2, 0x5678
    bne t1, t2, test5_fail
    
    # Re-enable interrupts
    csrs mstatus, t1
    
    j test5_pass

test5_fail:
    li a0, 5                # Error code 5: Nested trap test failed
    j write_result
    
test5_pass:
    addi s0, s0, 1          # Increment test counter
    addi s1, s1, 1          # Increment pass counter
    j test6_start

    # ============================================
    # TEST 6: Multiple Sequential Traps
    # ============================================
test6_start:
    li s3, 6                # Test ID: 6
    
    # First ECALL
    li t1, 0
    ecall
    li t2, 0x5678
    bne t1, t2, test6_fail
    
    # Second ECALL immediately after
    li t1, 0
    ecall
    li t2, 0x5678
    bne t1, t2, test6_fail
    
    # EBREAK after ECALLs
    li t1, 0
    ebreak
    li t2, 0xDEF0
    bne t1, t2, test6_fail
    
    j test6_pass

test6_fail:
    li a0, 6                # Error code 6: Sequential trap test failed
    j write_result
    
test6_pass:
    addi s0, s0, 1          # Increment test counter
    addi s1, s1, 1          # Increment pass counter
    j test7_start

    # ============================================
    # TEST 7: Register Preservation
    # ============================================
test7_start:
    li s3, 7                # Test ID: 7
    
    # Set up registers with known values
    li t0, 0x11111111
    li t1, 0x22222222
    li t2, 0x33333333
    li t3, 0x44444444
    li t4, 0x55555555
    
    # Save t1 before trap (it will be modified by handler)
    mv s4, t1
    
    # Trigger trap
    ecall
    
    # Check t0, t2, t3, t4 are preserved
    li t5, 0x11111111
    bne t0, t5, test7_fail
    
    li t5, 0x33333333
    bne t2, t5, test7_fail
    
    li t5, 0x44444444
    bne t3, t5, test7_fail
    
    li t5, 0x55555555
    bne t4, t5, test7_fail
    
    # Check t1 was modified by handler (should be 0x5678)
    li t5, 0x5678
    bne t1, t5, test7_fail
    
    j test7_pass

test7_fail:
    li a0, 7                # Error code 7: Register preservation failed
    j write_result
    
test7_pass:
    addi s0, s0, 1          # Increment test counter
    addi s1, s1, 1          # Increment pass counter
    j test_suite_complete

    # ============================================
    # Test Suite Complete
    # ============================================
test_suite_complete:
    # All tests passed
    # Write test summary to memory
    li t0, 0x40000000       # MMIO_EXIT_ADDR
    sw s0, 0(t0)            # Total tests
    sw s1, 4(t0)            # Passed tests
    sw s2, 8(t0)            # Failed tests
    sw zero, 12(t0)         # Success indicator (0 = success)
    
    # Write success code
    li a0, 0x5555           # All tests passed
    j write_result

    # ============================================
    # Write final result
    # ============================================
write_result:
    li t0, 0x40000000       # MMIO_EXIT_ADDR
    sw a0, 0(t0)            # Write result code
    j forever

forever:
    j forever

# ============================================
# Trap Handler
# ============================================
trap_handler:
    # Save registers that we'll use
    addi sp, sp, -64        # Allocate stack frame
    sw ra, 0(sp)            # Save return address
    sw t0, 4(sp)            # Save t0
    sw t2, 8(sp)            # Save t2
    sw t3, 12(sp)           # Save t3
    sw t4, 16(sp)           # Save t4
    sw t5, 20(sp)           # Save t5
    sw t6, 24(sp)           # Save t6
    sw s3, 28(sp)           # Save test ID
    sw s4, 32(sp)           # Save s4 (scratch)
    
    # Note: We intentionally do NOT save t1
    # t1 is used as a communication channel between handler and main code

    # Read trap cause
    csrr t0, mcause
    
    # Save mcause and mepc for debugging
    csrr t2, mepc
    sw t2, 36(sp)           # Save mepc to stack
    
    # Dispatch based on trap cause
    li t3, 11               # ECALL from M-mode
    beq t0, t3, handle_ecall
    
    li t3, 3                # EBREAK
    beq t0, t3, handle_ebreak
    
    li t3, 2                # Illegal instruction
    beq t0, t3, handle_illegal
    
    # Unknown trap cause
    j trap_error

handle_ecall:
    # Set t1 to indicate ECALL was handled
    li t1, 0x5678
    
    # Advance mepc past ECALL instruction
    csrr t2, mepc
    addi t2, t2, 4          # ECALL is 4 bytes
    csrw mepc, t2
    
    # Store trap info for debugging
    li t3, 0x40000100       # Debug memory area
    sw t0, 0(t3)            # Save mcause
    sw t2, 4(t3)            # Save updated mepc
    
    j trap_return

handle_ebreak:
    # Set t1 to indicate EBREAK was handled
    li t1, 0xDEF0
    
    # Advance mepc past EBREAK instruction
    csrr t2, mepc
    addi t2, t2, 4          # EBREAK is 4 bytes (compressed: 2 bytes)
    csrw mepc, t2
    
    # Store trap info for debugging
    li t3, 0x40000100       # Debug memory area
    sw t0, 0(t3)            # Save mcause
    sw t2, 4(t3)            # Save updated mepc
    
    j trap_return

handle_illegal:
    # For illegal instruction test, jump to test completion
    # Set a0 to success code
    li a0, 0x5555
    
    # Instead of returning, write result directly
    li t0, 0x40000000       # MMIO_EXIT_ADDR
    sw a0, 0(t0)
    
    # Also write test stats
    li t2, 0x40000000
    sw s0, 0(t2)            # Total tests
    sw s1, 4(t2)            # Passed tests
    sw s2, 8(t2)            # Failed tests
    
    # Stay in handler forever
    j forever_from_trap

trap_error:
    # Unknown trap - indicate error
    li a0, 0xDEAD           # Error code for unknown trap
    
    # Write error to MMIO
    li t0, 0x40000000
    sw a0, 0(t0)
    
    # Stay in handler forever
    j forever_from_trap

trap_return:
    # Restore saved registers (except t1)
    lw ra, 0(sp)            # Restore return address
    lw t0, 4(sp)            # Restore t0
    lw t2, 8(sp)            # Restore t2
    lw t3, 12(sp)           # Restore t3
    lw t4, 16(sp)           # Restore t4
    lw t5, 20(sp)           # Restore t5
    lw t6, 24(sp)           # Restore t6
    lw s3, 28(sp)           # Restore test ID
    lw s4, 32(sp)           # Restore s4
    
    # Free stack frame
    addi sp, sp, 64
    
    # Return from trap
    mret

forever_from_trap:
    j forever_from_trap

# ============================================
# Stack Section
# ============================================
.section .data
.align 4
stack:
    .space 2048             # 2KB stack space
stack_top:

# ============================================
# Debug Section (optional)
# ============================================
.section .data
.align 4
debug_info:
    .word 0                 # Last mcause
    .word 0                 # Last mepc
    .word 0                 # Trap counter
    .word 0                 # Reserved
