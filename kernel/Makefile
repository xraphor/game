CC = gcc
LD = ld
CFLAGS = -m32 -ffreestanding -fno-pie -fno-stack-protector -fno-asynchronous-unwind-tables -Wall -Wextra -Werror -O2
.PHONY: all iso run clean
all: build/nuke-core.elf
build:
	mkdir -p build
build/boot.o: boot.S | build
	$(CC) -m32 -c $< -o $@
build/kernel.o: kernel.c | build
	$(CC) $(CFLAGS) -c $< -o $@
build/nuke-core.elf: build/boot.o build/kernel.o linker.ld
	$(LD) -m elf_i386 -T linker.ld -o $@ build/boot.o build/kernel.o
iso: all
	mkdir -p build/iso/boot/grub
	cp build/nuke-core.elf build/iso/boot/
	cp grub.cfg build/iso/boot/grub/
	grub-mkrescue -o build/nuke-core.iso build/iso
run: all
	qemu-system-i386 -kernel build/nuke-core.elf -m 64
clean:
	rm -rf build
