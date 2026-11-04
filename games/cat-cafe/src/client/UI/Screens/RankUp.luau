--!strict
-- Rank up card (F24, data-model section 5b): the current tier, the next tier's name, each requirement
-- ticked or not (coins, different cats, a rarity from Tier 3) and what the next tier opens. The button
-- only lights up when everything is met; the server checks it all again on RankUp.
-- RankUp.progress is shared with the HUD's tier and goal block so both always agree.
-- Where the window has the room (PC, tablet) it is TALL, everything in one column; on a short screen (a phone, sideways)
-- it is WIDE: the requirements on the left, what the tier opens and the button on the right, so it never runs off the
-- screen or under Roblox's menu buttons.

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local Format = require(script.Parent.Parent.Components.Format)
local Panel = require(script.Parent.Parent.Components.Panel)
local RankUpNeeds = require(script.Parent.Parent.Components.RankUpNeeds) -- #1141: the server's own counts
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

-- the dark window palette (#1028), in place of Theme.modal
local PAL = Theme.dark

export type Requirement = {
	label: string, -- "5 different cats"
	short: string, -- "Different cats", the HUD goal block's caption over its bar, where the status says how many
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
local TALL = Vector2.new(560, 470) -- the window where the screen has room for it
local WIDE = Vector2.new(840, 310) -- the window on a shorter screen
local LEFT = 0.6 -- the wide window's requirements column, a share of the content's width
local BUTTON = Vector2.new(260, 52)
local LIST_TOP = 58
local LIST_H = 3 * ROW_HEIGHT + 2 * Theme.sizes.gap
local OPENS_TOP = LIST_TOP + LIST_H + 10 -- the tall window's "It opens", under the requirements

local RARITY_WORDS: { [number]: string } = { "One", "Two", "Three", "Four", "Five" }

local function findTier(tiers: { Types.TierDef }, tier: number): Types.TierDef?
	for _, def in tiers do
		if def.tier == tier then
			return def
		end
	end
	return nil
end

local function requirement(
	label: string,
	short: string,
	have: number,
	need: number,
	haveText: string?,
	needText: string?
): Requirement
	local met = have >= need
	return {
		label = label,
		short = short,
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
		("Money x%s"):format((string.format("%.2f", nextTier.multiplier):gsub("0$", "")))
	)
	local caps = {}
	local before = if current then current.caps else nil
	if not before or nextTier.caps.tables > before.tables then
		table.insert(caps, ("tables to %d"):format(nextTier.caps.tables))
	end
	if not before or nextTier.caps.espresso > before.espresso then
		table.insert(caps, ("espresso to %d"):format(nextTier.caps.espresso))
	end
	if not before or nextTier.caps.net > before.net then
		table.insert(caps, ("net to %d"):format(nextTier.caps.net))
	end
	-- F82: each tier opens one more bowl level
	if not before or nextTier.caps.lure_bowl > before.lure_bowl then
		table.insert(caps, ("bait bowl to %d"):format(nextTier.caps.lure_bowl))
	end
	-- F88: each tier opens one more Lucky Cat level
	local lucky: number? = (nextTier.caps :: any).lucky_cat
	local luckyBefore: number? = if before then (before :: any).lucky_cat else nil
	if lucky ~= nil and lucky > 0 and lucky > (luckyBefore or 0) then
		table.insert(caps, ("Lucky Cat to %d"):format(lucky))
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
		local needs = RankUpNeeds.of(nextTier, state)
		table.insert(
			requirements,
			requirement(
				Format.money(nextTier.cost) .. " coins",
				"Coins",
				needs.coinsHave,
				needs.coinsNeed,
				Format.money(state.money),
				Format.money(nextTier.cost)
			)
		)
		table.insert(
			requirements,
			requirement(
				("%d different cats"):format(nextTier.distinctCats),
				"Different cats",
				needs.catsHave,
				needs.catsNeed
			)
		)
		local needsRarity = needs.rarity
		if needsRarity then
			local count = needs.rarityNeed
			local have = needs.rarityHave
			local label = if count == 1
				then ("One cat, %s or better"):format(needsRarity)
				else ("%s different cats, %s or better"):format(
					RARITY_WORDS[count] or tostring(count),
					needsRarity
				)
			table.insert(
				requirements,
				requirement(label, ("%s or better"):format(needsRarity), have, count)
			)
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
		TextColor3 = PAL.text,
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
		dark = true, -- #1028
		name = "RankUp",
		color = Theme.colors.goldDark,
		icon = "🏆",
		title = "Rank up",
		subtitle = "Tier 1",
		size = UDim2.fromOffset(TALL.X, TALL.Y),
		onClose = callbacks.close,
	})
	self._panel = panel
	self.frame = panel.frame
	local content = panel.content
	self._wide = nil :: boolean?
	self._room = nil :: RBXScriptConnection?

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
		TextColor3 = PAL.subtext,
		Text = "To rank up you need",
		Parent = content,
	})
	local list: Frame = Create("Frame", {
		Name = "Requirements",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, LIST_TOP),
		Size = UDim2.new(1, 0, 0, LIST_H),
		Parent = content,
	}, {
		Create("UIListLayout", {
			Padding = UDim.new(0, Theme.sizes.gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self._list = list

	self._opensLabel = text({
		Name = "OpensLabel",
		Position = UDim2.fromOffset(0, OPENS_TOP),
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.subtext,
		Text = "It opens",
		Parent = content,
	})
	self._opens = text({
		Name = "Opens",
		Position = UDim2.fromOffset(0, OPENS_TOP + 22),
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
		size = UDim2.fromOffset(BUTTON.X, BUTTON.Y),
		anchorPoint = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, 0),
		textSize = Theme.sizes.textLarge - 2,
		enabled = false,
		parent = content,
		onClick = callbacks.rankUp,
	})

	-- the window's room is the modal container it sits in, known once it is parented
	self._parented = panel.frame.AncestryChanged:Connect(function()
		self:_watchRoom()
	end)
	self:_watchRoom()
	return self :: RankUp
end

function RankUp._watchRoom(self: any)
	if self._room then
		self._room:Disconnect()
		self._room = nil
	end
	local holder = self.frame.Parent
	if holder and holder:IsA("GuiObject") then
		self._room = holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			self:_fit()
		end)
		self:_fit()
	end
end

-- TALL where it fits, WIDE (no bigger than the room) where it does not.
function RankUp._fit(self: any)
	local holder = self.frame.Parent
	if not (holder and holder:IsA("GuiObject")) then
		return
	end
	local room = holder.AbsoluteSize / math.max(Scale.get(), 0.01)
	if room.Y <= 0 then
		return
	end
	local wide = room.Y < TALL.Y
	local size = if wide
		then Vector2.new(math.min(WIDE.X, room.X), math.min(WIDE.Y, room.Y))
		else TALL
	self.frame.Size = UDim2.fromOffset(math.floor(size.X), math.floor(size.Y))
	if self._wide == wide then
		return
	end
	self._wide = wide
	local half = Theme.sizes.gap / 2
	local left = if wide then UDim.new(LEFT, -half) else UDim.new(1, 0)
	self._nextTitle.Size = UDim2.new(left, UDim.new(0, 30))
	self._needsLabel.Size = UDim2.new(left, UDim.new(0, 20))
	self._list.Size = UDim2.new(left, UDim.new(0, LIST_H))
	local button = self._button.instance
	if wide then
		-- the right column: what opens from the top, the button at the foot
		local right = UDim.new(1 - LEFT, -half)
		local x = UDim.new(LEFT, half)
		self._opensLabel.Position = UDim2.new(x, UDim.new(0, 0))
		self._opensLabel.Size = UDim2.new(right, UDim.new(0, 20))
		self._opens.Position = UDim2.new(x, UDim.new(0, 22))
		self._opens.Size = UDim2.new(right, UDim.new(1, -(22 + BUTTON.Y + Theme.sizes.gap)))
		button.Position = UDim2.new(LEFT + (1 - LEFT) / 2, half / 2, 1, 0)
	else
		self._opensLabel.Position = UDim2.fromOffset(0, OPENS_TOP)
		self._opensLabel.Size = UDim2.new(1, 0, 0, 20)
		self._opens.Position = UDim2.fromOffset(0, OPENS_TOP + 22)
		self._opens.Size = UDim2.new(1, 0, 0, 84)
		button.Position = UDim2.new(0.5, 0, 1, 0)
	end
end

function RankUp.setCatalog(self: any, catalog: Types.Catalog)
	self._catalog = catalog
end

function RankUp._row(self: any, index: number, item: Requirement): Frame
	local row: Frame = Create("Frame", {
		Name = "Row" .. index,
		BackgroundColor3 = PAL.card,
		BorderSizePixel = 0,
		LayoutOrder = index,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		Parent = self._list,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }),
		Create("UIStroke", {
			Color = if item.met then Theme.colors.good else PAL.cardStroke,
			Thickness = Theme.sizes.stroke,
		}),
	})
	text({
		Name = "Label",
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -190, 1, -6),
		FontFace = Theme.fonts.bodyBold,
		Text = item.label,
		Parent = row,
	})
	text({
		Name = "Status",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 0),
		-- room for "$45,000 / $80,000" at full size (the economy pass of 2026-10-28 put ranks at $8K to $5M)
		Size = UDim2.new(0, 170, 1, -6),
		FontFace = Theme.fonts.display,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = if item.met then PAL.good else PAL.warn,
		Text = item.status,
		Parent = row,
	})
	local track: Frame = Create("Frame", {
		Name = "Track",
		BackgroundColor3 = PAL.line,
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
	self._parented:Disconnect()
	if self._room then
		self._room:Disconnect()
		self._room = nil
	end
	self._button:destroy()
	self._panel:destroy()
end

return RankUp
