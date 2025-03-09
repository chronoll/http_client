#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 <number>"
    exit 1
fi
x=$1

base_dir="all-$x"
csv_dir="csv/$base_dir"
output_file="$csv_dir/process.csv"
dir_list_file="$base_dir/directories.txt"
temp_dir="temp_results"

mkdir -p "$csv_dir"

# 一時ディレクトリを作成
mkdir -p "$temp_dir"

# 順序を文字列として定義
order_string='First connection established
First request sent
Time from request to first response
Response received
File saved
Command executed
Second connection established
Second request sent
Result uploaded
Process completed successfully. Total execution time'

# ヘッダー行の作成
echo -n "Description" > "$output_file"

# 各ディレクトリを処理
grep -v '^#' "$dir_list_file" | grep -v '^$' | while read -r dir; do
    # ラベルを抽出してヘッダーに追加
    # W-1-x のxが1~4桁の数字に対応するように正規表現を修正
    label=$(echo "$dir" | grep -o 'W-[0-9]-[0-9]\{1,4\}')
    echo -n ",$label" >> "$output_file"
    
    # 各ディレクトリの結果を一時ファイルに保存
    temp_file="$temp_dir/$label.csv"
    
    # process_*.logファイルの処理
    for log_file in "$base_dir/$dir/client"/process_*.log; do
        grep "ms$" "$log_file" | \
        grep -v "INFO: Receive loop" | \
        while read -r line; do
            # メッセージの抽出（変更なし）
            message=$(echo "$line" | sed 's/.*INFO: \(.*\) in \([0-9]\+m \)\?[0-9]\+\.[0-9]\+ms$/\1/')
            
            # 時間の抽出と計算を修正
            if echo "$line" | grep -q "[0-9]\+m "; then
                # 分が含まれる場合
                minutes=$(echo "$line" | grep -o "[0-9]\+m " | sed 's/m //')
                milliseconds=$(echo "$line" | grep -o "[0-9]\+\.[0-9]\+ms$" | sed 's/ms$//')
                # 分をミリ秒に変換して加算
                time=$(awk "BEGIN {printf \"%.6f\", $minutes * 60000 + $milliseconds}")
            else
                # 分が含まれない場合（従来通りの処理）
                time=$(echo "$line" | grep -o '[0-9]\+\.[0-9]\+ms$' | sed 's/ms$//')
            fi
            
            echo "\"$message\",$time" >> "$temp_file.raw"
        done
    done

    # 平均を計算して一時ファイルに保存
    echo "$order_string" | while read -r desc; do
        if [ -n "$desc" ]; then
            awk -F',' -v description="$desc" '
                NR >= 1 {
                    gsub(/"/, "", $1)
                    if ($1 == description) {
                        sum += $2
                        count++
                    }
                }
                END {
                    if (count > 0) {
                        printf "\"%s\",%.6f\n", description, sum/count
                    }
                }
            ' "$temp_file.raw" >> "$temp_file"
        fi
    done
done

# ヘッダー行を完成させる
echo "" >> "$output_file"

# 結果を列として結合
echo "$order_string" | while read -r desc; do
    if [ -n "$desc" ]; then
        # 行の開始（Description）
        echo -n "\"$desc\"" >> "$output_file"
        
        # 各ディレクトリの結果を追加
        grep -v '^#' "$dir_list_file" | grep -v '^$' | while read -r dir; do
            # ここも同様に修正
            label=$(echo "$dir" | grep -o 'W-[0-9]-[0-9]\{1,4\}')
            value=$(grep "\"$desc\"" "$temp_dir/$label.csv" | cut -d',' -f2)
            echo -n ",$value" >> "$output_file"
        done
        
        # 行の終了
        echo "" >> "$output_file"
    fi
done

# 一時ディレクトリの削除
rm -r "$temp_dir"

echo "処理が完了しました。結果は $output_file に保存されました。"
