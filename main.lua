require("tetrominoes")
require("utilFuncs")
require("aiFuncs")


local function main()
	-- 10 by 20 2D matrix representing the game's playfield
	local pf = nil
	local cur_tet = nil


	local frame_counter = 1
	-- key = frame to update the joypad buttons, value = table with state of each joypad button
	local joypad_states = {}
	local new_tet_handled = false

	-- Is called oncer after every NES frame
	local function eachFrame()
		pf = scanPf()

		-- https://datacrystal.romhacking.net/wiki/Tetris_(NES):RAM_map
		local game_state = memory.readbyte(0x48)

		-- If the main game screen is currently active rather than the game being over, being on the level select screen, etc.
		if game_state ~= 0x0 and game_state ~= 0xA and #pf == 20 then
			local spawn_tet = getCurTet()

			-- new tetromino spawned
			if new_tet_handled and spawn_tet ~= cur_tet then
				new_tet_handled = false
			end

			-- handle cur_tet (only executes once for each tetromino)
			-- spawn_tet is nil during the line-clear animation
			if not new_tet_handled and spawn_tet ~= nil then
				new_tet_handled = true
				cur_tet = spawn_tet
				frame_counter = 1


				t0 = os.clock()

				-- getBestMove arguments: pf, cur_tet, cur_depth, max_depth, debug
				joypad_states = generateJoypadStates(getBestMove(pf, cur_tet, 0, 2, true))
				
				t1 = os.clock()
				print("seconds elapsed: " .. (t1 - t0))
			end

			-- Update the joypad state when the correct time/frame comes
			if joypad_states[frame_counter] ~= nil then
				-- The "1" means "player 1's joypad"
				joypad.set(1, joypad_states[frame_counter])
			end

			frame_counter = frame_counter + 1
		end
	end


	emu.registerafter(eachFrame)
end


main()