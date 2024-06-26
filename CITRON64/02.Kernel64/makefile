#############
# CONSTS
#############
NASM64 = nasm -f elf64
GCC64 = x86_64-linux-gnu-gcc -c -m64 -ffreestanding 
LD64 = x86_64-linux-gnu-ld -melf_x86_64 -T ../elf_x86_64.x -nostdlib -e Main -Ttext 0x20000
OBJCOPY64 = x86_64-linux-gnu-objcopy -j .text -j .data -j .rodata -j .bss -S -O binary

OBJECTDIRECTORY = Temp
SOURCEDIRECTORY = Source


#############
# Functions 
#############
all: prepare Kernel64.bin

prepare:
	mkdir -p $(OBJECTDIRECTORY)

dep:
	@echo === Make Dependency File ===
	make -C $(OBJECTDIRECTORY) -f ../makefile InternalDependency
	@echo === Dependency Search Complete ===

ExecuteInternalBuild: dep
	make -C $(OBJECTDIRECTORY) -f ../makefile Kernel64.elf

Kernel64.bin: ExecuteInternalBuild 
	$(OBJCOPY64) $(OBJECTDIRECTORY)/Kernel64.elf $@ 

clean:
	rm -f *.bin
	rm -f $(OBJECTDIRECTORY)/*.*

#############
# Recursive Functions (From OBJECTDIRECTORY) 
#############
ENTRYPOINTSOURCEFILE = ../$(SOURCEDIRECTORY)/EntryPoint.s
ENTRYPOINTOBJECTFILE = EntryPoint.o

CSOURCEFILES = $(wildcard ../$(SOURCEDIRECTORY)/*.c)
ASSEMBLYSOURCEFILES = $(wildcard ../$(SOURCEDIRECTORY)/*.asm)
COBJECTFILES = $(notdir $(patsubst %.c,%.o,$(CSOURCEFILES)))
ASSEMBLYOBJECTFILES = $(notdir $(patsubst %.asm,%.o,$(ASSEMBLYSOURCEFILES)))


$(ENTRYPOINTOBJECTFILE): $(ENTRYPOINTSOURCEFILE)
	$(NASM64) -o $@ $<

%.o: ../$(SOURCEDIRECTORY)/%.c
	$(GCC64) $<

%.o: ../$(SOURCEDIRECTORY)/%.asm
	$(NASM64) -o $@ $< 

InternalDependency:
	$(GCC64) -MM $(CSOURCEFILES) > Dependency.dep

Kernel64.elf: $(CENTRYPOINTOBJECTFILE) $(COBJECTFILES) $(ASSEMBLYOBJECTFILES)
	$(LD64) -o $@ $^

ifeq (Dependency.dep, $(wildcard Dependency.dep))
include Dependency.dep
endif

