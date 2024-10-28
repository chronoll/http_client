#include <iostream>
#include <mpi.h>
#include <cstdlib>

using namespace std;

int main(int argc, char** argv) {
    MPI_Init(&argc, &argv);

    int rank;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);  // 各プロセスのランク（ID）を取得

    // プロセスごとに異なるコマンドを実行
    string command = "./recv-object";
    command += " " + to_string(rank);     // ランクをコマンドライン引数として渡す

    cout << "Process " << rank << " is executing: " << command << endl;
    int result = system(command.c_str());

    if (result != 0) {
        cerr << "Process " << rank << " failed to execute recv-object with exit code " << result << endl;
    }

    MPI_Finalize();
    return 0;
}
