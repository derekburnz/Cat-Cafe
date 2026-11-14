--!strict
-- #3883: the small bubble by the Feedback tile ("Suggest a new map theme! ..."). The tile sits on the screen's
-- top edge, so the bubble hangs just under it with its point up at the tile, its right edge in line with the tile's
-- (the icon row is at the screen's right). It sits on the HUD's root over the goal card (which is under the icon row)
-- and follows the tile. It pops in and bobs gently; a tap on it calls `onOpen`, its X `onClose`. When it shows is
-- FeedbackCalloutLogic's; this only draws it. Review-QA's Studio run (2026-11-14): under the tile it covered the goal
-- card's title for its 20 s, so with `avoid` (the goal card) showing it moves left of it, its point at its top right
-- corner, up toward the icon row.
--   FeedbackCallout.new(root, tile, onOpen, onClose, avoid?)  built hidden on `root` (the HUD's scaled root)
--   :show() / :hide()                                  :hide() is safe to call twice

local GuiService = game:GetService("GuiService")

local Button = require(script.Parent.Button)
local Create = require(script.Parent.Create)
local FeedbackCalloutLogic = require(script.Parent.FeedbackCalloutLogic)
local Outline = require(script.Parent.Outline)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Tween)

local WIDTH = 230
local HEIGHT = 62
local POINT = 12 -- the point's size
local DROP = 8 -- px between the tile's bottom and the point's tip
local RIGHT = 4 -- px the bubble's right edge sits past the tile's
local BOB = 3 -- px up and down
local CLOSE = if Scale.isTouch() then 30 else 36 -- the UI gate's mouse minimum; on touch Button's pad reaches 44
local CLEAR = math.ceil(CLOSE / 2) + 6 -- px between the bubble and the goal card it steps aside from: its X hangs out
local BOB_INFO = TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

export type FeedbackCallout = {
	frame: Frame,
	show: (self: FeedbackCallout) -> (),
	hide: (self: FeedbackCallout) -> (),
	destroy: (self: FeedbackCallout) -> (),
}

local FeedbackCallout = {}
FeedbackCallout.__index = FeedbackCallout

function FeedbackCallout.new(
	root: GuiObject,
	tile: GuiObject,
	onOpen: () -> (),
	onClose: () -> (),
	avoid: GuiObject?
): FeedbackCallout
	local self = setmetatable({}, FeedbackCallout) :: any
	self._root = root
	self._tile = tile
	self._avoid = avoid
	self._at = Vector2.zero
	local top = DROP + POINT
	local frame: Frame = Create("Frame", {
		Name = "FeedbackCallout",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(WIDTH, top + HEIGHT),
		Visible = false,
		ZIndex = 60, -- over the goal card under the icon row
		Parent = root,
	})
	self.frame = frame
	-- the bubble, a tap anywhere on it opens Feedback
	local bubble: TextButton = Create("TextButton", {
		Name = "Bubble",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.colors.paper,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, top),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		Text = "",
		ZIndex = 60,
		Parent = frame,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, 12) }),
	})
	Outline.border(bubble, 3, Theme.colors.gold)
	-- the point: a small square turned 45 degrees under the tile's middle, half of it behind the bubble
	local tileW = tile.Size.X.Offset
	self._pointUnder = UDim2.new(1, -(RIGHT + math.floor(tileW / 2)), 0, top + 1)
	self._pointCorner = UDim2.new(1, -18, 0, top + 1)
	self._point = Create("Frame", {
		Name = "Point",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.colors.paper,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -(RIGHT + math.floor(tileW / 2)), 0, top + 1),
		Rotation = 45,
		Size = UDim2.fromOffset(POINT * 1.4, POINT * 1.4),
		ZIndex = 59,
		Parent = frame,
	}, {
		Create("UIStroke", { Color = Theme.colors.gold, Thickness = 3 }),
	})
	Create("TextLabel", {
		Name = "Words",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -(10 + CLOSE / 2 + 6), 1, -8),
		FontFace = Theme.fonts.bodyBold,
		Text = FeedbackCalloutLogic.WORDS,
		TextColor3 = Theme.colors.ink,
		TextSize = Theme.sizes.textTiny + 1,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = 61,
		Parent = bubble,
	})
	self._close = Button.new({
		name = "Close",
		text = "X",
		style = "danger",
		size = UDim2.fromOffset(CLOSE, CLOSE),
		anchorPoint = Vector2.new(0.5, 0.5),
		position = UDim2.new(1, -4, 0, top + 4), -- hangs over the bubble's corner, as the ask card's X
		textSize = Theme.sizes.textSmall,
		parent = frame,
		zIndex = 62,
		onClick = function()
			onClose()
		end,
	})
	self._tapped = bubble.Activated:Connect(function()
		onOpen()
	end)
	self._bob = nil :: Tween?
	self._follow = nil :: RBXScriptConnection?
	return self :: FeedbackCallout
