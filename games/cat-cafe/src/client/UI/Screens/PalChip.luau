--!strict
-- The HUD's pal chip (F92, playing-together.md section 2): while pals are on your server it closes the potion timers'
-- row over the money (Screens/BuffChips), in their look with no panel behind it: up to three round headshots that
-- overlap, a "+2" tile for more, and "+10% with pals" (two or more: "+15% with pals") in outlined white. It shows nothing
-- with no pals, so a solo player never sees a missing bonus. A tap opens the money's boosts card, where "Pals (2)"
-- has its row. The list comes from PalsChanged through UI.pals (Components/PalsLogic cleans it).
--
-- Roblox terms: an "rbxthumb://" image is Roblox's own picture of a player's avatar head, loaded by user id.

local Create = require(script.Parent.Parent.Components.Create)
local Outline = require(script.Parent.Parent.Components.Outline)
local PalsLogic = require(script.Parent.Parent.Components.PalsLogic)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)

export type PalChip = {
	chip: TextButton,
	set: (self: PalChip, userIds: { number }) -> (),
	count: (self: PalChip) -> number,
	destroy: (self: PalChip) -> (),
}

local TILE = 28 -- the potion chips' tile
local OVERLAP = 18 -- each next headshot starts this far right of the one before

local PalChip = {}
PalChip.__index = PalChip

-- `row`: the potion timers' row (BuffChips.frame); `onShown` hears when the chip shows or hides (the row stays up
-- for it), `onTap` when it is pressed.
function PalChip.new(row: Frame, onShown: (shown: boolean) -> (), onTap: () -> ()): PalChip
	local self = setmetatable({}, PalChip) :: any
	self._onShown = onShown
	self._ids = {} :: { number }
	self._said = ""

	local chip: TextButton = Create("TextButton", {
		Name = "Pals",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, Scale.tapHeight(36)),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 100, -- after the Luck chip and every potion timer
		Visible = false,
		Parent = row,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self._faces = Create("Frame", {
		Name = "Faces",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(TILE, TILE),
		LayoutOrder = 1,
		Parent = chip,
	}) :: Frame
	self._text = Create("TextLabel", {
		Name = "Bonus",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 30),
		FontFace = Theme.fonts.display,
		TextSize = 18,
		TextColor3 = Theme.colors.white,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		LayoutOrder = 2,
		Parent = chip,
	}) :: TextLabel
	Outline.text(self._text, 2)
	chip.Activated:Connect(function()
		onTap()
	end)
	self.chip = chip
	return self :: PalChip
end

function PalChip.count(self: any): number
	return #self._ids
end

function PalChip.set(self: any, userIds: { number })
	local words = PalsLogic.chip(#userIds)
	local key = table.concat(userIds, ",")
	if key == self._said then
		return
	end
	self._said = key
	local was = #self._ids > 0
	self._ids = table.clone(userIds)
	for _, child in self._faces:GetChildren() do
		child:Destroy()
	end
	local shown, more = PalsLogic.faces(userIds)
	for index, userId in shown do
		local face: ImageLabel = Create("ImageLabel", {
			Name = "Face" .. index,
			BackgroundColor3 = Theme.colors.cream,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset((index - 1) * OVERLAP, 0),
			Size = UDim2.fromOffset(TILE, TILE),
			Image = PalsLogic.headshot(userId),
			ZIndex = 2 + #shown - index, -- the first pal's face on top, the "+2" tile under the last
			Parent = self._faces,
		}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		Outline.border(face, 2)
	end
	local tiles = #shown
	if more > 0 then
		-- "+2" in a dark round tile at the end of the stack, as one more face
		local count: TextLabel = Create("TextLabel", {
			Name = "More",
			BackgroundColor3 = Theme.hud.panel,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(#shown * OVERLAP, 0),
			Size = UDim2.fromOffset(TILE, TILE),
			FontFace = Theme.fonts.display,
			TextSize = 13,
			TextColor3 = Theme.colors.white,
			Text = "+" .. more,
			ZIndex = 1,
			Parent = self._faces,
		}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		Outline.border(count, 2)
		tiles += 1
	end
	self._faces.Size = UDim2.fromOffset(TILE + math.max(0, tiles - 1) * OVERLAP, TILE)
	self._text.Text = words or ""
	local now = words ~= nil
	self.chip.Visible = now
	if now and not was then
		Tween.popIn(self.chip, 0.8)
	end
	if now ~= was then
		self._onShown(now)
	end
end

function PalChip.destroy(self: any)
	self.chip:Destroy()
end

return PalChip
