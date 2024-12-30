#include <iostream>
#include <string>
#include <cstring>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <fstream>
#include <vector>

using namespace std;

unsigned short port = 80;
string host = "127.0.0.1";

string extractHeaderValue(const string &header, const string &key);

/* MPIのrankをコマンドラインで指定して実行*/
int main(int argc, char** argv) {
    if (argc < 2) {
        cerr << "Usage: " << argv[0] << " <id>" << endl;
        return 1;
    }

    char buffer[1024];
    int len;
    bool headerEnded = false;
    string response;
    string mpiRank;
    string groupID;
    string jobID;
    string subJobID;

    int id = stoi(argv[1]);  // コマンドライン引数からidを設定
    string object_path = "objects/temp_" + to_string(id);
    string result_file_path = "results/result_" + to_string(id);

    /* create address */
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    addr.sin_addr.s_addr = inet_addr(host.c_str());

    /* create socket */
    int sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) {
        cerr << "socket error" << endl;
        return 1;
    }

    /* connect to server */
    if (connect(sock, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        cerr << "connect error" << endl;
        return 1;
    }

    string request = "GET /http_server/send-object.php?ID=" + to_string(id) + " HTTP/1.1\r\n"
                     "Host: " + host + "\r\n"
                     "Connection: close\r\n\r\n";

    /* send request */
    if (send(sock, request.c_str(), request.size(), 0) < 0) {
        cerr << "send error" << endl;
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
                        string body = response.substr(pos + 4);  // ボディ部分を取得
                        cerr << "Error from server: " << body << endl;
                        cerr << "Header: " << header << endl;
                        close(sock);
                        return 1;
                    }
                }

                mpiRank = extractHeaderValue(header, "MPI-Rank");
                groupID = extractHeaderValue(header, "Group-ID");
                jobID = extractHeaderValue(header, "Job-ID");
                subJobID = extractHeaderValue(header, "Sub-Job-ID");

                headerEnded = true;
                response = response.substr(pos + 4);
            }
        }
    }
    close(sock);

    // // 送信失敗時のシミュレーション用
    // if (stoi(subJobID) == 1 || stoi(subJobID) == 11) {
    //     return 0;
    // }

    /* バイナリをローカルに保存 */
    ofstream outputFile(object_path, ios::binary);
    if (!outputFile.is_open()) {
        cerr << "file open error" << endl;
        return 1;
    }
    outputFile.write(response.c_str(), response.size());
    outputFile.close();
    cout << "File saved" << endl;

    /* バイナリに実行権限を付与 */
    string chmodCommand = "chmod +x " + object_path;
    system(chmodCommand.c_str());

    /* バイナリを実行して標準出力の内容を別ファイルに書き込む */
    string execCommand = "./" + object_path + " " + mpiRank;
    FILE *pipe = popen(execCommand.c_str(), "r");
    if (pipe == NULL) {
        cerr << "popen failed" << endl;
        return 1;
    }

    ofstream resultFile(result_file_path);
    if (!resultFile.is_open()) {
        cerr << "result file open error" << endl;
        return 1;
    }

    char buf[1024];
    while (fgets(buf, sizeof(buf), pipe) != NULL) {
        resultFile << buf;
    }

    int ret = pclose(pipe);
    if (ret == -1) {
        cerr << "pclose failed" << endl;
        return 1;
    }

    cout << "Result saved" << endl;
    resultFile.close();

    // // ファイルの2行目を上書きする処理
    // if (stoi(groupID) % 2 == 1) { // groupIDが偶数の場合
    //     vector<string> lines;
    //     string line;

    //     // ファイルを開いて内容を取得
    //     ifstream inputFile(result_file_path);
    //     if (!inputFile.is_open()) {
    //         cerr << "Unable to open result file for modification: " << result_file_path << endl;
    //         return 1;
    //     }

    //     while (getline(inputFile, line)) {
    //         lines.push_back(line); // 各行を配列に保存
    //     }
    //     inputFile.close();

    //     // 2行目を "test" に変更（行番号は0-based index）
    //     if (lines.size() > 1) {
    //         lines[1] = "test";
    //     } else {
    //         cerr << "File does not have enough lines to modify." << endl;
    //         return 1;
    //     }

    //     // ファイルを書き換え
    //     ofstream outputFile(result_file_path, ios::trunc);
    //     if (!outputFile.is_open()) {
    //         cerr << "Unable to open result file for writing: " << result_file_path << endl;
    //         return 1;
    //     }

    //     for (const auto& modifiedLine : lines) {
    //         outputFile << modifiedLine << '\n';
    //     }
    //     outputFile.close();

    //     cout << "File modified successfully: 2nd line replaced with 'test'." << endl;
    // }

    /* create socket */
    int sock_ = socket(AF_INET, SOCK_STREAM, 0);
    if (sock_ < 0) {
        cerr << "socket error" << endl;
        return 1;
    }

    /* connect to server */
    if (connect(sock_, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        cerr << "connect error" << endl;
        return 1;
    }

    ifstream resultFileStream(result_file_path, ios::in | ios::binary);
    if (!resultFileStream.is_open()) {
        cerr << "result file open error" << endl;
        return 1;
    }

    /* ファイルサイズを取得 */
    resultFileStream.seekg(0, ios::end);
    size_t fileSize = resultFileStream.tellg();
    resultFileStream.seekg(0, ios::beg);

    string filename = "result_" + mpiRank;

    string request_ = "POST /http_server/receive-result.php?ID=" + to_string(id) + "&RANK=" + mpiRank + "&GROUP=" + groupID + "&JOB_ID=" + jobID + "&SUB_JOB_ID=" + subJobID + " HTTP/1.1\r\n"
                 "Host: " + host + "\r\n"
                 "Content-Type: application/octet-stream\r\n"
                 "X-Filename: " + filename + "\r\n"
                 "Content-Length: " + to_string(fileSize) + "\r\n"
                 "Connection: close\r\n\r\n";

    /* HTTPリクエストヘッダを送信 */
    if (send(sock_, request_.c_str(), request_.size(), 0) < 0) {
        cerr << "send error (header)" << endl;
        resultFileStream.close();
        close(sock_);
        return 1;
    }

    /* ファイルデータを送信 */
    char sendBuf[1024];
    while (resultFileStream.read(sendBuf, sizeof(sendBuf)) || resultFileStream.gcount() > 0) {
        size_t bytesRead = resultFileStream.gcount();
        if (send(sock_, sendBuf, bytesRead, 0) < 0) {
            cerr << "send error (file data)" << endl;
            resultFileStream.close();
            close(sock_);
            return 1;
        }
    }

    resultFileStream.close();

    close(sock_);

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
