CROSS   = riscv32-unknown-elf-
CC      = $(CROSS)gcc
OBJCOPY = $(CROSS)objcopy

# RV32I only — no M, no A, no C.
CFLAGS  = -march=rv32i_zicsr -mabi=ilp32 \
          -Os -ffreestanding -fno-builtin -fno-stack-protector \
          -fno-common -Wall -Wextra -Werror \
          -nostdlib -nostartfiles -ffunction-sections -fdata-sections \
          -mno-relax

# Provide softmul stubs so the linker never pulls in libgcc's __mulsi3.
LDFLAGS = -T link.ld -nostdlib -Wl,--gc-sections -Wl,-Map=fw.map

all: fw.elf fw.hex fw.bin

fw.elf: start.S traps.S main.c tests.c libc_stubs.c link.ld
	$(CC) $(CFLAGS) $(LDFLAGS) start.S traps.S main.c tests.c libc_stubs.c -o $@

fw.bin: fw.elf ; $(OBJCOPY) -O binary $< $@
fw.hex: fw.elf ; $(OBJCOPY) -O verilog --verilog-data-width=4 $< $@

clean:
	rm -f fw.elf fw.bin fw.hex fw.map

.PHONY: all clean
