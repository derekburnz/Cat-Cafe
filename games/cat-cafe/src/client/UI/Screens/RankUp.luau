--!strict
-- Rank up card (F24, data-model section 5b): the current tier, the next tier's name, each requirement
-- ticked or not (coins, different cats, a rarity from Tier 3) and what the next tier opens. The button
-- only lights up when everything is met; the server checks it all again on RankUp.
-- RankUp.progress is shared with the HUD's tier and goal block so both always agree.
-- Where the window has the room (PC, tablet) it is TALL, everything in one column; on a short screen (a phone, sideways)
-- it is WIDE: the requirements on the left, what the tier opens and the button on the right, so it never runs off the
-- screen or under Roblox's menu buttons.
-- #2687: a gold line under "It opens" teases the next tier's station and its perk, and the "Perks" button in the title
-- bar opens the "Your perks" card (Screens/PerkCard) over the window.
-- #2915: just after the rank up to Tier 2 the button reads "Fly to the Park" (setFly) and takes the player to the
-- cannon with the Park card ringed (UI.cannon.flyToPark), until a flight or until the next rank up is ready.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- firstRankLock: seconds after a RANK UP press that has not taken before the window lets go (RankUp.locked)
local LOCK_GRACE = 5

local Button = require(script.Parent.Parent.Components.Button)
local CafeGrewLogic = require(script.Parent.Parent.Components.CafeGrewLogic) -- #4543
local Create = require(script.Parent.Parent.Components.Create)
local FitText = require(script.Parent.Parent.Components.FitText)
local Format = require(script.Parent.Parent.Components.Format)
local GoalLines = require(script.Parent.Parent.Components.GoalLines) -- #3997: no goal behind a live switch
local LiveFlags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LiveFlags"))
local MenuFamily = require(script.Parent.Parent.Components.MenuFamily)
local Panel = require(script.Parent.Parent.Components.Panel)
local PerkCardLogic = require(script.Parent.Parent.Components.PerkCardLogic) -- #2687: the next station's perk
local RankUpNeeds = require(script.Parent.Parent.Components.RankUpNeeds) -- #1141: the server's own counts
local RankUpRightAway =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RankUpRightAway"))
local Scale = require(script.Parent.Parent.Scale)
local ShopIcons = require(script.Parent.Parent.Components.ShopIcons)
local Theme = require(script.Parent.Parent.Theme)
local TutorialGlow = require(script.Parent.Parent.Components.TutorialGlow) -- #4847
local Types = require(script.Parent.Parent.Types)

