import time, threading, os


NEW_TET_TO_PROCESS = '1'
NO_TET_TO_PROCESS = '0'
TET_FLAG_FILE = 'new_tet_flag.txt'
FRAMES_TO_DECIDE_FILE = 'frames_to_decide.txt'


def readSingleLineFile(file_name):
	with open(file_name, 'r') as file:
		for line in file:
			# There's only one line
			return line



while True:
	tet_flag = readSingleLineFile(TET_FLAG_FILE)
	
	if tet_flag == NEW_TET_TO_PROCESS:
		# file is empty when Lua is in the process of writing to it
		while readSingleLineFile('next_tet.txt') == None:
			time.sleep(0.001)

		# print(readSingleLineFile('next_tet.txt'))

		os.system('lua callGetBestMove.lua')
		
		with open(TET_FLAG_FILE, 'w') as file:
			file.write(NO_TET_TO_PROCESS)

	time.sleep(0.01)
