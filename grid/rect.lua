--- Some iterators over rectangular grid regions.

--
-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:
--
-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
-- CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
-- TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
-- SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--
-- [ MIT license: http://www.opensource.org/licenses/mit-license.php ]
--

-- Standard library imports --
local abs = math.abs
local max = math.max

-- Modules --
local iterator_utils = require("iterator_ops.utils")

-- Exports --
local M = {}

--
--
--

--- Iterator over a rectangular region on an array-based grid.
-- @function GridIter
-- @uint c1 Column index #1.
-- @uint r1 Row index #1.
-- @uint c2 Column index #2.
-- @uint r2 Row index #2.
-- @uint[opt=max(c1, c2)] ncols Number of columns in a grid row.
-- @treturn iterator Supplies the following, in order, at each iteration:
--
-- * Current iteration index.
-- * Array index, as per @{tektite_core.array.grid.CellToIndex}.
-- * Column index.
-- * Row index.
-- @see iterator_ops.utils.InstancedAutocacher
M.GridIter = iterator_utils.InstancedAutocacher(function()
	local cbase, cto, col, row, dc, dr, to_cbase

	-- Body --
	return function(_, cell_index)
		if col == cto then
			col, row, cell_index = cbase, row + dr, cell_index + to_cbase
		else
			cell_index = cell_index + dc
		end

		col = col + dc

		return cell_index, col, row
	end,

	-- Done --
	function(last_cell, cell_index)
		return cell_index == last_cell
	end,

	-- Setup --
	function(C1, R1, C2, R2, ncols)
		dc, dr = C1 < C2 and 1 or -1, R1 < R2 and 1 or -1
		cbase = C1 - dc -- start each row off-by-one
		col, cto, ncols, row = cbase, C2, ncols or max(C1, C2), R1
		to_cbase = dr * (ncols - abs(C2 - C1)) -- spaces from C2 to cbase in next row

		return (R2 - 1) * ncols + C2, (R1 - 1) * ncols + cbase
	end
end)

return M