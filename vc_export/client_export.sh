#!/bin/bash

output_file="csv/client/process.csv"
temp_dir="temp_results"
dir_list_file="directories.txt"  # 外部のテキストファイルを指定

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
    label=$(echo "$dir" | grep -o 'W-[0-9]-[0-9]')
    echo -n ",$label" >> "$output_file"
    
    # 各ディレクトリの結果を一時ファイルに保存
    temp_file="$temp_dir/$label.csv"
    
    # process_*.logファイルの処理
    for log_file in "$dir/client"/process_*.log; do
        grep "ms$" "$log_file" | \
        grep -v "INFO: Receive loop" | \
        while read -r line; do
            message=$(echo "$line" | sed 's/.*INFO: \(.*\) in [0-9.]*ms$/\1/')
            time=$(echo "$line" | grep -o '[0-9.]*ms$' | sed 's/ms$//')
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
            label=$(echo "$dir" | grep -o 'W-[0-9]-[0-9]')
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
