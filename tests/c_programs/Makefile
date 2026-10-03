CC      = riscv32-unknown-elf-gcc
OBJCOPY = riscv32-unknown-elf-objcopy
OBJDUMP = riscv32-unknown-elf-objdump
CFLAGS  = -march=rv32i -mabi=ilp32 -O0 -nostdlib
LDFLAGS = -T link.ld

ifndef NAME
$(error Usage : make NAME=main)
endif

all: clean_temp $(NAME).hex $(NAME).txt clean

startup.o: startup.s
	$(CC) $(CFLAGS) -c $< -o $@

$(NAME).o: $(NAME).c
	$(CC) $(CFLAGS) -c $< -o $@

$(NAME).elf: startup.o $(NAME).o
	$(CC) $(CFLAGS) $(LDFLAGS) $^ -o $@

$(NAME).hex: $(NAME).elf
	$(OBJCOPY) -O verilog --verilog-data-width=4 $< $@

$(NAME).txt: $(NAME).elf
	$(OBJDUMP) -d $< > $@

clean:
	rm -f *.o *.elf

clean_temp:
	rm -f *.o *.elf *.hex program.hex 
