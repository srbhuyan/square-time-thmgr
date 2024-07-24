#!/bin/bash

usage()
{
  echo "Usage: $0 <serial algorithm> <parallel algirithm> <iva> <iva data> <iva data file> <core count file> <time serial analytics file> <time parallel analytics file> <space serial analytics file> <space parallel analytics file> <power serial analytics file> <power parallel analytics file> <energy serial analytics file> <energy parallel analytics file> <speedup analytics file> <freeup analytics file> <powerup analytics file> <energyup analytics file>"
  exit 1
}

if [ "$#" -ne 18 ]; then
    echo "Invalid number of parameters. Expected:18 Passed:$#"
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
power_serial_analytics_file=${11}
power_parallel_analytics_file=${12}
energy_serial_analytics_file=${13}
energy_parallel_analytics_file=${14}
speedup_analytics_file=${15}
freeup_analytics_file=${16}
powerup_analytics_file=${17}
energyup_analytics_file=${18}

serial_measurement=serial.csv
parallel_measurement=parallel.csv

# cleanup
rm $time_serial_analytics_file 2> /dev/null
rm $time_parallel_analytics_file 2> /dev/null
rm $space_serial_analytics_file 2> /dev/null
rm $space_parallel_analytics_file 2> /dev/null
rm $power_serial_analytics_file 2> /dev/null
rm $power_parallel_analytics_file 2> /dev/null
rm $energy_serial_analytics_file 2> /dev/null
rm $energy_parallel_analytics_file 2> /dev/null
rm $speedup_analytics_file 2> /dev/null
rm $freeup_analytics_file 2> /dev/null
rm $powerup_analytics_file 2> /dev/null
rm $energyup_analytics_file 2> /dev/null
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
  # time, memory
  start=`date +%s.%N`;\
  heaptrack -o "$serial_algo.$count" ./$serial_algo $i;\
  end=`date +%s.%N`;\
  time_serial=`printf '%.8f' $( echo "$end - $start" | bc -l )`;\
  memory_serial=`heaptrack --analyze "$serial_algo.$count.zst"  | grep "peak heap memory consumption" | awk '{print $5}'`;

  # power, energy
  ./$serial_algo $i && \
  power=`ipmimonitoring | grep "PW consumption" | awk '{print $13}'`; \
  energy=`echo "tm=$time_serial;pw=$power;tm * pw" | bc`;

  echo "$i,$time_serial,$memory_serial,$power,$energy" >> "$serial_measurement"
  count=$((count+1))
done

# parallel run
count=1
for i in ${core[@]}
do
  # time, memory
  start=`date +%s.%N`;\
  heaptrack -o "$parallel_algo.$count" ./$parallel_algo $iva_data $i;\
  end=`date +%s.%N`;\
  time_parallel=`printf '%.8f' $( echo "$end - $start" | bc -l )`;\
  memory_parallel=`heaptrack --analyze "$parallel_algo.$count.zst"  | grep "peak heap memory consumption" | awk '{print $5}'`;

  # power, energy
  ./$parallel_algo $iva_data $i && \
  power=`ipmimonitoring | grep "PW consumption" | awk '{print $13}'`; \
  energy=`echo "pw=$power;tm=$time_parallel;pw * tm" | bc`;

  echo "$i,$time_parallel,$memory_parallel,$power,$energy" >> "$parallel_measurement"
  count=$((count+1))
done

# analytics
iva=()
core=()
time_serial=()
space_serial=()
time_parallel=()
space_parallel=()
power_serial=()
power_parallel=()
energy_serial=()
energy_parallel=()

while IFS=, read -r i t s p e;
do iva+=($i) time_serial+=($t) space_serial+=($s) power_serial+=($p) energy_serial+=($e);
done < $serial_measurement

while IFS=, read -r i t s p e;
do core+=($i) time_parallel+=($t) space_parallel+=($s) power_parallel+=($p) energy_parallel+=($e);
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

