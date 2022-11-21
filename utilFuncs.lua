-- Returns a deep copy of the given 1-dimensional table/array
function d1TblCopy(orig_tbl)
	local new_tbl = {}

	for i, val in pairs(orig_tbl) do
		new_tbl[i] = val
	end

	return new_tbl
end


-- Returns a deep copy of the given 2-dimensional table/array
function d2TblCopy(orig_tbl)
	local new_tbl = {}

	for i, row in pairs(orig_tbl) do
		local row_copy = {}

		for j, val in pairs(row) do
			row_copy[j] = val
		end

		table.insert(new_tbl, row_copy)
	end

	return new_tbl
end
