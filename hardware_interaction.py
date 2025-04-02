import time
import time
import gpiod
from gpiod.line import Direction, Value, Bias

LINE = 27
B_LINE = 21

with gpiod.request_lines(
	"/dev/gpiochip0",
	consumer="blink-example",
	config={
		LINE: gpiod.LineSettings(direction=Direction.OUTPUT, output_value=Value.INACTIVE),
		B_LINE: gpiod.LineSettings(direction=Direction.INPUT,bias=Bias.PULL_UP)
    	},
) as request:
	while True:
		button_state = request.get_value(B_LINE)
		print(f"Button state: {button_state}")
		if button_state == Value.INACTIVE:
			request.set_value(LINE, Value.ACTIVE)
		else:
			request.set_value(LINE, Value.INACTIVE)
		time.sleep(0.1)
        	#request.set_value(LINE, Value.ACTIVE)
        	#time.sleep(1)
        	#request.set_value(LINE, Value.INACTIVE)
        	#time.sleep(1)
