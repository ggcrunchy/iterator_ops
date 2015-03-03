--- Some iterators for grids.

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
local floor = math.floor
local max = math.max

-- Modules --
local divide = require("tektite_core.number.divide")
local grid_funcs = require("tektite_core.array.grid")
local iterator_utils = require("iterator_ops.utils")

-- Imports --
local CellToIndex = grid_funcs.CellToIndex
local DivRem = divide.DivRem

-- Cached module references --
local _CircleOctant_
local _EllipseQuadrant_

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

-- Per-quadrant coordinate symmetry functions --
local QuadFunc = {
	-- (+x, +y) --
	function(coords, i)
		return coords[i - 1], coords[i] -- indices are 0-based
	end,

	-- (-x, +y) --
	function(coords, i, n)
		local yi = n - i + 2 -- account for size

		return -coords[yi - 1], coords[yi]
	end,

	-- (-x, -y) --
	function(coords, i)
		return -coords[i + 1], -coords[i + 2] -- skip first index (done in quadrant 2)
	end,

	-- (+x, -y) --
	function(coords, i, n)
		local yi = n - i + 4 -- account for size

		return coords[yi - 1], -coords[yi]
	end
}

--- DOCME
M.Ellipse = iterator_utils.InstancedAutocacher(function()
	local coords, qi, qfunc, i, n = {}

	-- Body --
	return function()
		i = i + 2

		return qfunc(coords, i, n)
	end,

	-- Done --
	function()
		if i == n then
			if n == 0 or qi == 4 then
				return true
			else
				qi, i = qi + 1, 0
				qfunc = QuadFunc[qi]

				if qi == 2 or qi == 3 then
					n = n - 2
				else
					n = n + 2
				end
			end
		end
	end,

	-- Setup --
	function(a, b)
		qi, i, n = 0, 0, 0

		for x, y in _EllipseQuadrant_(a, b) do
			coords[n + 1], coords[n + 2], n = x, y, n + 2
		end

		coords[n + 1], coords[n + 2] = 0, -b -- n incremented in done()

		i = n -- trigger a quadrant switch immediately
	end
end)

--- DOCME
-- Compare: https://web.archive.org/web/20120225095359/http://homepage.smc.edu/kennedy_john/belipse.pdf (might be the same algorithm; looks close, anyhow)
M.EllipseQuadrant = iterator_utils.InstancedAutocacher(function()
	local x, y, ax, ay, diff, dline, ddiag, asqr, bsqr, inc, sum

	-- Body --
	return function()
		local xwas, ywas, inc_diag, same = x, y

		--
		if ax > ay then
			if diff > 0 then
				x, ax, inc_diag = x - 1, ax - bsqr, true
			end

			y, ay = y - 1, ay + asqr
			same = ax > ay

		--
		else
			if diff < 0 then
				y, inc_diag = y - 1, true
			end

			x = x - 1
		end

		--
		if inc_diag then
			diff = diff + ddiag
			ddiag = ddiag + sum
		else
			diff = diff + dline
			ddiag = ddiag + inc
		end

		--
		if same then
			dline = dline + inc
		else
			dline, inc = bsqr * (1 - 2 * x), sum - inc
		end

		return xwas, ywas
	end,

	-- Done --
	function()
		return x == 0
	end,

	-- Setup --
	function(a, b)
		x, y, asqr, bsqr = a, 0, a^2, b^2
		inc, ax, ay = 2 * asqr, bsqr * x, 0
		sum = inc + 2 * bsqr

		local init = -2 * bsqr * x

		diff = floor(.25 * (init + inc + asqr))
		dline, ddiag = 3 * asqr, init + inc + bsqr
	end
end)

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

--- Iterator over a line on the grid, using Bresenham's algorithm.
-- @function LineIter
-- @int col1 Start column.
-- @int row1 Start row.
-- @int col2 End column.
-- @int row2 End row.
-- @treturn iterator Supplies column, row at each iteration, in order.
M.LineIter = iterator_utils.InstancedAutocacher(function()
	local adx, ady, curx, cury, endx, err, steep, xstep, ystep

	-- Body --
	return function()
		local x, y = curx, cury

		curx = curx + xstep

		if steep then
			x, y = y, x 
		end

		err = err - ady

		if err < 0 then
			err = err + adx
			cury = cury + ystep
		end

		return x, y
	end,

	-- Done --
	function()
		return curx == endx
	end,

	-- Setup --
	function(x1, y1, x2, y2)
		steep = abs(y2 - y1) > abs(x2 - x1)

		if steep then
			x1, y1 = y1, x1
			x2, y2 = y2, x2
		end

		adx = abs(x2 - x1)
		ady = abs(y2 - y1)
		curx = x1
		cury = y1
		err = floor(adx / 2)

		xstep = x1 <= x2 and 1 or -1
		ystep = y1 <= y2 and 1 or -1

		endx = x2 + xstep
	end
end)