# speedup
speedup=()
t_max=${time_parallel[0]}
for t in "${time_parallel[@]}"; do
  speedup+=(`echo "scale=2;$t_max/$t" | bc`)
done

# freeup
freeup=()
s_max=${space_parallel[0]}
for s in "${space_parallel[@]}"; do
  freeup+=(`echo "scale=2;$s_max/$s" | bc`)
done

# powerup
powerup=()
p_1=${power_parallel[0]}
for p_core in "${power_parallel[@]}"; do
  powerup+=(`echo "scale=4;$p_1/$p_core" | bc`)
done

# energyup
energyup=()
e_1=${energy_parallel[0]}
for e_core in "${energy_parallel[@]}"; do
  energyup+=(`echo "scale=4;$e_1/$e_core" | bc`)
done

jo -p iva=$(jo name=$iva_name values=$(jo -a ${iva[@]})) \
measurements=$(jo -a ${time_serial[@]}) > time-serial.json
jo -p iva=$(jo name=core values=$(jo -a ${core[@]})) \
measurements=$(jo -a ${time_parallel[@]}) > time-parallel.json
jo -p iva=$(jo name=$iva_name values=$(jo -a ${iva[@]})) \
measurements=$(jo -a ${space_serial[@]}) > space-serial.json
jo -p iva=$(jo name=core values=$(jo -a ${core[@]})) \
measurements=$(jo -a ${space_parallel[@]}) > space-parallel.json
jo -p iva=$(jo name=$iva_name values=$(jo -a ${iva[@]})) \
measurements=$(jo -a ${power_serial[@]}) > power-serial.json
jo -p iva=$(jo name=core values=$(jo -a ${core[@]})) \
measurements=$(jo -a ${power_parallel[@]}) > power-parallel.json
jo -p iva=$(jo name=$iva_name values=$(jo -a ${iva[@]})) \
measurements=$(jo -a ${energy_serial[@]}) > energy-serial.json
jo -p iva=$(jo name=core values=$(jo -a ${core[@]})) \
measurements=$(jo -a ${energy_parallel[@]}) > energy-parallel.json
jo -p iva=$(jo name=core values=$(jo -a ${core[@]})) \
measurements=$(jo -a ${speedup[@]}) > speedup.json
jo -p iva=$(jo name=core values=$(jo -a ${core[@]})) \
measurements=$(jo -a ${freeup[@]}) > freeup.json
jo -p iva=$(jo name=core values=$(jo -a ${core[@]})) \
measurements=$(jo -a ${powerup[@]}) > powerup.json
jo -p iva=$(jo name=core values=$(jo -a ${core[@]})) \
measurements=$(jo -a ${energyup[@]}) > energyup.json

# curve fitting
fit.py --in-file time-serial.json --out-file time-serial-fitted.json
fit.py --in-file time-parallel.json --out-file time-parallel-fitted.json
fit.py --in-file space-serial.json --out-file space-serial-fitted.json
fit.py --in-file space-parallel.json --out-file space-parallel-fitted.json
fit.py --in-file power-serial.json --out-file power-serial-fitted.json
fit.py --in-file power-parallel.json --out-file power-parallel-fitted.json
fit.py --in-file energy-serial.json --out-file energy-serial-fitted.json
fit.py --in-file energy-parallel.json --out-file energy-parallel-fitted.json
fit.py --in-file speedup.json --out-file speedup-fitted.json
fit.py --in-file freeup.json --out-file freeup-fitted.json
fit.py --in-file powerup.json --out-file powerup-fitted.json
fit.py --in-file energyup.json --out-file energyup-fitted.json

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

# power serial
jo -p \
iva=$(jo data=$(jo -a ${iva[@]}) name=$iva_name unit=size) \
measurements=$(jo data=$(jo -a ${power_serial[@]}) name=power unit="watts") \
predictions=$(jo data="`jq '.fitted_measurements' power-serial-fitted.json`" name=power unit="watts") \
polynomial="`jq '.polynomial' power-serial-fitted.json`" \
maxError="`jq '.max_error' power-serial-fitted.json`" \
> $power_serial_analytics_file

