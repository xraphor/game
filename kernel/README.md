# NUKE CORE 0.1
Primeiro nucleo proprio experimental, em C e Assembly para x86 32-bit.
Inclui inicializacao Multiboot, console VGA, leitura de teclado PS/2 e comandos help, clear, about e halt.
Nao e Linux e nao roda aplicativos Linux/Windows. Ainda nao possui disco, rede, interface grafica, protecao de memoria ou multitarefa.

## Compilar
No Linux, com GCC, binutils e make:
```bash
cd kernel
make
```
Gera build/nuke-core.elf sem depender de biblioteca C.

## Executar
Instale QEMU no computador ou ambiente de desenvolvimento:
```bash
make run
```
O emulador abre uma tela de texto. Clique nela e digite help.
Em servidor sem tela, use um cliente grafico remoto ou configure QEMU com VNC privado; isso ainda nao esta automatizado.

## ISO opcional
Com grub-mkrescue, componentes GRUB para BIOS e xorriso instalados:
```bash
make iso
qemu-system-i386 -cdrom build/nuke-core.iso -m 64
```
A ISO nao foi gerada neste ambiente por falta dessas ferramentas.
O ELF foi compilado e ligado com GCC/binutils; boot e comandos ainda precisam de teste em QEMU, ausente neste ambiente.
Hardware alvo: PC x86 com VGA e teclado PS/2 emulado. Nao instalar em disco real.

## Sobre a execucao
Um nucleo organiza recursos existentes; nao cria CPU/RAM. O emulador usa o dispositivo onde roda. Nao ha servidor permanente criado.
O desktop Linux via Docker continua na raiz do repositorio, separado deste experimento.
