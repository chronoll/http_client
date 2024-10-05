#include <iostream>
#include <string>
#include <cstring>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <fstream>

using namespace std;

int receiver = 3;
string object_path = "objects/temp";

int main() {
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

    string request = "GET /http_server/send-object.php?RECEIVER=" + to_string(receiver) + " HTTP/1.1\r\n"
                     "Host: " + host + "\r\n"
                     "Connection: close\r\n\r\n";

    if (send(sock, request.c_str(), request.size(), 0) < 0) {
        cerr << "send error" << endl;
        return 1;
    }

    /* バイナリを書き込むファイルを開く */
    ofstream outputFile(object_path, ios::binary);  // バイナリモード
    if (!outputFile.is_open()) {
        cerr << "file open error" << endl;
        return 1;
    }

    char buffer[1024];
    int len;
    bool headerEnded = false;

    /* データを受信 */
    while ((len = recv(sock, buffer, sizeof(buffer), 0)) > 0) {
        if (!headerEnded) {
            // HTTPレスポンスヘッダーをスキップ
            string response(buffer, len);
            size_t pos = response.find("\r\n\r\n");
            if (pos != string::npos) {
                // ヘッダーの終わりからバイナリを書き出す
                size_t offset = pos + 4;
                outputFile.write(buffer + offset, len - offset);
                headerEnded = true;
            }
        } else {
            // スキップした後のバイナリを保存
            outputFile.write(buffer, len);
        }
    }
    
    outputFile.close();
    close(sock);

    cout << "File saved" << endl;

    /* ファイルを実行 */
    string chmodCommand = "chmod +x " + object_path;
    system(chmodCommand.c_str());

    string execCommand = "./" + object_path;
    int ret = system(execCommand.c_str());
    if (ret != 0) {
        cerr << "Execution failed with code " << ret << endl;
    }

    return 0;
}
