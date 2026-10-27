--!strict
-- Settings screen (UI plan 2026-10-27, wave 2): a row per setting with its icon, name, one line on what it does
-- and a chunky ON or OFF switch, like the settings lists of Pet Simulator 99 and Grow a Garden. Opened from the
-- gear in the HUD's top-right icon row. Rows and the shown value come from Components/SettingsList.
--
-- A tap flips the switch at once and fires callbacks.setSetting(key, value); the engineer forwards it as
-- SetSetting and applies music and sound locally so the change is heard at once. The saved value arrives back
-- in state.settings through ProfileSync.

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local SettingsList = require(script.Parent.Parent.Components.SettingsList)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

export type Callbacks = {
	setSetting: (key: string, value: boolean) -> (),
	changed: (key: string, value: boolean) -> (), -- the shown value moved (a tap, or the server's answer)
	close: () -> (),
}

export type Settings = {
	frame: Frame,
	render: (self: Settings, state: Types.PlayerState) -> (),
	value: (self: Settings, key: string) -> boolean,
	destroy: (self: Settings) -> (),
}

local ROW_HEIGHT = 80
local TILE = 56
local SWITCH = Vector2.new(108, 48)
-- each row's icon tile colour, by setting key
local TILE_COLORS: { [string]: Color3 } = {
	music = Theme.colors.berry,
	sfx = Theme.colors.sky,
	markers = Theme.colors.good,
}

local Settings = {}
Settings.__index = Settings

local function text(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textBody,
		TextColor3 = Theme.modal.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("TextLabel", merged)
end

function Settings.new(callbacks: Callbacks): Settings
	local self = setmetatable({}, Settings) :: any
	self._callbacks = callbacks
	self._taps = {} :: { [string]: SettingsList.Tap }
	self._shown = {} :: { [string]: boolean }
	self._settings = nil :: { [string]: unknown }?
	self._switches = {} :: { [string]: Button.Button }
	self._alive = true

	local panel = Panel.new({
		name = "Settings",
		title = "Settings",
		subtitle = "Saved with your cafe",
		color = Theme.colors.cocoa,
		icon = Theme.icons.settings,
		size = UDim2.fromScale(1, 1),
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", { MaxSize = Vector2.new(580, 420), Parent = panel.frame })
	self._panel = panel
	self.frame = panel.frame

	local list: ScrollingFrame = Create("ScrollingFrame", {
		Name = "List",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.colors.caramel,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = panel.content,
	}, {
		Create("UIListLayout", {
			Padding = UDim.new(0, Theme.sizes.gap + 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Create("UIPadding", {
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 6),
			PaddingLeft = UDim.new(0, 2),
			PaddingRight = UDim.new(0, 8),
		}),
	})

	for index, row in SettingsList.ROWS do
		local card: Frame = Create("Frame", {
			Name = row.key,
			BackgroundColor3 = Theme.modal.card,
			BorderSizePixel = 0,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
			Parent = list,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
			Create("UIStroke", { Color = Theme.modal.cardStroke, Thickness = Theme.sizes.stroke }),
		})
		local tile: Frame = Create("Frame", {
			Name = "Icon",
			BackgroundColor3 = TILE_COLORS[row.key] or Theme.colors.caramel,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 12, 0.5, 0),
			Size = UDim2.fromOffset(TILE, TILE),
			Parent = card,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }),
			text({
				Name = "Glyph",
				Size = UDim2.fromScale(1, 1),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextSize = 30,
				Text = row.icon,
			}),
		})
		Outline.border(tile, 2)
		Outline.shade(tile, 0.2)
		local textLeft = 12 + TILE + 12
		text({
			Name = "Name",
			Position = UDim2.fromOffset(textLeft, 12),
			Size = UDim2.new(1, -(textLeft + SWITCH.X + 24), 0, 28),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textLarge,
			Text = row.name,
			Parent = card,
		})
		text({
			Name = "Detail",
			Position = UDim2.fromOffset(textLeft, 42),
			Size = UDim2.new(1, -(textLeft + SWITCH.X + 24), 0, 26),
			TextSize = Theme.sizes.textSmall,
			TextColor3 = Theme.modal.subtext,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = row.detail,
			Parent = card,
		})
		local key = row.key
		self._switches[key] = Button.new({
			name = "Switch",
			text = "ON",
			style = "primary",
			size = UDim2.fromOffset(SWITCH.X, SWITCH.Y),
			anchorPoint = Vector2.new(1, 0.5),
			position = UDim2.new(1, -12, 0.5, -2),
			textSize = Theme.sizes.textLarge,
			parent = card,
			onClick = function()
				self:_tap(key)
			end,
		})
		self._shown[key] = true
	end

	return self :: Settings
end

function Settings._tap(self: any, key: string)
	local value = not self:value(key)
	self._taps[key] = { value = value, at = os.clock() }
	self._callbacks.setSetting(key, value)
	self:_refresh()
	-- after the hold, fall back to the saved value if the server never answered
	task.delay(SettingsList.HOLD_SECONDS + 0.1, function()
		if self._alive then
			self:_refresh()
		end
	end)
end

function Settings._refresh(self: any)
	local now = os.clock()
	for _, row in SettingsList.ROWS do
		local key = row.key
		local on = SettingsList.shown(self._settings, self._taps, key, now)
		local switch: Button.Button = self._switches[key]
		switch:setText(if on then "ON" else "OFF")
		switch:setStyle(if on then "primary" else "danger")
		if self._shown[key] ~= on then
			self._shown[key] = on
			self._callbacks.changed(key, on)
		end
	end
end

function Settings.render(self: any, state: Types.PlayerState)
	self._settings = (state :: any).settings
	self:_refresh()
end

-- What the switch shows now (on until the player turns it off).
function Settings.value(self: any, key: string): boolean
	local shown: boolean? = self._shown[key]
	return shown ~= false
end

function Settings.destroy(self: any)
	self._alive = false
	for _, switch: Button.Button in self._switches do
		switch:destroy()
	end
	table.clear(self._switches)
	self._panel:destroy()
end

return Settings
