#include <iostream>
#include <string>
#include <cstring>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <fstream>

using namespace std;

int main(int argc, char** argv) {
    if (argc < 2) {
        cerr << "Usage: " << argv[0] << " <id>" << endl;
        return 1;
    }

    int id = stoi(argv[1]);  // コマンドライン引数からidを設定
    string object_path = "objects/temp_" + to_string(id);

    unsigned short port = 80;
    string host = "127.0.0.1";

    /* create socket */
    int sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) {
        cerr << "socket error" << endl;
        return 1;
    }

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    addr.sin_addr.s_addr = inet_addr(host.c_str());

    /* connect to server */
    if (connect(sock, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        cerr << "connect error" << endl;
        return 1;
    }

    string request = "GET /http_server/send-object.php?ID=" + to_string(id) + " HTTP/1.1\r\n"
                     "Host: " + host + "\r\n"
                     "Connection: close\r\n\r\n";

    if (send(sock, request.c_str(), request.size(), 0) < 0) {
        cerr << "send error" << endl;
        return 1;
    }

    char buffer[1024];
    int len;
    bool headerEnded = false;
    string response;

    while ((len = recv(sock, buffer, sizeof(buffer), 0)) > 0) {
        response.append(buffer, len);

        if (!headerEnded) {
            size_t pos = response.find("\r\n\r\n");
            if (pos != string::npos) {
                string header = response.substr(0, pos);
                
                // ステータスコードを確認
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

                headerEnded = true;
                response = response.substr(pos + 4);
            }
        }
    }

    ofstream outputFile(object_path, ios::binary);
    if (!outputFile.is_open()) {
        cerr << "file open error" << endl;
        return 1;
    }

    outputFile.write(response.c_str(), response.size());
    outputFile.close();
    close(sock);

    cout << "File saved" << endl;

    string chmodCommand = "chmod +x " + object_path;
    system(chmodCommand.c_str());

    string execCommand = "./" + object_path;
    int ret = system(execCommand.c_str());
    if (ret != 0) {
        cerr << "Execution failed with code " << ret << endl;
    }

    return 0;
}
