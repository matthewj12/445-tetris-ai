require('utilFuncs')
require('constants')
require('tetrominoes')


function readMoveFromFile(file_name)
	local str = nil

	for line in io.lines(file_name) do
		str = line
	end

	local i = 0

	while string.sub(str, i, i) ~= ',' do
		i = i + 1
	end

	local x_str = string.sub(str, 1, i-1)
	local rot_indx_str = string.sub(str, i+1, #str)

	return {x = tonumber(x_str), rot_indx = tonumber(rot_indx_str)}
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
	return level_to_frames_per_gridcell[tonumber(memory.readbyte(0x44))]
end


-- returns whether the given tetromino in the given position and rotation overlapps with blocks currently on the playfield
function isColliding(pf, tet_key, rot_indx, piece_x, piece_y)
	-- print('tet key: ' .. tet_key)
	-- print('rot_indx: ' .. rot_indx)
	local tet_2D_array = tetrominoes[tet_key][rot_indx]

	for tet_y = 1, 4 do
		for tet_x = 1, 4 do
			-- We need to subtract 1 to account for the fact that both tet_x and piece_x are 1-indexed
			x = tet_x + piece_x - 1
			y = tet_y + piece_y - 1

			if y >= 1 and (tet_2D_array[tet_y][tet_x] == 1 and (y > 20 or x < 1 or x > 10 or pf[y][x] == 1)) then
				return true
			end
		end
	end

	return false
end


-- Calculates the total number of frames from the time the given tetromino spawns onto the playfield to when the next tetromino spawns onto the playfield, which depends on where the given tetromino is placed.

-- Is called on the frame after the piece preview updates (and the tetromino that was previously previewed begins falling), at which point we already know where to place the newly falling tetromino and must begin the process of deciding where to place the newly previewed tetromino.
function calcFramesUntilNextTet(pf, cur_tet, move)
	-- calculate the difference between start_y (-2?) and cur_tet's final resting position y
	y = START_Y

	while (not isColliding(pf, cur_tet, move.rot_indx, move.x, y+1)) do
		y = y + 1
	end

	-- multiply this by the number of frames it takes tet to fall one gridcell (grav)

	-- The plus 10 is to account for the ARE delay (10-18 frames for NES Tetris, let's assume it's 10 for simplicity)
	-- https://tetris.wiki/Tetris_(NES,_Nintendo)
	return y * getCurrentGravity() + 10
end


-- returns a character representing the current tetromino that can be manipulated on the playfield by the player or AI agent
function getCurTet()
	-- https://datacrystal.romhacking.net/wiki/Tetris_(NES):RAM_map
	return TET_ID_MAP[memory.readbyte(0x42)]
end


function getNextTet()
	return TET_ID_MAP[memory.readbyte(0xBF)]
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
			if pf[i][j] == EMPTY then
				row_str = row_str .. ' '
			elseif pf[i][j] == BLOCK then
				row_str = row_str .. 'O'
			elseif pf[i][j] == 2 then
				row_str = row_str .. 'H'
			end

		end
		
		print(row_str .. 'X')
	end

	print('XXXXXXXXXXXX\n')
end


-- returns the a table containing all possible moves that can be applied to the given tetromino in the given playfield where each move is represented by a {rotation_index, x_position} table
-- Some moves may not actually be possible at high enough game levels, the detection and removal of which is something to implement in the future.
function enumerateMoves(pf, cur_tet)
	-- The minimum and maximum x positions that each piece can be at without going off the playfield
	local possible_x_ranges = {
		-- Lua is 1-indexed, so 1 represents the leftmost playfield column
		-- These ranges leave the rightmost column open (for getting tetrises)
		["S"] = {{0, 6}, {-1, 6}},
		["Z"] = {{0, 6}, {-1, 6}},
		["I"] = {{1, 6}, {-1, 7}},
		["O"] = {{0, 7}},
		["J"] = {{0, 6}, {0, 7}, {0, 6}, {-1, 6}},
		["L"] = {{0, 6}, {0, 7}, {0, 6}, {-1, 6}},
		["T"] = {{0, 6}, {0, 7}, {0, 6}, {-1, 6}}
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


-- Returns the absolute value of the difference between the highest and lowest columns
function getLargestHeightDiff(pf)
	local highest_height = nil
	local lowest_height = nil

	for x = 1, 10 do
		local height

		for y = 1, 20 do
			if pf[y][x] == BLOCK then
				height = y
				break
			end

			height = 21
		end

		if highest_height == nil or height > highest_height then
			highest_height = height
		end
		if lowest_height == nil or height < lowest_height then
			lowest_height = height
		end
	end

	return highest_height - lowest_height
end


-- returns the flatness number of the current playfield. 
-- flatness is determined by taking the absolute difference between the current and last column
-- higher return val = less flat/more jagged
function calcJaggedness(pf)
	local jaggedness = 0
	-- need to make the last flatness -1 because we havent started. 
	-- -1 will also be used to identify the first column so we can skip it. 
	local prev_block_dist = nil

	for x = 1, 10 do
		-- If the columns is empty, the bottom of the playfield serves as the first "block"
		local block_dist = 21

		for y = 1, 20 do
			if pf[y][x] == 1 then
				-- once we get to the first block coming down from the top,
				-- the current index is basically the height of the current column
				block_dist = y
				break
			end
		end

		-- Skip the first column
		if prev_block_dist ~= nil then
			-- columns with a height difference > HEIGHT_DIFF_THRESHOLD on both sides will be double counted, which is what we want
			local diff =  math.abs(prev_block_dist - block_dist)
			-- small differences in column height are okay and sometimes even optimal
			if diff == 1 then
				jaggedness = jaggedness + 1 * diff
			end
			if diff == 2 then
				-- only count the height difference exceeding the threshold
				jaggedness = jaggedness + 2 * diff
			elseif diff >= 3 then
				jaggedness = jaggedness + 4 * diff
			end
		end

		-- current flatness is now last flatness because we are going to the next number
		prev_block_dist = block_dist
	end

	return jaggedness
end



function markEachGridcelType(the_pf)
	local pf = d2TblCopy(the_pf)
	local hole_count = 0

	for x = 1, 10 do
		local block_above = false

		for y = 1, 20 do
			if pf[y][x] == BLOCK then
				block_above = true
			elseif pf[y][x] == EMPTY and block_above then
				pf[y][x] = HOLE
			end
		end
	end

	return pf
end


-- returns the number of holes in the given playfield
-- As of this commit, a "hole" is simply an empty grid cell with block(s) above it in the same column. Although it's very much possible and often optimal to place pieces in such as way that they would be counted as "holes" by this definition but then fill them in later via a "tuck" and/or "spin", the code currently counts "holes" this way for the sake of simplicity, ignoring tucks and spins.
function countHoles(pf)
	local hole_count = 0

	for x = 1, 10 do
		local block_above = false

		for y = 1, 20 do
			if pf[y][x] == BLOCK then
				block_above = true
			elseif pf[y][x] == EMPTY and block_above then
				hole_count = hole_count + 1
			end
		end
	end

	return hole_count
end


-- applies the given move for the given tetromino to the given playfield and returns the resulting playfield

-- A pf grid cell value of 0 means "empty space" while 1 represent a block.

-- We can create a temporary playfield with a non-1 value for fill_val to then print out for debugging purposes to more easily see where the most recent block (tet_key) was placed.
function applyMove(pf_arg, tet_key, move, fill_val)
	local pf = d2TblCopy(pf_arg)
	local tet_2d_array = tetrominoes[tet_key][move.rot_indx]

	-- Find what the y-position of the current tetromino will be after it reaches its final resting location.
	-- -1 is the default starting y-position for all newly spawned tetrominoes (with the 1-based indexing used to represent pf).
	local y = START_Y
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

			if not (y_to_fill_in < 1 or y_to_fill_in > 20 or x_to_fill_in < 1 or x_to_fill_in > 10)
				 and tet_2d_array[tet_y][tet_x] == 1
			then
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

	local moves_to_exec = {}

	-- Begin by populating moves_to_exec with controller states where no buttons are pressed
	-- No move requires more than 80 frames to execute with btn_up/down_frms = 4
	for i = 1, 80 do
		table.insert(moves_to_exec, d1TblCopy(NOTHING_PRESSED))
	end

	-- the starting location and rotation of tetrominoes after they spawn
	local cur_x = START_X
	local cur_rot_indx = 1

	-- Have one frame after the tetromino spawns where no buttons are pressed
	local frame = 2

	-- Fill in the right and left arrow button presses for moving the tetromino.
	while cur_x ~= move.x do
		if cur_x < move.x then
			cur_x = cur_x + 1

			for i = 0, BTN_DOWN_FRMS-1 do
				moves_to_exec[frame+i].right = true
			end
		else
			cur_x = cur_x - 1

			for i = 0, BTN_DOWN_FRMS-1 do
				moves_to_exec[frame+i].left = true
			end
		end

		frame = frame + 8
	end

	-- Fill in the A and B button presses for rotating the tetromino.
	frame = 2

	while cur_rot_indx < move.rot_indx do
		for i = 0, BTN_DOWN_FRMS-1 do
			moves_to_exec[frame+i].A = true
		end

		-- We already have button states where nothing is pressed that we can leave as-is, 
		--so there's no need to have another for loop like the one above to set button = false for BTN_UP_FRMS frames.
		frame = frame + BTN_DOWN_FRMS + BTN_UP_FRMS
		cur_rot_indx = cur_rot_indx + 1
	end

	return moves_to_exec
end



-- scales to a value in the range (0, 1]
function sig(score)
	return 1 / (1 + score)
end


-- returns a "score" or "expected value" from 0 to 1 representing how good or desirable the playfield is by looking only at what gridcells are currently filled. A higher value signifies a better playfield.
function baseCasePfEval(pf)
	-- print(string.format('holes: %d, jaggedness: %d', countHoles(pf), calcJaggedness(pf)))
	-- printPf(pf)
	local height_diff_score = sig(getLargestHeightDiff(pf))
	local holes_score = sig(countHoles(pf))
	local jagedness_score = sig(calcJaggedness(pf))

	local overall_score = avgTblVal({0.4*holes_score, 0.4*jagedness_score, 0.4*height_diff_score})

	return overall_score
end


function atLeast4FullRows(pf_arg)
	local pf = d2TblCopy(pf_arg)
	pf = markEachGridcelType(pf)

	local full_row_count = 0

	for y = 20, 1, -1 do
		if pf[y][10] == EMPTY then
			local a = true

			for x = 1, 9 do
				-- holes count towards the gridcell being filled in
				if pf[y][x] ~= BLOCK and pf[y][x] ~= HOLE then
					a = false
				end
			end

			if a then
				full_row_count = full_row_count + 1
			end
		end
	end

	return full_row_count >= 4
end



function s(a, b)
	return a.expected_val > b.expected_val
end


-- Calculates the expected value/score of each possible move and then returns one(s) with the highest expected value.
function getBestMove(pf, cur_tet, cur_depth, max_depth, debug, frames_to_decide)
	local all_moves = enumerateMoves(pf, cur_tet)

	if debug then
		-- print(generateIndentation(cur_depth) .. 'getBestMove cur_tet = ' .. cur_tet .. ', cur_depth = ' .. cur_depth, 'max_depth = ' .. max_depth)
	end

	-- base case expected vals
	local bc_expected_vals = {}
	-- Remove all but the best 5 moves from all_moves
	for i = 1, #all_moves do
		local temp_pf = applyMove(pf, cur_tet, all_moves[i], BLOCK)

		table.insert(bc_expected_vals, {indx = i, expected_val = baseCasePfEval(temp_pf)})
	end

	-- The key will serve as the index of the move in the original all_moves table
	table.sort(bc_expected_vals, s)

	local moves_indxs_to_consider = {}
	-- Iterate over the 5 best moves
	for i = 1, 5 do
		table.insert(moves_indxs_to_consider, bc_expected_vals[i].indx)
	end

	for i = 1, #all_moves do
		table.insert(moves_indxs_to_consider, i)
	end

	-- move(s) with the highest expected value. If it contains more than one move, then they must necessarily all have exactly the same score. In other words, if there's more than one "best move", it's because they're all tied for first place.
	local best_moves = {}

	for i = 1, #all_moves do
		if moves_indxs_to_consider[i] ~= nil then
			local temp_pf = applyMove(pf, cur_tet, all_moves[i], BLOCK)
			local cur_expected_val

			-- cur_depth is incremented in recursivePfEval.
			if cur_depth == max_depth then
				cur_expected_val = baseCasePfEval(temp_pf)
			else
				cur_expected_val = recursivePfEval(temp_pf, cur_tet, cur_depth, max_depth, false, frames_to_decide)
			end

			if debug then
				-- print(string.format('x = %d, r = %d  |  %s', all_moves[i].x, all_moves[i].rot_indx, tostring(truncateNum(cur_expected_val, 1))))
				-- print(cur_expected_val)
				-- printPf(temp_pf)
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
	end

	-- print()

	-- If we can clear 4 lines at once, then that's the best move
	if cur_tet == 'I' and atLeast4FullRows(pf) then
		return {x = 8, rot_indx = 2}
	end

	-- Alternatively, we can randomly select a move index from best_moves
	local i = 1
	local j = best_moves[i].move_index
	local best_move = all_moves[j]

	-- print('-------- exiting getBestMove() --------')

	return best_move
end


local function readCurFrameFromFile()
	for line in io.lines(CUR_FRAME_FILE) do
		return tonumber(line)
	end
end


-- returns a "score" or "expected value" from 0 to 1 representing how good or desirable the playfield is by calculating the best move(s) for each of the 7 tetrominos and then recursively evaluating the resulting playfield. A higher value signifies a more desirable playfield.
function recursivePfEval(pf, prev_tet, cur_depth, max_depth, debug, frames_to_decide)
	if debug then
		print(generateIndentation(cur_depth) .. 'recursivePfEval depth = ' .. cur_depth)
	end

	if cur_depth == max_depth then
		if debug then
			print(generateIndentation(cur_depth+1) .. '*hits base case*')
		end
		return baseCasePfEval(pf)
	end

	local tet_keys = {[1] = 'S', [2] = 'Z', [3] = 'T', [4] = 'L', [5] = 'J', [6] = 'I', [7] = 'O'}

	-- The keys in expected_vals will be the values in tet_keys
	local expected_vals = {}

	for i = 1, #tet_keys do
		-- To save on compuation and avoid "recursion inside of recursion", only consider where each of the 7 tetrominoes would be placed according to baseCasePfEval()
		local best_move = getBestMove(pf, tet_keys[i], max_depth, max_depth, debug, frames_to_decide)
		-- TODO: consider several of the best moves according to baseCasePfEval() rather than just one (for example: the top 3 best moves, all of the moves that have an expected value > 0.8, etc.)

		local temp_pf = applyMove(pf, tet_keys[i], best_move, 1)
		local temp_pf_to_print = applyMove(pf, tet_keys[i], best_move, 2)


		local e
		-- cur_frm is declared in globals.lua
		-- print(string.format('cur_frm: %s, frames_to_decide: %s', cur_frm, frames_to_decide))

		local cur_frame = readCurFrameFromFile()

		if cur_frame < frames_to_decide then
			e = recursivePfEval(temp_pf, tet_keys[i], cur_depth+1, max_depth, debug, frames_to_decide)
		else
			print('recursion terminated early')
			-- terminate the recursive evaluation early if there's not enough time to go deeper
			return baseCasePfEval(temp_pf)
		end

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
