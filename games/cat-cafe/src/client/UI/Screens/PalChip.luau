--!strict
-- The HUD's pal chip (F92, playing-together.md section 2): while pals are on your server, up to three round headshots
-- that overlap, a "+2" tile for more, and "+10% with pals" (two or more: "+15% with pals") in outlined white, with no
-- panel behind it. It shows nothing with no pals, so a solo player never sees a missing bonus. The list comes from
-- PalsChanged through UI.pals (Components/PalsLogic cleans it).
-- On a PC it closes the potion timers' row over the money (Screens/BuffChips), and a tap opens the money's boosts
-- card, where "Pals (2)" has its row.
-- #3052 (Derek2 11-10: "sometimes ui still gets pushed down when friends join move the friend join bonuses and make
-- it smaller"): on touch it is out of that row, so a pal joining or leaving never changes what fits beside the money
-- in Roblox's top bar. There it is a small plain label, one pal's face and "+10%", at the left end of the clock's line
-- under the icon row (the clock is right-aligned, so nothing is laid out from the chip); it takes no taps (the
-- money's card still has the pals' row) and shows with the clock.
--
-- Roblox terms: an "rbxthumb://" image is Roblox's own picture of a player's avatar head, loaded by user id.

local Create = require(script.Parent.Parent.Components.Create)
local Outline = require(script.Parent.Parent.Components.Outline)
local PalsLogic = require(script.Parent.Parent.Components.PalsLogic)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)

export type PalChip = {
	chip: GuiObject, -- a button in the row; a plain frame when it floats
	set: (self: PalChip, userIds: { number }) -> (),
	count: (self: PalChip) -> number,
	destroy: (self: PalChip) -> (),
}

-- #3052: smaller than the potion chips' 28 px tile (18 px words); smaller again when it floats on touch
local ROW = { tile = 24, overlap = 15, text = 16, more = 13, height = 30, outline = 2 }
local FLOAT = { tile = 20, overlap = 13, text = 14, more = 13, height = 24, outline = 1.5 }
local FLOAT_FACES = 1 -- a floating chip shows one pal's face; the bonus says how many there are
local FLOAT_GAP = 8

local PalChip = {}
PalChip.__index = PalChip

-- `parent`: the potion timers' row (BuffChips.frame), or with `float` the HUD's clock line; `onShown` hears when the
-- chip shows or hides (the row stays up for it), `onTap` when a chip in the row is pressed.
function PalChip.new(
	parent: Instance,
	onShown: (shown: boolean) -> (),
	onTap: () -> (),
	float: boolean?
): PalChip
	local self = setmetatable({}, PalChip) :: any
	self._onShown = onShown
	self._ids = {} :: { number }
	self._said = ""
	self._float = float == true
	local look = if float then FLOAT else ROW
	self._look = look

	local chip: GuiObject = Create(if float then "Frame" else "TextButton", {
		Name = "Pals",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, if float then look.height else Scale.tapHeight(36)),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = if float then -1 else 100, -- before the clock's sun; after the Luck chip and potion timers
		Visible = false,
		Parent = parent,
	}, {
		-- (a floating chip keeps a little clear of the clock's sun)
		Create("UIPadding", { PaddingRight = UDim.new(0, if float then FLOAT_GAP else 0) }),
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
		Size = UDim2.fromOffset(look.tile, look.tile),
		LayoutOrder = 1,
		Parent = chip,
	}) :: Frame
	self._text = Create("TextLabel", {
		Name = "Bonus",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, look.height),
		FontFace = Theme.fonts.display,
		TextSize = look.text,
		TextColor3 = Theme.colors.white,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		LayoutOrder = 2,
		Parent = chip,
	}) :: TextLabel
	Outline.text(self._text, look.outline)
	if chip:IsA("TextButton") then
		local button = chip :: TextButton
		button.Text = ""
		button.AutoButtonColor = false
		button.Activated:Connect(function()
			onTap()
		end)
	end
	self.chip = chip
	return self :: PalChip
end

function PalChip.count(self: any): number
	return #self._ids
end

function PalChip.set(self: any, userIds: { number })
	local words = PalsLogic.chip(#userIds, Scale.isTouch()) -- #2712: "+10%" alone on touch
	local key = table.concat(userIds, ",")
	if key == self._said then
		return
	end
	self._said = key
	local was = #self._ids > 0
	local look = self._look
	local tile, overlap = look.tile, look.overlap
	self._ids = table.clone(userIds)
	for _, child in self._faces:GetChildren() do
		child:Destroy()
	end
	local shown, more = PalsLogic.faces(userIds)
	if self._float then
		shown, more = table.move(shown, 1, math.min(#shown, FLOAT_FACES), 1, {}), 0
	end
	for index, userId in shown do
		local face: ImageLabel = Create("ImageLabel", {
			Name = "Face" .. index,
			BackgroundColor3 = Theme.colors.cream,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset((index - 1) * overlap, 0),
			Size = UDim2.fromOffset(tile, tile),
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
			Position = UDim2.fromOffset(#shown * overlap, 0),
			Size = UDim2.fromOffset(tile, tile),
			FontFace = Theme.fonts.display,
			TextSize = look.more,
			TextColor3 = Theme.colors.white,
			Text = "+" .. more,
			ZIndex = 1,
			Parent = self._faces,
		}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		Outline.border(count, 2)
		tiles += 1
	end
	self._faces.Size = UDim2.fromOffset(tile + math.max(0, tiles - 1) * overlap, tile)
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
