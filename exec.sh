#!/bin/bash

export LD_LIBRARY_PATH=/lib/x86_64-linux-gnu:/lib64:/opt/lampp/lib

# コマンドライン引数の確認（オプション追加）
if [ $# -lt 2 ] || [ $# -gt 3 ]; then
    echo "Usage: $0 <group_count> <number_of_processes> [-e]"
    echo "Example: $0 1 4"
    echo "Options:"
    echo "  -e    Exit if MPI rank is 0"
    exit 1
fi

GROUP=$1
NUM_PROCESSES=$2
OPTION=${3:-""}  # 3番目の引数がない場合は空文字を設定

rm objects/*
rm results/*

sudo rm /opt/lampp/htdocs/files/*
sudo rm /opt/lampp/logs/access_log

sh sql.sh $GROUP $NUM_PROCESSES

# mpirunにオプションを環境変数として渡す
export RECV_OBJECT_OPTION="$OPTION"
mpirun -np "$NUM_PROCESSES" ./mpi-launcher
