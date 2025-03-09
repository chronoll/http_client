#!/bin/bash

# パスの定数定義
CLIENT_ROOT="/home/kurotaka/http_client"
SERVER_ROOT="/opt/lampp/htdocs/http_server"

# コマンドライン引数のチェック
if [ $# -ne 1 ]; then
   echo "Usage: $0 <RANK>"
   exit 1
fi

RANK=$1

# 現在時刻を取得してディレクトリ名として使用
TIMESTAMP=$(date +"%Y%m%d%H%M")
EXPORT_DIR="${CLIENT_ROOT}/export/${TIMESTAMP}"

# 必要なディレクトリをすべて作成
mkdir -p ${EXPORT_DIR}/client
mkdir -p ${EXPORT_DIR}/server/receive_result
mkdir -p ${EXPORT_DIR}/server/send_object
mkdir -p ${EXPORT_DIR}/server/m-first
mkdir -p ${EXPORT_DIR}/server/merge_job
mkdir -p ${EXPORT_DIR}/server/timer

# クライアント側のログ処理
for i in $(seq 0 $(($RANK-1))); do
   INPUT_FILE="${CLIENT_ROOT}/logs/process_${i}.log"
   OUTPUT_FILE="${EXPORT_DIR}/client/process_${i}.log"

   if [ ! -f "$INPUT_FILE" ]; then
       echo "Warning: Input file $INPUT_FILE does not exist"
       continue
   fi

   LINES=`grep -n "^=\{10,\}$" "$INPUT_FILE" | cut -d: -f1 | tail -2`
   SECOND_LAST=`echo "$LINES" | head -1`
   LAST=`echo "$LINES" | tail -1`

   if [ ! -z "$SECOND_LAST" ] && [ ! -z "$LAST" ]; then
       sed -n "$((SECOND_LAST+1)),$((LAST-1))p" "$INPUT_FILE" > "$OUTPUT_FILE"
   else
       echo "Warning: Could not find delimiter lines in $INPUT_FILE"
   fi
done

# サーバー側のログ処理（receive_result）
for i in $(seq 0 $(($RANK-1))); do
   INPUT_FILE="${SERVER_ROOT}/logs/receive_result_${i}.log"
   OUTPUT_FILE="${EXPORT_DIR}/server/receive_result/receive_result_${i}.log"

   if [ ! -f "$INPUT_FILE" ]; then
       echo "Warning: Input file $INPUT_FILE does not exist"
       continue
   fi

   LINES=`grep -n "^=\{10,\}$" "$INPUT_FILE" | cut -d: -f1 | tail -2`
   SECOND_LAST=`echo "$LINES" | head -1`
   LAST=`echo "$LINES" | tail -1`

   if [ ! -z "$SECOND_LAST" ] && [ ! -z "$LAST" ]; then
       sed -n "$((SECOND_LAST+1)),$((LAST-1))p" "$INPUT_FILE" > "$OUTPUT_FILE"
   else
       echo "Warning: Could not find delimiter lines in $INPUT_FILE"
   fi
done

# サーバー側のログ処理（send_object）
for i in $(seq 0 $(($RANK-1))); do
   INPUT_FILE="${SERVER_ROOT}/logs/send_object_${i}.log"
   OUTPUT_FILE="${EXPORT_DIR}/server/send_object/send_object_${i}.log"

   if [ ! -f "$INPUT_FILE" ]; then
       echo "Warning: Input file $INPUT_FILE does not exist"
       continue
   fi

   LINES=`grep -n "^=\{10,\}$" "$INPUT_FILE" | cut -d: -f1 | tail -2`
   SECOND_LAST=`echo "$LINES" | head -1`
   LAST=`echo "$LINES" | tail -1`

   if [ ! -z "$SECOND_LAST" ] && [ ! -z "$LAST" ]; then
       sed -n "$((SECOND_LAST+1)),$((LAST-1))p" "$INPUT_FILE" > "$OUTPUT_FILE"
   else
       echo "Warning: Could not find delimiter lines in $INPUT_FILE"
   fi
done

# m-firstログファイルの処理
for INPUT_FILE in ${SERVER_ROOT}/logs/m-first_*.log; do
   # ファイルが存在しない場合はスキップ
   if [ ! -f "$INPUT_FILE" ]; then
       continue
   fi

   BASENAME=$(basename "$INPUT_FILE")
   OUTPUT_FILE="${EXPORT_DIR}/server/m-first/${BASENAME}"

   LINES=`grep -n "^=\{10,\}$" "$INPUT_FILE" | cut -d: -f1 | tail -2`
   SECOND_LAST=`echo "$LINES" | head -1`
   LAST=`echo "$LINES" | tail -1`

   if [ ! -z "$SECOND_LAST" ] && [ ! -z "$LAST" ]; then
       sed -n "$((SECOND_LAST+1)),$((LAST-1))p" "$INPUT_FILE" > "$OUTPUT_FILE"
   else
       echo "Warning: Could not find delimiter lines in $INPUT_FILE"
   fi
done

# merge_jobログファイルの処理
for INPUT_FILE in ${SERVER_ROOT}/logs/merge_job_*.log; do
   if [ ! -f "$INPUT_FILE" ]; then
       continue
   fi

   BASENAME=$(basename "$INPUT_FILE")
   OUTPUT_FILE="${EXPORT_DIR}/server/merge_job/${BASENAME}"

   LINES=`grep -n "^=\{10,\}$" "$INPUT_FILE" | cut -d: -f1 | tail -2`
   SECOND_LAST=`echo "$LINES" | head -1`
   LAST=`echo "$LINES" | tail -1`

   if [ ! -z "$SECOND_LAST" ] && [ ! -z "$LAST" ]; then
       sed -n "$((SECOND_LAST+1)),$((LAST-1))p" "$INPUT_FILE" > "$OUTPUT_FILE"
   else
       echo "Warning: Could not find delimiter lines in $INPUT_FILE"
   fi
done

# timerログファイルの処理
for INPUT_FILE in ${SERVER_ROOT}/logs/timer_*.log; do
   if [ ! -f "$INPUT_FILE" ]; then
       continue
   fi

   BASENAME=$(basename "$INPUT_FILE")
   OUTPUT_FILE="${EXPORT_DIR}/server/timer/${BASENAME}"

   LINES=`grep -n "^=\{10,\}$" "$INPUT_FILE" | cut -d: -f1 | tail -2`
   SECOND_LAST=`echo "$LINES" | head -1`
   LAST=`echo "$LINES" | tail -1`

   if [ ! -z "$SECOND_LAST" ] && [ ! -z "$LAST" ]; then
       sed -n "$((SECOND_LAST+1)),$((LAST-1))p" "$INPUT_FILE" > "$OUTPUT_FILE"
   else
       echo "Warning: Could not find delimiter lines in $INPUT_FILE"
   fi
done

echo "Processing completed. Check the directory: ${EXPORT_DIR}"
