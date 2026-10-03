.text
.globl _start

_start:

# ---------- (1) Load Values ----------
addi x1, x0, 5        # x1 = 5
addi x2, x0, 3        # x2 = 3

# ---------- (2) Addition ----------
add  x3, x1, x2        # x3 = x1 + x2 = 8

# ---------- (3) Store to Memory ----------
sw   x3, 0(x0)        # Memory[0] = x3 = 8

# ---------- (4) Load from Memory ----------
lw   x4, 0(x0)        # x4 = Memory[0] = 8

# ---------- (5) Check: Is x3 == x4? ----------
beq  x3, x4, pass     # If equal -> go to pass
beq  x0, x0, fail     # Else -> go to fail

# ---------- (6) Result ----------
pass:
    addi x31, x0, 1    # FLAG = 1  (Success)
    beq  x0, x0, end   # Jump to end

fail:
    addi x31, x0, 0    # FLAG = 0  (Failure)

end:
    beq  x0, x0, end   # Infinite loop (End of program)
