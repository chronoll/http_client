#!/bin/bash

export LD_LIBRARY_PATH=/lib/x86_64-linux-gnu:/lib64:/opt/lampp/lib

# コマンドライン引数の確認
if [ $# -ne 2 ]; then
    echo "Usage: $0 <group_count> <number_of_processes>"
    echo "Example: $0 1 4"
    exit 1
fi

GROUP=$1
NUM_PROCESSES=$2

rm objects/*
rm results/*

sh sql.sh $GROUP $NUM_PROCESSES

# mpirun コマンドを実行
mpirun -np "$NUM_PROCESSES" ./mpi-launcher
