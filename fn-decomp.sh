#!/bin/bash

filenames=$(ls *.c)

for filename in ${filenames[@]}
do
  noextn="${filename%.*}"

  clang -fplugin=FunctionDecomp.so \
  -Xclang -plugin -Xclang fn-decomp \
  -Xclang -plugin-arg-fn-decomp -Xclang -target-function \
  -Xclang -plugin-arg-fn-decomp -Xclang main \
  -Xclang -plugin-arg-fn-decomp -Xclang -out-file \
  -Xclang -plugin-arg-fn-decomp -Xclang "$noextn"-fn-decomp.json \
  -Xclang -plugin-arg-fn-decomp -Xclang -format \
  -Xclang -plugin-arg-fn-decomp -Xclang json \
  -c "$filename"

done

