--- Some functionality for grid-based stencils.

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
local assert = assert

-- Modules --
local bresenham = require("iterator_ops.grid.bresenham")
local iterator_utils = require("iterator_ops.utils")
local range = require("tektite_core.number.range")

-- Exports --
local M = {}

-- --
local Stencils = setmetatable({}, { __mode = "k" })

--- DOCME
-- @tparam Stencil stencil
-- @int[opt=0] midc
-- @int[opt=0] midr
-- @treturn int CMIN
-- @treturn int RMIN
-- @treturn int CMAX
-- @treturn int RMAX
function M.GetExtents (stencil, midc, midr)
	stencil, midc, midr = assert(Stencils[stencil], "Invalid stencil"), midc or 0, midr or 0

	return midc + stencil.cmin, midr + stencil.rmin, midc + stencil.cmax, midr + stencil.rmax
end

--- DOCME
-- @param stencil
-- @treturn boolean X
function M.IsStencil (stencil)
	return Stencils[stencil] ~= nil
end

--
local AuxIter = iterator_utils.InstancedAutocacher(function()
	local stencil, cx, cy, pos, n

	-- Body --
	return function()
		pos = pos + 2

		return cx + stencil[pos - 1], cy + stencil[pos]
	end,

	-- Done --
	function()
		return pos == n
	end,

	-- Setup --
	function(arr, col, row)
		stencil, cx, cy, pos, n = arr, col, row, 0, #arr
	end,

	-- Reclaim --
	function()
		stencil = nil
	end
end)

--- DOCME
-- @tparam Stencil stencil
-- @int[opt=0] col
-- @int[opt=0] row
-- @treturn iterator X
function M.StencilIter (stencil, col, row)
	return AuxIter(assert(Stencils[stencil], "Invalid stencil"), col or 0, row or 0)
end

--
local AuxIter_FromTo = iterator_utils.InstancedAutocacher(function()
	local coords, used, pos, n = {}, {}

	-- Body --
	return function()
		pos, used[coords[pos + 1]] = pos + 3

		return coords[pos - 1], coords[pos]
	end,

	-- Done --
	function()
		return pos == n
	end,

	-- Setup --
	function(stencil, c1, r1, c2, r2)
		pos, n = 0, 0

		local w = abs(c2 - c1) + stencil.cmax - stencil.cmin + 1 -- sweep width + stencil width - center pixel

		for cx, cy in bresenham.LineIter(c1, r1, c2, r2) do
			for i = 1, #stencil, 2 do
				local col, row = cx + stencil[i], cy + stencil[i + 1]
				local id = row * w + col

				if not used[id] then
					coords[n + 1], coords[n + 2], coords[n + 3], n, used[id] = id, col, row, n + 3, true
				end
			end
		end
	end,

	-- Reclaim --
	function()
		while pos < n do
			pos, used[coords[pos + 1]] = pos + 3
		end
	end
end)

--- DOCME
-- @tparam Stencil stencil
-- @int col1
-- @int row1
-- @int col2
-- @int row2
-- @treturn iterator X
function M.StencilIter_FromTo (stencil, col1, row1, col2, row2)
	stencil = assert(Stencils[stencil], "Invalid stencil")

	if col1 ~= col2 or row1 ~= row2 then
		return AuxIter_FromTo(stencil, col1, row1, col2, row2)
	else
		return AuxIter(stencil, col1, row1)
	end
end

--- DOCME
-- @array coords
-- @treturn Stencil X
function M.NewStencil (coords)
	--
	local pos, used, cmin, cmax, rmin, rmax = {}, {}

	for i = 1, #coords, 2 do
		local col, row = coords[i], coords[i + 1]
		local id = ("%ix%i"):format(col, row)

		if not used[id] then
			used[id] = true

			cmin, cmax = range.MinMax_New(cmin, cmax, col)
			rmin, rmax = range.MinMax_New(rmin, rmax, row)

			pos[#pos + 1] = col
			pos[#pos + 1] = row
		end
	end

	--
	local stencil = {}

	pos.cmin, pos.cmax = cmin, cmax
	pos.rmin, pos.rmax = rmin, rmax

	Stencils[stencil] = pos

	return stencil
end

-- Export the module.
return M