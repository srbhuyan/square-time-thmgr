all: serial parallel

serial:
	gcc -std=c99 -o squaretime_serial squaretime_serial.c

parallel:
	gcc -std=c99 -o squaretime_parallel squaretime_parallel.c -lpthread

clean:
	rm squaretime_serial squaretime_parallel
