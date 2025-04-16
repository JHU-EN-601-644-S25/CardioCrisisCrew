// pi_to_phone.cpp  –  minimal bridge to the built‑in  /text/string  characteristic
#include <iostream>
#include <string>
#include <thread>
#include <mutex>
#include <unistd.h>
#include <arpa/inet.h>
#include <netinet/in.h>

#include "external/gobbledegook/include/Gobbledegook.h"

// ────────────── globals ──────────────
static std::string latest = "Hello, world!";   // initial value matches sample
static std::mutex  latestMtx;

constexpr uint16_t TCP_PORT = 5000;
static const char *CHAR_PATH = "/com/gobbledegook/text/string"; // path in sample server

// ────────────── TCP listener ─────────
void socketListener()
{
    int server_fd = socket(AF_INET, SOCK_STREAM, 0);
    sockaddr_in addr{};
    addr.sin_family      = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port        = htons(TCP_PORT);

    bind(server_fd, (sockaddr *)&addr, sizeof(addr));
    listen(server_fd, 3);

    char buf[1024];

    while (true)
    {
        int client = accept(server_fd, nullptr, nullptr);
        if (client < 0) continue;

        int n = read(client, buf, sizeof(buf));
        close(client);

        if (n > 0)
        {
            std::lock_guard<std::mutex> lock(latestMtx);
            latest.assign(buf, n);

            // tell Gobbledegook the value changed
            ggkNofifyUpdatedCharacteristic(CHAR_PATH);
        }
    }
}

// ────────────── GGK delegates ────────
const void *dataGetter(const char *name)
{
    if (std::string(name) == "text/string")   // sample server asks for this key
    {
        std::lock_guard<std::mutex> lock(latestMtx);
        return latest.c_str();                // must point to stable memory
    }
    return nullptr;
}

int dataSetter(const char *, const void *)    // not used, but must exist
{
    return 1;
}

// ────────────── main ─────────────────
int main()
{
    std::thread(socketListener).detach();     // start background TCP listener

    // optional console logging
    ggkLogRegisterInfo([](const char *m){ std::cout << "[GG INFO] " << m << '\n'; });
    ggkLogRegisterError([](const char *m){ std::cout << "!!ERROR: " << m << '\n'; });

    // start the built‑in sample server (no custom services needed)
    if (!ggkStart("gobbledegook", "Gobbledegook", "Gobbledegook",
                  dataGetter, dataSetter, 5000))
    {
        std::cerr << "failed to start server\n";
        return 1;
    }

    pause();                                   // keep main thread alive
    return 0;
}
