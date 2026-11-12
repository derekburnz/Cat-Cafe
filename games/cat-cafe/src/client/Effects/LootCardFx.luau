--!strict
-- The pop-in of a loot card (#3464, the Rummage Bin's "You found:" card; any card of rows can use it). The UI builds
-- the card and owns its words, icons, place and closing; this only moves it:
--   LootCardFx.play(card, rows, icons)
-- The card scales in from a little small with one soft overshoot (the toast's pop), then the rows land one after
-- the other, `gap` seconds apart, each row's icon giving one small bounce as it lands. `rows` are the row objects top
-- to bottom and `icons[i]` is row i's icon (or nil). A row waits hidden (Visible false) until its turn, so give the
-- card a size that does not depend on which rows show.
-- Reduce Motion: everything shows at once and nothing moves. A card that is closed or destroyed part way just stops;
-- every row is left visible, so a quick tap never leaves a half drawn card behind. Calling it again on the same card
-- starts over. No particles, no sound, nothing sent anywhere. Numbers in Presets.lootCard.

local RunService = game:GetService("RunService")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local MouseDashFx = require(script.Parent.MouseDashFx)
local Presets = require(script.Parent.Presets)

local LootCardFx = {}

local playing: { [GuiObject]: RBXScriptConnection } = {}

-- Pure: the card's scale `t` seconds in: from `from` up to 1 with one soft overshoot, then exactly 1.
function LootCardFx.cardScale(t: number): number
	local p = Presets.lootCard
	if t >= p.popSeconds then
		return 1
	end
	return p.from + (1 - p.from) * Logic.easeOutBack(math.max(t, 0) / p.popSeconds)
end

-- Pure: when row `i` (1 at the top) lands, in seconds after the card starts.
function LootCardFx.rowAt(i: number): number
	local p = Presets.lootCard
	return p.firstRow + (math.max(i, 1) - 1) * p.gap
end

-- Pure: how many of `count` rows have landed `t` seconds in.
function LootCardFx.landed(t: number, count: number): number
	local p = Presets.lootCard
	if t < p.firstRow then
		return 0
	end
	return math.clamp(math.floor((t - p.firstRow) / p.gap) + 1, 0, math.max(count, 0))
end

-- Pure: the whole pop-in's seconds for `count` rows, the last icon's bounce included.
function LootCardFx.seconds(count: number): number
	local p = Presets.lootCard
	return math.max(p.popSeconds, LootCardFx.rowAt(math.max(count, 1)) + p.bounceSeconds)
end

local function scaleOf(object: GuiObject): UIScale
	local found = object:FindFirstChild("FxScale")
	if found ~= nil and found:IsA("UIScale") then
		return found :: UIScale
	end
	local made = Instance.new("UIScale")
	made.Name = "FxScale"
	made.Parent = object
	return made
end

local function showAll(rows: { GuiObject })
	for _, row in rows do
		if row.Parent ~= nil then
			row.Visible = true
		end
	end
end

function LootCardFx.play(card: GuiObject, rows: { GuiObject }, icons: { [number]: GuiObject }?)
	local old: RBXScriptConnection? = playing[card]
	if old then
		old:Disconnect()
		playing[card] = nil
	end
	if Context.reducedMotion() then
		showAll(rows)
		return
	end
	local set: { [number]: GuiObject } = icons or {}
	local scale = scaleOf(card)
	scale.Scale = LootCardFx.cardScale(0)
	for _, row in rows do
		row.Visible = false
	end
	local began = os.clock()
	local whole = LootCardFx.seconds(#rows)
	local shown = 0
	local loop: RBXScriptConnection
	loop = RunService.RenderStepped:Connect(function()
		local t = os.clock() - began
		if card.Parent == nil or not card.Visible or t >= whole then
			loop:Disconnect()
			if playing[card] == loop then
				playing[card] = nil
			end
			if scale.Parent ~= nil then
				scale.Scale = 1
			end
			showAll(rows)
			return
		end
		scale.Scale = LootCardFx.cardScale(t)
		local now = LootCardFx.landed(t, #rows)
		while shown < now do
			shown += 1
			local row = rows[shown]
			if row.Parent ~= nil then
				row.Visible = true
				local icon: GuiObject? = set[shown]
				if icon and icon.Parent ~= nil then
					MouseDashFx.bounce(icon, "pop")
				end
			end
		end
	end)
	playing[card] = loop
end

return LootCardFx
