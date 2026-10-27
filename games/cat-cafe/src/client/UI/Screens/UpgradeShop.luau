--!strict
-- Upgrades screen with two tabs, in the style of the fishing simulators' upgrade lists (UI plan 2026-10-27):
--   Cafe   one row per upgrade: an icon box, the name, a star per level (gold up to the level owned), the effect
--          line and a gold price button ("MAX" when maxed, "Tier 3" while the tier gate holds it).
--   Staff  the role slots that used to float over the cafe as labels: one row per role with a square per slot in
--          the order they open (Components/StaffSlots): the working cat's initial on its rarity colour, a green
--          "+" for a free slot (a tap opens the cat room) or a grey lock with the tier that opens it. A rank up
--          card on top names the next tier and what it opens; its button opens the rank up card.
-- Rows are built once per catalog and only their text, colours and buttons change on render.

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local Format = require(script.Parent.Parent.Components.Format)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local RankUp = require(script.Parent.RankUp)
local StaffSlots = require(script.Parent.Parent.Components.StaffSlots)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

export type Links = {
	openCatRoom: () -> (), -- a free slot's "+" and Add cat
	openRankUp: () -> (), -- the rank up card's button
}

export type Tab = "Cafe" | "Staff"

export type UpgradeShop = {
	frame: Frame,
	setCatalog: (self: UpgradeShop, catalog: Types.Catalog) -> (),
	render: (self: UpgradeShop, state: Types.PlayerState) -> (),
	showTab: (self: UpgradeShop, tab: Tab) -> (),
	destroy: (self: UpgradeShop) -> (),
}

local TAB_HEIGHT = Theme.sizes.touchMin
local ROW_HEIGHT = 104
local ICON_BOX = 72
local STAR = 22
local SLOT = Theme.sizes.touchMin -- reviewer N102: tappable slot squares
local RANK_HEIGHT = 76
local TEXT_LEFT = 12 + ICON_BOX + 14
local BUTTON_W = 136

local UpgradeShop = {}
UpgradeShop.__index = UpgradeShop

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

local function card(name: string, height: number, order: number, parent: Instance): Frame
	return Create("Frame", {
		Name = name,
		BackgroundColor3 = Theme.modal.card,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, height),
		LayoutOrder = order,
		Parent = parent,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", { Color = Theme.modal.cardStroke, Thickness = Theme.sizes.stroke }),
	})
end

-- The square on the left of a row with a big glyph, like the item art boxes in the references.
local function iconBox(parent: Instance, glyph: string, color: Color3)
	local box: Frame = Create("Frame", {
		Name = "Icon",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, (ROW_HEIGHT - ICON_BOX) / 2),
		Size = UDim2.fromOffset(ICON_BOX, ICON_BOX),
		Parent = parent,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("TextLabel", {
			Name = "Glyph",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.7, 0.7),
			FontFace = Theme.fonts.display,
			TextScaled = true,
			TextColor3 = Theme.colors.white,
			Text = glyph,
		}),
	})
	Outline.border(box, Theme.sizes.stroke)
	Outline.shade(box, 0.2)
end

