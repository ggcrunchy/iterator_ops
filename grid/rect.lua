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
local divide = require("tektite_core.number.divide")
local grid_funcs = require("tektite_core.array.grid")
local iterator_utils = require("iterator_ops.utils")

-- Imports --
local CellToIndex = grid_funcs.CellToIndex
local DivRem = divide.DivRem

-- Exports --
local M = {}

--- Iterator over a rectangular region on an array-based grid.
-- @function GridIter
-- @uint c1 Column index #1.
-- @uint r1 Row index #1.
-- @uint c2 Column index #2.
-- @uint r2 Row index #2.
-- @number dw Uniform cell width.
-- @number dh Uniform cell height.
-- @uint[opt=max(c1, c2)] ncols Number of columns in a grid row.
-- @treturn iterator Supplies the following, in order, at each iteration:
--
-- * Current iteration index.
-- * Array index, as per @{tektite_core.array.index.CellToIndex}.
-- * Column index.
-- * Row index.
-- * Cell corner x-coordinate, 0 at _c_ = 1.
-- * Cell corner y-coordinate, 0 at _r_ = 1.
-- @see iterator_ops.utils.InstancedAutocacher
M.GridIter = iterator_utils.InstancedAutocacher(function()
	local c1, r1, c2, r2, dw, dh, ncols, cw

	-- Body --
	return function(_, i)
		local dr, dc = DivRem(i, cw)

		dc = c2 < c1 and -dc or dc
		dr = r2 < r1 and -dr or dr

		local col = c1 + dc
		local row = r1 + dr

		return i + 1, CellToIndex(col, row, ncols), col, row, (col - 1) * dw, (row - 1) * dh
	end,

	-- Done --
	function(area, i)
		return i >= area
	end,

	-- Setup --
	function(...)
		c1, r1, c2, r2, dw, dh, ncols = ...
		ncols = ncols or max(c1, c2)
		cw = abs(c2 - c1) + 1

		return cw * (abs(r2 - r1) + 1), 0
	end
end)

-- Export the module.
return M