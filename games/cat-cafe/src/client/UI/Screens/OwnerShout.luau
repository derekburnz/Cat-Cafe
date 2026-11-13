--!strict
-- The owner's shout bubble (#3301, Derek2 2026-11-11: "make the /shout make a quick bubble with OWNER "whatever
-- messege I put" on screen when i shout"): an owner's `/shout hello` (OwnerTestService, every server) pops a speech
-- bubble across the upper screen for everyone: OWNER in gold over "hello" in a cream bubble with a tail. It stays
-- OwnerTest.bubbleSeconds(text) (10 to 20 s by length, #3872), never takes input, and a newer shout replaces it. With Roblox's Reduce Motion it shows
-- and goes without the pop.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(script.Parent.Parent.Components.Create)
local Outline = require(script.Parent.Parent.Components.Outline)
local OwnerTest = require(ReplicatedStorage.Shared.OwnerTest)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)

export type OwnerShout = {
	screenGui: ScreenGui,
	show: (self: OwnerShout, text: string) -> (),
	destroy: (self: OwnerShout) -> (),
}

local WIDTH = 480
local LINE_HEIGHT = 30
local MAX_LINES = 3 -- OwnerTest.SHOUT_MAX (120) characters fit in three lines at this width
local CHARS_PER_LINE = 40

local OwnerShout = {}
OwnerShout.__index = OwnerShout

function OwnerShout.new(parent: Instance): OwnerShout
	local self = setmetatable({}, OwnerShout) :: any
	self._token = 0
	local screenGui: ScreenGui = Create("ScreenGui", {
		Name = "CatCafeOwnerShout",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 14, -- over the area title and the Team Rescue pop, under the modals
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
		Name = "Bubble",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 64),
		Size = UDim2.fromOffset(WIDTH, 40 + LINE_HEIGHT * MAX_LINES + 20),
		Parent = root,
	})
	self._holder = holder
	local title: TextLabel = Create("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(1, 0, 0, 40),
		FontFace = Theme.fonts.display,
		TextSize = 34,
		TextColor3 = Theme.colors.gold,
		Text = OwnerTest.BUBBLE_TITLE,
		ZIndex = 4,
		Parent = holder,
	})
	Outline.text(title, 4)
	local bubble: Frame = Create("Frame", {
		Name = "Speech",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 34),
		Size = UDim2.new(1, 0, 0, LINE_HEIGHT + 20),
		BackgroundColor3 = Theme.colors.cream,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = holder,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, 18) }),
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, 16),
			PaddingRight = UDim.new(0, 16),
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
		}),
	})
	Outline.border(bubble, Theme.sizes.outline)
	self._bubble = bubble
	-- the speech bubble's tail, a turned square behind the bubble's bottom middle (a sibling under it, as a child
	-- would draw over the bubble); show() moves it to the bubble's bottom
	local tail: Frame = Create("Frame", {
		Name = "Tail",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 34 + LINE_HEIGHT + 20),
		Size = UDim2.fromOffset(18, 18),
		Rotation = 45,
		BackgroundColor3 = Theme.colors.cream,
		BorderSizePixel = 0,
		ZIndex = 1,
		Parent = holder,
	})
	Outline.border(tail, Theme.sizes.outline)
	self._tail = tail
	self._line = Create("TextLabel", {
		Name = "Line",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		TextColor3 = Theme.colors.ink,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		ZIndex = 3,
		Parent = bubble,
	}) :: TextLabel
	return self :: OwnerShout
end

-- `text` is the shout as the server filtered it; a newer shout takes over the bubble.
function OwnerShout.show(self: any, text: string)
	self._token += 1
	local token = self._token
	local line: TextLabel = self._line
	line.Text = OwnerTest.bubbleLine(text)
	-- one to MAX_LINES lines, about CHARS_PER_LINE characters each at this width and size
	local lines =
		math.clamp(math.ceil((utf8.len(line.Text) or #line.Text) / CHARS_PER_LINE), 1, MAX_LINES)
	local height = LINE_HEIGHT * lines + 20
	self._bubble.Size = UDim2.new(1, 0, 0, height)
	self._tail.Position = UDim2.new(0.5, 0, 0, 34 + height)
	self._holder.Visible = true
	self.screenGui.Enabled = true
	if not GuiService.ReducedMotionEnabled then
		Tween.popIn(self._holder, 0.6)
	end
	task.delay(OwnerTest.bubbleSeconds(text), function()
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

function OwnerShout.destroy(self: any)
	self._token += 1
	Scale.unbind(self._uiScale)
	self.screenGui:Destroy()
end

return OwnerShout
