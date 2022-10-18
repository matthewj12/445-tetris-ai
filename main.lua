require("tetrominoes")


-- datacrystal.romhacking.net/wiki/Tetris_(NES):RAM_map
nes_ram_map = {
	-- y position of the current tetromino
	cur_tet_y = 65,
	-- id of the current tetromino
	cur_tet_id = 66,
	-- play field top left
	pf_tl = 1024
}

-- How tetrominoes are represented in the NES's memory
tet_id_map = {
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


function d2TblEq(t1, t2)
	for y, row in ipairs(t1) do
		for x, val in ipairs(row) do
			if (val ~= t2[y][x]) then
				return false
			end
		end
	end

	return true
end


function d1TblEq(t1, t2)
	for i, val in ipairs(t1) do
		if (val ~= t2[i]) then
			return false
		end
	end

	return true
end


function getCurTet()
	return tet_id_map[memory.readbyte(nes_ram_map.cur_tet_id)]
end


function scanPf()
	local pf = {}

	for y = 0, 19 do
		local row = {}

		for x = 0, 9 do
			cell = memory.readbyte(nes_ram_map.pf_tl + (10 * y) + x)

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


function printPf(pf)
	for i, row in ipairs(pf) do
		rowstr = ''
		for i, val in ipairs(row) do
			if val == 0 then
				rowstr = rowstr .. ' '
			else
				rowstr = rowstr .. 'O'
			end
		end
		print(rowstr)
	end
end

-- [piece[rotation index]]
possible_x_range = {
	["S"] = {
		{-1, 6},
		{-1, 7}
	},
	["Z"] = {
		{-1, 6},
		{-1, 7}
	},
	["I"] = {
		{0, 6},
		{-2, 7}
	},
	["O"] = {
		{-1, 7}
	},
	["J"] = {
		{-1, 6},
		{-1, 7},
		{-1, 6},
		{-2, 6}
	},
	["L"] = {
		{-1, 6},
		{-1, 7},
		{-1, 6},
		{-2, 6}
	},
	["T"] = {
		{-1, 6},
		{-1, 7},
		{-1, 6},
		{-2, 6}
	}
}

function isColliding(pf, tet, piece_x, piece_y)
	for tet_y = 1, 4 do
		for tet_x = 1, 4 do
			x = tet_x + piece_x
			y = tet_y + piece_y

			if (tet[tet_y]:sub(tet_x, tet_x) ~= " " and
				 ((x < 1 or x > 10 or y < 1 or y > 20) or pf[y][x] ~= 0) ) then
				return true
			end
		end
	end

	return false
end


function enumerateMoves(pf, cur_tet)
	-- {tetronimo name, rotation index, x, y} where the piece isn't overlapping/colliding squares already on the playfield
	valid_resting_locations = {}
	-- {tetronimo name, rotation index, x, y} that can be reached via normal game inputs
	reachable_valid_resting_locations = {}
		

	for rot_indx, tet_2d_arr in ipairs(tetrominoes[cur_tet]) do
		r = possible_x_range[cur_tet][rot_indx]

		for x = r[1], r[2] do
			tet = tetrominoes[cur_tet][rot_indx]

			-- the value we will add/subtract, NOT an index on it's own
			for y = -2, 19 do
				-- Checks for "tucks"
				--
				-- Number of possible locations without tucks (e.g. when the playfield is empty):
				--  9 -- O
				-- 17 -- I
				-- 17 -- Z, S
				-- 34 -- L, J, T
				if (not isColliding(pf, tet, x, y) and isColliding(pf, tet, x, y+1)) then
					table.insert(valid_resting_locations, {rot_indx, x, 999})
				end
			end
		end
	end

	return valid_resting_locations
end


function getBestMove(pf, cur_tet)
	possible_moves = enumerateMoves(pf, cur_tet)

	-- for i, v in ipairs(possible_moves) do
	-- 	print("rot = " .. v[1] .. ", x = " .. v[2] .. " y = " .. v[3])
	-- end

	print(#possible_moves)

	return {}
end


function tblCopy(tbl)
	to_return = {}
	
	for k, v in pairs(tbl) do
		to_return[k] = v
	end

	return to_return
end


btns = {up=nil, down=nil, right=nil, left=nil, A=nil, B=nil, start=nil, select=nil}
function resetInps()
	joypad.set(1, btns)
end


function execInps(move)
	-- joypad state
	jps = tblCopy(btns)

	for i, pressed in ipairs(move) do
		if (pressed == 'fall') then
			falling = true

			cur_tet_pre_fall_y = memory.readbyte(nes_ram_map.cur_tet_y)
		else
			jps[pressed] = true
		end
	end

	joypad.set(1, jps)
end


cur_tet = nil
new_tet_handled = false

-- queue of button(s) to be pressed for upcoming frames
inp_queue = {}

-- frame count (to limit input speed)
frm_count = 0
-- minimum frames between inputs
frms_between_inps = 5 -- at 60 hz = 12 joypad state changes per second

-- 2D playfield matrix (10 by 20)
pf = nil
-- true when we want to let a piece fall one gridcell without moving or rotating it
falling = false
-- used to keep track of when a tetromino falls one grid cell
cur_tet_pre_fall_pf = nil


function eachFrame()
	pf = scanPf()

	spawn_tet = getCurTet()
	
	-- new tetromino spawned, update cur_tet and pf
	if spawn_tet ~= cur_tet and new_tet_handled then
		pf = scanPf()
		new_tet_handled = false
	end

	-- handle cur_tet (only executes once for each tetromino)
	if spawn_tet ~= nil and not new_tet_handled then
		cur_tet = spawn_tet

		for i, inp in ipairs(getBestMove(pf, cur_tet)) do
			table.insert(inp_queue, #inp_queue+1, inp)
		end

		new_tet_handled = true
	end


	if (frm_count == 0) then
		if (falling) then
			cur_tet_y = memory.readbyte(nes_ram_map.cur_tet_y)
			
			if (cur_tet_y ~= cur_tet_pre_fall_y) then
				falling = false
			end
		elseif (#inp_queue ~= 0) then
			execInps(table.remove(inp_queue, 1))
		else
			resetInps()
		end
	end


	-- frm_count = (frm_count + 1) % frms_between_inps
end


emu.registerafter(eachFrame)