-- the dark window palette (#1028), in place of Theme.modal
local PAL = MenuFamily.pal
local CARD = MenuFamily.card -- #3558: what sits on a picture card (cream in the family look)

export type Requirement = {
	label: string, -- "5 different cats"
	short: string, -- "Different cats", the HUD goal block's caption over its bar, where the status says how many
	touch: string?, -- #2999: that caption on a touch screen when it differs ("2 Mythical+ cats")
	status: string, -- "3 / 5" or "Done"
	fraction: number, -- 0 to 1
	met: boolean,
	kind: string?, -- #5218: "coins", "cats" or "rarity", what the step's Go does
	step: string?, -- #5218: the need as a step in plain words ("Catch 3 different cats")
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
	perks: (() -> ())?, -- #2687: the title bar's Perks button
	fly: (() -> ())?, -- #2915: the button while it reads "Fly to the Park" (setFly)
	go: ((kind: string) -> ())?, -- #5218: a step's Go (UI.init: the Cannon, to catch and earn)
}

export type RankUp = {
	frame: Frame,
	setCatalog: (self: RankUp, catalog: Types.Catalog) -> (),
	render: (self: RankUp, state: Types.PlayerState) -> (),
	-- #2915: just ranked up to Tier 2, the button reads `text` ("Fly to the Park") and calls callbacks.fly until the
	-- next rank up is ready; nil puts it back
	setFly: (self: RankUp, text: string?) -> (),
	setGrew: (self: RankUp, tier: number?) -> (),
	button: (self: RankUp) -> GuiObject, -- #3555: the Rank up button, for the first rank up's walk-through
	locked: (self: RankUp) -> boolean, -- firstRankLock: held open while the first rank up is ready
	destroy: (self: RankUp) -> (),
}

local RankUp = {}
RankUp.__index = RankUp

function RankUp.button(self: any): GuiObject
	return self._button.instance
end

-- Derek 2026-11-17 (switch firstRankLock, shared/RankUpRightAway.locked): the first rank up's window stays open while
-- the rank up is ready. If a press has not taken within LOCK_GRACE seconds (the server said no), it lets go, so a
-- player is never stuck behind it.
function RankUp.locked(self: any): boolean
	local pressed: number? = self._pressedAt
	if pressed ~= nil and os.clock() - pressed > LOCK_GRACE then
		return false
	end
	return self._locked == true
end

local ROW_HEIGHT = 46
local TALL = Vector2.new(560, 492) -- the window where the screen has room for it (#2687: 22 px for the perk teaser)
local WIDE = Vector2.new(840, 310) -- the window on a shorter screen
local LEFT = 0.6 -- the wide window's requirements column, a share of the content's width
local BUTTON = Vector2.new(260, 52)
local LIST_TOP = 58
local LIST_H = 3 * ROW_HEIGHT + 2 * Theme.sizes.gap
local OPENS_TOP = LIST_TOP + LIST_H + 10 -- the tall window's "It opens", under the requirements
-- #5258 (Derek 2026-11-18: "remove the it opens area of the rank up menu"): with the switch `noRankOpens` on, the
-- window has no "It opens" section (no label, perk teaser or cards). It is one column, as tall as the needs and the
-- button take, on every screen: TALL less the section's 128 px (its label, teaser and cards), no taller than the room.
RankUp.NO_OPENS_FLAG = "noRankOpens"
local BARE_HEIGHT = TALL.Y - 128
-- Sync's phone look (rankUpSteps): the steps window was BARE_HEIGHT for any count, so two steps left 88 px empty (one
-- row and STEPS_SLACK under the last). It now loses a row's height for each step under three and the slack, so the
-- Rank Up button sits right under the last step (RankUp.stepsHeight).
-- #5368 (Derek 2026-11-18: "rankup button shows on top of goals"): taking STEPS_SLACK off every count put the button
-- over step 3, since the steps view's "N steps left" line uses that room. The window now loses only the missing rows.
local STEPS_SLACK = 0
-- #5218 (Derek 2026-11-18: "goal should be to show steps clearly"): with the switch `rankUpSteps` on, the window is
-- the same one column (it implies noRankOpens), titled "Rank up to <tier>" over "N steps left" (gold "Ready!" once
-- all are met). The needs are numbered steps in rankUpBlocker's order (cats, rarity, coins) in plain words; a met step
-- keeps its green tick, and the first unmet one has a gold border and a Go button (callbacks.go). The grey button
-- reads "Rank Up (N steps left)".
RankUp.STEPS_FLAG = "rankUpSteps"
local GO_W = 64
-- Sync's portrait read (rankUpSteps): the steps window is about 420 px wide at the 0.75 touch floor, so on a 360 px
-- portrait phone it ran past the edge. It is now no wider than STEPS_MAX_W of the room, and a step's words wrap
-- (never under STEP_MIN_TEXT) instead of shrinking away.
local STEPS_MAX_W = 0.92
local STEP_MIN_TEXT = 14
-- The status box's width and its inset from the row's right edge, plus the gap kept between it and the label (the
-- label ran 8 px into the status before).
local STATUS_W = 170
local STATUS_IN = 14
local LABEL_GAP = 8
local function flagOn(key: string): boolean
	return LiveFlags.shown(key, ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. key))
end
local function steps(): boolean
	return flagOn(RankUp.STEPS_FLAG)
