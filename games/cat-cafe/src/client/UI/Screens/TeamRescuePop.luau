--!strict
-- The Team Rescue pop (F92, playing-together.md section 3): when a helped rescue frees its cat, both players see a
-- small pop across the upper screen for a moment: the two players' headshots side by side with a paw between them,
-- "Team Rescue!" in gold outlined letters, and under it "Sam helped you free it!" for the rescuer or "You helped Alex
-- free it! +$1,240" for the helper (the helper's tip, none inside TeamRescueTipCooldown; Components/PalsLogic). It
-- never takes input. The world's burst and the two-note chime are VFX-Agent's and Sound-Agent's (Moments.TeamRescue).
-- With Roblox's Reduce Motion it shows and goes without the pop.

local GuiService = game:GetService("GuiService")

local Create = require(script.Parent.Parent.Components.Create)
local Outline = require(script.Parent.Parent.Components.Outline)
local PalsLogic = require(script.Parent.Parent.Components.PalsLogic)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)

export type TeamRescuePop = {
	screenGui: ScreenGui,
	show: (self: TeamRescuePop, rescuerUserId: number, helperUserId: number, line: string) -> (),
	destroy: (self: TeamRescuePop) -> (),
}

local HOLD = 2.6 -- seconds on screen before it fades
local FACE = 56

local TeamRescuePop = {}
TeamRescuePop.__index = TeamRescuePop

function TeamRescuePop.new(parent: Instance): TeamRescuePop
	local self = setmetatable({}, TeamRescuePop) :: any
	self._token = 0
	local screenGui: ScreenGui = Create("ScreenGui", {
		Name = "CatCafeTeamRescue",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 13, -- over the area title, under the modals
		Enabled = false,
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
	local holder: Frame = Create("Frame", {
		Name = "Pop",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.2),
		Size = UDim2.fromOffset(560, FACE + 92),
		Parent = root,
	})
	self._holder = holder
	-- the two faces and the paw between them
	local faces: Frame = Create("Frame", {
		Name = "Faces",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(FACE * 2 + 52, FACE),
		Parent = holder,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local function face(name: string, order: number): ImageLabel
		local image: ImageLabel = Create("ImageLabel", {
			Name = name,
			BackgroundColor3 = Theme.colors.cream,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(FACE, FACE),
			LayoutOrder = order,
			Parent = faces,
		}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		Outline.border(image, 3, Theme.colors.gold)
		return image
	end
	self._rescuer = face("Rescuer", 1)
	local paw = Create("TextLabel", {
		Name = "Paw",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(40, 40),
		FontFace = Theme.fonts.display,
		TextSize = 30,
		Text = "🐾",
		LayoutOrder = 2,
		Parent = faces,
	})
	Outline.text(paw, 2)
	self._helper = face("Helper", 3)
	self._title = Create("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, FACE + 4),
		Size = UDim2.new(1, 0, 0, 52),
		FontFace = Theme.fonts.display,
		TextSize = 46,
		TextColor3 = Theme.colors.gold,
		Text = PalsLogic.TITLE,
		Parent = holder,
	}) :: TextLabel
	Outline.text(self._title, 4)
	self._line = Create("TextLabel", {
		Name = "Line",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, FACE + 58),
		Size = UDim2.new(1, 0, 0, 30),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		TextColor3 = Theme.colors.white,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		Parent = holder,
	}) :: TextLabel
	Outline.text(self._line, 3)
	return self :: TeamRescuePop
end

function TeamRescuePop.show(self: any, rescuerUserId: number, helperUserId: number, line: string)
	self._token += 1
	local token = self._token
	self._rescuer.Image = PalsLogic.headshot(rescuerUserId)
	self._helper.Image = PalsLogic.headshot(helperUserId)
	self._line.Text = line
	self._holder.Visible = true
	self.screenGui.Enabled = true
	if not GuiService.ReducedMotionEnabled then
		Tween.popIn(self._holder, 0.6)
	end
	task.delay(HOLD, function()
		if self._token ~= token then
			return
		end
		local function gone()
			if self._token == token then
				self.screenGui.Enabled = false
			end
		end
		if GuiService.ReducedMotionEnabled then
			gone()
		else
			Tween.popOut(self._holder, gone)
		end
	end)
end

function TeamRescuePop.destroy(self: any)
	self._token += 1
	Scale.unbind(self._uiScale)
	self.screenGui:Destroy()
end

return TeamRescuePop
