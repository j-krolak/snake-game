VERSION=1.0

.PHONY: all
all: boot
	qemu-system-i386 -drive format=raw,file=boot.bin 

boot: boot.asm
	nasm boot.asm -o boot.bin


.PHONY: clean
clean:
	rm boot.bin