end
local function bare(): boolean
	return flagOn(RankUp.NO_OPENS_FLAG) or steps()
end

-- #5218: the needs as steps and how many are left (Components/RankUpNeeds.steps, where the specs check it)
RankUp.steps = RankUpNeeds.steps
local TEASER_TALL = 20 -- #2687: the perk teaser's one line in the tall window
local TEASER_WIDE = 38 -- and its two in the wide window's narrower column
local PERKS_BUTTON = Vector2.new(112, 36) -- #2687: the title bar's Perks button, a 36 px face on a mouse
local PERKS_RIGHT = 64 -- the title bar's room for the X, right of the Perks button
local PERKS_GAP = 14 -- #2839: on touch, the space between the Perks button and the X
local PERKS_TOUCH_WIDE = 92 -- #2857 (Derek2: "perks button ... too big"): a narrower face on touch
local CLOSE_OVERHANG = 10 -- Components/Panel's: how far the touch X sticks out past the window's right edge

-- #3961: the family look (batch 1 mock): each need on a cream card with its picture and a tick once met, and what the
-- tier opens as cream cards with a picture each, in place of the plain lines
local NEED_ICONS: { string } = { "💰", "🐱", "⭐" }
local OPENS_ICONS: { { string } } = {
	{ "^Opens the", "🗺️" },
	{ "role slots", "🪑" },
	{ "^Money", "💰" },
	{ "^Upgrade", "⬆️" },
	{ "^New decor", "🪴" },
}

local function opensIcon(line: string): string
	for _, pair in OPENS_ICONS do
		if string.find(line, pair[1]) then
			return pair[2]
		end
	end
	return "✨"
