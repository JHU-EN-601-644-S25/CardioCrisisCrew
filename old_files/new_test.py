import time
import board
import busio
import adafruit_ads1x15.ads1115 as ADS
from adafruit_ads1x15.analog_in import AnalogIn
import socket
from datetime import datetime

i2c = busio.I2C(board.SCL, board.SDA)

# Create the ADS object and specify the gain
ads = ADS.ADS1115(i2c)
ads.gain = 1 
chan = AnalogIn(ads, ADS.P0)


chan_name = "P0"
sample_interval = 1  # sample every 1 second
duration = 30        # total time to collect data (in seconds)
samples = []

start_time = time.time()
time_only = datetime.now().strftime("%H-%M-%S")
filename = f"data_{time_only}.txt"

# Continuously print the values
while time.time() - start_time < duration:
	voltage = chan.voltage
	print(f"Collected {chan_name}: {voltage:.3f}V")
	samples.append(voltage)
	time.sleep(sample_interval)
try:
	s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
	s.connect(('127.0.0.1', 5000))

	# Format the data as a single string
	msg_lines = [f"{v:.3f}V" for v in samples]
	msg = "\n".join(msg_lines).encode('utf-8')

	s.sendall(msg)
	print("Data sent successfully.")

	with open(filename, "w") as f:
		for value in samples:
			f.write(f"{value}\n")
		
finally:
    s.close()
