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

string extractHeaderValue(const string &header, const string &key);
void writeLog(const string &message, const string &logPath, bool isError = false);
string getCurrentTimestamp();
string formatDuration(const duration<double>& duration);

int main(int argc, char** argv) {
    auto startTime = high_resolution_clock::now();
    if (argc < 2) {
        cerr << "Usage: " << argv[0] << " <id>" << endl;
        return 1;
    }

    int id = stoi(argv[1]);
    string object_path = "objects/temp_" + to_string(id);
    string result_file_path = "results/result_" + to_string(id);
    string log_file_path = "logs/process_" + to_string(id) + ".log";  // ログファイルパス

    // ログディレクトリが存在しない場合は作成
    system("mkdir -p logs");

    writeLog("Process started with ID: " + to_string(id), log_file_path);

    char buffer[1024];
    int len;
    bool headerEnded = false;
    string response;
    string mpiRank;
    string groupID;
    string jobID;
    string subJobID;

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

    /* connect to server */
    if (connect(sock, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        writeLog("Connection error", log_file_path, true);
        return 1;
    }

    string request = "GET /http_server/send-object.php?ID=" + to_string(id) + " HTTP/1.1\r\n"
                     "Host: " + host + "\r\n"
                     "Connection: close\r\n\r\n";

    writeLog("Sending request: " + request, log_file_path);

    /* send request */
    if (send(sock, request.c_str(), request.size(), 0) < 0) {
        writeLog("Send error", log_file_path, true);
        return 1;
    }

    while ((len = recv(sock, buffer, sizeof(buffer), 0)) > 0) {
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

                writeLog("Received headers - MPI-Rank: " + mpiRank + ", Group-ID: " + groupID + 
                        ", Job-ID: " + jobID + ", Sub-Job-ID: " + subJobID, log_file_path);

                headerEnded = true;
                response = response.substr(pos + 4);
            }
        }
    }
    close(sock);

    /* バイナリをローカルに保存 */
    ofstream outputFile(object_path, ios::binary);
    if (!outputFile.is_open()) {
        writeLog("File open error: " + object_path, log_file_path, true);
        return 1;
    }
    outputFile.write(response.c_str(), response.size());
    outputFile.close();
    writeLog("File saved: " + object_path, log_file_path);

    /* バイナリに実行権限を付与 */
    string chmodCommand = "chmod +x " + object_path;
    system(chmodCommand.c_str());
    writeLog("Execution permission granted to: " + object_path, log_file_path);

    /* バイナリを実行して標準出力の内容を別ファイルに書き込む */
    string execCommand = "./" + object_path + " " + mpiRank + " " + "4";
    writeLog("Executing command: " + execCommand, log_file_path);
    
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

    writeLog("Result saved to: " + result_file_path, log_file_path);
    resultFile.close();

    /* create socket */
    int sock_ = socket(AF_INET, SOCK_STREAM, 0);
    if (sock_ < 0) {
        writeLog("Socket creation error for result upload", log_file_path, true);
        return 1;
    }

    /* connect to server */
    if (connect(sock_, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        writeLog("Connection error for result upload", log_file_path, true);
        return 1;
    }

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
                     "&JOB_ID=" + jobID + "&SUB_JOB_ID=" + subJobID + " HTTP/1.1\r\n"
                     "Host: " + host + "\r\n"
                     "Content-Type: application/octet-stream\r\n"
                     "X-Filename: " + filename + "\r\n"
                     "Content-Length: " + to_string(fileSize) + "\r\n"
                     "Connection: close\r\n\r\n";

    writeLog("Sending result upload request", log_file_path);

    /* HTTPリクエストヘッダを送信 */
    if (send(sock_, request_.c_str(), request_.size(), 0) < 0) {
        writeLog("Send error (header) for result upload", log_file_path, true);
        resultFileStream.close();
        close(sock_);
        return 1;
    }

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

    resultFileStream.close();
    close(sock_);
    
    auto endTime = high_resolution_clock::now();
    chrono::duration<double> duration = endTime - startTime;
    
    // 実行時間をログに出力
    writeLog("Process completed successfully. Total execution time: " + formatDuration(duration), log_file_path);
    
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
    time_t now = time(nullptr);
    char timestamp[64];
    strftime(timestamp, sizeof(timestamp), "%Y-%m-%d %H:%M:%S", localtime(&now));
    return string(timestamp);
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
    auto seconds = duration.count();
    auto minutes = static_cast<int>(seconds) / 60;
    auto remainingSeconds = seconds - minutes * 60;
    
    stringstream ss;
    if (minutes > 0) {
        ss << minutes << "m ";
    }
    ss << fixed << setprecision(3) << remainingSeconds << "s";
    return ss.str();
}
