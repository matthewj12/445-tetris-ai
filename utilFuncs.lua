-- returns true if all the values in both arrays are equal
function d1TblsEq(a, b)
	for i = 1, #a do
		if a[i] ~= b[i] then
			return false
		end
	end

	return true
end


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


function avgTblVal(tbl)
	local sum = 0
	local len = 0

	for key, val in pairs(tbl) do
		sum = sum + val
		len = len + 1
	end

	return sum / len
end


-- precision specifies the number of digits after the decimal point to keep
function truncateNum(num, precision)
	local x = 10 ^ precision

	return math.floor(num * x) / x
end


function generateIndentation(width)
	local indentation = ''

	for i = 1, width do
		indentation = indentation .. '\t'
	end

	return indentation
end


