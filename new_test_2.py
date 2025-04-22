import time
import board
import busio
import adafruit_ads1x15.ads1115 as ADS
from adafruit_ads1x15.analog_in import AnalogIn
import gpiod
from gpiod.line import Direction, Value, Bias
import sys
import atexit
from datetime import datetime

LINE = 27
B_LINE = 21

# Initialize the I2C bus and ADS1115
i2c = busio.I2C(board.SCL, board.SDA)
ads = ADS.ADS1115(i2c)
ads.gain = 1  # Adjust gain based on the voltage range you're expecting
chan = AnalogIn(ads, ADS.P0)

chan_name = "P0"
sample_interval = 1  # sample every 1 second
duration = 30        # total time to collect data (in seconds)
samples = []


# GPIO Setup
def exitHandler():
	print("Exiting")
	sys.exit(0)

atexit.register(exitHandler)

with gpiod.request_lines(
        "/dev/gpiochip0",
	consumer="ecg-data-collection",
	config={
		LINE: gpiod.LineSettings(direction=Direction.OUTPUT, output_value=Value.INACTIVE),
		B_LINE: gpiod.LineSettings(direction=Direction.INPUT, bias=Bias.PULL_UP)
	},
) as request:
	print("Press button to start data collection")
	collecting = False

	while True:
		button_state = request.get_value(B_LINE)
		#print(f"Button state: {button_state}")

		if button_state == Value.INACTIVE:
			if not collecting:
				print("Starting data collection")
				time.sleep(1)  # Wait for stabilization
				collecting = True
				request.set_value(LINE, Value.ACTIVE)  # Activate the AD8232 sensor
				time.sleep(2)

			#samples.clear()
			start_time = time.time()
            		# Read the ECG voltage from the ADS1115
			while time.time() - start_time < duration:
        			voltage = chan.voltage
        			print(f"Collected {chan_name}: {voltage:.3f}V")
        			samples.append(voltage)
        			time.sleep(sample_interval)
			timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
			filename = f"data_{timestamp}.txt"
			with open(filename, "w") as f:
				for v in samples:
					f.write(f"{v}\n")
			print(f"Data written to {filename}")
		else:
			if collecting:
				print("Stopping data collection")
				collecting = False
				request.set_value(LINE, Value.INACTIVE)  # Deactivate the AD8232 sensor
				time.sleep(1)

		time.sleep(0.1)  # Debounce button press
