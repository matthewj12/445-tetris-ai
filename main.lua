require("tetrominoes")
require("utilFuncs")


-- returns a character representing the current tetromino that can be manipulated on the playfield by the player or AI agent
local function getCurTet()
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
local function scanPf()
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
local function printPf(pf)
	print('\nXXXXXXXXXX')

	for i = 1, #pf do
		local row_str = 'X'

		for j = 1, #pf[i] do
			local cell_str = ' '

			if pf[i][j] == 1 then
				cell_str = 'O'
			end

			row_str = row_str .. cell_str
		end
		
		print(row_str .. 'X')
	end

	print('XXXXXXXXXX\n')
end


-- returns the number of frames it takes for the piece to fall one gridcell
local function getCurrentGravity()
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
local function isColliding(pf, tet_key, rot_indx, piece_x, piece_y)
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
local function enumerateMoves(pf, cur_tet)
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

-- refactored from the countHole function. This part of the code is used in multiple functions so to avoid duplicating coe,
-- we need to place it in its own function and call is multiple times. 
-- All this does it turn the playfield into a 2d represenation and returns it. 
local function identifyPf(the_pf)
	--[[
		The meaning of the values in pf change after calling fillIn():
			value | before      | after
			-----------------------------------------------------
			0     | empty space | empty space that is a hole
			1     | block       | block
			2     | N/A         | empty space that is not a hole
	]]

	local pf = d2TblCopy(the_pf)

	local function fillIn(x, y)
		if x < 1 or x > 10 or y < 1 or y > 20 or pf[y][x] == 1 or pf[y][x] == 2 then
			return
		else
			pf[y][x] = 2
			fillIn(x+1, y)
			fillIn(x-1, y)
			fillIn(x, y+1)
			fillIn(x, y-1)
		end
	end

	-- should work starting from any location within the piece spawning area
	fillIn(5, 1)

	return pf
end

-- returns the number of holes in the given playfield
-- A hole is a gridcell that is "blocked off" or inaccessible from the tetromino spawn location because it's surrounded by blocks and/or the wall(s) of the playfield
-- TODO: Include in the hole count gridcells that are not completely blocked off yet still can't be filled in by a tetromino. For the purpose of evaluating moves, these two type of holes are identical.
local function countHoles(the_pf)
	
	local holes = 0
	local pf = identifyPf(the_pf)

	-- Count up the number gridcells that are holes
	for y = 1, 20, 1 do
		for x = 1, 10, 1 do
			if pf[y][x] == 0 then
				holes = holes + 1
			end
		end
	end

	return holes
end

-- this function will check for flatness of the platfield. Starting at the first block identified as an object, it will iterate
-- through the playfield and give a corresponding number to each hole, empty space, and object (similar to the countHole function).
-- Where this is different is that it will increase the flatness rating by one for each space not filled by an object. 
-- holes that cannot be filled will be penalized 5 times the regular rating number. 
-- returns the flatness rating. Perfect score of 0 means completly flat with no holes. Higher the flatness rating, the more uneven it is.
local function checkFlattness()
	-- overall flatness score
	local flatness = 0
	-- have we seen the first block. We will keep track of the score from there. 
	local foundFirstBlock = false
	-- get the 2d representation of the playfield. 
	local pf = identifyPf(the_pf)

	for y = 1, 20, 1 do
		-- current flatness of the row we are on. This number needs to be reset everytime we iterate. 
		-- each rows flatness is independent of the others. We can choose to keep the rows flatness if we want. 
		-- In this case, we are not keep the flatness of the rows which the user has not placed anything in. 
		local rowFlatness = 0
		for x = 1, 10, 1 do
			-- 0 means its a empty space with a hole. Increase the number by 5 because its weighed more negitivly. 
			if pf[y][x] == 0 then
				rowFlatness = rowFlatness + 5
			end
			-- empty space; not hole
			if pf[y][x] == 2 then
				rowFlatness = rowFlatness + 1
			end
			-- block cell. First time block has been seen, so we will mark the boolean operator. 
			if pf[y][x] == 1 and foundFirstBlock == false then
				foundFirstBlock = true
			end
			-- we have reached the end of the row and the first block has been seen. 
			-- this means we can start monitoring the flatness. Add the rows flatness the overall number. 
			-- and keep going. 
			if y == 20 and foundFirstBlock == true then
				flatness = flatness + rowFlatness
			end
	end

	return flatness