end

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
	-- a tier held by its live switch is not the goal yet (GoalLines.nextTier): the cafe reads as the top one until the
	-- new areas open, then the next tier's needs appear by themselves
	local nextTier: Types.TierDef? = GoalLines.nextTier(tiers, tier)
	local requirements: { Requirement } = {}
	local opens: { string } = {}
	if nextTier then
		-- the cat and rarity counts read the shared Catalog (as the server does), not `catalog.cats`
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
		requirements[#requirements].kind = "coins"
		requirements[#requirements].step = "Save " .. Format.money(nextTier.cost)
		if nextTier.distinctCats > 0 then -- #5533: coinsOnly asks no cats, so no row
			table.insert(
				requirements,
				requirement(
					(if nextTier.anyCats == true then "%d cats" else "%d different cats"):format(
						nextTier.distinctCats
					),
					if nextTier.anyCats == true then "Cats" else "Different cats", -- #4809
					needs.catsHave,
					needs.catsNeed
				)
			)
			requirements[#requirements].kind = "cats"
			requirements[#requirements].step = (if nextTier.anyCats == true
				then "Catch %d cats"
				else "Catch %d different cats"):format(nextTier.distinctCats)
		end
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
			local row = requirement(
				label,
				RankUpNeeds.rarityCaption(needsRarity, count, false),
				have,
				count
			)
			row.touch = RankUpNeeds.rarityCaption(needsRarity, count, true) -- #2999
			row.kind = "rarity"
			row.step = if count == 1
				then ("Find 1 %s or better"):format(needsRarity)
				else ("Find %d different %s or better"):format(count, needsRarity)
			table.insert(requirements, row)
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
	self._rowsKey = nil :: string? -- #4292: what the drawn rows say
	self._callbacks = callbacks
	self._goButton = nil :: any -- #5218: the first unmet step's Go (a Button)
	self._opensKey = nil :: string? -- #4292: what the drawn "It opens" cards say

	local panel = Panel.new({
		dark = true, -- #1028
		name = "RankUp",
		color = Theme.colors.goldDark,
		icon = "🏆",
		image = ShopIcons.hud("RankUp"), -- #2836: the drawn badge (the emoji until it loads)
		title = "Rank up",
		subtitle = "Tier 1",
		size = UDim2.fromOffset(TALL.X, TALL.Y),
		onClose = callbacks.close,
	})
	self._panel = panel
	self.frame = panel.frame
	local content = panel.content
	self._wide = nil :: boolean?
	self._bare = nil :: boolean? -- #5258: whether the window was last fitted without "It opens"
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
	-- #2687: the next tier's station and perk, in gold
	self._teaser = text({
		Name = "PerkTeaser",
		Position = UDim2.fromOffset(0, OPENS_TOP + 22),
		Size = UDim2.new(1, 0, 0, TEASER_TALL),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textSmall + 1,
		TextColor3 = PAL.gold,
		TextWrapped = true,
		Visible = false,
		Parent = content,
	})
	self._opensCards = {} :: { Frame }
	-- #3961: what opens as cards, where the family look has them (the plain lines stay hidden then)
	self._opensList = Create("ScrollingFrame", {
		Name = "OpensCards",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, OPENS_TOP + 22),
		Size = UDim2.new(1, 0, 0, 84),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = PAL.caramel,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		-- #4292 again (Derek 2026-11-14 22:01 UTC: the bottom card still flashed on and off): with three cards the
		-- list only just overflows. The bar came on, took 4 px from the cards' width, their wrapped words grew or
		-- shrank the canvas, the bar went off, the width came back, and round again every frame. The bar's strip is
		-- now always kept, so the cards' width never depends on the bar.
		VerticalScrollBarInset = Enum.ScrollBarInset.Always,
		Visible = true,
		Parent = content,
	}, {
		Create("UIListLayout", {
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Create("UIPadding", { -- room for the cards' outlines
			PaddingLeft = UDim.new(0, 2),
			PaddingRight = UDim.new(0, 2), -- the bar's own strip is kept beside this (VerticalScrollBarInset)
			PaddingTop = UDim.new(0, 2),
			PaddingBottom = UDim.new(0, 2),
		}),
	})
	self._opens = text({
		Name = "Opens",
		Visible = false,
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
		onClick = function()
			if self._flying and callbacks.fly ~= nil then
				callbacks.fly()
			else
				self._pressedAt = os.clock() -- firstRankLock: the X comes back if the rank up does not go through
				callbacks.rankUp()
				task.delay(LOCK_GRACE + 0.1, function()
					local state: Types.PlayerState? = self._state
					if state ~= nil and self.frame.Parent ~= nil then
						self:render(state)
					end
				end)
			end
		end,
	})
	self._pressedAt = nil :: number?
	self._locked = false
	self._fly = nil :: string?
	self._grewTier = nil :: number? -- #4543: the tier whose rank up grew the cafe (setGrew)
	self._flying = false
	self._state = nil :: Types.PlayerState?

	-- #2687: "Your perks", in the title bar left of the X
	self._perksButton = nil :: any
	if callbacks.perks then
		local header = panel.body:FindFirstChild("Header") :: Frame?
		local touch = Scale.isTouch()
		-- #2839 (Derek2 11-09, phone: "buttons squished"): on touch the button was a finger tall, taller than a short
		-- screen's header, and sat against the X. Now its face fits inside the header (Components/Button's Hit pad still
		-- reaches a finger's 44 px), and it keeps PERKS_GAP clear of the touch X, which is as wide as Panel draws it
		-- and sticks out past the window's edge.
		local height = PERKS_BUTTON.Y
		local right = PERKS_RIGHT
		local wide = PERKS_BUTTON.X
		if touch then
			wide = PERKS_TOUCH_WIDE
			local side = Theme.sizes.touchMin
			local closeWide = math.max(
				side,
				Scale.tapHeight(side, Theme.sizes.buttonDepth) - Theme.sizes.buttonDepth
			)
			right = closeWide - CLOSE_OVERHANG + PERKS_GAP
			height = math.min(PERKS_BUTTON.Y, panel.headerHeight - 14) -- room for its outline and lip
		end
		self._perksButton = Button.new({
			name = "Perks",
			text = "Perks",
			icon = "⭐",
			style = "ghost",
			size = UDim2.fromOffset(wide, height),
			anchorPoint = Vector2.new(1, 0.5),
			position = UDim2.new(1, -right, 0.5, if touch then 0 else -2),
			textSize = if touch then Theme.sizes.textSmall else Theme.sizes.textBody, -- #2857: smaller on touch
			zIndex = 3,
			parent = header or content,
			onClick = callbacks.perks,
		})
	end

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

-- The steps window's height for `count` steps (1 to 3): BARE_HEIGHT less each missing row and STEPS_SLACK.
function RankUp.stepsHeight(count: number): number
	local missing = math.clamp(3 - count, 0, 2)
	return BARE_HEIGHT - missing * (ROW_HEIGHT + Theme.sizes.gap) - STEPS_SLACK
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
	local noOpens = bare()
	local wide = not noOpens and room.Y < TALL.Y
	local bareHeight = if steps() then RankUp.stepsHeight(self._stepCount or 3) else BARE_HEIGHT
	local size = if noOpens
		then Vector2.new(
			math.min(TALL.X, if steps() then room.X * STEPS_MAX_W else room.X),
			math.min(bareHeight, room.Y)
		)
		elseif wide then Vector2.new(math.min(WIDE.X, room.X), math.min(WIDE.Y, room.Y))
		else TALL
	self.frame.Size = UDim2.fromOffset(math.floor(size.X), math.floor(size.Y))
	if self._wide == wide and self._bare == noOpens then
		return
	end
	self._wide = wide
	self._bare = noOpens
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
		self._teaser.Position = UDim2.new(x, UDim.new(0, 22))
		self._teaser.Size = UDim2.new(right, UDim.new(0, TEASER_WIDE))
		self._opens.Position = UDim2.new(x, UDim.new(0, 22 + TEASER_WIDE + 2))
		-- Review-QA's Studio pass 2026-11-13: on a short screen the last row sat under the button (its lip and
		-- touch pad stand taller than BUTTON.Y), so the list now ends above the button's full height
		local buttonTall = math.max(BUTTON.Y + Theme.sizes.buttonDepth, button.AbsoluteSize.Y)
		self._opens.Size = UDim2.new(
			right,
			UDim.new(1, -(22 + TEASER_WIDE + 2 + buttonTall + Theme.sizes.gap + 6))
		)
		self._opensList.Position = self._opens.Position
		self._opensList.Size = self._opens.Size
		button.Position = UDim2.new(LEFT + (1 - LEFT) / 2, half / 2, 1, 0)
	else
		self._opensLabel.Position = UDim2.fromOffset(0, OPENS_TOP)
		self._opensLabel.Size = UDim2.new(1, 0, 0, 20)
		self._teaser.Position = UDim2.fromOffset(0, OPENS_TOP + 22)
		self._teaser.Size = UDim2.new(1, 0, 0, TEASER_TALL)
		self._opens.Position = UDim2.fromOffset(0, OPENS_TOP + 22 + TEASER_TALL + 2)
		self._opens.Size = UDim2.new(1, 0, 0, 84)
		self._opensList.Position = self._opens.Position
		self._opensList.Size = self._opens.Size
		button.Position = UDim2.new(0.5, 0, 1, 0)
	end
end

function RankUp.setCatalog(self: any, catalog: Types.Catalog)
	self._catalog = catalog
end

function RankUp._row(
	self: any,
	index: number,
	item: Requirement,
	asStep: boolean?,
	go: boolean?
): Frame
	local row: Frame = Create("Frame", {
		Name = "Row" .. index,
		BackgroundColor3 = CARD.card,
		BorderSizePixel = 0,
		LayoutOrder = index,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		Parent = self._list,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }),
		Create("UIStroke", {
			Color = if item.met
				then Theme.colors.good
				elseif go then Theme.colors.gold
				else CARD.cardStroke,
			Thickness = if go then Theme.sizes.stroke + 1 else Theme.sizes.stroke,
		}),
	})
	local left = 14
	local goRoom = if go then GO_W + 8 else 0 -- #5218
	-- #3961: the need's picture on the left
	local tile: TextLabel = text({
		Name = "Picture",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, -2),
		Size = UDim2.fromOffset(30, 30),
		BackgroundTransparency = 0,
		BackgroundColor3 = CARD.line,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 18,
		Text = if asStep then tostring(index) else NEED_ICONS[index] or "✨", -- #5218: the step's number
		Parent = row,
	})
	Create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = tile })
	left = 46
	-- Sync's portrait read (rankUpSteps): a step's label takes only the width left after the status and the Go button,
	-- with LABEL_GAP between, and wraps onto a second line
	local labelRight = if asStep then STATUS_IN + STATUS_W + LABEL_GAP else 176
	local label = text({
		Name = "Label",
		Position = UDim2.fromOffset(left, 0),
		Size = UDim2.new(1, -(left + labelRight + goRoom), 1, -6),
		FontFace = Theme.fonts.bodyBold,
		TextColor3 = CARD.text,
		Text = if asStep then (item.step or item.label) else item.label,
		Parent = row,
	})
	if asStep then
		label.TextWrapped = true
		label.TextTruncate = Enum.TextTruncate.None
	end
	text({
		Name = "Status",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -(STATUS_IN + goRoom), 0, 0),
		-- room for "$45,000 / $80,000" at full size (the economy pass of 2026-10-28 put ranks at $8K to $5M)
		Size = UDim2.new(0, STATUS_W, 1, -6),
		FontFace = Theme.fonts.display,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = if item.met then CARD.good else CARD.warn,
		Text = if item.met then "✓" else item.status,
		Parent = row,
	})
	if go then
		-- #5218: Go on the first unmet step
		local kind = item.kind or "coins"
		self._goButton = Button.new({
			name = "Go",
			text = "Go",
			style = "primary",
			size = UDim2.fromOffset(GO_W, ROW_HEIGHT - 8),
			anchorPoint = Vector2.new(1, 0.5),
			position = UDim2.new(1, -8, 0.5, -2),
			textSize = Theme.sizes.textBody,
			parent = row,
			onClick = function()
				local goTo: ((string) -> ())? = self._callbacks.go
				if goTo then
					goTo(kind)
				end
			end,
		})
	end
	-- #4479 (Derek 2026-11-15: "in the rankup cards on mobile the coins don't show the full ... $##/..."): the need and
	-- its numbers shrink to fit on a phone instead of ending in "..."
	FitText.shrink(label, if asStep then STEP_MIN_TEXT else nil)
	if not item.met then
		FitText.shrink(row:FindFirstChild("Status") :: TextLabel)
	end
	if item.met then
		-- #3961: a met need's tick in a green circle, as in the mock
		local tick = row:FindFirstChild("Status") :: TextLabel
		tick.AnchorPoint = Vector2.new(1, 0.5)
		tick.Position = UDim2.new(1, -10, 0.5, -2)
		tick.Size = UDim2.fromOffset(28, 28)
		tick.BackgroundTransparency = 0
		tick.BackgroundColor3 = Theme.colors.good
		tick.TextColor3 = Theme.colors.white
		tick.TextXAlignment = Enum.TextXAlignment.Center
		Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = tick })
	end
	local track: Frame = Create("Frame", {
		Name = "Track",
		BackgroundColor3 = CARD.line,
		BorderSizePixel = 0,
		Position = UDim2.new(0, left, 1, -9),
		Size = UDim2.new(1, -(left + 14 + goRoom), 0, 4),
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
	self._state = state
	local progress = RankUp.progress(catalog, state)
	local current = progress.current
	self._panel:setTitle(
		"Rank up",
		("Tier %d%s"):format(progress.tier, if current then "  ·  " .. current.name else "")
	)
	local nextTier = progress.nextTier
	-- #4292 (Derek 11-14: "those bottom white bubbles flash on and off"): render runs on every state push (money
	-- ticks), and it threw the rows and the "It opens" cards away and drew them again each time. The cards size
	-- themselves a frame later, so they blinked. Now they are drawn again only when what they say changes.
	local stepsOn = steps() -- #5218
	local shownRows: { Requirement } = progress.requirements
	local stepsLeft = 0
	if stepsOn then
		shownRows, stepsLeft = RankUp.steps(progress.requirements)
	end
	local rowsKey = if stepsOn then "steps\n" else ""
	if nextTier then
		local parts = {}
		for _, entry in shownRows do
			local item: Requirement = entry
			table.insert(
				parts,
				("%s|%s|%s|%.3f"):format(item.label, item.status, tostring(item.met), item.fraction)
			)
		end
		rowsKey = table.concat(parts, "\n")
	end
	if rowsKey ~= self._rowsKey then
		self._rowsKey = rowsKey
		for _, row in self._rows :: { Frame } do
			row:Destroy()
		end
		table.clear(self._rows)
		if self._goButton then
			self._goButton:destroy()
			self._goButton = nil
		end
		if nextTier then
			local goSet = false
			for index, item in shownRows do
				-- #5218: the first unmet step gets the Go button
				local go = stepsOn and not item.met and not goSet
				goSet = goSet or go
				local row: Frame = self:_row(index, item, stepsOn, go)
				table.insert(self._rows, row)
			end
		end
	end

	if not nextTier then
		self._nextTitle.Text = if current then current.name else "Top tier"
		self._needsLabel.Text = "You reached the top tier. Every area and role slot is open."
		self._opensLabel.Visible = false
		self._teaser.Visible = false
		self._opens.Text = ""
		self:_fillOpens({})
		self._button.instance.Visible = false
		return
	end
	self._nextTitle.Text = if stepsOn
		then "Rank up to " .. nextTier.name
		else ("Next: Tier %d  ·  %s"):format(nextTier.tier, nextTier.name)
	-- #4543: one gold line, no pop-up, while the card is on the tier whose rank up grew the cafe
	local grew = CafeGrewLogic.shows(self._grewTier, progress.tier)
	self._needsLabel.RichText = grew
	self._needsLabel.Text = if grew
		then ('<font color="#%s">%s</font>  To rank up you need'):format(
			PAL.gold:ToHex(),
			CafeGrewLogic.LINE
		)
		else "To rank up you need"
	if stepsOn and not grew then
		-- #5218: how many steps are left, gold "Ready!" once none are
		self._needsLabel.RichText = true
		self._needsLabel.Text = if stepsLeft == 0
			then ('<font color="#%s">Ready!</font>'):format(PAL.gold:ToHex())
			elseif stepsLeft == 1 then "1 step left"
			else ("%d steps left"):format(stepsLeft)
	end
	-- #5258: with noRankOpens on, no "It opens" section; a flip of the switch fits the window again
	local noOpens = bare()
	local stepCount = if stepsOn then #shownRows else nil
	if noOpens ~= self._bare or stepCount ~= self._stepCount then
		self._stepCount = stepCount
		self:_fit()
	end
	self._opensLabel.Visible = not noOpens
	local teaser = PerkCardLogic.teaser(progress.tier, PerkCardLogic.poolStands())
	self._teaser.Text = teaser or ""
	self._teaser.Visible = teaser ~= nil and not noOpens
	self._opens.Text = if noOpens then "" else table.concat(progress.opens, "\n")
	self:_fillOpens(if noOpens then {} else progress.opens)
	self._button.instance.Visible = true
	-- #2915: a ready rank up wins over "Fly to the Park"
	local fly: string? = if progress.ready then nil else self._fly
	self._flying = fly ~= nil
	self._button:setEnabled(progress.ready or fly ~= nil)
	-- #4920 item 7: the grey button says what is still missing ("Need 2 more kinds"), not "Not yet"
	local function short(amount: number): string
		return Format.money(amount)
	end
	local missing: string? = nil
	if not progress.ready and fly == nil then
		missing = RankUpNeeds.missing(nextTier, RankUpNeeds.of(nextTier, state), short)
	end
	if stepsOn and missing ~= nil then
		missing = if stepsLeft == 1
			then "Rank Up (1 step left)"
			else ("Rank Up (%d steps left)"):format(stepsLeft)
	end
	local words = fly or missing or "Not yet"
	if progress.ready then
		words = "RANK UP  ·  " .. Format.money(nextTier.cost)
	end
	self._button:setText(words)
	-- #4847 (Derek 2026-11-16, his screenshot: the Tier 1 window, both requirements met, nothing pointing): the first
	-- rank up's button gets the tutorial's ring and arrow whenever it is ready, wherever the window was opened (the
	-- dimmed walk-through, RankSpot, lights it only on the safe side). No dim, so the window's X still works.
	-- Derek 2026-11-17 (firstRankLock): while it is held open, the screen dims too and the X goes
	local on = LiveFlags.shown(
		RankUpRightAway.LOCK_FLAG,
		ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. RankUpRightAway.LOCK_FLAG)
	)
	self._locked = RankUpRightAway.locked(on, progress.tier, progress.ready)
	if not self._locked then
		self._pressedAt = nil
	end
	local held = self:locked()
	local close = self._panel._close
	if close ~= nil then
		close.instance.Visible = not held
	end
	if held ~= self._heldShown then
		-- TutorialGlow keeps a glow that is already there, so a change of dim takes it off first
		self._heldShown = held
		TutorialGlow.set(self._button.instance, false)
	end
	TutorialGlow.set(self._button.instance, progress.ready and progress.tier == 1, nil, not held)
