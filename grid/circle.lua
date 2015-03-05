--- Some circle-based iterators over grid regions.

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

-- Cached module references --
local _CircleOctant_

-- Exports --
local M = {}

-- --
local OctantFunc = {
	--
}

--- DOCME
M.Circle = iterator_utils.InstancedAutocacher(function()
	local coords, oi, ofunc, i, n = {}

	-- Body --
	return function()
		i = i + 2

		return ofunc(coords, i, n)
	end,

	-- Done --
	function()
		if i == n then
			if n == 0 or oi == 8 then
				return true
			else
				oi, i = oi + 1, 0
				ofunc = OctantFunc[oi]
--[[
				if qi == 2 or qi == 3 then
					n = n - 2
				else
					n = n + 2
				end
]]
			end
		end
	end,

	-- Setup --
	function(radius)
		oi, i, n = 0, 0, 0

		for x, y in _CircleOctant_(radius) do
			coords[n + 1], coords[n + 2], n = x, y, n + 2
		end

		coords[n + 1], coords[n + 2] = 0, -radius -- n incremented in done()

		i = n -- trigger an octant switch immediately
	end
end)

--- Iterator over a circular octant, from 0 to 45 degrees (approximately), using a variant
-- of the midpoint circle method.
-- @function CircleOctant
-- @int radius Circle radius.
-- @treturn iterator Supplies column, row at each iteration, in order.
M.CircleOctant = iterator_utils.InstancedAutocacher(function()
	local x, y, diff

	-- Body --
	return function()
		y = y + 1

		if y > 0 then
			x = x - 1
			diff = diff + y - x

			if diff < 0 then
				diff = diff + x
				x = x + 1
			end
		else
			x = x + 1
		end

		return x, y
	end,

	-- Done --
	function()
		return x <= y
	end,

	-- Setup --
	function(radius)
		x, y, diff = radius - 1, -1, 0
	end
end)

--- DOCME
M.CircleSpans = iterator_utils.InstancedAutocacher(function()
	local edges, row = {}

	-- Body --
	return function()
		local ri, edge = row, edges[abs(row) + 1]

		row = row + 1

		if ri >= 0 then
			edges[row] = 0
		end

		return ri, edge
	end,

	-- Done --
	function(radius)
		return row > radius
	end,

	-- Setup --
	function(radius, width)
		--
		local xc, yc, xp, yp, dx = -1, 0, radius, 0, width or 1

		if dx ~= 1 then
			xp = xp * dx
		end

		--
		for x, y in _CircleOctant_(radius) do
			if x ~= xc then
				xc, xp = x, xp - dx
			end

			if y ~= yc then
				yc, yp = y, yp + dx
			end

			edges[x + 1] = max(edges[x + 1] or 0, yp)
			edges[y + 1] = max(edges[y + 1] or 0, xp)
		end

		row = -radius

		return radius
	end,

	-- Reclaim --
	function(radius)
		for i = max(row, 0), radius do
			edges[i + 1] = 0
		end
	end
end)

-- Cache module members --
_CircleOctant_ = M.CircleOctant

-- Export the module.
return M