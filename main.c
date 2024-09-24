#include <stdio.h>
#include <stdlib.h>

double square_time(int iterations) {

  double tempIter = iterations;
  double result = 1.0;
 
  for (double index1 = 1.0; index1 < tempIter; index1++){
    for (double index2 = 1.0; index2 < tempIter; index2++) {
      result = (result + index1)*index2;
      result /= index1;
    }
  }

  return 0.0;
}

int main (int argc, char *argv[]){

  if(argc < 2){
    printf("Usage: main <interations>\n");
    exit(1);
  }

  int iterations = atoi(argv[1]);

  printf("iterations = %d\n", iterations);

  square_time(iterations);

  return 0;
}
