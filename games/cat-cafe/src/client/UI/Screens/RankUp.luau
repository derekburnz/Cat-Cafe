--!strict
-- Rank up card (F24, data-model section 5b): the current tier, the next tier's name, each requirement
-- ticked or not (coins, different cats, a rarity from Tier 3) and what the next tier opens. The button
-- only lights up when everything is met; the server checks it all again on RankUp.
-- RankUp.progress is shared with the HUD's tier pill so both always agree.

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local Format = require(script.Parent.Parent.Components.Format)
local Panel = require(script.Parent.Parent.Components.Panel)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

export type Requirement = {
	label: string, -- "5 different cats"
	status: string, -- "3 / 5" or "Done"
	fraction: number, -- 0 to 1
	met: boolean,
}

export type Progress = {
	tier: number,
	current: Types.TierDef?,
	nextTier: Types.TierDef?, -- nil at the top tier
	requirements: { Requirement },
	opens: { string },
	ready: boolean,
	fraction: number, -- mean of the requirement fractions, for the HUD bar
}

export type Callbacks = {
	rankUp: () -> (),
	close: () -> (),
}

export type RankUp = {
	frame: Frame,
	setCatalog: (self: RankUp, catalog: Types.Catalog) -> (),
	render: (self: RankUp, state: Types.PlayerState) -> (),
	destroy: (self: RankUp) -> (),
}

local RankUp = {}
RankUp.__index = RankUp

local ROW_HEIGHT = 46

local RARITY_WORDS: { [number]: string } = { "One", "Two", "Three", "Four", "Five" }

-- Common is 1, Mythical 5. Unknown rarities rank 0, so they never meet a requirement.
local function rarityRank(rarity: string): number
	return table.find(Theme.rarityOrder, rarity) or 0
end

local function findTier(tiers: { Types.TierDef }, tier: number): Types.TierDef?
	for _, def in tiers do
		if def.tier == tier then
			return def
		end
	end
	return nil
end

-- Distinct cats ever caught. collection (catId -> firstCaughtAt) is the source; a state without it falls
-- back to the cats owned now.
local function caughtIds(state: Types.PlayerState): { string }
	local ids = {}
	local source: { [string]: any } = state.collection or state.catsOwned
	for catId in source do
		table.insert(ids, catId)
	end
	return ids
end

local function requirement(
	label: string,
	have: number,
	need: number,
	haveText: string?,
	needText: string?
): Requirement
	local met = have >= need
	return {
		label = label,
		status = if met
			then "Done"
			else ("%s / %s"):format(
				haveText or Format.commas(have),
				needText or Format.commas(need)
			),
		fraction = if need <= 0 then 1 else math.clamp(have / need, 0, 1),
		met = met,
	}
end

-- What the next tier adds on top of the current one, in plain words.
local function opensList(
	catalog: Types.Catalog,
	current: Types.TierDef?,
	nextTier: Types.TierDef
): { string }
	local lines = {}
	table.insert(lines, "Opens the " .. Format.areaName(nextTier.area))
	local slotsBefore = if current then current.slots else 0
	if nextTier.slots > slotsBefore then
		table.insert(
			lines,
			("%d more role slots (%d in all)"):format(nextTier.slots - slotsBefore, nextTier.slots)
		)
	end
	table.insert(
		lines,
		("Tips x%s"):format((string.format("%.2f", nextTier.multiplier):gsub("0$", "")))
	)
	local caps = {}
	local before: { tables: number, espresso: number, net: number }? = if current
		then current.caps
		else nil
	if not before or nextTier.caps.tables > before.tables then
		table.insert(caps, ("tables to %d"):format(nextTier.caps.tables))
	end
	if not before or nextTier.caps.espresso > before.espresso then
		table.insert(caps, ("espresso to %d"):format(nextTier.caps.espresso))
	end
	if not before or nextTier.caps.net > before.net then
		table.insert(caps, ("net to %d"):format(nextTier.caps.net))
	end
	if #caps > 0 then
		local text = table.concat(caps, ", ")
		table.insert(lines, "Upgrade " .. text)
	end
	local decorNames = {}
	for _, def in catalog.decor do
		if def.requiresTier == nextTier.tier then
			table.insert(decorNames, def.name)
		end
	end
	if #decorNames > 0 then
		table.insert(lines, "New decor: " .. table.concat(decorNames, ", "))
	end
	return lines
end

function RankUp.progress(catalog: Types.Catalog, state: Types.PlayerState): Progress
	local tiers: { Types.TierDef } = catalog.tiers or {}
	local tier = state.tier or 1
	local current = findTier(tiers, tier)
	local nextTier = findTier(tiers, tier + 1)
	local requirements: { Requirement } = {}
	local opens: { string } = {}
	if nextTier then
		local rarityOf: { [string]: string } = {}
		for _, def in catalog.cats do
			rarityOf[def.id] = def.rarity
		end
		local ids = caughtIds(state)
		table.insert(
			requirements,
			requirement(
				Format.money(nextTier.cost) .. " coins",
				state.money,
				nextTier.cost,
				Format.money(state.money),
				Format.money(nextTier.cost)
			)
		)
		table.insert(
			requirements,
			requirement(
				("%d different cats"):format(nextTier.distinctCats),
				#ids,
				nextTier.distinctCats
			)
		)
		local needsRarity = nextTier.needsRarity
		if needsRarity then
			-- "or better": a rarer cat also counts (designer, data-model 5b), matching the server's
			-- Catching.rarityAtLeast over distinct catIds in the collection
			local count = nextTier.needsRarityCount or 1
			local minimum = rarityRank(needsRarity)
			local have = 0
			for _, catId in ids do
				local rarity = rarityOf[catId]
				if rarity and rarityRank(rarity) >= minimum then
					have += 1
				end
			end
			local label = if count == 1
				then ("One cat, %s or better"):format(needsRarity)
				else ("%s different cats, %s or better"):format(
					RARITY_WORDS[count] or tostring(count),
					needsRarity
				)
			table.insert(requirements, requirement(label, have, count))
		end
		opens = opensList(catalog, current, nextTier)
	end
	local ready = nextTier ~= nil
	local total = 0
	for _, item in requirements do
		ready = ready and item.met
		total += item.fraction
	end
	return {
		tier = tier,
		current = current,
		nextTier = nextTier,
		requirements = requirements,
		opens = opens,
		ready = ready,
		fraction = if #requirements > 0 then total / #requirements else 1,
	}
