#include <iostream>
#include <string>
#include <cstring>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <unistd.h>

using namespace std;

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

    int receiver = 2;
    string request = "GET /http_server/send.php?RECEIVER=" + to_string(receiver) + " HTTP/1.1\r\n"
                     "Host: " + host + "\r\n"
                     "Connection: close\r\n\r\n";

    if (send(sock, request.c_str(), request.size(), 0) < 0) {
        cerr << "send error" << endl;
        return 1;
    }

    char buffer[1024];
    int len;
    while ((len = recv(sock, buffer, sizeof(buffer), 0)) > 0) {
        cout.write(buffer, len);
    }

    close(sock);

    return 0;
}