end

-- #3961: one cream card per line of what the tier opens, its picture on the left
function RankUp._fillOpens(self: any, lines: { string })
	local key = table.concat(lines, "\n")
	if key == self._opensKey then
		return -- #4292: the same cards are already there
	end
	self._opensKey = key
	for _, card in self._opensCards :: { Frame } do
		card:Destroy()
	end
	table.clear(self._opensCards)
	for index, line in lines do
		local card: Frame = Create("Frame", {
			Name = "Open" .. index,
			BackgroundColor3 = CARD.card,
			BorderSizePixel = 0,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 30),
			LayoutOrder = index,
			Parent = self._opensList,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }),
			Create("UIStroke", { Color = CARD.cardStroke, Thickness = 1 }),
		})
		text({
			Name = "Picture",
			Position = UDim2.fromOffset(6, 3),
			Size = UDim2.fromOffset(24, 24),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextSize = 16,
			Text = opensIcon(line),
			Parent = card,
		})
		local words = text({
			Name = "Line",
			Position = UDim2.fromOffset(36, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, -42, 0, 30),
			FontFace = Theme.fonts.bodyBold,
			TextSize = Theme.sizes.textSmall,
			TextColor3 = CARD.text,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			Text = line,
			Parent = card,
		})
		Create("UIPadding", {
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
			Parent = words,
		})
		table.insert(self._opensCards, card)
	end
end

-- #4543: `tier` is the tier a rank up just grew the cafe at (nil: none); the card shows "Your cafe grew!" on it
function RankUp.setGrew(self: any, tier: number?)
	if self._grewTier == tier then
		return
	end
	self._grewTier = tier
	local state: Types.PlayerState? = self._state
	if state ~= nil then
		self:render(state)
	end
end

function RankUp.setFly(self: any, text: string?)
	if self._fly == text then
		return
	end
	self._fly = text
	local state: Types.PlayerState? = self._state
	if state ~= nil then
		self:render(state)
	end
end

function RankUp.destroy(self: any)
	self._parented:Disconnect()
	if self._room then
		self._room:Disconnect()
		self._room = nil
	end
	self._button:destroy()
	if self._goButton then
		self._goButton:destroy()
	end
	if self._perksButton then
		self._perksButton:destroy()
	end
	self._panel:destroy()
end

return RankUp
