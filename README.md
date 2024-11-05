send.cpp recv.cpp
簡単なHTTPリクエストを送ってレスポンスを標準出力で返すクライアントサイドのプログラム

recv-object.cpp
指定した番号に合致するバイナリの内容を標準出力で受けとり、保存して実行するプログラム

mpi-launcher.cpp
recv-object.cppをmpiで並列実行させる
コマンド mpicxx -o mpi-launcher mpi-launcher.cpp mpirun -np 9 ./mpi-launcher
