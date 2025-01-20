#!/bin/bash

# 入力ファイル名を引数から取得
input_file="202501161922-W-1-8/server/receive_result/receive_result_1.log"
output_file="recv_1.csv"

# CSVのヘッダーを書き込む
echo "Description,Time (ms)" > "$output_file"

# msで終わる行を抽出し、必要な情報を取り出してCSVに書き込む
grep "ms$" "$input_file" | while read -r line; do
    # INFO: 以降のメッセージを取得
    message=$(echo "$line" | sed 's/.*INFO: \(.*\) in [0-9.]*ms$/\1/')
    
    # 時間値を取得
    time=$(echo "$line" | grep -o '[0-9.]*ms$' | sed 's/ms$//')
    
    # CSVに書き込む（メッセージにカンマが含まれる可能性があるのでダブルクォートで囲む）
    echo "\"$message\",$time" >> "$output_file"
done
