--!strict
-- The Decor screen's Style tab (#1624, store-pass-looks.md: "the player picks a style for the whole cafe on the
-- cafe's Style panel"). DecorShop shows it in place of its strip and grid when the "Style" chip is picked, and the
-- chip only while the player owns something to pick (Components/StyleLogic.shows). One row per kind: the cafe sign,
-- then uniforms and the cafe theme once the server sends them. Each row lists the default (Plain or Classic) and every
-- owned style as a button; the one in use is gold. A tap is a request: the callback becomes SetSignStyle or SetLook,
-- which the server checks, and the next ProfileSync moves the gold.

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local Scale = require(script.Parent.Parent.Scale)
local StyleLogic = require(script.Parent.Parent.Components.StyleLogic)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

-- the dark window palette (#1028), in place of Theme.modal
local PAL = Theme.dark

export type Callbacks = {
	-- kind "sign", "uniform", "accessory" or "theme"; id "" for the plain sign, Classic or None
	pick: (kind: string, id: string) -> (),
}

export type StyleTab = {
	frame: ScrollingFrame,
	render: (self: StyleTab, state: Types.PlayerState) -> (),
	destroy: (self: StyleTab) -> (),
}

local TITLE_H = 26
local OPTION_W = 164
local ROW_GAP = 14

local StyleTab = {}
StyleTab.__index = StyleTab

function StyleTab.new(parent: Instance, callbacks: Callbacks): StyleTab
	local self = setmetatable({}, StyleTab) :: any
	self._callbacks = callbacks
	self._buttons = {} :: { Button.Button }
	self._rows = {} :: { Frame }
	self._shape = "" -- the kinds and option ids on show; a change rebuilds the rows
	self._optionH = Scale.tapHeight(Theme.sizes.touchMin, Theme.sizes.buttonDepth)
	self.frame = Create("ScrollingFrame", {
		Name = "StyleTab",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = PAL.caramel,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Visible = false,
		Parent = parent,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, ROW_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Create("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingRight = UDim.new(0, 10) }),
	})
	return self :: StyleTab
end

function StyleTab._clear(self: any)
	for _, button in self._buttons do
		button:destroy()
	end
	table.clear(self._buttons)
	for _, frame in self._rows do
		frame:Destroy()
	end
	table.clear(self._rows)
end

-- A row's title and its option buttons, which wrap onto more lines on a narrow window.
function StyleTab._build(self: any, rows: { StyleLogic.Row })
	self:_clear()
	for index, row in rows do
		local frame: Frame = Create("Frame", {
			Name = row.kind,
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = index,
			Parent = self.frame,
		})
		Create("TextLabel", {
			Name = "Title",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, TITLE_H),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textBody + 2,
			TextColor3 = PAL.text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = row.title,
			Parent = frame,
		})
		local options: Frame = Create("Frame", {
			Name = "Options",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Position = UDim2.fromOffset(0, TITLE_H + 4),
			Size = UDim2.new(1, 0, 0, 0),
			Parent = frame,
		}, {
			Create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Wraps = true,
				Padding = UDim.new(0, Theme.sizes.gap),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Create("UIPadding", { PaddingBottom = UDim.new(0, 4) }),
		})
		for order, option in row.options do
			local kind = row.kind
			local id = option.id
			local button = Button.new({
				name = if id == "" then "Default" else id,
				text = option.name,
				style = if option.picked then "gold" else "ghost",
				size = UDim2.fromOffset(OPTION_W, self._optionH),
				textSize = Theme.sizes.textBody,
				layoutOrder = order,
				parent = options,
				sound = "uiTab",
				onClick = function()
					self._callbacks.pick(kind, id)
				end,
			})
			table.insert(self._buttons, button)
		end
		table.insert(self._rows, frame)
	end
end

function StyleTab.render(self: any, state: Types.PlayerState)
	local rows = StyleLogic.rows(state)
	local keys: { string } = {}
	for _, row in rows do
		local ids: { string } = {}
		for _, option in row.options do
			table.insert(ids, option.id)
		end
		table.insert(keys, row.kind .. "=" .. table.concat(ids, ","))
	end
	local shape = table.concat(keys, ";")
	if shape ~= self._shape then
		self._shape = shape
		self:_build(rows)
	end
	-- the gold follows the pick
	local index = 0
	for _, row in rows do
		for _, option in row.options do
			index += 1
			local button: Button.Button? = self._buttons[index]
			if button then
				button:setStyle(if option.picked then "gold" else "ghost")
			end
		end
	end
end

function StyleTab.destroy(self: any)
	self:_clear()
	self.frame:Destroy()
end

return StyleTab
