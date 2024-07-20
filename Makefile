all: serial parallel

serial:
	gcc -std=c99 -o main_serial main_serial.c

parallel:
	gcc -std=c99 -o main_parallel main_parallel.c -lpthread -lthpool

clean:
	rm main_serial main_parallel
