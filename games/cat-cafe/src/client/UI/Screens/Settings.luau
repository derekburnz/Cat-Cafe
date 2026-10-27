--!strict
-- Settings screen (UI plan 2026-10-27, wave 2; v2 the same day: volumes, screen shake and the like): a Sound and a
-- Screen section, a row per setting with its icon, name and one line on what it does, like the settings lists of
-- Pet Simulator 99 and Grow a Garden. Switch rows have a chunky ON or OFF switch; volume rows a slider with a
-- percent and "−" and "+" buttons for gamepads and small steps. Opened from the gear in the HUD's top-right icon
-- row. Rows, defaults and the shown value come from Components/SettingsList.
--
-- A tap fires callbacks.setSetting(key, value) at once. A slider follows the finger live (callbacks.changed, so
-- Audio can follow) and fires setSetting once on release, and the "−" and "+" buttons after a short pause, since
-- SetSetting is rate limited and only the last value matters (review N120). The saved value arrives back in
-- state.settings through ProfileSync.

local UserInputService = game:GetService("UserInputService")

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local SettingsList = require(script.Parent.Parent.Components.SettingsList)
local Sound = require(script.Parent.Parent.Components.Sound)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

export type Callbacks = {
	setSetting: (key: string, value: boolean | number) -> (),
	changed: (key: string, value: boolean | number) -> (), -- the shown value moved (a tap, a drag or the server)
	close: () -> (),
}

export type Settings = {
	frame: Frame,
	render: (self: Settings, state: Types.PlayerState) -> (),
	value: (self: Settings, key: string) -> boolean,
	volume: (self: Settings, key: string) -> number,
	destroy: (self: Settings) -> (),
}

local ROW_HEIGHT = 80
local HEADER_HEIGHT = 26
local TILE = 56
local SWITCH = Vector2.new(108, 48)
local STEP_BUTTON = Vector2.new(50, 44) -- "−" and "+", side by side where a switch row has its switch
local NUDGE = 0.1 -- what one "−" or "+" press moves a volume
local NUDGE_PAUSE = 0.5 -- seconds after the last "−" or "+" before the volume is sent
local KNOB = 28
-- each row's icon tile colour, by setting key
local TILE_COLORS: { [string]: Color3 } = {
	music = Theme.colors.berry,
	musicVolume = Theme.colors.berry,
	sfx = Theme.colors.sky,
	sfxVolume = Theme.colors.sky,
	screenShake = Theme.colors.warn,
	lowPerformance = Theme.colors.mintDark,
	showOtherCats = Theme.colors.caramel,
	markers = Theme.colors.good,
}
-- a volume row's switch: the slider greys while that switch is off
local VOLUME_SWITCH: { [string]: string } = { musicVolume = "music", sfxVolume = "sfx" }

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

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

function Settings.new(callbacks: Callbacks): Settings
	local self = setmetatable({}, Settings) :: any
	self._callbacks = callbacks
	self._taps = {} :: { [string]: SettingsList.Tap }
	self._shown = {} :: { [string]: boolean | number }
	self._drag = {} :: { [string]: number } -- a volume being dragged or nudged, before it is sent
	self._dragging = nil :: string? -- the slider under the finger
	self._nudges = {} :: { [string]: number } -- a token per volume, so only the last nudge sends
	self._settings = nil :: { [string]: unknown }?
	self._switches = {} :: { [string]: Button.Button }
	self._sliders = {} :: { [string]: any }
	self._buttons = {} :: { Button.Button }
	self._connections = {} :: { RBXScriptConnection }
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
	Create("UISizeConstraint", { MaxSize = Vector2.new(600, 520), Parent = panel.frame })
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
	self._list = list

	local order = 0
	for _, section in SettingsList.SECTIONS do
		order += 1
		text({
			Name = section.title,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textLarge,
			TextColor3 = Theme.modal.subtext,
			Text = section.title,
			Parent = list,
		})
		for _, row in section.rows do
			order += 1
			self:_buildRow(row, order)
		end
	end

	-- a drag keeps following the finger off the track, and ends wherever it lets go
	table.insert(
		self._connections,
		UserInputService.InputChanged:Connect(function(input: InputObject)
			local key: string? = self._dragging
			if
				key
				and (
					input.UserInputType == Enum.UserInputType.MouseMovement
					or input.UserInputType == Enum.UserInputType.Touch
				)
			then
				self:_dragTo(key, input.Position.X)
			end
		end)
	)
	table.insert(
		self._connections,
		UserInputService.InputEnded:Connect(function(input: InputObject)
			local key: string? = self._dragging
			if key and isPress(input) then
				self._dragging = nil
				list.ScrollingEnabled = true
				self:_send(key)
			end
		end)
	)
	self:_refresh() -- defaults first: Low performance starts OFF

	return self :: Settings
