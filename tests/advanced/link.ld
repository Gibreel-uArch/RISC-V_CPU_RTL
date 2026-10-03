/* Custom linker script for the SoC:
 *   ITCM (Instruction Tightly Coupled Memory) : 64 KiB, read/execute
 *   DTCM (Data Tightly Coupled Memory)        : 64 KiB, read/write
 *   MMIO region at 0x40000000 for pass/fail signalling.
 *   MMIO + 4 holds diagnostic word.
 */
ENTRY(_start)

MEMORY
{
    ITCM (rx)  : ORIGIN = 0x00000000, LENGTH = 64K
    DTCM (rw)  : ORIGIN = 0x00010000, LENGTH = 64K
}

SECTIONS
{
    .text : {
        *(.text.start)      /* keep _start at ITCM base */
        *(.text.trap)       /* trap vector stays near base */
        *(.text*)
    } > ITCM

    .rodata : { *(.rodata*) } > ITCM

    .data : {
        __data_start = .;
        *(.data*)
        __data_end = .;
    } > DTCM

    .bss : {
        __bss_start = .;
        *(.bss*) *(COMMON)
        __bss_end = .;
    } > DTCM

    /* Stack grows downward from top of DTCM (0x00020000) */
    __stack_top   = ORIGIN(DTCM) + LENGTH(DTCM);
    __stack_guard = ORIGIN(DTCM) + LENGTH(DTCM) - 32;

    /* MMIO base used to report PASS/FAIL to the SoC testbench */
    __mmio_base = 0x40000000;
}
