#!/bin/bash

# 2から20までのディレクトリに対して処理を実行
for i in $(seq 2 20); do
    sh client_export.sh $i
    sh server_export.sh $i
done