end

function Settings._buildRow(self: any, row: SettingsList.Row, order: number)
	local card: Frame = Create("Frame", {
		Name = row.key,
		BackgroundColor3 = Theme.modal.card,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		Parent = self._list,
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
	local textRight = textLeft + SWITCH.X + 24
	local key = row.key
	if row.kind == "volume" then
		text({
			Name = "Name",
			Position = UDim2.fromOffset(textLeft, 10),
			Size = UDim2.new(1, -(textRight + 60), 0, 28),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textLarge,
			Text = row.name,
			Parent = card,
		})
		local percent = text({
			Name = "Percent",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -(SWITCH.X + 24), 0, 10),
			Size = UDim2.fromOffset(60, 28),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textBody,
			TextColor3 = Theme.modal.subtext,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = card,
		})
		self:_buildSlider(card, key, textLeft, textRight, percent)
		local function nudge(delta: number)
			self:_nudge(key, delta)
		end
		local minus = Button.new({
			name = "Minus",
			text = "−",
			style = "secondary",
			size = UDim2.fromOffset(STEP_BUTTON.X, STEP_BUTTON.Y),
			anchorPoint = Vector2.new(1, 0.5),
			position = UDim2.new(1, -(12 + STEP_BUTTON.X + 8), 0.5, -2),
			textSize = Theme.sizes.textLarge,
			parent = card,
			sound = false, -- the slider's tick is the sound
			onClick = function()
				nudge(-NUDGE)
			end,
		})
		local plus = Button.new({
			name = "Plus",
			text = "+",
			style = "secondary",
			size = UDim2.fromOffset(STEP_BUTTON.X, STEP_BUTTON.Y),
			anchorPoint = Vector2.new(1, 0.5),
			position = UDim2.new(1, -12, 0.5, -2),
			textSize = Theme.sizes.textLarge,
			parent = card,
			sound = false, -- the slider's tick is the sound
			onClick = function()
				nudge(NUDGE)
			end,
		})
		table.insert(self._buttons, minus)
		table.insert(self._buttons, plus)
		self._sliders[key].minus = minus
		self._sliders[key].plus = plus
	else
		text({
			Name = "Name",
			Position = UDim2.fromOffset(textLeft, 12),
			Size = UDim2.new(1, -textRight, 0, 28),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textLarge,
			Text = row.name,
			Parent = card,
		})
		text({
			Name = "Detail",
			Position = UDim2.fromOffset(textLeft, 42),
			Size = UDim2.new(1, -textRight, 0, 26),
			TextSize = Theme.sizes.textSmall,
			TextColor3 = Theme.modal.subtext,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = row.detail,
			Parent = card,
		})
		local switch = Button.new({
			name = "Switch",
			text = "ON",
			style = "primary",
			size = UDim2.fromOffset(SWITCH.X, SWITCH.Y),
			anchorPoint = Vector2.new(1, 0.5),
			position = UDim2.new(1, -12, 0.5, -2),
			textSize = Theme.sizes.textLarge,
			parent = card,
			sound = "uiToggle",
			onClick = function()
				self:_tap(key)
			end,
		})
		self._switches[key] = switch
		table.insert(self._buttons, switch)
	end
	self._shown[key] = SettingsList.default(key)
end

-- The bar under a volume row's name: a track to press or drag, the fill and a round knob at its end.
function Settings._buildSlider(
	self: any,
	card: Frame,
	key: string,
	left: number,
	right: number,
	percent: TextLabel
)
	local track: TextButton = Create("TextButton", {
		Name = "Track",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.colors.line,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(left + KNOB / 2, 48),
		Size = UDim2.new(1, -(right + KNOB / 2), 0, 14),
		Parent = card,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(track, 2)
	local fill: Frame = Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = TILE_COLORS[key] or Theme.colors.good,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = track,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local knob: Frame = Create("Frame", {
		Name = "Knob",
		BackgroundColor3 = Theme.colors.white,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(KNOB, KNOB),
		ZIndex = 3,
		Parent = track,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(knob, 3)
	table.insert(
		self._connections,
		track.InputBegan:Connect(function(input: InputObject)
			if isPress(input) then
				self._dragging = key
				self._list.ScrollingEnabled = false -- a sideways drag must not scroll the list
				self:_dragTo(key, input.Position.X)
			end
		end)
	)
	self._sliders[key] = { track = track, fill = fill, knob = knob, percent = percent }
end

function Settings._dragTo(self: any, key: string, x: number)
	local track: TextButton = self._sliders[key].track
	local width = track.AbsoluteSize.X
	if width <= 0 then
		return
	end
	self:_setDrag(key, SettingsList.step((x - track.AbsolutePosition.X) / width))
end

-- A dragged or nudged volume: shown at once, with a tick on every 5% step (uiSlider plays on the sound
-- channel, so it previews the new volume).
function Settings._setDrag(self: any, key: string, volume: number)
	if volume ~= self:volume(key) then
		Sound.play("uiSlider")
	end
	self._drag[key] = volume
	self:_refresh()
end

function Settings._nudge(self: any, key: string, delta: number)
	self:_setDrag(key, SettingsList.step(self:volume(key) + delta))
	local token = (self._nudges[key] or 0) + 1
	self._nudges[key] = token
	task.delay(NUDGE_PAUSE, function()
		if self._alive and self._nudges[key] == token and self._dragging ~= key then
			self:_send(key)
		end
	end)
end

-- Sends a dragged or nudged volume once, and holds it on screen until the server agrees.
function Settings._send(self: any, key: string)
	local value: number? = self._drag[key]
	if value == nil then
		return
	end
	self._drag[key] = nil
	self._taps[key] = { value = value, at = os.clock() }
	self._callbacks.setSetting(key, value)
	self:_refresh()
	self:_refreshLater()
end

function Settings._tap(self: any, key: string)
	local value = not self:value(key)
	self._taps[key] = { value = value, at = os.clock() }
	self._callbacks.setSetting(key, value)
	self:_refresh()
	self:_refreshLater()
end

-- after the hold, fall back to the saved value if the server never answered
function Settings._refreshLater(self: any)
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
		local shown: boolean | number = self._drag[key]
			or SettingsList.shown(self._settings, self._taps, key, now)
		if row.kind == "volume" then
			local volume = if type(shown) == "number" then shown else 1
			local slider = self._sliders[key]
			slider.fill.Size = UDim2.fromScale(volume, 1)
			slider.knob.Position = UDim2.fromScale(volume, 0.5)
			slider.percent.Text = SettingsList.percent(volume)
			slider.minus:setEnabled(volume > 0)
			slider.plus:setEnabled(volume < 1)
			local switchKey = VOLUME_SWITCH[key]
			local muted = switchKey ~= nil and self:value(switchKey) == false
			slider.fill.BackgroundColor3 = if muted
				then Theme.colors.disabled
				else TILE_COLORS[key] or Theme.colors.good
		else
			local on = shown == true
			local switch: Button.Button = self._switches[key]
			switch:setText(if on then "ON" else "OFF")
			switch:setStyle(if on then "primary" else "danger")
		end
		local before = self._shown[key]
		if before ~= shown then
			self._shown[key] = shown
			self._callbacks.changed(key, shown)
		end
	end
end

function Settings.render(self: any, state: Types.PlayerState)
	self._settings = (state :: any).settings
	self:_refresh()
end

-- What a switch shows now (its default until the server or the player says otherwise).
function Settings.value(self: any, key: string): boolean
	local shown = self._shown[key]
	if shown == nil then
		return SettingsList.default(key) == true
	end
	return shown == true
end

-- What a volume shows now, 0 to 1 (live while it is dragged).
function Settings.volume(self: any, key: string): number
	local shown = self._shown[key]
	return if type(shown) == "number" then shown else 1
end

function Settings.destroy(self: any)
	self._alive = false
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	for _, button: Button.Button in self._buttons do
		button:destroy()
	end
	table.clear(self._buttons)
	table.clear(self._switches)
	self._panel:destroy()
end

return Settings
