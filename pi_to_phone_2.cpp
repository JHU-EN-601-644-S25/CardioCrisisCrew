// pi_to_phone.cpp  –  minimal bridge to the built‑in  /text/string  characteristic
#include <iostream>
#include <string>
#include <thread>
#include <mutex>
#include <unistd.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <pybind11/embed.h>
#include "external/gobbledegook/include/Gobbledegook.h"

// ────────────── globals ──────────────
static std::string latest = "Hello, world!";   // initial value matches sample
static std::mutex  latestMtx;
namespace py = pybind11;

constexpr uint16_t TCP_PORT = 5000;
static const char *CHAR_PATH = "/com/gobbledegook/text/string"; // path in sample server

// ────────────── TCP listener ─────────
void socketListener()
{
    char buf[1024];
    //embedded python to call get_latest_session()
    py::scoped_interpreter guard{}; //interpreter
    py::module db_module = py::module::import("db"); 
    py::module json = py::module::import("json");

    while (true)
    {
        //std::cout << "inside while loop" << std::endl;
	{
            std::lock_guard<std::mutex> lock(latestMtx);

            //embedded python to call get_latest_session()
            py::object latest_data = db_module.attr("get_latest_session")();
            //convert python list of ints to JSON string
            std::string json_str = py::str(json.attr("dumps")(latest_data));

            latest = json_str;
            //ggkNofifyUpdatedCharacteristic(CHAR_PATH);
            if (!ggkNofifyUpdatedCharacteristic(CHAR_PATH)) {
                std::cerr << "[ERROR] Failed to notify characteristic" << std::endl;
            }
        }
        std::this_thread::sleep_for(std::chrono::seconds(2));
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
