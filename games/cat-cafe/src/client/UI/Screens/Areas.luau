--!strict
-- Areas screen (F19 fast travel): one card per area with its icon, its name and a Go button (no spawn rates since
-- 2026-10-28, Derek: "No need to show area rates everytime you walk into it or at all"). Only the areas the player's tier has opened show (Derek 2026-10-27: no buttons for places you cannot
-- go yet), so the grid grows as they rank up, and every Go greys out while the player is carrying a cat, because
-- walking it home is the loop. Opened from the Areas button in the HUD travel row.

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

export type Callbacks = {
	travel: (areaId: string) -> (),
	close: () -> (),
}

export type Areas = {
	frame: Frame,
	setCatalog: (self: Areas, catalog: Types.Catalog) -> (),
	setAreasOpen: (self: Areas, open: boolean) -> (),
	render: (self: Areas, state: Types.PlayerState, carrying: boolean) -> (),
	destroy: (self: Areas) -> (),
}

local CARD = Vector2.new(226, 196)

local Areas = {}
Areas.__index = Areas

local function text(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textBody,
		TextColor3 = Theme.modal.text,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("TextLabel", merged)
end

function Areas.new(callbacks: Callbacks): Areas
	local self = setmetatable({}, Areas) :: any
	self._callbacks = callbacks
	self._cards = {} :: { [string]: any }
	self._catalog = nil :: Types.Catalog?

	local panel = Panel.new({
		name = "Areas",
		color = Theme.colors.good,
		icon = Theme.icons.travel,
		title = "Areas",
		subtitle = "Pick an area to travel to",
		size = UDim2.fromScale(1, 1),
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", { MaxSize = Vector2.new(760, 520), Parent = panel.frame })
	self._panel = panel
	self.frame = panel.frame

	self._grid = Create("ScrollingFrame", {
		Name = "Grid",
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
		Create("UIGridLayout", {
			CellSize = UDim2.fromOffset(CARD.X, CARD.Y),
			CellPadding = UDim2.fromOffset(Theme.sizes.gap + 4, Theme.sizes.gap + 4),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Create("UIPadding", {
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 6),
		}),
	})

	return self :: Areas
end

function Areas._buildCards(self: any)
	for _, card in self._cards do
		card.go:destroy()
		card.frame:Destroy()
	end
	table.clear(self._cards)
	local catalog: Types.Catalog? = self._catalog
	if not catalog then
		return
	end
	assert(catalog, "catalog not set; call UI.init first")
	local areaList: { Types.AreaDef } = catalog.areas or {}
	for index, area in areaList do
		local frame: Frame = Create("Frame", {
			Name = area.id,
			BackgroundColor3 = Theme.modal.card,
			BorderSizePixel = 0,
			LayoutOrder = index,
			Parent = self._grid,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
			Create("UIStroke", { Color = Theme.modal.cardStroke, Thickness = Theme.sizes.stroke }),
		})
		local art: Frame = Create("Frame", {
			Name = "Art",
			BackgroundColor3 = Theme.areaColors[area.id] or Theme.colors.caramel,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(10, 10),
			Size = UDim2.new(1, -20, 0, 78),
			Parent = frame,
		}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }) })
		Outline.border(art, 2)
		Outline.shade(art, 0.2)
		local icon = text({
			Name = "Icon",
			Size = UDim2.fromScale(1, 1),
			FontFace = Theme.fonts.display,
			TextScaled = true,
			Text = (Theme.icons :: any)[area.id] or Theme.icons.travel,
			Parent = art,
		})
		Create("UIPadding", {
			PaddingTop = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 12),
			Parent = icon,
		})
		local lock = text({
			Name = "Lock",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 4),
			Size = UDim2.fromOffset(28, 28),
			FontFace = Theme.fonts.display,
			TextScaled = true,
			Text = Theme.icons.lock,
			Visible = false,
			Parent = art,
		})
		local name = text({
			Name = "Name",
			Position = UDim2.fromOffset(10, 92),
			Size = UDim2.new(1, -20, 0, 26),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textLarge - 2,
			Text = area.name,
			Parent = frame,
		})
		local go = Button.new({
			name = "Go",
			text = "Go",
			style = "primary",
			size = UDim2.new(1, -20, 0, 44),
			anchorPoint = Vector2.new(0.5, 1),
			position = UDim2.new(0.5, 0, 1, -10),
			textSize = Theme.sizes.textBody + 1,
			parent = frame,
			onClick = function()
				self._callbacks.travel(area.id)
			end,
		})
		self._cards[area.id] = {
			frame = frame,
			art = art,
			icon = icon,
			lock = lock,
			name = name,
			go = go,
			def = area,
		}
	end
end

function Areas.setCatalog(self: any, catalog: Types.Catalog)
	self._catalog = catalog
	self:_buildCards()
end

-- F66: false from dusk to sunrise. The next render greys every Go with "🌙 Sunrise".
function Areas.setAreasOpen(self: any, open: boolean)
	self._areasOpen = open
end

function Areas.render(self: any, state: Types.PlayerState, carrying: boolean)
	local tier = state.tier or 1
	local closed = self._areasOpen == false
	local hidden = 0
	for _, card in self._cards do
		local def: Types.AreaDef = card.def
		local unlocked = def.tier <= tier
		card.frame.Visible = unlocked
		if not unlocked then
			hidden += 1
		end
		card.lock.Visible = not unlocked
		card.icon.TextTransparency = if unlocked then 0 else 0.55
		card.art.BackgroundTransparency = if unlocked then 0 else 0.45
		card.name.TextColor3 = if unlocked then Theme.modal.text else Theme.modal.subtext
		if unlocked then
			card.go:setText(if closed then Theme.icons.moon .. " Sunrise" else "Go")
			card.go:setEnabled(not carrying and not closed)
		else
			card.go:setText(("Opens at Tier %d"):format(def.tier))
			card.go:setEnabled(false)
		end
	end
	self._panel:setTitle(
		"Areas",
		if carrying
			then "Walk your cat home first"
			elseif closed then "The areas are closed at night. They open at sunrise."
			elseif hidden > 0 then "Pick an area to travel to. More open as you rank up."
			else "Pick an area to travel to"
	)
end

function Areas.destroy(self: any)
	for _, card in self._cards do
		card.go:destroy()
	end
	self._panel:destroy()
end

return Areas
