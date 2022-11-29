require('aiFuncs')
require('constants')


local function readPfFromFile(file_name)
	local pf = {}

	for line in io.lines(file_name) do
		table.insert(pf, {})

		for i = 1, #line do
			if tonumber(string.sub(line, i, i)) == BLOCK then
				table.insert(pf[#pf], BLOCK)
			else
				table.insert(pf[#pf], EMPTY)
			end
		end
	end

	return pf
end


local function readSingleLineFile(file_name)
	for line in io.lines(file_name) do
		return line
	end
end

local cur_tet = nil
local next_tet = nil
local cur_move = nil
local pf = nil
local frames_to_decide = nil

while cur_tet == nil or next_tet == nil or cur_move == nil or pf == nil or frames_to_decide == nil do
	cur_tet = readSingleLineFile(CUR_TET_FILE)
	next_tet = readSingleLineFile(NEXT_TET_FILE)
	cur_move = readMoveFromFile(MOVE_FILE)
	pf = readPfFromFile(PF_STATE_FILE)
	-- frames_to_decide = readSingleLineFile(FRAMES_TO_DECIDE_FILE);
	frames_to_decide = 30
end

-- We're "looking ahead" by applying the move that's currently in-progress
pf = applyMove(pf, cur_tet, cur_move, BLOCK)

-- print('after placing cur_tet ' .. cur_tet)
-- print('holes: ' .. countHoles(pf))
-- print('jagedness: ' .. calcJaggedness(pf))
-- printPf(pf)
-- print()

-- The - 20 is to account for the overhead of the unwinding of the recursion
local best_move = getBestMove(pf, next_tet, 0, 0, false, frames_to_decide - 20)

local file = io.open(MOVE_FILE, 'w')
io.output(file)
io.write(string.format('%d,%d', best_move.x, best_move.rot_indx))
io.close()