#include <iostream>
#include <string>
#include <cstring>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <fstream>
#include <vector>
#include <ctime>
#include <sstream>
#include <chrono>
#include <iomanip> 

using namespace std;
using namespace chrono;

unsigned short port = 80;
string host = "127.0.0.1";
// string host = "192.168.100.3";

string extractHeaderValue(const string &header, const string &key);
void writeLog(const string &message, const string &logPath, bool isError = false);
void writeSeparator(const string &logPath);
string getCurrentTimestamp();
string formatDuration(const duration<double>& duration);

int main(int argc, char** argv) {
    // コマンドライン引数の解析
    if (argc < 2) {
        cerr << "Usage: " << argv[0] << " <id> [-e|-f]" << endl;
        cerr << "Options:" << endl;
        cerr << "  -e    Exit" << endl;
        cerr << "  -f    False result" << endl;
        return 1;
    }

    bool exitFlag = false;
    bool falseFlag = false;

    // オプションの確認
    for (int i = 1; i < argc; i++) {
        string arg = argv[i];
        if (arg == "-e") {
            exitFlag = true;
        } else if (arg == "-f") {
            falseFlag = true;
        }
    }
    
    auto allStartTime = high_resolution_clock::now();

    int id = stoi(argv[1]);
    string object_path = "objects/temp_" + to_string(id);
    string result_file_path = "results/result_" + to_string(id);
    // string object_path = "/home/vc/kurotaka/objects/temp_" + to_string(id);
    // string result_file_path = "/home/vc/kurotaka/results/result_" + to_string(id);
    string log_file_path = "logs/process_" + to_string(id) + ".log";  // ログファイルパス

    // ログディレクトリが存在しない場合は作成
    system("mkdir -p logs");

    writeSeparator(log_file_path);
    writeLog("Process started with ID: " + to_string(id), log_file_path);

    char buffer[16384];
    int len;
    bool headerEnded = false;
    string response;
    string mpiRank;
    string groupID;
    string jobID;
    string subJobID;
    string RankCount;

    /* create address */
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    addr.sin_addr.s_addr = inet_addr(host.c_str());

    /* create socket */
    int sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) {
        writeLog("Socket creation error", log_file_path, true);
        return 1;
    }

    auto firstConnectStartTime = high_resolution_clock::now();

    /* connect to server */
    if (connect(sock, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        writeLog("Connection error", log_file_path, true);
        return 1;
    }

    auto firstConnectEndTime = high_resolution_clock::now();
    chrono::duration<double> firstConnectDuration = firstConnectEndTime - firstConnectStartTime;
    writeLog("First connection established in " + formatDuration(firstConnectDuration), log_file_path);

    string request = "GET /http_server/send-object.php?ID=" + to_string(id) + " HTTP/1.1\r\n"
                     "Host: " + host + "\r\n"
                     "Connection: close\r\n\r\n";

    writeLog("Sending request: " + request, log_file_path);

    auto firstRequestStartTime = high_resolution_clock::now();

    /* send request */
    if (send(sock, request.c_str(), request.size(), 0) < 0) {
        writeLog("Send error", log_file_path, true);
        return 1;
    }

    auto firstRequestEndTime = high_resolution_clock::now();
    chrono::duration<double> firstRequestDuration = firstRequestEndTime - firstRequestStartTime;
    writeLog("First request sent in " + formatDuration(firstRequestDuration), log_file_path);

    auto receiveStartTime = high_resolution_clock::now();
    bool firstResponseReceived = false;
    int loopCount = 0;

    while ((len = recv(sock, buffer, sizeof(buffer), 0)) > 0) {
        auto loopStartTime = high_resolution_clock::now();
        loopCount++;

        if (!firstResponseReceived) {
            auto firstResponseReceivedTime = high_resolution_clock::now();
            chrono::duration<double> firstResponseDuration = firstResponseReceivedTime - receiveStartTime; // レスポンス受信までの時間
            writeLog("Time from request to first response in " + formatDuration(firstResponseDuration), log_file_path);
            firstResponseReceived = true;
        }
        response.append(buffer, len);

        if (!headerEnded) {
            size_t pos = response.find("\r\n\r\n");
            if (pos != string::npos) {
                string header = response.substr(0, pos);
                
                /* ステータスコードを確認 */
                size_t statusPos = header.find(" ");
                if (statusPos != string::npos && statusPos + 4 <= header.size()) {
                    int statusCode = stoi(header.substr(statusPos + 1, 3));
                    if (statusCode != 200) {
                        string body = response.substr(pos + 4);
                        writeLog("Error from server: " + body, log_file_path, true);
                        writeLog("Header: " + header, log_file_path, true);
                        close(sock);
                        return 1;
                    }
                }

                mpiRank = extractHeaderValue(header, "MPI-Rank");
                groupID = extractHeaderValue(header, "Group-ID");
                jobID = extractHeaderValue(header, "Job-ID");
                subJobID = extractHeaderValue(header, "Sub-Job-ID");
                RankCount = extractHeaderValue(header, "Rank-Count");

                writeLog("Received headers - MPI-Rank: " + mpiRank + ", Group-ID: " + groupID + 
                        ", Job-ID: " + jobID + ", Sub-Job-ID: " + subJobID + ", Rank-Count: " + RankCount, log_file_path);

                headerEnded = true;
                response = response.substr(pos + 4);
            }
        }

        auto loopEndTime = high_resolution_clock::now();
        chrono::duration<double> loopDuration = loopEndTime - loopStartTime;
        writeLog("Receive loop #" + to_string(loopCount) + " received " + to_string(len) + " bytes in " + formatDuration(loopDuration), log_file_path);
    }

    auto receiveEndTime = high_resolution_clock::now();
    chrono::duration<double> receiveDuration = receiveEndTime - receiveStartTime;
    writeLog("Response received in " + formatDuration(receiveDuration), log_file_path);

    close(sock);

    auto saveStartTime = high_resolution_clock::now();

    /* バイナリをローカルに保存 */
    ofstream outputFile(object_path, ios::binary);
    if (!outputFile.is_open()) {
        writeLog("File open error: " + object_path, log_file_path, true);
        return 1;
    }
    outputFile.write(response.c_str(), response.size());
    outputFile.close();

    auto saveEndTime = high_resolution_clock::now();
    chrono::duration<double> saveDuration = saveEndTime - saveStartTime;
    writeLog("File saved in " + formatDuration(saveDuration), log_file_path);

    writeLog("File saved to: " + object_path, log_file_path);

    // デバッグ用オプションが有効なら、MPIランクが0の場合にプロセスを終了
    if (exitFlag && stoi(groupID) == 1) {
        writeLog("This process is exited. mpiRank: " + mpiRank, log_file_path);
        writeSeparator(log_file_path);
        return 0;
    }

// デバッグ用オプションが有効なら、groupIDが1の場合に間違った結果を返す
    if (falseFlag && stoi(groupID) == 1) {
        writeLog("This process return wrong answer. mpiRank: " + mpiRank, log_file_path, true);
        
        // "false"という内容で結果ファイルを上書き
        ofstream resultFile(result_file_path);
        if (!resultFile.is_open()) {
            writeLog("Result file open error when writing false result: " + result_file_path, log_file_path, true);
            return 1;
        }
        resultFile << endl  // 1行目の改行
            << endl  // 2行目の改行
            << "id0: " << endl  // 3行目
            << "Sums = false" << endl;  // 4行目
        resultFile.close();
        
        writeLog("False result written to: " + result_file_path, log_file_path);
    } else {
        /* バイナリに実行権限を付与 */
        string chmodCommand = "chmod +x " + object_path;
        system(chmodCommand.c_str());
        writeLog("Execution permission granted to: " + object_path, log_file_path);

        /* バイナリを実行して標準出力の内容を別ファイルに書き込む */
        // string execCommand = "./" + object_path + " " + mpiRank + " " + RankCount + " " + groupID;
        string execCommand = object_path + " " + mpiRank + " " + RankCount + " " + groupID;
        writeLog("Executing command: " + execCommand, log_file_path);
        
        auto execStartTime = high_resolution_clock::now();

        FILE *pipe = popen(execCommand.c_str(), "r");
        if (pipe == NULL) {
            writeLog("popen failed", log_file_path, true);
            return 1;
        }

        ofstream resultFile(result_file_path);
        if (!resultFile.is_open()) {
            writeLog("Result file open error: " + result_file_path, log_file_path, true);
            return 1;
        }

        char buf[1024];
        while (fgets(buf, sizeof(buf), pipe) != NULL) {
            resultFile << buf;
        }

        int ret = pclose(pipe);
        if (ret == -1) {
            writeLog("pclose failed", log_file_path, true);
            return 1;
        }

        auto execEndTime = high_resolution_clock::now();
        chrono::duration<double> execDuration = execEndTime - execStartTime;
        writeLog("Command executed in " + formatDuration(execDuration), log_file_path);
        writeLog("Result saved to: " + result_file_path, log_file_path);

        resultFile.close();
    }

    /* create socket */
    int sock_ = socket(AF_INET, SOCK_STREAM, 0);
    if (sock_ < 0) {
        writeLog("Socket creation error for result upload", log_file_path, true);
        return 1;
    }

    auto secondConnectStartTime = high_resolution_clock::now();

    /* connect to server */
    if (connect(sock_, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        writeLog("Connection error for result upload", log_file_path, true);
        return 1;
    }

    auto secondConnectEndTime = high_resolution_clock::now();
    chrono::duration<double> secondConnectDuration = secondConnectEndTime - secondConnectStartTime;
    writeLog("Second connection established in " + formatDuration(secondConnectDuration), log_file_path);

    ifstream resultFileStream(result_file_path, ios::in | ios::binary);
    if (!resultFileStream.is_open()) {
        writeLog("Result file open error for upload: " + result_file_path, log_file_path, true);
        return 1;
    }

    /* ファイルサイズを取得 */
    resultFileStream.seekg(0, ios::end);
    size_t fileSize = resultFileStream.tellg();
    resultFileStream.seekg(0, ios::beg);

    string filename = "result_" + mpiRank;

    string request_ = "POST /http_server/receive-result.php?ID=" + to_string(id) + 
                     "&RANK=" + mpiRank + "&GROUP=" + groupID + 
                     "&JOB_ID=" + jobID + "&SUB_JOB_ID=" + subJobID + "&RANK_COUNT=" + RankCount + " HTTP/1.1\r\n"
                     "Host: " + host + "\r\n"
                     "Content-Type: application/octet-stream\r\n"
                     "X-Filename: " + filename + "\r\n"
                     "Content-Length: " + to_string(fileSize) + "\r\n"
                     "Connection: close\r\n\r\n";

    writeLog("Sending result upload request", log_file_path);

    auto secondRequestStartTime = high_resolution_clock::now();

    /* HTTPリクエストヘッダを送信 */
    if (send(sock_, request_.c_str(), request_.size(), 0) < 0) {
        writeLog("Send error (header) for result upload", log_file_path, true);
        resultFileStream.close();
        close(sock_);
        return 1;
    }

    auto secondRequestEndTime = high_resolution_clock::now();
    chrono::duration<double> secondRequestDuration = secondRequestEndTime - secondRequestStartTime;
    writeLog("Second request sent in " + formatDuration(secondRequestDuration), log_file_path);

    auto sendResultStartTime = high_resolution_clock::now();

    /* ファイルデータを送信 */
    char sendBuf[1024];
    while (resultFileStream.read(sendBuf, sizeof(sendBuf)) || resultFileStream.gcount() > 0) {
        size_t bytesRead = resultFileStream.gcount();
        if (send(sock_, sendBuf, bytesRead, 0) < 0) {
            writeLog("Send error (file data) for result upload", log_file_path, true);
            resultFileStream.close();
            close(sock_);
            return 1;
        }
    }

    auto sendResultEndTime = high_resolution_clock::now();
    chrono::duration<double> sendResultDuration = sendResultEndTime - sendResultStartTime;
    writeLog("Result uploaded in " + formatDuration(sendResultDuration), log_file_path);

    resultFileStream.close();
    close(sock_);
    
    auto allEndTime = high_resolution_clock::now();
    chrono::duration<double> allDuration = allEndTime - allStartTime;
    
    // 実行時間をログに出力
    writeLog("Process completed successfully. Total execution time in " + formatDuration(allDuration), log_file_path);
    writeSeparator(log_file_path);

    return 0;
}

/* HTTPヘッダから特定の変数を抽出 */
string extractHeaderValue(const string &header, const string &key) {
    size_t keyPos = header.find(key + ": ");
    if (keyPos != string::npos) {
        size_t endPos = header.find("\r\n", keyPos);
        return header.substr(keyPos + key.length() + 2, endPos - keyPos - key.length() - 2);
    }
    return "";
}

/* タイムスタンプを取得 */
string getCurrentTimestamp() {
    // 現在時刻をマイクロ秒単位で取得
    auto now = system_clock::now();
    auto now_c = system_clock::to_time_t(now);
    auto now_us = duration_cast<microseconds>(now.time_since_epoch()) % 1000000;

    char timestamp[64];
    strftime(timestamp, sizeof(timestamp), "%Y-%m-%d %H:%M:%S", localtime(&now_c));
    
    // マイクロ秒を追加
    stringstream ss;
    ss << timestamp << "." << setfill('0') << setw(6) << now_us.count();
    
    return ss.str();
}

/* ログを書き込む */
void writeLog(const string &message, const string &logPath, bool isError) {
    ofstream logFile(logPath, ios::app);
    if (logFile.is_open()) {
        logFile << "[" << getCurrentTimestamp() << "] " 
                << (isError ? "ERROR: " : "INFO: ") 
                << message << endl;
        logFile.close();
    }
    
    // 標準出力/エラー出力にも表示
    if (isError) {
        cerr << message << endl;
    } else {
        cout << message << endl;
    }
}

/* 実行時間を見やすい形式にフォーマット */
string formatDuration(const duration<double>& duration) {
    auto milliseconds = chrono::duration_cast<chrono::microseconds>(duration).count() / 1000.0;
    auto minutes = static_cast<int>(milliseconds) / (1000 * 60);
    auto remainingMilliseconds = milliseconds - minutes * (1000 * 60);
    
    stringstream ss;
    if (minutes > 0) {
        ss << minutes << "m ";
    }
    ss << fixed << setprecision(6) << remainingMilliseconds << "ms";
    return ss.str();
}

/* 区切り線を書き込む */
void writeSeparator(const string &logPath) {
    ofstream logFile(logPath, ios::app);
    if (logFile.is_open()) {
        logFile << "\n" 
                << "===========================================================" << endl
                << endl;
        logFile.close();
    }
}
