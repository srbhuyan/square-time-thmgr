#!/bin/bash

usage()
{
  echo "Usage: $0 <serial algorithm> <parallel algirithm> <iva> <iva data> <iva data file> <core count file> <time serial analytics file> <time parallel analytics file> <space serial analytics file> <space parallel analytics file>"
  exit 1
}

if [ "$#" -ne 10 ]; then
    echo "Invalid number of parameters. Expected:10 Passed:$#"
    usage
fi

serial_algo=$1
parallel_algo=$2
iva_name=$3
iva_data=$4
iva_data_file=$5
core_count_file=$6
time_serial_analytics_file=$7
time_parallel_analytics_file=$8
space_serial_analytics_file=$9
space_parallel_analytics_file=${10}

serial_measurement=serial.csv
parallel_measurement=parallel.csv

# cleanup
rm $time_serial_analytics_file 2> /dev/null
rm $time_parallel_analytics_file 2> /dev/null
rm $space_serial_analytics_file 2> /dev/null
rm $space_parallel_analytics_file 2> /dev/null
rm $serial_measurement 2> /dev/null
rm $parallel_measurement 2> /dev/null

readarray -t iva  < $iva_data_file
readarray -t core < $core_count_file

# make
make

# serial run
count=1
for i in ${iva[@]}
do
  start=`date +%s.%N`;\
  heaptrack -o "$serial_algo.$count" ./$serial_algo $i;\
  end=`date +%s.%N`;\
  time_serial=`printf '%.8f' $( echo "$end - $start" | bc -l )`;\
  memory_serial=`heaptrack --analyze "$serial_algo.$count.zst"  | grep "peak heap memory consumption" | awk '{print $5}'`;

  echo "$i,$time_serial,$memory_serial" >> "$serial_measurement"
  count=$((count+1))
done

# parallel run
count=1
for i in ${core[@]}
do
  start=`date +%s.%N`;\
  heaptrack -o "$parallel_algo.$count" ./$parallel_algo $iva_data $i;\
  end=`date +%s.%N`;\
  time_parallel=`printf '%.8f' $( echo "$end - $start" | bc -l )`;\
  memory_parallel=`heaptrack --analyze "$parallel_algo.$count.zst"  | grep "peak heap memory consumption" | awk '{print $5}'`;

  echo "$i,$time_parallel,$memory_parallel" >> "$parallel_measurement"
  count=$((count+1))
done

# analytics
iva=()
core=()
time_serial=()
space_serial=()
time_parallel=()
space_parallel=()

while IFS=, read -r i t s;
do iva+=($i) time_serial+=($t) space_serial+=($s);
done < $serial_measurement

while IFS=, read -r i t s;
do core+=($i) time_parallel+=($t) space_parallel+=($s);
done < $parallel_measurement

# data prep
for i in "${!space_serial[@]}"; do
  if [[ ${space_serial[$i]: -1} == "K" ]]; then
    val=${space_serial[$i]::-1}
    space_serial[$i]=`printf '%.4f' $(echo "v=$val;v * 0.001" | bc)`
  else
    space_serial[$i]=${space_serial[$i]::-1}
  fi
done

for i in "${!space_parallel[@]}"; do
  if [[ ${space_parallel[$i]: -1} == "K" ]]; then
    val=${space_parallel[$i]::-1}
    space_parallel[$i]=`printf '%.4f' $(echo "v=$val;v * 0.001" | bc)`
  else
    space_parallel[$i]=${space_parallel[$i]::-1}
  fi
done

jo -p iva=$(jo name=$iva_name values=$(jo -a ${iva[@]})) \
measurements=$(jo -a ${time_serial[@]}) > time-serial.json
jo -p iva=$(jo name=core values=$(jo -a ${core[@]})) \
measurements=$(jo -a ${time_parallel[@]}) > time-parallel.json
jo -p iva=$(jo name=$iva_name values=$(jo -a ${iva[@]})) \
measurements=$(jo -a ${space_serial[@]}) > space-serial.json
jo -p iva=$(jo name=core values=$(jo -a ${core[@]})) \
measurements=$(jo -a ${space_parallel[@]}) > space-parallel.json

# curve fitting
fit.py --in-file time-serial.json --out-file time-serial-fitted.json
fit.py --in-file time-parallel.json --out-file time-parallel-fitted.json
fit.py --in-file space-serial.json --out-file space-serial-fitted.json
fit.py --in-file space-parallel.json --out-file space-parallel-fitted.json

# time serial
jo -p \
iva=$(jo data=$(jo -a ${iva[@]}) name=$iva_name unit=size) \
measurements=$(jo data=$(jo -a ${time_serial[@]}) name=time unit=seconds) \
predictions=$(jo data="`jq '.fitted_measurements' time-serial-fitted.json`" name=time unit=seconds) \
polynomial="`jq '.polynomial' time-serial-fitted.json`" \
maxError="`jq '.max_error' time-serial-fitted.json`" \
> $time_serial_analytics_file

# time parallel
jo -p \
iva=$(jo data=$(jo -a ${core[@]}) name=core unit=count) \
measurements=$(jo data=$(jo -a ${time_parallel[@]}) name=time unit=seconds) \
predictions=$(jo data="`jq '.fitted_measurements' time-parallel-fitted.json`" name=time unit=seconds) \
polynomial="`jq '.polynomial' time-parallel-fitted.json`" \
maxError="`jq '.max_error' time-parallel-fitted.json`" \
> $time_parallel_analytics_file

# memory serial
jo -p \
iva=$(jo data=$(jo -a ${iva[@]}) name=$iva_name unit=size) \
measurements=$(jo data=$(jo -a ${space_serial[@]}) name=memory unit=MB) \
predictions=$(jo data="`jq '.fitted_measurements' space-serial-fitted.json`" name=memory unit=MB) \
polynomial="`jq '.polynomial' space-serial-fitted.json`" \
maxError="`jq '.max_error' space-serial-fitted.json`" \
> $space_serial_analytics_file

# memory parallel
jo -p \
iva=$(jo data=$(jo -a ${core[@]}) name=core unit=count) \
measurements=$(jo data=$(jo -a ${space_parallel[@]}) name=memory unit=MB) \
predictions=$(jo data="`jq '.fitted_measurements' space-parallel-fitted.json`" name=memory unit=MB) \
polynomial="`jq '.polynomial' space-parallel-fitted.json`" \
maxError="`jq '.max_error' space-parallel-fitted.json`" \
> $space_parallel_analytics_file

