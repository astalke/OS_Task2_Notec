example: notec.o example.o
	gcc notec.o example.o -lpthread -o example

example.o: example.c
	gcc -DN=$(N) -c -Wall -Wextra -O2 -std=c11 -o example.o example.c

notec.o: notec.asm
	nasm -DN=$(N) -f elf64 -w+all -o notec.o notec.asm

.PHONY: clean
clean:
	rm notec.o example.o example
