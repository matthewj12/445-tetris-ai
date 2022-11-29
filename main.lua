require("tetrominoes")
require("utilFuncs")
require("aiFuncs")


local function writeMoveToFile(move)
	local file = io.open(MOVE_FILE, 'w')
	io.output(file)
	io.write(string.format('%d,%d', move.x, move.rot_indx))
	io.close()
end


local function updatePfFile(pf)
	-- pf, piece_preview_tet
	local file = io.open(PF_STATE_FILE, 'w')
	io.output(file)
	for y = 1, #pf do
		for x = 1, #pf[1] do
			if pf[y][x] == BLOCK then
				io.write(BLOCK)
			else
				io.write(EMPTY)
			end
		end
		if y < #pf then
			io.write('\n')
		end
	end
	io.close(file)
end


local function writeCurFrameToFile(cur_frame)
	file = io.open(CUR_FRAME_FILE, 'w')
	io.output(file)
	io.write(cur_frame)
	io.close()
end


local function updateFramesToDecideFile(pf, cur_tet, move)
	local frames_to_decide = calcFramesUntilNextTet(pf, cur_tet, move)

	file = io.open(FRAMES_TO_DECIDE_FILE, 'w')
	io.output(file)
	io.write(frames_to_decide)
	io.close()
end


local function updateFiles(pf, cur_tet, next_tet, move)
	updatePfFile(pf)
	updateFramesToDecideFile(pf, cur_tet, move)

	file = io.open(CUR_TET_FILE, 'w')
	io.output(file)
	io.write(cur_tet)
	io.close()

	file = io.open(NEXT_TET_FILE, 'w')
	io.output(file)
	io.write(next_tet)
	io.close()

	file = io.open(GRAV_FILE, 'w')
	io.output(file)
	io.write(getCurrentGravity())
	io.close()

	-- Let the main program know that there's a new tetromino to determine a best move for
	local file = io.open(TET_FLAG_FILE, 'w')
	io.output(file)
	io.write(NEW_TET_TO_PROCESS)
	io.close(file)
end


local function readTetFlagFromFile(file_name)
	for line in io.lines(file_name) do
		-- only one line in file
		return line
	end
end


local function main()
	-- 10 by 20 2D matrix representing the game's playfield
	local pf = nil
	local cur_tet = nil
	local next_tet = nil
	local best_move = nil
	local new_tet_handled = nil
	-- key = frame to update the joypad buttons, value = table with state of each joypad button
	local joypad_states = nil
	local cur_frame = nil
	local game_state = nil

	local game_started = false
	-- updateFiles(pf, cur_tet, next_tet, best_move)

	-- Is called oncer after every NES frame
	local function eachFrame()
		-- https://datacrystal.romhacking.net/wiki/Tetris_(NES):RAM_map
		game_state = memory.readbyte(0x48)

		-- Wait for the game to start (if we're currently on the level select screen, main menu, etc.)
		if not (game_state ~= 0x0 and game_state ~= 0xA) then
			game_started = false
		elseif (game_state ~= 0x0 and game_state ~= 0xA) and not game_started then
			pf = EMPTY_PF
			cur_tet = getCurTet()
			next_tet = getNextTet()
			new_tet_handled = false
			cur_frame = 1
			best_move = OPENING_MOVES[cur_tet]

			updateFiles(pf, cur_tet, next_tet, best_move)
			writeMoveToFile(best_move)

			game_started = true
		end

		if game_started then
			writeCurFrameToFile(cur_frame)

			local spawn_tet = getCurTet()

			-- is true on the very first frame
			-- new tetromino spawned
			if new_tet_handled and spawn_tet ~= cur_tet then
				new_tet_handled = false
			end

			-- handle cur_tet (only executes once for each tetromino)
			-- spawn_tet is nil during the line-clear animation
			if not new_tet_handled and spawn_tet ~= nil then
				new_tet_handled = true
				pf = scanPf()
				cur_tet = spawn_tet
				next_tet = getNextTet()
				cur_frame = 1

				best_move = readMoveFromFile(MOVE_FILE)

				joypad_states = generateJoypadStates(best_move)

				updateFiles(pf, cur_tet, getNextTet(), best_move)

			end

			-- Update the joypad state when the correct time/frame comes
			if joypad_states[cur_frame] ~= nil then
				-- The "1" means "player 1's joypad"
				joypad.set(1, joypad_states[cur_frame])
			end

			cur_frame = cur_frame + 1
		end
	end

	emu.registerafter(eachFrame)
end


main()
