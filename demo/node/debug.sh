#!/usr/bin/env bash

cd demo/node
mkdir -p tmp
node --inspect-brk cli.js "$1" > tmp/out.cpp
clang++ -std=c++1y tmp/out.cpp -o tmp/a.out
tmp/a.out