end

-- Where the bubble's top right goes, in the root's design px: under the tile's bottom right, RIGHT px past it, or
-- left of the goal card (`avoid`) when it would cover it.
function FeedbackCallout._place(self: any, bob: number)
	local root: GuiObject = self._root
	local tile: GuiObject = self._tile
	local uiScale = root:FindFirstChildOfClass("UIScale")
	local scale = math.max(if uiScale ~= nil then uiScale.Scale else 1, 0.01)
	local corner = tile.AbsolutePosition + Vector2.new(tile.AbsoluteSize.X, tile.AbsoluteSize.Y)
	local at = (corner - root.AbsolutePosition) / scale
	local x = at.X + RIGHT
	local frame: Frame = self.frame
	local height = frame.Size.Y.Offset
	local avoid: GuiObject? = self._avoid
	local aside = false
	if avoid ~= nil and avoid.Visible and avoid.AbsoluteSize.X > 0 then
		local left = (avoid.AbsolutePosition.X - root.AbsolutePosition.X) / scale
		local top = (avoid.AbsolutePosition.Y - root.AbsolutePosition.Y) / scale
		local bottom = top + avoid.AbsoluteSize.Y / scale
		local right = left + avoid.AbsoluteSize.X / scale
		local overlaps = x - WIDTH < right and x > left and at.Y < bottom and at.Y + height > top
		if overlaps then
			x = left - CLEAR
			aside = true
		end
	end
	self._point.Position = if aside then self._pointCorner else self._pointUnder
	self._at = at
	return UDim2.fromOffset(math.floor(x), math.floor(at.Y + bob))
end

function FeedbackCallout.show(self: any)
	local frame: Frame = self.frame
	if frame.Visible then
		return
	end
	frame.Visible = true
	frame.Position = self:_place(0)
	Tween.popIn(frame, 0.8)
	local function bob()
		local running: Tween? = self._bob
		if running then
			running:Cancel()
		end
		frame.Position = self:_place(0)
		self._bob = if GuiService.ReducedMotionEnabled
			then nil
			else Tween.to(frame, BOB_INFO, { Position = self:_place(BOB) })
	end
	bob()
	-- the icon row moves (the top bar's free stretch, a resize): the bubble follows
	self._follow = (self._tile :: GuiObject)
		:GetPropertyChangedSignal("AbsolutePosition")
		:Connect(bob)
end

function FeedbackCallout.hide(self: any)
	local bob: Tween? = self._bob
	self._bob = nil
	if bob then
		bob:Cancel()
	end
	local follow: RBXScriptConnection? = self._follow
	self._follow = nil
	if follow then
		follow:Disconnect()
	end
	self.frame.Visible = false
end

function FeedbackCallout.destroy(self: any)
	self:hide()
	self._tapped:Disconnect()
	self._close:destroy()
	self.frame:Destroy()
end

return FeedbackCallout
