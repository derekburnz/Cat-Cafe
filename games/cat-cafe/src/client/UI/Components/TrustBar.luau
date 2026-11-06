--!strict
-- Catch v3's trust bar (#1884, catch-rework.md 7b): a short pill over the cat being caught, a heart then a bar that
-- fills toward the rarity's trustNeed with each press (Components/CatchTrust). It turns gold when full and empties
-- red when the cat bolts. Only the catching player sees it: the billboard lives in their PlayerGui.
--
-- Roblox terms: a BillboardGui is 2D UI drawn at a point in the 3D world, always facing the camera; Adornee is the
-- part it hangs from, and StudsOffsetWorldSpace lifts it that many studs.
--
--   TrustBar.new(parent)                 the billboard (hidden)
--   bar:show(model, trust, need)         hang it over `model` (its top, plus LIFT studs) at that trust
--   bar:set(trust, need)                 slide the fill to a new trust
--   bar:finish(caught)                   gold when caught, red when it bolted
--   bar:hide(), bar:destroy()

local CatchTrust = require(script.Parent.CatchTrust)
local Create = require(script.Parent.Create)
local Outline = require(script.Parent.Outline)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Tween)

export type TrustBar = {
	gui: BillboardGui,
	fill: Frame,
	show: (self: TrustBar, model: Model?, trust: number, need: number) -> (),
	set: (self: TrustBar, trust: number, need: number) -> (),
	finish: (self: TrustBar, caught: boolean) -> (),
	hide: (self: TrustBar) -> (),
	destroy: (self: TrustBar) -> (),
}

local TrustBar = {}
TrustBar.__index = TrustBar

TrustBar.LIFT = 1.4 -- studs over the top of the cat, clear of the rings round its head
TrustBar.WIDTH = 132
TrustBar.HEIGHT = 26
local HEART = 22
local SLIDE = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local FILL_COLOR = Color3.fromHex("FF8FB1") -- a warm pink, the purr
local EMPTY_COLOR = Theme.colors.outline

function TrustBar.new(parent: Instance): TrustBar
	local self = setmetatable({}, TrustBar) :: any
	local gui: BillboardGui = Create("BillboardGui", {
		Name = "CatchTrustBar",
		Size = UDim2.fromOffset(TrustBar.WIDTH, TrustBar.HEIGHT),
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 120,
		ResetOnSpawn = false,
		Enabled = false,
		Parent = parent,
	})
	local heart: TextLabel = Create("TextLabel", {
		Name = "Heart",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(HEART, HEART),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Text = "💗",
		TextScaled = true,
		Parent = gui,
	})
	local track: Frame = Create("Frame", {
		Name = "Track",
		BackgroundColor3 = EMPTY_COLOR,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, HEART + 4, 0.5, 0),
		Size = UDim2.new(1, -(HEART + 6), 0, 14),
		Parent = gui,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(track, 2)
	local fill: Frame = Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = FILL_COLOR,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = track,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	self.gui = gui
	self.fill = fill
	self._heart = heart
	return self :: TrustBar
end

-- The top of the model: its bounding box's top over its main part, so a lying or sitting cat still gets it overhead.
local function anchor(model: Model): (BasePart?, number)
	local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if part == nil then
		return nil, 0
	end
	local box, size = model:GetBoundingBox()
	return part :: BasePart, box.Position.Y + size.Y / 2 - (part :: BasePart).Position.Y
end

function TrustBar.show(self: any, model: Model?, trust: number, need: number)
	local part, lift = nil, 0
	if model ~= nil then
		part, lift = anchor(model)
	end
	self.gui.Adornee = part
	self.gui.StudsOffsetWorldSpace = Vector3.new(0, lift + TrustBar.LIFT, 0)
	self.fill.BackgroundColor3 = FILL_COLOR
	self.fill.Size = UDim2.fromScale(CatchTrust.fill(trust, need), 1)
	self.gui.Enabled = part ~= nil
end

function TrustBar.set(self: any, trust: number, need: number)
	Tween.to(self.fill, SLIDE, { Size = UDim2.fromScale(CatchTrust.fill(trust, need), 1) })
end

function TrustBar.finish(self: any, caught: boolean)
	if caught then
		self.fill.BackgroundColor3 = Theme.colors.gold
		Tween.to(self.fill, SLIDE, { Size = UDim2.fromScale(1, 1) })
	else
		self.fill.BackgroundColor3 = Theme.colors.red
		Tween.to(self.fill, SLIDE, { Size = UDim2.fromScale(0, 1) })
	end
end

function TrustBar.hide(self: any)
	self.gui.Enabled = false
	self.gui.Adornee = nil
end

function TrustBar.destroy(self: any)
	self.gui:Destroy()
end

return TrustBar
