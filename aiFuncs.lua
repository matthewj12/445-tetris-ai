require('utilFuncs')

-- returns a character representing the current tetromino that can be manipulated on the playfield by the player or AI agent
function getCurTet()
	-- The keys are the NES game's internal representation of the current tetromino
	local tet_id_map = {
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

	-- https://datacrystal.romhacking.net/wiki/Tetris_(NES):RAM_map
	return tet_id_map[memory.readbyte(0x42)]
end


-- returns a 2-dimensional table/array representing the blocks on the game's current playfield
function scanPf()
	local pf = {}

	for y = 0, 19 do
		local row = {}

		for x = 0, 9 do
			-- https://datacrystal.romhacking.net/wiki/Tetris_(NES):RAM_map
			local cell = memory.readbyte(0x400 + (10 * y) + x)

			-- 239 = empty
			if cell == 239 then
				table.insert(row, 0)
			else
				table.insert(row, 1)
			end
		end

		table.insert(pf, row)
	end


	return pf
end


-- prints a representation of the given playfield in the Output Console of the Lua Script Control window
-- This currently looks terrible because the output console uses a non-monospaced font.
function printPf(pf)
	print('\nXXXXXXXXXXXX')

	for i = 1, #pf do
		local row_str = 'X'

		for j = 1, #pf[i] do
			local cell_str = '  '

			if pf[i][j] == 1 then
				cell_str = 'O'
			elseif pf[i][j] == 2 then
				cell_str = 'H'
			end

			row_str = row_str .. cell_str
		end
		
		print(row_str .. 'X')
	end

	print('XXXXXXXXXXXX\n')
end


-- returns the number of frames it takes for the piece to fall one gridcell
function getCurrentGravity()
	local level_to_frames_per_gridcell = {
		[0] =	48,
		[1] =	43,
		[2] =	38,
		[3] =	33,
		[4] =	28,
		[5] =	23,
		[6] =	18,
		[7] =	13,
		[8] =	8,
		[9] =	6,
		[10] = 5,
		[13] = 4,
		[16] = 3,
		[19] = 2,
		[29] = 1
	}
	
	-- https://datacrystal.romhacking.net/wiki/Tetris_(NES):RAM_map
	return level_to_frames_per_gridcell[memory.readbyte(0x44)]
end


-- returns whether the given tetromino in the given position and rotation overlapps with blocks currently on the playfield
function isColliding(pf, tet_key, rot_indx, piece_x, piece_y)
	local tet_2D_array = tetrominoes[tet_key][rot_indx]

	for tet_y = 1, 4 do
		for tet_x = 1, 4 do
			-- We need to subtract 1 to account for the fact that both tet_x and piece_x are 1-indexed
			x = tet_x + piece_x - 1
			y = tet_y + piece_y - 1

			if y >= 1 and (tet_2D_array[tet_y][tet_x] == 1 and (y > 20 or pf[y][x] == 1)) then
				return true
			end
		end
	end

	return false
end


-- returns the a table containing all possible moves that can be applied to the given tetromino in the given playfield where each move is represented by a {rotation_index, x_position} table
-- Some moves may not actually be possible at high enough game levels, the detection and removal of which is something to implement in the future.
function enumerateMoves(pf, cur_tet)
	-- The minimum and maximum x positions that each piece can be at without going off the playfield
	local possible_x_ranges = {
		-- Lua is 1-indexed, so 1 represents the leftmost playfield column
		["S"] = {{0, 7}, {-1, 7}},
		["Z"] = {{0, 7}, {-1, 7}},
		["I"] = {{1, 7}, {-1, 8}},
		["O"] = {{0, 8}},
		["J"] = {{0, 7}, {0, 8}, {0, 7}, {-1, 7}},
		["L"] = {{0, 7},{0, 8},{0, 7},{-1, 7}},
		["T"] = {{0, 7},{0, 8},{0, 7},{-1, 7}}
	}

	local moves = {}

	for cur_rot_indx = 1, #tetrominoes[cur_tet] do
		local r = possible_x_ranges[cur_tet][cur_rot_indx]

		for cur_x = r[1], r[2] do
			table.insert(moves, {rot_indx = cur_rot_indx, x = cur_x})
		end
	end

	return moves
end


-- returns the number of holes in the given playfield
-- As of this commit, a "hole" is simply an empty grid cell with block(s) above it in the same column. Although it's very much possible and often optimal to place pieces in such as way that they would be counted as "holes" by this definition but then fill them in later via a "tuck" and/or "spin", the code currently counts "holes" this way for the sake of simplicity, ignoring tucks and spins.
function countHoles(the_pf)
	local pf = the_pf
	local hole_count = 0

	for x = 1, 10 do
		local block_above = false

		for y = 1, 20 do
			if pf[y][x] == 1 then
				block_above = true
			elseif pf[y][x] == 0 and block_above then
				hole_count = hole_count + 1
			end
		end
	end

	return hole_count
end

-- returns the flatness number of the current playfield. 
-- flatness is determined by taking the absolute difference between the current and last column
function flatness(the_pf)
	local pf = the_pf
	local flatness_count = 0

	-- need to make the last flatness -1 because we havent started. 
	-- -1 will also be used to identify the first column so we can skip it. 
	local current_flatness = 0
	local last_flatness = -1

	-- going down starting from the top-left of the playfield (x = 0, y = 0)
	for x = 1, 10 do

		for y = 1, 20 do
			if pf[y][x] == 1 then
				-- once we get to the first block coming down from the top,
				-- the current index is basically the height of the current column
				current_flatness = y
				-- break here because we have reach the top of the column where a block can be placed. 
				break
			end
		end

		-- get the abolute difference
		local diff = math.abs(current_flatness - last_flatness)
		-- as long as diff is greater than or equal to 3 and last flatness is not -1
		if diff >= 3 and last_flatness ~= -1 then
			-- add the flatness since this abs diff meets our criteria
			flatness_count = flatness_count + diff
		end

		-- current flatness is now last flatness because we are going to the next number
		last_flatness = current_flatness
	end

	return flatness_count
end


-- applies the given move for the given tetromino to the given playfield and returns the resulting playfield

-- A pf grid cell value of 0 means "empty space" while 1 represent a block.

-- We can create a temporary playfield with a non-1 value for fill_val to then print out for debugging purposes to more easily see where the most recent block (tet_key) was placed.
function applyMove(pf_arg, tet_key, move, fill_val)
	local pf = d2TblCopy(pf_arg)
	local tet_2d_array = tetrominoes[tet_key][move.rot_indx]

	-- Find what the y-position of the current tetromino will be after it reaches its final resting location.
	-- -1 is the default starting y-position for all newly spawned tetrominoes (with the 1-based indexing used to represent pf).
	local y = -1
	while y <= 20 and not isColliding(pf, tet_key, move.rot_indx, move.x, y+1) do
		y = y + 1
	end

	local x = move.x

	-- tet_y and tet_x are the local positions/indicies within the 4 x 4 tet_2d_array
	for tet_y = 1, 4 do
		for tet_x = 1, 4 do
			local y_to_fill_in = y + tet_y - 1
			local x_to_fill_in = x + tet_x - 1

			local continue = false

			-- This part disallows the AI from placing a tetromino in a position where one or more of its blocks are above the visible portion of the playfield.
			if y_to_fill_in < 1 or y_to_fill_in > 20 or x_to_fill_in < 1 or x_to_fill_in > 10 then
				continue = true
			end

			if not continue and tet_2d_array[tet_y][tet_x] == 1 then
				pf[y_to_fill_in][x_to_fill_in] = fill_val
			end
		end
	end

	return pf
end


-- returns the array of frame-by-frame joypad states (whether each button is pressed or not) to get the current tetromino into the destination position and rotation. This function will become more complicated once we start considering tucks and spins.
function generateJoypadStates(move)
	-- down and start are set to nil to allow the human user's input to override whatever the Lua script has them set to. The user can press down after the tetromino is moved and rotated into it's target location to speed things up and press start to pause the game.
	local NOTHING_PRESSED  = {up=false, down=nil, right=false, left=false, A=false, B=false, start=nil, select=false}
	
	-- number of frames to hold down the button for before releasing it
	local btn_down_frms = 4
	-- number of frames to wait after releasing the button before pressing another button
	local btn_up_frms = 4

	local moves_to_exec = {}

	-- Begin by populating moves_to_exec with controller states where no buttons are pressed
	for i = 1, 500 do
		table.insert(moves_to_exec, d1TblCopy(NOTHING_PRESSED))
	end

	-- the starting location and rotation of tetrominoes after they spawn
	local cur_x = 4
	local cur_rot_indx = 1

	-- Have one frame after the tetromino spawns where no buttons are pressed
	local frame = 2

	-- Fill in the right and left arrow button presses for moving the tetromino.
	while cur_x ~= move.x do
		if cur_x < move.x then
			cur_x = cur_x + 1

			for i = 0, btn_down_frms-1 do
				moves_to_exec[frame+i].right = true
			end
		else
			cur_x = cur_x - 1

			for i = 0, btn_down_frms-1 do
				moves_to_exec[frame+i].left = true
			end
		end

		frame = frame + 8
	end

	-- Fill in the A and B button presses for rotating the tetromino.
	frame = 2

	while cur_rot_indx < move.rot_indx do
		for i = 0, btn_down_frms-1 do
			moves_to_exec[frame+i].A = true
		end

		-- We already have button states where nothing is pressed that we can leave as-is, 
		--so there's no need to have another for loop like the one above to set button = false for btn_up_frms frames.
		frame = frame + btn_down_frms + btn_up_frms
		cur_rot_indx = cur_rot_indx + 1
	end

	return moves_to_exec
end


-- returns a "score" or "expected value" from 0 to 1 representing how good or desirable the playfield is by looking only at what gridcells are currently filled. A higher value signifies a better playfield.
function baseCasePfEval(pf)
	return 1 / (countHoles(pf) + 1)
end


-- Calculates the expected value/score of each possible move and then returns one(s) with the highest expected value.
function getBestMove(pf, cur_tet, cur_depth, max_depth, debug)
	local all_moves = enumerateMoves(pf, cur_tet)

	if debug then
		-- print(generateIndentation(cur_depth) .. 'getBestMove cur_tet = ' .. cur_tet .. ', cur_depth = ' .. cur_depth)
	end
	
	-- move(s) with the highest expected value. If it contains more than one move, then they must necessarily all have exactly the same score. In other words, if there's more than one "best move", it's because they're all tied for first place.
	local best_moves = {}
	
	for i = 1, #all_moves do
		local temp_pf = applyMove(pf, cur_tet, all_moves[i], 1)
		local cur_expected_val
		
		if cur_depth == max_depth then
			-- print('hit base case')
			cur_expected_val = baseCasePfEval(temp_pf)
		else
			-- cur_depth is incremented in recursivePfEval.
			cur_expected_val = recursivePfEval(temp_pf, cur_tet, cur_depth, max_depth, false)
		end
		
		if debug then
			-- print(string.format('x = %d, r = %d  |  %s', all_moves[i].x, all_moves[i].rot_indx, truncateNum(cur_expected_val, 1)))
			-- printPf(temp_pf)
			-- print()
		end

		-- If this is the first iteration OR we find a better move
		if #best_moves == 0 or cur_expected_val > best_moves[1].expected_val then
			-- move_index refers to the move's index in all_moves
			best_moves = {{move_index = i, expected_val = cur_expected_val}}

		-- If we find a move that's just as good as the current best move(s)
		elseif cur_expected_val == best_moves[1].expected_val then
			table.insert(best_moves, {move_index = i, expected_val = cur_expected_val})
		end
	end

	-- Alternatively, we can randomly select a move index from best_moves
	local i = 1
	local j = best_moves[i].move_index
	local best_move = all_moves[j]


	-- local s = ''
	-- if cur_depth ~= 0 then
	-- 	s = '        '
	-- end

	-- print(s .. "cur tet: " .. cur_tet)
	-- print(s .. "cur depth: " .. cur_depth)
	-- print(s .. 'best move expected val: ' .. best_moves[indx].expected_val)
	-- local pf_after_best_move = applyMove(pf, cur_tet, best_move, 2)
	-- printPf(pf_after_best_move)


	-- print('-------- exiting getBestMove() --------')

	return best_move
end


-- returns a "score" or "expected value" from 0 to 1 representing how good or desirable the playfield is by calculating the best move(s) for each of the 7 tetrominos and then recursively evaluating the resulting playfield. A higher value signifies a more desirable playfield.
function recursivePfEval(pf, prev_tet, cur_depth, max_depth, debug)
	if debug then
		-- print(generateIndentation(cur_depth) .. 'recursivePfEval depth = ' .. cur_depth)
	end
	
	if cur_depth == max_depth then
		if debug then
			-- print(generateIndentation(cur_depth+1) .. '*hits base case*')
		end
		return baseCasePfEval(pf)
	end

	local tet_keys = {[1] = 'S', [2] = 'Z', [3] = 'T', [4] = 'L', [5] = 'J', [6] = 'I', [7] = 'O'}

	-- The keys in expected_vals will be the values in tet_keys
	local expected_vals = {}

	for i = 1, #tet_keys do
		-- To save on compuation and avoid "recursion inside of recursion", only consider where each of the 7 tetrominoes would be placed according to baseCaseEval()
		local best_move = getBestMove(pf, tet_keys[i], max_depth, max_depth, debug)
		-- TODO: consider several of the best moves according to baseCasePfEval() rather than just one (for example: the top 3 best moves, all of the moves that have an expected value > 0.8, etc.)

		local temp_pf = applyMove(pf, tet_keys[i], best_move, 1)
		local temp_pf_to_print = applyMove(pf, tet_keys[i], best_move, 2)

		local e = recursivePfEval(temp_pf, tet_keys[i], cur_depth+1, max_depth, debug)

		expected_vals[tet_keys[i]] = e

		-- print(tet_keys[i] .. " expected val: " .. truncateNum(e, 2))
		-- printPf(temp_pf_to_print)
		-- print()
	end

	-- TODO: take into account the game's bias against repeated pieces
	local avg = avgTblVal(expected_vals)
	-- print("Avg expected val: " .. truncateNum(avg, 2))

	return avg
end
