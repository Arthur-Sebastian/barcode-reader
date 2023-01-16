CC=cc
CFLAGS=-g -Wextra -Wall
NASMFLAGS=-g -w+all

default: x64

main.o:
	$(CC) $(CFLAGS) -m32 -c main.c
main64.o:
	$(CC) $(CFLAGS) -c main.c

proj.o:
	nasm $(NASMFLAGS) -f elf32 proj.s
proj64.o:
	nasm $(NASMFLAGS) -f elf64 proj64.s

x86: main.o proj.o
	$(CC) $(CFLAGS) -no-pie -m32 *.o -o proj
	$(RM) *.o

x64: main64.o proj64.o
	$(CC) $(CFLAGS) -no-pie *.o -o proj64
	$(RM) *.o

