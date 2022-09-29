from tetrominoes import tetrominoes

import numpy as np
import time
from windowcapture import WindowCapture

wincap = WindowCapture('FCEUX 2.6.4')

scale = 1

# game screen top
gst = 21
# tetromino block color (the first non-black pixel in the top-left)
tbc = [252, 252, 252]
# tetromino start left
tsl = scale * 120
# tetromino start top
tst = scale * (gst + 40)
# tetromino block width (width of sub-blocks that make up tetromino)
tbw = scale * 8

def checkForNewTet(screenshot):
	spawn_space = np.full((2, 4), 0)

	for y in range(spawn_space.shape[0]):
		for x in range(spawn_space.shape[1]):
			px = screenshot[tst + tbw * y, tsl + tbw * x]
			
			if list(px) == tbc:
				spawn_space[y][x] = 1

	for tet_name, tet_arr in tetrominoes.items():
		if spawn_space.tolist() == tet_arr:
			print(tet_name)


while(True):
	screenshot = wincap.get_screenshot()

	checkForNewTet(screenshot)

	time.sleep(.5)
