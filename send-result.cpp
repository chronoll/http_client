#include <iostream>
#include <string>
#include <cstring>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <fstream>

using namespace std;

int main() {
    string result_file_path = "results/result_0";

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

    ifstream resultFileStream(result_file_path, ios::in | ios::binary);
    if (!resultFileStream.is_open()) {
        cerr << "result file open error" << endl;
        return 1;
    }

    // ファイルサイズを取得
    resultFileStream.seekg(0, ios::end);
    size_t fileSize = resultFileStream.tellg();
    resultFileStream.seekg(0, ios::beg);

    string request = "POST /http_server/recieve-result.php HTTP/1.1\r\n"
                 "Host: " + host + "\r\n"
                 "Content-Type: application/octet-stream\r\n"
                 "Content-Length: " + to_string(fileSize) + "\r\n"
                 "Connection: close\r\n\r\n";

    // HTTPリクエストヘッダを送信
    if (send(sock, request.c_str(), request.size(), 0) < 0) {
        cerr << "send error (header)" << endl;
        resultFileStream.close();
        close(sock);
        return 1;
    }

    // ファイルデータを送信
    char sendBuf[1024];
    while (resultFileStream.read(sendBuf, sizeof(sendBuf)) || resultFileStream.gcount() > 0) {
        size_t bytesRead = resultFileStream.gcount();
        if (send(sock, sendBuf, bytesRead, 0) < 0) {
            cerr << "send error (file data)" << endl;
            resultFileStream.close();
            close(sock);
            return 1;
        }
    }

    resultFileStream.close();

    close(sock);

    return 0;
}
