import time, sys, signal, atexit
import gpiod
from gpiod.line import Direction, Value, Bias
from __future__ import print_function
from upm import pyupm_ad8232 as upmAD8232


LINE = 27
B_LINE = 21

myAD8232 = upmAD8232.AD8232(10, 11, 0)

def exitHandler():
    print("Exiting")
    sys.exit(0)

atexit.register(exitHandler)

with gpiod.request_lines(
	"/dev/gpiochip0",
	consumer="blink-example",
	config={
		LINE: gpiod.LineSettings(direction=Direction.OUTPUT, output_value=Value.INACTIVE),
		B_LINE: gpiod.LineSettings(direction=Direction.INPUT,bias=Bias.PULL_UP)
    	},
) as request:
	print("Press button to start data collection")
	collecting = False

	while True:
		button_state = request.get_value(B_LINE)
		print(f"Button state: {button_state}")
		if button_state == Value.INACTIVE:
			if not collecting:
				print("Starting data collection")
				time.sleep(2)
				collecting = True
				request.set_value(LINE, Value.ACTIVE)
			print(myAD8232.value())
			time.sleep(0.001)
		else:
			if collecting:
				print("Stopping data collection")
				collecting = False
				request.set_value(LINE, Value.INACTIVE)
		time.sleep(0.1)
        	#request.set_value(LINE, Value.ACTIVE)
        	#time.sleep(1)
        	#request.set_value(LINE, Value.INACTIVE)
        	#time.sleep(1)
