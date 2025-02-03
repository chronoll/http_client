#!/bin/bash

# 除外パターンを定義
declare -A exclude_patterns
exclude_patterns["all-2"]="W-1-16"
exclude_patterns["all-3"]="W-1-128"
exclude_patterns["all-11"]="W-1-8"
exclude_patterns["all-13"]="W-1-32"
exclude_patterns["all-14"]="W-1-4"
exclude_patterns["all-16"]="W-1-8"
exclude_patterns["all-20"]="W-1-64"

# CSVファイルの処理を行う関数
process_csv() {
   local file_type=$1    # process, recv_times, または send_times
   local output_file="csv/${file_type}_avg.csv"
   local temp_dir="temp_results/${file_type}"

   echo "Processing ${file_type}.csv files..."

   # ディレクトリの作成
   mkdir -p "csv"
   mkdir -p "$temp_dir"

   # 最初のCSVファイルからヘッダーを取得
   local first_csv
   first_csv=$(find csv/all-* -name "${file_type}.csv" | head -n 1)
   if [ -z "$first_csv" ]; then
       echo "Error: No ${file_type}.csv files found"
       return 1
   fi

   # ヘッダー行をコピー
   head -n 1 "$first_csv" > "$output_file"

   # 入力ファイルの行数を取得
   local num_lines
   num_lines=$(wc -l < "$first_csv")

   # ヘッダーから列名を取得
   local header
   header=$(head -n 1 "$first_csv")

   # 2行目から最後まで処理（ヘッダーを除く）
   for line_num in $(seq 2 $num_lines); do
       # 現在の行のDescriptionを取得
       local description
       description=$(awk -F',' -v ln="$line_num" 'NR==ln {print $1}' "$first_csv")
       echo -n "$description" > temp_line.txt
       
       # 各列（W-1-*）について処理
       local num_columns
       num_columns=$(echo "$header" | tr ',' '\n' | wc -l)
       for col in $(seq 1 $((num_columns - 1))); do
           # 列名を取得
           local column_name
           column_name=$(echo "$header" | cut -d',' -f$((col + 1)) | tr -d ' ' | tr -d '\r')
           local temp_file="$temp_dir/${column_name}.csv"
           
           # 一時ファイルのヘッダーを作成（存在しない場合）
           if [ ! -f "$temp_file" ]; then
               echo "Description,Value" > "$temp_file"
           fi
           
           local sum=0
           local count=0
           
           # 全てのCSVファイルから対応する値を収集
           for csv_file in csv/all-*/${file_type}.csv; do
               # ディレクトリ名を抽出（例：all-2）
               local dir_name
               dir_name=$(echo "$csv_file" | grep -o 'all-[0-9]\+')
               
               # 除外パターンをチェック
               if [ "${exclude_patterns[$dir_name]}" = "$column_name" ]; then
                   continue
               fi

               local value
               value=$(awk -F',' -v ln="$line_num" -v col="$((col+1))" 'NR==ln {print $col}' "$csv_file")
               if [ -n "$value" ] && [ "$value" != "NA" ]; then
                   sum=$(awk "BEGIN {print $sum + $value}")
                   count=$((count + 1))
                   # 値を一時ファイルに追加
                   local description_clean
                   description_clean=$(echo "$description" | tr -d '"')
                   echo "\"$description_clean\",$value" >> "$temp_file"
               fi
           done
           
           # 平均を計算
           if [ $count -gt 0 ]; then
               local avg
               avg=$(awk "BEGIN {printf \"%.6f\", $sum / $count}")
               echo -n ",$avg" >> temp_line.txt
           else
               echo -n ",NA" >> temp_line.txt
           fi
       done
       
       # 完成した行をファイルに追加
       cat temp_line.txt >> "$output_file"
       echo "" >> "$output_file"
   done

   echo "Completed processing ${file_type}.csv"
   echo "Results saved to ${output_file}"
   echo "Individual column data saved in ${temp_dir}/"
}

# メイン処理
echo "Starting CSV processing..."

# 各タイプのCSVファイルを処理
for file_type in process recv_times send_times; do
   process_csv "$file_type"
done

# 一時ファイルを削除
rm -f temp_line.txt

echo "All processing completed."
echo "Average results are saved in:"
echo "- csv/process_avg.csv"
echo "- csv/recv_times_avg.csv"
echo "- csv/send_times_avg.csv"
echo "Individual column data is preserved in temp_results/{process,recv_times,send_times}/"
