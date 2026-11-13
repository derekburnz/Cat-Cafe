--!strict
-- #3938 (Derek 2026-11-13: "the squares don't open menus if item not ready"): the card a camp station's square opens
-- when nothing waits there (the Picnic Basket, Fish Pond or Lost and Found, or one still shut). Its picture and name,
-- the timer line in gold ("Next in 4 h 14 m", "Opens at Tier 3", Components/CampExtrasLogic.info), what the station
-- gives, and an OK button. The timer moves on each second while the card is up; walking off the square closes it
-- (CampExtrasController). One card a station, so its badge wears that station's picture.

local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Components.Button)
local CampExtrasLogic = require(script.Parent.Parent.Components.CampExtrasLogic)
local Create = require(script.Parent.Parent.Components.Create)
local MenuFamily = require(script.Parent.Parent.Components.MenuFamily)
local Panel = require(script.Parent.Parent.Components.Panel)
local Scale = require(script.Parent.Parent.Scale)
local ShopIcons = require(script.Parent.Parent.Components.ShopIcons)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

local PAL = MenuFamily.pal

export type StationInfo = {
	frame: Frame,
	-- the station's view from CampExtrasState
	setView: (self: StationInfo, view: Types.CampExtraView?) -> (),
	opened: (self: StationInfo) -> (),
	closed: (self: StationInfo) -> (),
	destroy: (self: StationInfo) -> (),
}

local MAX_WIDTH = 420
local GAP = Theme.sizes.gap

local StationInfo = {}
StationInfo.__index = StationInfo

local function text(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textBody,
		TextColor3 = PAL.text,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("TextLabel", merged)
end

function StationInfo.new(extraId: string, close: () -> ()): StationInfo
	local self = setmetatable({}, StationInfo) :: any
	self._extraId = extraId
	self._view = nil :: Types.CampExtraView?
	self._open = false
	self._tick = 0

	local short = Scale.isShort()
	local buttonH = Scale.tapHeight(44, Theme.sizes.buttonDepth)
	local statusH = 30
	local givesH = 44
	local height = statusH + givesH + buttonH + GAP * 3 + (if short then 44 else 56)

	local first = CampExtrasLogic.info(extraId, { open = true, held = 0 } :: any, 0)
	local panel = Panel.new({
		dark = true,
		name = "StationInfo_" .. extraId,
		title = first.title,
		color = Theme.colors.berry,
		icon = first.icon,
		image = ShopIcons.clean(first.picture),
		size = UDim2.new(1, 0, 0, height),
		onClose = close,
	})
	Create("UISizeConstraint", { MaxSize = Vector2.new(MAX_WIDTH, height), Parent = panel.frame })
	panel.frame.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.frame.Position = UDim2.fromScale(0.5, 0.5)
	self._panel = panel
	self.frame = panel.frame
	local content = panel.content

	self._status = text({
		Name = "Status",
		Size = UDim2.new(1, 0, 0, statusH),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textBody + 4,
		TextColor3 = PAL.gold,
		Parent = content,
	})
	self._gives = text({
		Name = "Gives",
		Position = UDim2.fromOffset(0, statusH + GAP),
		Size = UDim2.new(1, 0, 0, givesH),
		TextColor3 = PAL.subtext,
		Parent = content,
	})
	self._button = Button.new({
		name = "Ok",
		text = "OK",
		style = "primary",
		size = UDim2.new(0, 160, 0, buttonH),
		anchorPoint = Vector2.new(0.5, 0),
		position = UDim2.new(0.5, 0, 0, statusH + givesH + GAP * 2),
		parent = content,
		onClick = close,
	})
	return self
end

function StationInfo.setView(self: any, view: Types.CampExtraView?)
	self._view = view
	self:_paint()
end

function StationInfo._paint(self: any)
	local view: Types.CampExtraView? = self._view
	if view == nil then
		return
	end
	local info = CampExtrasLogic.info(self._extraId, view, Workspace:GetServerTimeNow())
	self._status.Text = info.status
	self._gives.Text = info.gives
end

function StationInfo.opened(self: any)
	self._open = true
	self._tick += 1
	local tick = self._tick
	self:_paint()
	task.spawn(function()
		while self._open and self._tick == tick do
			task.wait(1)
			if self._open and self._tick == tick then
				self:_paint()
			end
		end
	end)
end

function StationInfo.closed(self: any)
	self._open = false
	self._tick += 1
end

function StationInfo.destroy(self: any)
	self._open = false
	self._tick += 1
	self._button:destroy()
	self._panel:destroy()
end

return StationInfo