# power parallel
jo -p \
iva=$(jo data=$(jo -a ${core[@]}) name=core unit=count) \
measurements=$(jo data=$(jo -a ${power_parallel[@]}) name=power unit="watts") \
predictions=$(jo data="`jq '.fitted_measurements' power-parallel-fitted.json`" name=power unit="watts") \
polynomial="`jq '.polynomial' power-parallel-fitted.json`" \
maxError="`jq '.max_error' power-parallel-fitted.json`" \
> $power_parallel_analytics_file

# energy serial
jo -p \
iva=$(jo data=$(jo -a ${iva[@]}) name=$iva_name unit=size) \
measurements=$(jo data=$(jo -a ${energy_serial[@]}) name=energy unit="watt-seconds") \
predictions=$(jo data="`jq '.fitted_measurements' energy-serial-fitted.json`" name=energy unit="watt-seconds") \
polynomial="`jq '.polynomial' energy-serial-fitted.json`" \
maxError="`jq '.max_error' energy-serial-fitted.json`" \
> $energy_serial_analytics_file

# energy parallel
jo -p \
iva=$(jo data=$(jo -a ${core[@]}) name=core unit=count) \
measurements=$(jo data=$(jo -a ${energy_parallel[@]}) name=energy unit="watt-seconds") \
predictions=$(jo data="`jq '.fitted_measurements' energy-parallel-fitted.json`" name=energy unit="watt-seconds") \
polynomial="`jq '.polynomial' energy-parallel-fitted.json`" \
maxError="`jq '.max_error' energy-parallel-fitted.json`" \
> $energy_parallel_analytics_file

# speedup
jo -p \
iva=$(jo data=$(jo -a ${core[@]}) name=core unit=count) \
measurements=$(jo data=$(jo -a ${speedup[@]}) name='T1/Tcore' unit='') \
predictions=$(jo data="`jq '.fitted_measurements' speedup-fitted.json`" name='T1/Tcore' unit='') \
polynomial="`jq '.polynomial' speedup-fitted.json`" \
maxError="`jq '.max_error' speedup-fitted.json`" \
> $speedup_analytics_file

# freeup
jo -p \
iva=$(jo data=$(jo -a ${core[@]}) name=core unit=count) \
measurements=$(jo data=$(jo -a ${freeup[@]}) name='S1/Score' unit='') \
predictions=$(jo data="`jq '.fitted_measurements' freeup-fitted.json`" name='S1/Score' unit='') \
polynomial="`jq '.polynomial' freeup-fitted.json`" \
maxError="`jq '.max_error' freeup-fitted.json`" \
> $freeup_analytics_file

# powerup
jo -p \
iva=$(jo data=$(jo -a ${core[@]}) name=core unit=count) \
measurements=$(jo data=$(jo -a ${powerup[@]}) name='P1/Pcore' unit='') \
predictions=$(jo data="`jq '.fitted_measurements' powerup-fitted.json`" name='P1/Pcore' unit='') \
polynomial="`jq '.polynomial' powerup-fitted.json`" \
maxError="`jq '.max_error' powerup-fitted.json`" \
> $powerup_analytics_file

# energyup
jo -p \
iva=$(jo data=$(jo -a ${core[@]}) name=core unit=count) \
measurements=$(jo data=$(jo -a ${energyup[@]}) name='E1/Ecore' unit='') \
predictions=$(jo data="`jq '.fitted_measurements' energyup-fitted.json`" name='E1/Ecore' unit='') \
polynomial="`jq '.polynomial' energyup-fitted.json`" \
maxError="`jq '.max_error' energyup-fitted.json`" \
> $energyup_analytics_file

