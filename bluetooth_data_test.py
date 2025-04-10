import socket
import time

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect(('127.0.0.1', 5000))

try:
	while True:
		message = b'hello from raspberry pi'
		s.sendall(message)
		print('sent message')
		time.sleep(2)
except KeyboardInterrupt:
	print('some issue')
	s.close()
