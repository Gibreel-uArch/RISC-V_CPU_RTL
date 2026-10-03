CC      = riscv32-unknown-elf-gcc
OBJCOPY = riscv32-unknown-elf-objcopy
OBJDUMP = riscv32-unknown-elf-objdump
CFLAGS  = -march=rv32i_zicsr -mabi=ilp32 -O0 -nostdlib
LDFLAGS = -T link.ld

ifndef NAME
$(error Usage : make NAME=main)
endif

all: clean_temp $(NAME).hex $(NAME).txt clean

$(NAME).elf: $(NAME).S
	$(CC) $(CFLAGS) $(LDFLAGS) $^ -o $@

$(NAME).hex: $(NAME).elf
	$(OBJCOPY) -O verilog --verilog-data-width=4 $< $@

$(NAME).txt: $(NAME).elf
	$(OBJDUMP) -d $< > $@

clean:
	rm -f *.o *.elf

clean_temp:
	rm -f *.o *.elf *.hex program.hex 
