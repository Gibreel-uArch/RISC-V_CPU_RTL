# ==========================================
# RISC-V Assembly - Test Program
# ==========================================

start:
    addi t0, zero, 2            # t0 = 2
    addi t1, zero, 3            # t1 = 3
    addi t2, zero, 5            # t2 = 5
    nop
    nop
    nop
    add  t3, t0, t1             # t3 = 2 + 3 = 5
    nop
    nop
    nop
    addi t4, zero, 0x100        # t4 = 0x100 
    nop
    nop
    nop
    sw   t3, 0(t4)              # store t3 (5) at 0x100
    nop
    lw   t5, 0(t4)              # t5 = mem[0x100] = 5
    nop
    nop
    nop
    beq  t5, t2, success        # if t5 == t2 (5 == 5) -> success
    nop

    # ---------- Failure path ----------
    li t6, 0x40000000   # t6 = 0x40000000
    nop
    nop
    nop
    lui  t0, 0xE                # t0 = 0x0000E000
    nop
    nop
    nop
    addi  t0, t0, -0x135        # t0 = 0x0000DEAD
    nop 
    nop
    nop
    sw   t0, 0(t6)              # mem[0x40000000] = 0x0000DEAD
    nop
    j    end
    nop

success:
    # ---------- Success path ----------
    li t6, 0x40000000   # t6 = 0x40000000
    nop
    nop
    nop
    lui  t0, 0x5                # t0 = 0x00005000
    nop
    nop
    nop
    ori  t0, t0, 0x555          # t0 = 0x00005555
    nop
    nop
    nop
    sw   t0, 0(t6)              # mem[0x40000000] = 0x00005555
    nop
    j    end
    nop

end:
    j    end                  
    nop
