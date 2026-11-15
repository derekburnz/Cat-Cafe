--!strict
-- A sideways row's ◀ and ▶ (#4258 on the Cafe Pass; #4264 on the Index's milestones, Derek 2026-11-14: "expanded
-- milestones index side scrolling doesn't work and the scroll bar is too small anyways just add arrows like the cafe
-- pass is doing to click through the sides left or right"). The row has no scroll bar and does not spring back after a
-- drag; one tap moves it a page of whole items (as many as show, at least one), landing on an item's edge, and an arrow
-- with nowhere to go is dimmed (attribute CanGo false). The owner sets the row's CanvasSize from its items (not
-- AutomaticCanvasSize, which read wrong under the view's UIScale) and places the arrows outside the row.
-- Review-QA in Studio at ViewScale 0.878 (#4258): CanvasPosition is in on-screen pixels, as AbsoluteCanvasSize and
-- AbsoluteWindowSize are, so an item's design width is scaled by Scale.get() before it is compared with them.

local Button = require(script.Parent.Button)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)

local SidePager = {}
SidePager.__index = SidePager

SidePager.SIZE = Vector2.new(44, 76) -- one arrow, design px

export type Options = {
	track: ScrollingFrame,
	parent: Instance, -- where the arrows go, outside the track so they never cover an item
	step: number, -- one item and the gap after it, design px
	lead: number, -- design px before the first item, less one gap (the track's left padding minus the gap)
	size: Vector2?,
	hideWhenFits: boolean?, -- no arrows at all while every item shows
}

export type Pager = {
	arrows: { [number]: any }, -- [-1] = ◀ PageLeft, [1] = ▶ PageRight (Button)
	track: ScrollingFrame,
	step: (self: Pager) -> number,
	most: (self: Pager) -> number,
	scrollTo: (self: Pager, x: number) -> (),
	page: (self: Pager, side: number) -> (),
	paint: (self: Pager) -> (),
	destroy: (self: Pager) -> (),
}

-- the row's look: sideways only, no bar, no spring back, the canvas sized by its owner
function SidePager.style(track: ScrollingFrame)
	track.AutomaticCanvasSize = Enum.AutomaticSize.None
	track.ScrollBarThickness = 0
	track.ElasticBehavior = Enum.ElasticBehavior.Never
	track.ScrollingDirection = Enum.ScrollingDirection.X
end

function SidePager.new(options: Options): Pager
	local self = setmetatable({}, SidePager) :: any
	local track = options.track
	SidePager.style(track)
	self.track = track
	self._step = options.step
	self._lead = options.lead
	self._hideWhenFits = options.hideWhenFits == true
	local size = options.size or SidePager.SIZE
	self.arrows = {}
	for _, side in { -1, 1 } do
		self.arrows[side] = Button.new({
			name = if side < 0 then "PageLeft" else "PageRight",
			text = if side < 0 then "◀" else "▶",
			style = "gold",
			size = UDim2.fromOffset(size.X, size.Y),
			anchorPoint = Vector2.new(if side < 0 then 0 else 1, 0.5),
			position = UDim2.fromScale(if side < 0 then 0 else 1, 0.5),
			textSize = Theme.sizes.textBody + 6,
			parent = options.parent,
			onClick = function()
				self:page(side)
			end,
		})
	end
	self._connections = {
		track:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
			self:paint()
		end),
		track:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(function()
			self:paint()
		end),
		track:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(function()
			self:paint()
		end),
	}
	self:paint()
	return self :: Pager
end

-- one item and the gap after it, on screen
function SidePager.step(self: any): number
	local scale = Scale.get()
	return self._step * (if scale > 0 then scale else 1)
end

-- the row's furthest scroll, on screen
function SidePager.most(self: any): number
	local track: ScrollingFrame = self.track
	return math.max(0, track.AbsoluteCanvasSize.X - track.AbsoluteWindowSize.X)
end

function SidePager.scrollTo(self: any, x: number)
	self.track.CanvasPosition = Vector2.new(math.clamp(x, 0, self:most()), 0)
	self:paint()
end

-- ◀ (-1) or ▶ (1): a page of whole items, landing on an item's edge
function SidePager.page(self: any, side: number)
	local step = self:step()
	local scale = step / self._step
	local window = self.track.AbsoluteWindowSize.X
	local perPage = math.max(1, math.floor((window - self._lead * scale) / step))
	local first = math.floor(self.track.CanvasPosition.X / step + 0.5)
	self:scrollTo((first + side * perPage) * step)
end

-- an arrow with nowhere to go is dimmed; with hideWhenFits, a row that shows everything has none
function SidePager.paint(self: any)
	local most = self:most()
	local x = self.track.CanvasPosition.X
	local shown = self.track.Visible and not (self._hideWhenFits and most < 0.5)
	for side, arrow in self.arrows do
		arrow.instance.Visible = shown
		local go = if side < 0 then x > 0.5 else x < most - 0.5
		arrow:setEnabled(go)
		arrow.instance:SetAttribute("CanGo", go)
	end
end

function SidePager.destroy(self: any)
	for _, connection in self._connections do
		connection:Disconnect()
	end
	for _, arrow in self.arrows do
		arrow:destroy()
	end
end

return SidePager