end

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

function RankUp.new(callbacks: Callbacks): RankUp
	local self = setmetatable({}, RankUp) :: any
	self._catalog = nil :: Types.Catalog?
	self._rows = {} :: { Frame }

	local panel = Panel.new({
		name = "RankUp",
		title = "Rank up",
		subtitle = "Tier 1",
		size = UDim2.fromOffset(560, 470),
		onClose = callbacks.close,
	})
	self._panel = panel
	self.frame = panel.frame
	local content = panel.content

	self._nextTitle = text({
		Name = "Next",
		Size = UDim2.new(1, 0, 0, 30),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		Parent = content,
	})
	self._needsLabel = text({
		Name = "NeedsLabel",
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.modal.subtext,
		Text = "To rank up you need",
		Parent = content,
	})
	local list: Frame = Create("Frame", {
		Name = "Requirements",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 58),
		Size = UDim2.new(1, 0, 0, 3 * ROW_HEIGHT + 2 * Theme.sizes.gap),
		Parent = content,
	}, {
		Create("UIListLayout", {
			Padding = UDim.new(0, Theme.sizes.gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self._list = list

	local opensTop = 58 + 3 * ROW_HEIGHT + 2 * Theme.sizes.gap + 10
	self._opensLabel = text({
		Name = "OpensLabel",
		Position = UDim2.fromOffset(0, opensTop),
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.modal.subtext,
		Text = "It opens",
		Parent = content,
	})
	self._opens = text({
		Name = "Opens",
		Position = UDim2.fromOffset(0, opensTop + 22),
		Size = UDim2.new(1, 0, 0, 84),
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextSize = Theme.sizes.textSmall + 1,
		Parent = content,
	})

	self._button = Button.new({
		name = "RankUpButton",
		text = "Not yet",
		style = "gold",
		size = UDim2.fromOffset(260, 52),
		anchorPoint = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, 0),
		textSize = Theme.sizes.textLarge - 2,
		enabled = false,
		parent = content,
		onClick = callbacks.rankUp,
	})
	return self :: RankUp
end

function RankUp.setCatalog(self: any, catalog: Types.Catalog)
	self._catalog = catalog
end

function RankUp._row(self: any, index: number, item: Requirement): Frame
	local row: Frame = Create("Frame", {
		Name = "Row" .. index,
		BackgroundColor3 = Theme.modal.card,
		BorderSizePixel = 0,
		LayoutOrder = index,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		Parent = self._list,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }),
		Create("UIStroke", {
			Color = if item.met then Theme.colors.good else Theme.modal.cardStroke,
			Thickness = Theme.sizes.stroke,
		}),
	})
	text({
		Name = "Label",
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -150, 1, -6),
		FontFace = Theme.fonts.bodyBold,
		Text = item.label,
		Parent = row,
	})
	text({
		Name = "Status",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 0),
		Size = UDim2.new(0, 130, 1, -6),
		FontFace = Theme.fonts.display,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = if item.met then Theme.colors.good else Theme.colors.warn,
		Text = item.status,
		Parent = row,
	})
	local track: Frame = Create("Frame", {
		Name = "Track",
		BackgroundColor3 = Theme.colors.line,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 14, 1, -9),
		Size = UDim2.new(1, -28, 0, 4),
		Parent = row,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = if item.met then Theme.colors.good else Theme.colors.caramel,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(item.fraction, 1),
		Parent = track,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	return row
end

function RankUp.render(self: any, state: Types.PlayerState)
	local catalog: Types.Catalog? = self._catalog
	if not catalog then
		return
	end
	local progress = RankUp.progress(catalog, state)
	local current = progress.current
	self._panel:setTitle(
		"Rank up",
		("Tier %d%s"):format(progress.tier, if current then "  ·  " .. current.name else "")
	)
	for _, row in self._rows :: { Frame } do
		row:Destroy()
	end
	table.clear(self._rows)

	local nextTier = progress.nextTier
	if not nextTier then
		self._nextTitle.Text = if current then current.name else "Top tier"
		self._needsLabel.Text = "You reached the top tier. Every area and role slot is open."
		self._opensLabel.Visible = false
		self._opens.Text = ""
		self._button.instance.Visible = false
		return
	end
	self._nextTitle.Text = ("Next: Tier %d  ·  %s"):format(nextTier.tier, nextTier.name)
	self._needsLabel.Text = "To rank up you need"
	for index, item in progress.requirements do
		local row: Frame = self:_row(index, item)
		table.insert(self._rows, row)
	end
	self._opensLabel.Visible = true
	self._opens.Text = table.concat(progress.opens, "\n")
	self._button.instance.Visible = true
	self._button:setEnabled(progress.ready)
	self._button:setText(
		if progress.ready then "Rank up  ·  " .. Format.money(nextTier.cost) else "Not yet"
	)
end

function RankUp.destroy(self: any)
	self._button:destroy()
	self._panel:destroy()
end

return RankUp
