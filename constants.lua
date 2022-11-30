-- starting location that new tetrominos spawn at
START_X = 4
START_Y = -1
-- number of frames to hold a buttons down/up
BTN_DOWN_FRMS = 1
BTN_UP_FRMS = 1

EMPTY = 0
BLOCK = 1
HOLE = 2

NEW_TET_TO_PROCESS = '1'
NO_TET_TO_PROCESS = '0'

MOVE_FILE = 'move.txt'
CUR_TET_FILE = 'cur_tet.txt'
NEXT_TET_FILE = 'next_tet.txt'
PF_STATE_FILE = 'pf_state.txt'
TET_FLAG_FILE = 'new_tet_flag.txt'
GRAV_FILE = 'cur_gravity.txt'
FRAMES_TO_DECIDE_FILE = 'frames_to_decide.txt'
CUR_FRAME_FILE = 'cur_frame.txt'

-- The keys are the NES game's internal representation of the current tetromino
TET_ID_MAP = {
	[0]  = 'T',
	[1]  = 'T',
	[2]  = 'T',
	[3]  = 'T',

	[4]  = 'J',
	[5]  = 'J',
	[6]  = 'J',
	[7]  = 'J',

	[8]  = 'Z',
	[9]  = 'Z',

	[10] = 'O',

	[11] = 'S',
	[12] = 'S',

	[13] = 'L',
	[14] = 'L',
	[15] = 'L',
	[16] = 'L',

	[17] = 'I',
	[18] = 'I'
}

OPENING_MOVES = {
	['S'] = {x=0,  rot_indx=1},
	['Z'] = {x=0,  rot_indx=1},
	['I'] = {x=1,  rot_indx=1},
	['O'] = {x=0,  rot_indx=1},
	['J'] = {x=0,  rot_indx=3},
	['L'] = {x=-1, rot_indx=4},
	['T'] = {x=0,  rot_indx=3}
}

EMPTY_PF = {
	{0,0,0,0,0,0,0,0,0,0},
	{0,0,0,0,0,0,0,0,0,0},
	{0,0,0,0,0,0,0,0,0,0},
	{0,0,0,0,0,0,0,0,0,0},
	{0,0,0,0,0,0,0,0,0,0},
	{0,0,0,0,0,0,0,0,0,0},
	{0,0,0,0,0,0,0,0,0,0},
	{0,0,0,0,0,0,0,0,0,0},
	{0,0,0,0,0,0,0,0,0,0},
	{0,0,0,0,0,0,0,0,0,0},
	{0,0,0,0,0,0,0,0,0,0},
	{0,0,0,0,0,0,0,0,0,0},
	{0,0,0,0,0,0,0,0,0,0},
	{0,0,0,0,0,0,0,0,0,0},
	{0,0,0,0,0,0,0,0,0,0},
	{0,0,0,0,0,0,0,0,0,0},
	{0,0,0,0,0,0,0,0,0,0},
	{0,0,0,0,0,0,0,0,0,0},
	{0,0,0,0,0,0,0,0,0,0},
	{0,0,0,0,0,0,0,0,0,0}
}
