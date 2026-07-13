

addi x2, x0, 32
lw   x1, 32(x2)
addi x2, x0, 4
addi x3, x0, 6
add  x3, x3, x2
beq  x3, x1, -4
beq  x3, x2, -4
sw   x3, 8(x2)
lw   x3, 8(x2)
