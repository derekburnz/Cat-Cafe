--!strict
-- The store's thank-you burst (#1823, the store remake; UI-Engineer calls it). Once the server confirms a Robux buy
-- (PassShop.changed or the pack's grant sync, never the prompt alone), the UI calls StoreBurst.play with the
-- bought card: sparkles fly out from round the card's edge and a ring grows from its middle, in the kind's colour. A
-- bundle (the King Cat bundle's reveal) gets more sparkles and a second, later ring. It draws on its own ScreenGui
-- just over the store window and never changes a UI object. Reduce Motion: half the sparkles, no rings. Low
-- performance: half the sparkles. Nothing random is sold through it; it only says thank you for what was bought.
-- Numbers in Presets.storeBurst.

local Context = require(script.Parent.Context)
local Presets = require(script.Parent.Presets)
local ScreenFx = require(script.Parent.ScreenFx)

local StoreBurst = {}

local GUI_NAME = "EffectsStore"

export type Kind = "pass" | "pack" | "bundle"

type KindSpec = { colour: Color3, sparkles: number, rings: number }

-- `count` spots evenly round the edge of a `size` box whose top left is `corner` (pixels).
local function edge(corner: Vector2, size: Vector2, count: number): { Vector2 }
	local spots: { Vector2 } = {}
	local around = 2 * (size.X + size.Y)
	if count <= 0 or around <= 0 then
		return spots
	end
	for i = 0, count - 1 do
		local d = (i + 0.5) / count * around
		local spot
		if d < size.X then
			spot = Vector2.new(d, 0)
		elseif d < size.X + size.Y then
			spot = Vector2.new(size.X, d - size.X)
		elseif d < 2 * size.X + size.Y then
			spot = Vector2.new(size.X - (d - size.X - size.Y), size.Y)
		else
			spot = Vector2.new(0, size.Y - (d - 2 * size.X - size.Y))
		end
		table.insert(spots, corner + spot)
	end
	return spots
end

-- The thank-you burst round `card` (the bought item's card or button) for a `kind` buy; an unknown kind plays as a
-- pass. Nothing happens for a card that isn't on screen.
function StoreBurst.play(card: GuiObject, kind: string?)
	local s = Presets.storeBurst
	local kinds: { [string]: KindSpec } = s.kinds :: any
	local spec: KindSpec? = kinds[kind or "pass"]
	if not spec then
		spec = kinds.pass
	end
	local k = spec :: KindSpec
	if not ScreenFx.shown(card) then
		return
	end
	local gui = ScreenFx.gui(GUI_NAME, s.displayOrder)
	if gui == nil then
		return
	end
	local still = Context.reducedMotion()
	local count = k.sparkles
	if still or Context.lowPerformance then
		count = math.ceil(count / 2)
	end
	local size = card.AbsoluteSize
	local corner = ScreenFx.toGui(gui, card.AbsolutePosition)
	local reach = math.clamp(math.min(size.X, size.Y) * s.reach, s.reachMin, s.reachMax)
	ScreenFx.sparkle(
		gui,
		edge(corner, size, count),
		k.colour,
		{ size = s.size, seconds = s.seconds, reach = reach, stagger = s.stagger }
	)
	if still then
		return
	end
	local middle = ScreenFx.centre(gui, card)
	local across = math.max(size.X, size.Y)
	for ring = 1, k.rings do
		task.delay((ring - 1) * s.ringGap, function()
			ScreenFx.ring(
				gui,
				middle,
				across * s.ringFrom,
				across * s.ringTo,
				k.colour,
				s.ringSeconds
			)
		end)
	end
end

return StoreBurst
