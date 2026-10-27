--!strict
-- Safe zone chip (UI plan 2026-10-27; Derek: "if you get back to the area with the cafes that can be considered
-- safe"): a small pill under the cafe tier pill at the top centre. On the street and in the cafes it reads
-- "🛡️ Safe zone" in green; in a catching area "🐾 Catching area · tackles on" in orange. Walking back from an area
-- pops it, and init toasts "Safe zone: no shoving here". Hidden until the controller first calls UI.setZone.

local Create = require(script.Parent.Parent.Components.Create)
local Outline = require(script.Parent.Parent.Components.Outline)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)
local Wayfinding = require(script.Parent.Parent.Components.Wayfinding)

export type ZoneChip = {
	-- returns true when the player just walked from a catching area into the safe zone
	set: (self: ZoneChip, zone: string?) -> boolean,
	setVisible: (self: ZoneChip, visible: boolean) -> (),
	destroy: (self: ZoneChip) -> (),
}

local TOP = 16 + 56 + 8 -- under the HUD's tier pill (HUD MARGIN + CAFE_HEIGHT + gap)
local HEIGHT = 30
local SAFE_TEXT = "🛡️ Safe zone"
local AREA_TEXT = "🐾 Catching area · tackles on"

local ZoneChip = {}
ZoneChip.__index = ZoneChip

function ZoneChip.new(parent: Instance): ZoneChip
	local self = setmetatable({}, ZoneChip) :: any
	local screenGui: ScreenGui = Create("ScreenGui", {
		Name = "CatCafeZoneChip",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 10, -- with the HUD
		Parent = parent,
	})
	self.screenGui = screenGui
	local root: Frame = Create("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = screenGui,
	})
	self._uiScale = Scale.bind(root)
	local chip: TextLabel = Create("TextLabel", {
		Name = "Zone",
		BackgroundColor3 = Theme.colors.good,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, TOP),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, HEIGHT),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textSmall + 1,
		TextColor3 = Theme.colors.white,
		Text = SAFE_TEXT,
		Visible = false,
		Parent = root,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }),
	})
	Outline.border(chip, Theme.sizes.outline)
	Outline.text(chip, 1.5)
	self._chip = chip
	self._known = false
	self._safe = true
	return self :: ZoneChip
end

function ZoneChip.set(self: any, zone: string?): boolean
	local safe = Wayfinding.isSafe(zone)
	local known: boolean = self._known
	local wasSafe: boolean = self._safe
	local cameBack = known and safe and not wasSafe
	local changed = not known or safe ~= wasSafe
	self._known = true
	self._safe = safe
	local chip: TextLabel = self._chip
	chip.Visible = true
	chip.Text = if safe then SAFE_TEXT else AREA_TEXT
	chip.BackgroundColor3 = if safe then Theme.colors.good else Theme.colors.warn
	if changed then
		Tween.popIn(chip, 0.85)
	end
	return cameBack
end

function ZoneChip.setVisible(self: any, visible: boolean)
	self.screenGui.Enabled = visible
end

function ZoneChip.destroy(self: any)
	Scale.unbind(self._uiScale)
	self.screenGui:Destroy()
end

return ZoneChip
