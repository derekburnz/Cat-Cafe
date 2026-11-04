--!strict
-- Where a camp's painted SAFE ZONE words go (#1132, pure geometry). Camp space: X across the camp, Z running into
-- the wild part, so the camp is z -CampDepth to 0 and the red stripe lies along z = STRIPE_Z. The words belong on the
-- camp side of the stripe (negative z). `fit` finds the widest words, then the one nearest the middle, then the
-- nearest the stripe, that keep GAP clear of every obstacle and of the stripe, and nil when nothing fits (the stripe
-- still marks the line).
local SafeWords = {}

export type Box = { x1: number, z1: number, x2: number, z2: number }
export type Spot = { x: number, z: number, width: number }

SafeWords.STRIPE_Z = -0.8 -- the stripe's middle in camp space
SafeWords.STRIPE_HALF = 0.25 -- half its thickness
SafeWords.GAP = 1 -- clear studs between the words and anything else
SafeWords.RATIO = 0.2 -- the plate's depth over its width
SafeWords.WIDTHS = { 12, 10, 8, 6 }
SafeWords.STEP = 0.5
SafeWords.MAX_DEPTH = 14 -- the words stay this near the stripe

local function overlaps(a: Box, b: Box, gap: number): boolean
	return a.x1 < b.x2 + gap and a.x2 > b.x1 - gap and a.z1 < b.z2 + gap and a.z2 > b.z1 - gap
end

-- `halfAcross`: half the camp's width (words stay inside it); `obstacles`: boxes in camp space.
function SafeWords.fit(obstacles: { Box }, halfAcross: number): Spot?
	local gap = SafeWords.GAP
	local nearEdge = SafeWords.STRIPE_Z - SafeWords.STRIPE_HALF - gap -- the words' edge nearest the stripe
	for _, width in SafeWords.WIDTHS do
		local depth = width * SafeWords.RATIO
		local reach = halfAcross - gap - width / 2
		if reach < 0 then
			continue -- the camp is too narrow for words this wide
		end
		local offsets: { number } = { 0 }
		local n = 1
		while n * 2 <= reach do
			table.insert(offsets, n * 2)
			table.insert(offsets, -n * 2)
			n += 1
		end
		for _, x in offsets do
			local shift = 0
			while nearEdge - shift - depth >= -SafeWords.MAX_DEPTH do
				local z = nearEdge - shift - depth / 2
				local words: Box = {
					x1 = x - width / 2,
					x2 = x + width / 2,
					z1 = z - depth / 2,
					z2 = z + depth / 2,
				}
				local clear = true
				for _, box in obstacles do
					if overlaps(words, box, gap) then
						clear = false
						break
					end
				end
				if clear then
					return { x = x, z = z, width = width }
				end
				shift += SafeWords.STEP
			end
		end
	end
	return nil
end

return SafeWords
