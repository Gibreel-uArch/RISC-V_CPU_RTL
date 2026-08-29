ENTRY(_start)

MEMORY
{
    ITCM (rx)  : ORIGIN = 0x00000000, LENGTH = 64K
    DTCM (rw)  : ORIGIN = 0x00010000, LENGTH = 64K
}

SECTIONS
{
    .text : { *(.text*) } > ITCM
    .rodata : { *(.rodata*) } > ITCM
    .data : { *(.data*) } > DTCM
    .bss : { *(.bss*) } > DTCM
    __stack_top = ORIGIN(DTCM) + LENGTH(DTCM); /* 0x00020000 */
}
