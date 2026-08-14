.section .text
.globl _start

_start:
    la sp, __stack_top
    call main
    j _exit

_exit:
    li a0, 0x40000000
    li a1, 0xCAFE
    sw a1, 0(a0)
    j _exit
