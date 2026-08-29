OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
    IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 0x2000
    DMEM (rw)  : ORIGIN = 0x00002000, LENGTH = 0x1FFC  
}

SECTIONS
{
    .text : {
        *(.text)
        *(.text.*)
    } > IMEM

    .rodata : {
        *(.rodata)
        *(.rodata.*)
    } > IMEM

    .data : {
        *(.data)
        *(.data.*)
    } > DMEM

    .bss : {
        *(.bss)
        *(.bss.*)
    } > DMEM

    . = 0x00003FFC;
    stack_top = .;
}
