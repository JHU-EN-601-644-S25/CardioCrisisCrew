#include <iostream>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <signal.h>
#include <iostream>
#include <thread>
#include <sstream>
#include "external/gobbledegook/include/Gobbledegook.h"
#include <arpa/inet.h>  //INADDR_ANY
#include <netinet/in.h>

void LogError(const char *pText) { std::cout << "!!ERROR: " << pText << std::endl; }

static std::string data;
int server_fd, new_socket;
struct sockaddr_in address;
int addrlen = sizeof(address);
char buffer[1024] = {0};

const void* MyDataGetter(const char* pName) {
    	if (pName == nullptr)
	{
		LogError("NULL name sent to server data getter");
		return nullptr;
	}

	std::cout << "waiting for connection" << std::endl;
	new_socket = accept(server_fd, (struct sockaddr*)&address, (socklen_t*)&addrlen);
	if (new_socket < 0) {
		perror("accept failed");
		return nullptr;
	}

	//read data from Python server
    	std::cout <<"about to read data" << std::endl;
	int valread = read(new_socket, buffer, 1024);
    	if (valread > 0) {
        	data = std::string(buffer, valread);
		std::cout << "received data: " << data << std::endl;
    	} else {
		std::cout << "failed to read data" << std::endl;
	}
	close(new_socket);
    	return data.c_str();
}

//receives data from client
int MyDataSetter(const char* pName,const void *pData) {
	std::string incomingData((const char*)pData);

    	//end data to Python server to handle it
    	std::cout << "Setting data " << pName << std::endl;
    
    	return 1;
}


int main() {
	ggkLogRegisterInfo([](const char* msg) {
                std::cout << "[GG INFO] " << msg << std::endl;
        });
        
        ggkLogRegisterError(LogError);

        if (!ggkStart("gobbledegook", "Gobbledegook", "Gobbledegook", MyDataGetter, MyDataSetter, 5000)) {
                std::cerr << "failed to start server" << std::endl;
                return -1;
        }

	server_fd = socket(AF_INET, SOCK_STREAM, 0);
	address.sin_family = AF_INET;
	address.sin_addr.s_addr = INADDR_ANY;
	address.sin_port = htons(5000);

	bind(server_fd, (struct sockaddr*)&address, sizeof(address));
	listen(server_fd, 3);
	//new_socket = accept(server_fd, (struct sockaddr*)&address, (socklen_t*)&addrlen);

    while (true) {
        sleep(1);
    }

    return 0;
}