end
-- applies the given move for the given tetromino to the given playfield and returns the resulting playfield
local function applyMove(pf_arg, tet_key, move)
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
				pf[y_to_fill_in][x_to_fill_in] = 1
			end
		end
	end

	return pf
end


-- returns the array of frame-by-frame controller states to get the current tetromino into the destination position and rotation (will become more complicated once we start considering tucks and spins)
local function generateJoypadStates(dest_x, dest_rot)
	-- number of frames to hold down the button for before releasing it
	local btn_down_frms = 4
	-- number of frames to wait after releasing the button before pressing another button
	local btn_up_frms = 4

	local moves_to_exec = {}

	-- Begin by populating moves_to_exec with controller states where no buttons are pressed
	for i = 1, 500 do
		table.insert(moves_to_exec, d1TblCopy(nothing_pressed))
	end

	-- the starting location and rotation of tetrominoes after they spawn
	local cur_x = 4
	local cur_rot_indx = 1

	-- Have one frame after the tetromino spawns where no buttons are pressed
	local frame = 2

	-- Fill in the right and left arrow button presses for moving the tetromino.
	while cur_x ~= dest_x do
		if cur_x < dest_x then
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

	while cur_rot_indx < dest_rot do
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


-- return the indicie(s) of moves in moves_to_filter that would result in the fewest holes if applied to playfied pf
local function filterMovesByHoles(moves_to_filter, cur_tet, pf)
	local holes = {}

	for i, cur_move in ipairs(moves_to_filter) do
		local temp_pf = applyMove(pf, cur_tet, cur_move)

		local temp_hole_count = countHoles(temp_pf)

		table.insert(holes, {move = cur_move, hole_count = temp_hole_count})
	end

	local min_hole_indxs = {1}

	for i = 2, #holes do
		local cur_min_hole_count = holes[min_hole_indxs[1]].hole_count

		if holes[i].hole_count == cur_min_hole_count then
			table.insert(min_hole_indxs, i)
		elseif holes[i].hole_count < cur_min_hole_count then
			min_hole_indxs = {}
			table.insert(min_hole_indxs, i)
		end
	end

	local min_hole_moves = {}

	for i, indx in ipairs(min_hole_indxs) do
		table.insert(min_hole_moves, moves_to_filter[indx])
	end

	return min_hole_moves
end


-- This function is called once immediately after every cur_tet spawns onto the playfield
local function getBestMove(pf, cur_tet)
	local all_moves = enumerateMoves(pf, cur_tet)
	local min_hole_moves = filterMovesByHoles(all_moves, cur_tet, pf)

	local best_move = min_hole_moves[math.random(#min_hole_moves)]

	return generateJoypadStates(best_move.x, best_move.rot_indx)
end


-- 10 by 20 2D matrix representing the game's playfield grid
Pf = {}
Cur_tet = 'I'

nothing_pressed  = {up=false, down=nil, right=false, left=false, A=false, B=false, start=false, select=false}

frame_counter = 1
moves_to_exec = {}
new_tet_handled = false

-- Is called after every NES frame
local function eachFrame()
	Pf = scanPf()

	-- Detect when the game is over
	-- https://datacrystal.romhacking.net/wiki/Tetris_(NES):RAM_map
	local game_state = memory.readbyte(0x48)
	if game_state == 0x0 or game_state == 0xA or #Pf ~= 20 then
		-- Don't do anything else if the game is over. Simply exit main() prematurely every frame until a new game starts.
		return
	end

	-- ___________________________________________________________________________

	spawn_tet = getCurTet()

	-- new tetromino spawned
	if new_tet_handled and spawn_tet ~= Cur_tet then
		new_tet_handled = false
	end

	-- handle cur_tet (only executes once for each tetromino)
	if not new_tet_handled then
		new_tet_handled = true
		Cur_tet = spawn_tet
		frame_counter = 1

		moves_to_exec = getBestMove(Pf, Cur_tet)
	end

	-- Update the joypad state when the correct time comes
	if moves_to_exec[frame_counter] ~= nil then
		-- The "1" means "player 1's joypad"
		joypad.set(1, moves_to_exec[frame_counter])
	end

	frame_counter = frame_counter + 1
end



-- main() will execute once after each NES frame
emu.registerafter(eachFrame)