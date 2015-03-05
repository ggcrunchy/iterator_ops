--- Some ellipse-based iterators over grid regions.

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
local floor = math.floor

-- Modules --
local iterator_utils = require("iterator_ops.utils")

-- Cached module references --
local _EllipseQuadrant_

-- Exports --
local M = {}

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

-- Cache module members --
_EllipseQuadrant_ = M.EllipseQuadrant

-- Export the module.
return M