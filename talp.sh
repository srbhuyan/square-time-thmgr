#!/bin/bash

filenames=$(ls *.c)

for filename in ${filenames[@]}
do
  noextn="${filename%.*}"

  clang -fplugin=Talp.so \
  -Xclang -plugin -Xclang talp \
  -Xclang -plugin-arg-talp -Xclang -target-function \
  -Xclang -plugin-arg-talp -Xclang main \
  -Xclang -plugin-arg-talp -Xclang -out-file \
  -Xclang -plugin-arg-talp -Xclang "$noextn".json \
  -Xclang -plugin-arg-talp -Xclang -format \
  -Xclang -plugin-arg-talp -Xclang json \
  -c "$filename"

done

