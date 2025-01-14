#!/bin/bash

export LD_LIBRARY_PATH=/lib/x86_64-linux-gnu:/lib64:/opt/lampp/lib
# コマンドライン引数からプロセス数を取得
if [ -z "$1" ]; then
    echo "Usage: $0 <number_of_processes>"
    exit 1
fi

NUM_PROCESSES=$1

HOST_FILE="--hostfile /home/vc/share/hostfiles/host_4"

# mpirun コマンドを実行
mpirun -np "$NUM_PROCESSES" $HOST_FILE ./mpi-launcher