do
	-- Has the (possibly degenerate) triangle been traversed?
	local function Done (yend, y)
		return y and y >= yend
	end

	-- Helper to get initial values for a given edge
	local function GetValues (edge)
		local dx, dy = edge.dx, edge.dy

		return dx, dy, DivRem(dx, dy)
	end

	--- Iterator over a triangle on the grid.
	-- @function TriangleIter
	-- @int x1 Column of point #1.
	-- @int y1 Row of point #1.
	-- @int x2 Column of point #2.
	-- @int y2 Row of point #2.
	-- @int x3 Column of point #3.
	-- @int y3 Row of point #3.
	-- @treturn iterator Supplies row, left and right column at each iteration, top to bottom.
	M.TriangleIter = iterator_utils.InstancedAutocacher(function()
		local long, top, low = {}, {}, {}
		local ymid, ledge, redge, lnumer, rnumer, ldx, ldy, lconst, lmod, rdx, rdy, rconst, rmod

		-- Body --
		return function(yend, y)
			local x1, x2 = ledge, redge

			if y then
				y = y + 1

				-- If both current edges are vertical, the third is as well, and updating
				-- the edges can be ignored; otherwise, increment each edge. When the middle
				-- row is crossed, switch the non-long edge state from top to low.
				if ldx ~= 0 or rdx ~= 0 then
					if y == ymid then
						if ldy < rdy then
							ldx, ldy, lconst, lmod = GetValues(low)
						else
							rdx, rdy, rconst, rmod = GetValues(low)
						end
					end

					ledge, lnumer = ledge + lconst + floor((lnumer % ldy + lmod) / ldy), lnumer + ldx
					redge, rnumer = redge + rconst + floor((rnumer % rdy + rmod) / rdy), rnumer + rdx
				end
			end

			return y or yend, x1, x2
		end,

		-- Done --
		Done,

		-- Setup --
		function(x1, y1, x2, y2, x3, y3)
			-- Sort the points from top to bottom.
			if y1 > y2 then
				x1, y1, x2, y2 = x2, y2, x1, y1
			end

			if y2 > y3 then
				x2, y2, x3, y3 = x3, y3, x2, y2
			end

			if y1 > y2 then
				x1, y1, x2, y2 = x2, y2, x1, y1
			end

			-- Sort any points on the same row left to right. Mark the middle row.
			if y1 == y2 and x2 < x1 then
				x1, x2 = x2, x1
			end

			if y2 == y3 and x3 < x2 then
				x2, x3 = x3, x2
			end

			ymid = y2

			-- Get the edge deltas: x-deltas are signed, y-deltas are positive whenever put
			-- to use (this is ensured by the one-row special case and middle row test).
			long.dx, long.dy = x3 - x1, y3 - y1
			top.dx, top.dy = x2 - x1, y2 - y1
			low.dx, low.dy = x3 - x2, y3 - y2

			-- Compute the initial edge states. If the low slope is less than the top
			-- slope, the triangle is left-oriented (i.e. the long edge is on the right,
			-- the other two on the left), otherwise right-oriented.
			local lvals, rvals = long, top

			if top.dx * low.dy < low.dx * top.dy then
				lvals, rvals = top, long
			end

			lnumer, ldx, ldy, lconst, lmod = -1, GetValues(lvals)
			rnumer, rdx, rdy, rconst, rmod = -1, GetValues(rvals)

			-- Get the initial edges. If the top row has width, the right edge begins at the
			-- rightmost x-coordinate; otherwise, both edges issue from the same x.
			ledge, redge = x1, y1 ~= y3 and (y1 ~= y2 and x1 or x2) or x3

			-- Iterate until the last row. Handle the case of a one-row triangle.
			return y3, long.dy > 0 and y1 - 1
		end
	end)
end

-- Cache module members --
_CircleOctant_ = M.CircleOctant
_EllipseQuadrant_ = M.EllipseQuadrant

-- Export the module.
return M