local function scrollList(name: string, parent: Instance): ScrollingFrame
	return Create("ScrollingFrame", {
		Name = name,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, TAB_HEIGHT + Theme.sizes.gap),
		Size = UDim2.new(1, 0, 1, -(TAB_HEIGHT + Theme.sizes.gap)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.colors.caramel,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = parent,
	}, {
		Create("UIListLayout", {
			Padding = UDim.new(0, Theme.sizes.gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Create("UIPadding", { PaddingRight = UDim.new(0, 10) }),
	})
end

function UpgradeShop.new(
	onBuy: (upgradeId: string) -> (),
	onClose: () -> (),
	links: Links?
): UpgradeShop
	local self = setmetatable({}, UpgradeShop) :: any
	self._onBuy = onBuy
	self._links = links
	self._rows = {} :: { [string]: any }
	self._roleRows = {} :: { [string]: any }
	self._catalog = nil :: Types.Catalog?
	self._catDefs = {} :: { [string]: Types.CatDef }
	self._dirty = true
	self._lastState = nil :: Types.PlayerState?
	self._tab = "Cafe" :: Tab

	local panel = Panel.new({
		name = "Upgrades",
		title = "Upgrades",
		subtitle = "Cafe Lv 1",
		size = UDim2.fromScale(1, 1),
		onClose = onClose,
	})
	Create("UISizeConstraint", { MaxSize = Vector2.new(760, 560), Parent = panel.frame })
	self._panel = panel
	self.frame = panel.frame

	local tabs: Frame = Create("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, TAB_HEIGHT),
		Parent = panel.content,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, Theme.sizes.gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self._cafeTab = Button.new({
		name = "CafeTab",
		text = "Cafe",
		style = "gold",
		size = UDim2.fromOffset(120, TAB_HEIGHT),
		textSize = Theme.sizes.textBody,
		layoutOrder = 1,
		parent = tabs,
		sound = "uiTab",
		onClick = function()
			self:showTab("Cafe")
		end,
	})
	self._staffTab = Button.new({
		name = "StaffTab",
		text = "Staff",
		style = "ghost",
		size = UDim2.fromOffset(120, TAB_HEIGHT),
		textSize = Theme.sizes.textBody,
		layoutOrder = 2,
		parent = tabs,
		sound = "uiTab",
		onClick = function()
			self:showTab("Staff")
		end,
	})

	self._list = scrollList("List", panel.content)
	self._staff = scrollList("Staff", panel.content)
	self._staff.Visible = false

	-- rank up card at the top of the Staff tab
	local rank = card("RankUp", RANK_HEIGHT, 0, self._staff)
	self._rankTitle = text({
		Name = "Title",
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -(BUTTON_W + 40), 0, 26),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge - 2,
		Parent = rank,
	})
	self._rankSub = text({
		Name = "Opens",
		Position = UDim2.fromOffset(16, 40),
		Size = UDim2.new(1, -(BUTTON_W + 40), 0, 24),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.modal.subtext,
		TextWrapped = true,
		Parent = rank,
	})
	self._rankButton = Button.new({
		name = "Rank",
		text = "Rank up",
		style = "gold",
		size = UDim2.fromOffset(BUTTON_W, Theme.sizes.touchMin + 4),
		anchorPoint = Vector2.new(1, 0.5),
		position = UDim2.new(1, -12, 0.5, 0),
		textSize = Theme.sizes.textBody,
		parent = rank,
		sound = false, -- the rank up card swishes open
		onClick = function()
			local open = self._links
			if open then
				open.openRankUp()
			end
		end,
	})

	return self :: UpgradeShop
end

function UpgradeShop.showTab(self: any, tab: Tab)
	self._tab = tab
	self._list.Visible = tab == "Cafe"
	self._staff.Visible = tab == "Staff"
	self._cafeTab:setStyle(if tab == "Cafe" then "gold" else "ghost")
	self._staffTab:setStyle(if tab == "Staff" then "gold" else "ghost")
	local state: Types.PlayerState? = self._lastState
	if state then
		self:render(state)
	end
end

function UpgradeShop._buildRows(self: any)
	for _, row in self._rows do
		row.buy:destroy()
		row.frame:Destroy()
	end
	table.clear(self._rows)
	for _, row in self._roleRows do
		row.add:destroy()
		row.frame:Destroy()
	end
	table.clear(self._roleRows)
	local catalog: Types.Catalog? = self._catalog
	if not catalog then
		return
	end
	assert(catalog, "catalog not set; call UI.init first")

	for index, upgrade in catalog.upgrades do
		local row = card(upgrade.id, ROW_HEIGHT, index, self._list)
		iconBox(row, Theme.upgradeIcons[upgrade.id] or Theme.icons.upgrades, Theme.colors.caramel)
		local name = text({
			Name = "Name",
			Position = UDim2.fromOffset(TEXT_LEFT, 8),
			Size = UDim2.new(1, -(TEXT_LEFT + BUTTON_W + 24), 0, 28),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textLarge,
			Text = upgrade.name,
			Parent = row,
		})
		-- one star per level, gold up to the level owned (the fishing games' purple stars, in cafe gold)
		local starRow: Frame = Create("Frame", {
			Name = "Stars",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(TEXT_LEFT, 38),
			Size = UDim2.fromOffset(upgrade.maxLevel * (STAR + 2), STAR),
			Parent = row,
		}, {
			Create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 2),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		local stars: { TextLabel } = {}
		for level = 1, upgrade.maxLevel do
			local star = text({
				Name = "Star",
				Size = UDim2.fromOffset(STAR, STAR),
				FontFace = Theme.fonts.display,
				TextSize = STAR,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextTruncate = Enum.TextTruncate.None,
				TextColor3 = Theme.colors.line,
				Text = "★",
				LayoutOrder = level,
				Parent = starRow,
			})
			Outline.text(star, 1.5)
			table.insert(stars, star)
		end
		local description = text({
			Name = "Description",
			Position = UDim2.fromOffset(TEXT_LEFT, 64),
			Size = UDim2.new(1, -(TEXT_LEFT + BUTTON_W + 24), 0, 20),
			TextSize = Theme.sizes.textSmall,
			TextColor3 = Theme.modal.subtext,
			Text = upgrade.description,
			Parent = row,
		})
		local buy = Button.new({
			name = "Buy",
			text = "",
			style = "gold",
			size = UDim2.fromOffset(BUTTON_W, Theme.sizes.touchMin + 6),
			anchorPoint = Vector2.new(1, 0.5),
			position = UDim2.new(1, -12, 0.5, 0),
			textSize = Theme.sizes.textBody + 1,
			parent = row,
			onClick = function()
				self._onBuy(upgrade.id)
			end,
		})
		self._rows[upgrade.id] = {
			frame = row,
			name = name,
			stars = stars,
			description = description,
			buy = buy,
			def = upgrade,
		}
	end

	-- Staff: one row per role, its slot squares built from the catalog's spots
	local layout = StaffSlots.rows(catalog.spots or {}, 1, nil)
	for index, role in layout do
		local row = card(role.role, ROW_HEIGHT, index, self._staff)
		iconBox(row, Theme.roleIcons[role.role] or Theme.icons.cats, Theme.colors.mintDark)
		text({
			Name = "Name",
			Position = UDim2.fromOffset(TEXT_LEFT, 8),
			Size = UDim2.fromOffset(200, 28),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textLarge,
			Text = role.name,
			Parent = row,
		})
		local summary = text({
			Name = "Summary",
			Position = UDim2.fromOffset(TEXT_LEFT, 36),
			Size = UDim2.new(1, -(TEXT_LEFT + BUTTON_W + 24), 0, 18),
			TextSize = Theme.sizes.textSmall,
			TextColor3 = Theme.modal.subtext,
			Parent = row,
		})
		local slotRow: Frame = Create("Frame", {
			Name = "Slots",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(TEXT_LEFT, 54),
			Size = UDim2.fromOffset(#role.slots * (SLOT + 6), SLOT),
			Parent = row,
		}, {
			Create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		local squares = {}
		for slotIndex, slot in role.slots do
			local square: TextButton = Create("TextButton", {
				Name = slot.spotId,
				Text = "",
				AutoButtonColor = false,
				BackgroundColor3 = Theme.colors.disabled,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(SLOT, SLOT),
				LayoutOrder = slotIndex,
				Parent = slotRow,
			}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }) })
			local border = Outline.border(square, Theme.sizes.stroke)
			local glyph = text({
				Name = "Glyph",
				Size = UDim2.fromScale(1, 1),
				FontFace = Theme.fonts.display,
				TextSize = Theme.sizes.textBody,
				TextColor3 = Theme.colors.white,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextTruncate = Enum.TextTruncate.None,
				Parent = square,
			})
			Outline.text(glyph, 1.5)
			-- the tier that opens a locked slot, small in its corner under the lock
			local tierTag = text({
				Name = "Tier",
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -2, 1, 0),
				Size = UDim2.fromOffset(SLOT, 14),
				FontFace = Theme.fonts.display,
				TextSize = Theme.sizes.textTiny,
				TextColor3 = Theme.colors.white,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextTruncate = Enum.TextTruncate.None,
				Text = "",
				ZIndex = 2,
				Parent = square,
			})
			Outline.text(tierTag, 1)
			square.Activated:Connect(function()
				local open = self._links
				if open and square:GetAttribute("Open") == true then
					open.openCatRoom()
				end
			end)
			table.insert(
				squares,
				{ button = square, glyph = glyph, tier = tierTag, border = border }
			)
		end
		local add = Button.new({
			name = "Add",
			text = "Add cat",
			style = "primary",
			size = UDim2.fromOffset(BUTTON_W, Theme.sizes.touchMin + 4),
			anchorPoint = Vector2.new(1, 0.5),
			position = UDim2.new(1, -12, 0.5, 0),
			textSize = Theme.sizes.textBody,
			parent = row,
			sound = false, -- the cat room swishes open
			onClick = function()
				local open = self._links
				if open then
					open.openCatRoom()
				end
			end,
		})
		self._roleRows[role.role] = {
			frame = row,
			summary = summary,
			squares = squares,
			add = add,
		}
	end
end

function UpgradeShop.setCatalog(self: any, catalog: Types.Catalog)
	self._catalog = catalog
	table.clear(self._catDefs)
	for _, def in catalog.cats do
		self._catDefs[def.id] = def
	end
	self:_buildRows()
	self._dirty = true
end

function UpgradeShop.render(self: any, state: Types.PlayerState)
	self._lastState = state
	if not self.frame.Visible then
		self._dirty = true
		return
	end
	self._dirty = false
	local tier = state.tier
	local catalog: Types.Catalog? = self._catalog
	self._panel:setTitle(
		"Upgrades",
		Format.tier(tier, if catalog then catalog.tiers else nil)
			.. "  ·  "
			.. Format.money(state.money)
	)
	if self._tab == "Staff" then
		self:_renderStaff(state)
		return
	end

	for upgradeId, row in self._rows do
		local def: Types.UpgradeDef = row.def
		local level = state.upgradeLevels[upgradeId] or 0
		local isMax = level >= def.maxLevel
		local nextCost = if isMax then nil else def.costs[level + 1]
		-- tier gates (data-model section 5b): level 1 needs requiresTier, higher levels the tier caps
		local needsTier: number? = def.requiresTier
		local perLevel = def.requiresTierAtLevel
		if perLevel and perLevel[level + 1] then
			needsTier = math.max(needsTier or 0, perLevel[level + 1])
		end
		local locked = needsTier ~= nil and tier < (needsTier :: number)

		for index, star in row.stars do
			star.TextColor3 = if index <= level then Theme.colors.gold else Theme.colors.line
		end

		if isMax then
			row.buy:setText("MAX")
			row.buy:setEnabled(false)
		elseif locked then
			row.buy:setText(Format.tier(needsTier :: number))
			row.buy:setEnabled(false)
		elseif nextCost == nil then
			row.buy:setText("—")
			row.buy:setEnabled(false)
		else
			row.buy:setText(Format.money(nextCost))
			row.buy:setEnabled(state.money >= nextCost)
		end
	end
end

function UpgradeShop._renderStaff(self: any, state: Types.PlayerState)
	local catalog: Types.Catalog? = self._catalog
	if not catalog then
		return
	end
	assert(catalog, "catalog")

	if catalog.tiers then
		local progress = RankUp.progress(catalog, state)
		local current = progress.current
		local nextTier = progress.nextTier
		self._rankTitle.Text = ("Tier %d%s"):format(
			progress.tier,
			if current then "  ·  " .. current.name else ""
		)
		if nextTier then
			local opens = if #progress.opens > 0
				then " opens " .. table.concat(progress.opens, ", ")
				else ""
			self._rankSub.Text = "Next: " .. nextTier.name .. opens
			self._rankButton:setText(if progress.ready then "Rank up!" else "See goals")
			self._rankButton:setStyle(if progress.ready then "gold" else "secondary")
			self._rankButton.instance.Visible = true
		else
			self._rankSub.Text = "Top tier: every slot is open"
			self._rankButton.instance.Visible = false
		end
	end

	-- cats resting in the cat room, so Add cat only lights when there is a cat to add
	local resting = 0
	local cats = state.cats
	if cats then
		for _, cat in cats do
			if cat.spotId == nil then
				resting += 1
			end
		end
	end

	for _, role in StaffSlots.rows(catalog.spots or {}, state.tier, cats) do
		local row = self._roleRows[role.role]
		if row then
			row.summary.Text = role.summary
			row.add.instance.Visible = role.open > 0
			row.add:setEnabled(resting > 0)
			for index, slot in role.slots do
				local square = row.squares[index]
				if square then
					local glyph: TextLabel = square.glyph
					local color = Theme.colors.disabled
					local label = Theme.icons.lock
					if slot.kind == "working" then
						local instance = if cats and slot.catUid then cats[slot.catUid] else nil
						local def: Types.CatDef? = if instance
							then self._catDefs[instance.catId]
							else nil
						color = Theme.rarityColor(if def then def.rarity else nil)
						label = StaffSlots.initial(
							if instance and instance.name
								then instance.name
								elseif def then def.name
								else "?"
						)
					elseif slot.kind == "open" then
						color = Theme.colors.good
						label = "+"
					end
					square.tier.Text = if slot.kind == "locked" then "T" .. slot.tier else ""
					square.button.BackgroundColor3 = color
					square.button:SetAttribute("Open", slot.kind == "open")
					glyph.Text = label
					glyph.TextSize = if slot.kind == "open"
						then Theme.sizes.textLarge
						else Theme.sizes.textBody
				end
			end
		end
	end
end

function UpgradeShop.destroy(self: any)
	for _, row in self._rows do
		row.buy:destroy()
	end
	for _, row in self._roleRows do
		row.add:destroy()
	end
	self._cafeTab:destroy()
	self._staffTab:destroy()
	self._rankButton:destroy()
	self._panel:destroy()
end

return UpgradeShop
