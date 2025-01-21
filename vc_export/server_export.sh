#!/bin/bash

receive_output="recv_times.csv"
send_output="send_times.csv"
temp_dir="temp_results"
dir_list_file="directories.txt"

# 一時ディレクトリを作成
mkdir -p "$temp_dir"

# receive_result の順序を定義
receive_order='[getClientID] MySQL connection established.
[getClientID] SELECT table_name FROM table_registry WHERE id = :job_id /
[getClientID] SELECT client FROM `matrix` WHERE id = :sub_job_id /
getClientID completed.
Read file completed.
[updateStatus] MySQL connection established.
[updateStatus] SELECT table_name FROM table_registry WHERE id = :job_id FOR UPDATE /
[updateStatus] UPDATE `matrix` SET status = :status WHERE id = :sub_job_id /
[updateStatus] SELECT COUNT_RECORDS FROM matrix /
[updateStatus] UPDATE table_registry SET status = :status WHERE id = :job_id /
updateStatus completed.
Write file completed.
[getGroupStatus] MySQL connection established.
[getGroupStatus] SELECT table_name FROM table_registry WHERE id = :job_id /
[getGroupStatus] SELECT status FROM `matrix` WHERE group_id = :group_id /
getGroupStatus completed.
Merge request completed.
Majority request completed.
Program completed. Total'

# send_object の順序を定義
send_order='[distributeJob] MySQL connection established.
[distributeJob] SELECT * FROM table_registry WHERE status <= :status ORDER BY id ASC FOR UPDATE /
[distributeJob] SELECT * FROM `matrix` WHERE status = :status ORDER BY id ASC LIMIT 1 FOR UPDATE /
[distributeJob] UPDATE_MATRIX_STATUS /
[distributeJob] UPDATE table_registry SET status = :status WHERE table_name = :table_name /
Distribute job completed.
Clean buffer completed.
Send headers completed.
Open file completed.
Output file completed.
Program completed. Total'

# ヘッダー行の作成
echo -n "Description" > "$receive_output"
echo -n "Description" > "$send_output"

# 各ディレクトリのラベルをヘッダーに追加
grep -v '^#' "$dir_list_file" | grep -v '^$' | while read -r dir; do
    label=$(echo "$dir" | grep -o 'W-[0-9]-[0-9]*')
    echo -n ",$label" >> "$receive_output"
    echo -n ",$label" >> "$send_output"
done
echo "" >> "$receive_output"
echo "" >> "$send_output"

# 各ディレクトリを処理
grep -v '^#' "$dir_list_file" | grep -v '^$' | while read -r dir; do
    label=$(echo "$dir" | grep -o 'W-[0-9]-[0-9]*')
    
    # receive_result の処理
    temp_file="$temp_dir/recv_$label.csv"
    
    # ログファイルの処理
    for log_file in "$dir/server/receive_result"/receive_result_*.log; do
        grep -E "([Tt]otal )?[Ee]xecution time[^:]*:" "$log_file" | while read -r line; do
            line=$(echo "$line" | sed 's/^\[[^]]*\] //')
            
            if echo "$line" | grep -q "Execution time (.*):"; then
                time=$(echo "$line" | grep -o '[0-9.]*[[:space:]]*ms' | sed 's/[[:space:]]*ms//' | tail -n 1)
                desc=$(echo "$line" | sed -E 's/^(.*) Execution time \(.*\): [0-9.]*[[:space:]]*ms$/\1/')
            else
                time=$(echo "$line" | grep -o '[0-9.]*[[:space:]]*ms' | sed 's/[[:space:]]*ms//' | tail -n 1)
                desc=$(echo "$line" | sed -E 's/^(.*)[[:space:]]([Tt]otal )?[Ee]xecution time: [0-9.]*[[:space:]]*ms$/\1/')
            fi
            echo "\"$desc\",$time" >> "$temp_file.raw"
        done
    done

    # 平均を計算して一時ファイルに保存
    echo "$receive_order" | while read -r desc; do
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

    # send_object の処理
    temp_file="$temp_dir/send_$label.csv"
    
    for log_file in "$dir/server/send_object"/send_object_*.log; do
        grep -E "([Tt]otal )?[Ee]xecution time[^:]*:" "$log_file" | while read -r line; do
            line=$(echo "$line" | sed 's/^\[[^]]*\] //')
            
            if echo "$line" | grep -q "Execution time (.*):"; then
                time=$(echo "$line" | grep -o '[0-9.]*[[:space:]]*ms' | sed 's/[[:space:]]*ms//' | tail -n 1)
                desc=$(echo "$line" | sed -E 's/^(.*) Execution time \(.*\): [0-9.]*[[:space:]]*ms$/\1/')
            else
                time=$(echo "$line" | grep -o '[0-9.]*[[:space:]]*ms' | sed 's/[[:space:]]*ms//' | tail -n 1)
                desc=$(echo "$line" | sed -E 's/^(.*)[[:space:]]([Tt]otal )?[Ee]xecution time: [0-9.]*[[:space:]]*ms$/\1/')
            fi
            echo "\"$desc\",$time" >> "$temp_file.raw"
        done
    done

    # 平均を計算して一時ファイルに保存
    echo "$send_order" | while read -r desc; do
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

# 結果を列として結合（receive_result）
echo "$receive_order" | while read -r desc; do
    if [ -n "$desc" ]; then
        echo -n "\"$desc\"" >> "$receive_output"
        grep -v '^#' "$dir_list_file" | grep -v '^$' | while read -r dir; do
            label=$(echo "$dir" | grep -o 'W-[0-9]-[0-9]*')
            # 固定文字列として扱うために -F オプションを追加
            value=$(grep -F "\"$desc\"" "$temp_dir/recv_$label.csv" | cut -d',' -f2)
            echo -n ",$value" >> "$receive_output"
        done
        echo "" >> "$receive_output"
    fi
done

# 結果を列として結合（send_object）
echo "$send_order" | while read -r desc; do
    if [ -n "$desc" ]; then
        echo -n "\"$desc\"" >> "$send_output"
        grep -v '^#' "$dir_list_file" | grep -v '^$' | while read -r dir; do
            label=$(echo "$dir" | grep -o 'W-[0-9]-[0-9]*')
            # 固定文字列として扱うために -F オプションを追加
            value=$(grep -F "\"$desc\"" "$temp_dir/send_$label.csv" | cut -d',' -f2)
            echo -n ",$value" >> "$send_output"
        done
        echo "" >> "$send_output"
    fi
done

# 一時ディレクトリの削除
rm -r "$temp_dir"

echo "処理が完了しました。"
echo "receive_result の結果は $receive_output に保存されました。"
echo "send_object の結果は $send_output に保存されました。"
