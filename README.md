# 分散計算システム クライアント側構成

## クライアントプログラム

### 主要なクライアントプログラム
- **recv-object.cpp**
  - サーバに対してジョブ配布リクエスト・ジョブ実行・計算結果送信を行うクライアントプログラム

### MPI関連
- **mpi-launcher.cpp**
  - MPIでrecv-object.cppを実行し、擬似的に複数台動作させるプログラム

## 起動スクリプト
- **ローカル環境**: `exec.sh`
- **VCクラスタ環境**: `exec_vc.sh`
  - 設定パラメータ:
    - `GROUP`: グループ数
    - `NUM_PROCESSES`: プロセス数

## VCクラスタでのログ管理
- **extract_log.sh**
  - VCクラスタのhtdocsのログファイルから、指定したプロセス数の数だけログを取得するスクリプト
- **vc_export/**
  - まとめたログファイルに対して、csv等を出力して整理するプログラム群

## システム全体の連携図

```
[クライアント側]                [サーバ側]
recv-object.cpp  <---------->  send-object.php
    |                              |
    |                              v
    |                         [programs/]
    |                         (バイナリ格納)
    |
    v
計算処理実行
    |
    v
結果送信  ------------------>  receive-result.php
                                  |
                                  v
                               [DB更新]
                                  |
                                  v
                              計算結果マージ
                              (merge.php/merge-matrix.php)
                                  |
                                  v
                              多数決処理
                              (majority.php/m-first.php)
```
