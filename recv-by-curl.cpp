#include <iostream>
#include <fstream>
#include <curl/curl.h>
#include <string>


using namespace std;

// Callback function to write the data to a file
size_t write_data(void* buffer, size_t size, size_t nmemb, void* userp) {
    std::ofstream* output = static_cast<std::ofstream*>(userp);
    output->write(static_cast<const char*>(buffer), size * nmemb);
    return size * nmemb;
}

int main() {
    CURL* curl;
    CURLcode res;

    string object_path = "curl/test";

    // Initialize libcurl
    curl_global_init(CURL_GLOBAL_DEFAULT);
    curl = curl_easy_init();
    
    if (curl) {
        std::ofstream outfile(object_path, std::ios::binary);

        if (!outfile) {
            std::cerr << "Could not open the file for writing.\n";
            return 1;
        }

        // Set the URL for the request
        curl_easy_setopt(curl, CURLOPT_URL, "http://localhost/http_server/send-by-http.php?RECEIVER=1");
        
        // Set the write function callback to save data to a file
        curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_data);
        curl_easy_setopt(curl, CURLOPT_WRITEDATA, &outfile);

        // Perform the request
        res = curl_easy_perform(curl);

        // Check for errors
        if (res != CURLE_OK) {
            std::cerr << "curl_easy_perform() failed: " << curl_easy_strerror(res) << "\n";
        }

        // Clean up
        outfile.close();
        curl_easy_cleanup(curl);
    }

    curl_global_cleanup();

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
