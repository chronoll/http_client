#!/bin/bash

# 1から20までのディレクトリに対して処理を実行
for i in $(seq 1 20); do
    # ディレクトリが存在することを確認
    if [ -d "all-$i" ]; then
        # all-[number]ディレクトリ内のサブディレクトリを取得し、
        # 最後のハイフン以降の数字で昇順ソートしてdirectories.txtに保存
        find "all-$i" -maxdepth 1 -mindepth 1 -type d -printf "%f\n" | \
        sort -t'-' -k4,4n > "all-$i/directories.txt"
        
        echo "Created directories.txt in all-$i"
    else
        echo "Warning: Directory all-$i does not exist"
    fi
done

# 実行完了メッセージ
echo "Directory listing complete!"
