#include <stdio.h>
#include <stdlib.h>
#include <thpool.h>

// ---- thread management code start ----

struct SquareTimeData{
  int iterations;
  int iterationsStart;
  int iterationsEnd;
};

double square_time(int iterations, int iterationsStart, int iterationsEnd);

void worker(void * data){
  int iterations      = ((struct SquareTimeData *)data)->iterations;
  int iterationsStart = ((struct SquareTimeData *)data)->iterationsStart;
  int iterationsEnd   = ((struct SquareTimeData *)data)->iterationsEnd;

  square_time(iterations, iterationsStart, iterationsEnd);
}

void square_time_parallel(int iterations, int core, threadpool thpool){

  for(int i=0;i<core;i++){
    struct SquareTimeData * data = (struct SquareTimeData *)malloc(sizeof(struct SquareTimeData));
    data->iterations      = iterations;
    data->iterationsStart = (iterations/core) * i;
    data->iterationsEnd   = (iterations/core) * (i+1);

    thpool_add_work(thpool, worker, (void *)data);
  }

  thpool_wait(thpool);
}
// ---- thread management code end ----

double square_time(int iterations, int iterationsStart, int iterationsEnd) {

  double tempIter = iterations;
  double result = 1.0;
 
  for (double index1 = iterationsStart; index1 < iterationsEnd; index1++){
    for (double index2 = 1.0; index2 < tempIter; index2++) {
      result = (result + index1)*index2;
      result /= index1;
    }
  }

  return 0.0;
}

int main (int argc, char *argv[]){

  if(argc < 3){
    printf("Usage: main <iterations> <core>\n");
    exit(1);
  }

  int iterations = atoi(argv[1]);
  int core       = atoi(argv[2]);

  // thread pool
  threadpool thpool = thpool_init(core);

  printf("iterations = %d, core = %d\n", iterations, core);

  square_time_parallel(iterations, core, thpool);

  thpool_destroy(thpool);

  return 0;
}
