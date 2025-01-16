#!/bin/bash

# コマンドライン引数のチェック
if [ $# -ne 2 ]; then
    echo "Usage: $0 <GROUP_COUNT> <RANK_COUNT>"
    echo "Example: $0 4 4"
    exit 1
fi

# 引数の検証（数値かどうか確認）
case $1 in
    ''|*[!0-9]*) 
        echo "Error: Arguments must be numbers"
        exit 1
        ;;
esac

case $2 in
    ''|*[!0-9]*) 
        echo "Error: Arguments must be numbers"
        exit 1
        ;;
esac

MYSQL_PATH="/opt/lampp/bin/mysql"
MYSQL_USER="root"
MYSQL_PASS="root"
MYSQL_DB="practice"
GROUP=$1
RANK=$2

# まず、テーブル名のリストを取得
TABLE_NAMES=$($MYSQL_PATH -u$MYSQL_USER -p$MYSQL_PASS $MYSQL_DB -N -e "SELECT table_name FROM table_registry")

# 各テーブルに対して個別にTRUNCATEを実行
for table in $TABLE_NAMES; do
    $MYSQL_PATH -u$MYSQL_USER -p$MYSQL_PASS $MYSQL_DB <<EOF
    SET FOREIGN_KEY_CHECKS = 0;
    TRUNCATE TABLE \`$table\`;
    SET FOREIGN_KEY_CHECKS = 1;
EOF
done

# table_registryのstatusとrank_countを更新
$MYSQL_PATH -u$MYSQL_USER -p$MYSQL_PASS $MYSQL_DB <<EOF
UPDATE table_registry SET 
    status = 0,
    rank_count = $RANK;
EOF

# 各テーブルに対してINSERTを実行
for table in $TABLE_NAMES; do
    # 一時的なSQLファイルを作成
    SQL_FILE=$(mktemp)
    
    echo "START TRANSACTION;" > $SQL_FILE
    
    for group in $(seq 1 $GROUP); do
        for rank in $(seq 0 $(($RANK-1))); do
            echo "INSERT INTO \`$table\` (group_id, rank) VALUES ($group, $rank);" >> $SQL_FILE
        done
    done
    
    echo "COMMIT;" >> $SQL_FILE
    
    # SQLを実行
    $MYSQL_PATH -u$MYSQL_USER -p$MYSQL_PASS $MYSQL_DB < $SQL_FILE
    
    # 一時ファイルを削除
    rm $SQL_FILE
done

echo "All operations completed successfully"
