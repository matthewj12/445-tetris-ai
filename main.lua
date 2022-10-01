require("tetrominoes")


scale = 1

-- game screen top
gst = 8
-- tetromino block color (the first non-black pixel in the top-left)
tbc = {252, 252, 252}

-- play field start left
pfsl = scale * 96
-- play field start top
pfst = gst + (scale * 40)

-- tetromino start left
tsl = scale * 120
-- tetromino start top
tst = gst + (scale * 40)

-- tetromino block width (width of sub-blocks that make up tetromino)
tbw = scale * 8


-- datacrystal.romhacking.net/wiki/Tetris_(NES):RAM_map
nes_ram_map = {
	-- y position of the current tetromino
	cur_tet_y = 65,
	-- id of the current tetromino
	cur_tet_id = 66,
	-- play field top left
	pf_tl = 1024
}


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


function getBestMove(pf, cur_tet)
	local map = {
		I = {{'B'},          {'fall'}, {'A'}},
		T = {{'B', 'left'},  {'fall'}, {'A'}},
		O = {{'B', 'right'}, {'fall'}, {'A'}},
		Z = {{'A'},          {'fall'}, {'A'}},
		S = {{'A', 'left'},  {'fall'}, {'A'}},
		L = {{'A', 'right'}, {'fall'}, {'A'}},
		J = {{'A', 'right'}, {'fall'}, {'B'}}
	}

	return map[cur_tet]
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
	spawn_tet = getCurTet()
	
	-- new tetromino spawned, update cur_tet and pf
	if spawn_tet ~= cur_tet and new_tet_handled then
		pf = scanPf()
		new_tet_handled = false
	end

	-- handle cur_tet (only executes once for each tetromino)
	if spawn_tet ~= nil and not new_tet_handled then
		cur_tet = spawn_tet
		print(cur_tet)

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