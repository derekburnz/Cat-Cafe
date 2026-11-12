--!strict
-- Short messages that drop in under the tier pill and travel row and fade out. #2399 (Derek2: "way too many bubble pop
-- ups in the middle top of screen especially for mobile"): at most two on a phone and three on a PC
-- (ToastRules.maxVisible), and the same words again within ToastRules.REPEAT_SECONDS of the last time show nothing
-- (a warning always shows).
-- rainbow(text, rarity) is the rainbow stray's shout-out (F99, rainbow-coat.md section 2): the announce pill with a
-- slowly turning rainbow edge (Components/Rainbow), silent as the sound is Sound-Agent's shimmer.
-- prize(title, prize) is the prize toast (F94 rule 3, F100 camp extras): the line on the green pill with what it
-- paid as at most two little pictures after it (Components/PrizeChips, outlined for the pill); it needs the catalog
-- (setCatalog) for the crates' and potions' pictures. Silent: the moment that pays brings its own sound.
-- #1435 (the friend 11-05: four "That's all the Cat Whistles for today" toasts stacked over the Corner Shop): a line
-- that is already on screen is not stacked again; that toast moves to the newest spot, pops and starts its time over.
-- #2207 (Derek2 11-07: "IBowBeforeGod tamed an Epic Gardener Cat at their..."): a line too long for one row wraps
-- onto more rows and the pill grows taller, so every word shows (Toasts._wrap).
-- #2338 (Laptop-Tester, iPhone SE: the Welcome back toast lay over the Index, Quests and Potions tiles): the stack keeps
-- clear of the HUD's columns (avoid, HUD.toastAvoid). It stays centred where there is room, slides sideways into the
-- gap between the menu and the goal card when that gap takes the widest pill, else drops under them; on a short screen
-- only as many toasts show as fit over the bottom row (Toasts._place), and the rest wait their turn (QUEUE_MAX).
-- #2479 (Derek2: Claim all's rewards "make it look so cluttered"): a green "<title>: <reward>, <reward>, ..." toast
-- with at least three rewards (Components/RewardList) shows the title on its own line and the rewards under it as a
-- wrapped row of small chips, each with its picture, and stays a little longer the more it holds.
-- #2729 (Derek2 11-09: "big claims of index and quests cap at one line and put …"): a good or info toast, a claim
-- too, is one row that ends in "…" (ToastRules.oneLine); only a warning, a shout-out or (#3205) the restart warning
-- still wraps.
-- #3132 (Derek2: the Collector's message "to show a face of the cat and rarity and not cut off the name make the msg
-- shorter and easier to see"): cat(card) is a short banner in the same stack: the cat's face, a small title and under
-- it one rich line that shrinks, then wraps onto a second row, so a name is never cut. A tap runs card.onTap.

local CatPortrait = require(script.Parent.Parent.Components.CatPortrait)
local Create = require(script.Parent.Parent.Components.Create)
local FitText = require(script.Parent.Parent.Components.FitText)
local Outline = require(script.Parent.Parent.Components.Outline)
local PrizeChips = require(script.Parent.Parent.Components.PrizeChips)
local Rainbow = require(script.Parent.Parent.Components.Rainbow)
local RewardList = require(script.Parent.Parent.Components.RewardList)
local Scale = require(script.Parent.Parent.Scale)
local Sound = require(script.Parent.Parent.Components.Sound)
local Theme = require(script.Parent.Parent.Theme)
local ToastRules = require(script.Parent.Parent.Components.ToastRules)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

export type CatCard = {
	def: Types.CatDef?,
	shiny: boolean?, -- its gold coat's picture
	title: string, -- "Collector wants"
	line: string, -- rich text: the name and the rarity in its colour
	seconds: number?,
	onTap: (() -> ())?,
}

export type Toasts = {
	screenGui: ScreenGui,
	show: (
		self: Toasts,
		text: string,
		kind: Types.ToastKind?,
		quiet: boolean?,
		seconds: number?
	) -> (),
	announce: (self: Toasts, text: string, rarity: string?) -> (),
	rainbow: (self: Toasts, text: string, rarity: string?) -> (),
	prize: (self: Toasts, text: string, prize: Types.IndexPrize?) -> (),
	cat: (self: Toasts, card: CatCard) -> (),
	setCatalog: (self: Toasts, catalog: Types.Catalog) -> (),
	avoid: (self: Toasts, boxes: () -> { Types.Box }, floor: (() -> number)?) -> (),
	setHeld: (self: Toasts, held: boolean) -> (),
	setFocus: (self: Toasts, on: boolean) -> (), -- #2724: mid-catch toasts wait
	isHeld: (self: Toasts) -> boolean,
	pin: (self: Toasts, piece: GuiObject) -> (), -- #3701: the rest banner, kept at the head of the stack
	lastShown: (self: Toasts) -> number?,
	destroy: (self: Toasts) -> (),
}

local LIFETIME = 2.4
local ANNOUNCE_LIFETIME = 4 -- server shout-outs stay a little longer
local MAX_VISIBLE = ToastRules.maxVisible(Scale.isTouch()) -- #2399
local PRIZE_LIFETIME = 3.2 -- a prize toast stays long enough to read its pictures
local PRIZE_TILE = 30
local PRIZE_TEXT_MAX = 300 -- the line's widest on a prize toast, leaving room for the pictures
local TEXT_MAX = 424 -- the line's widest on any other toast
local ROW_H = 40 -- a one-row pill
local WRAP_PAD = 9 -- above and below the rows of a line that wraps
local PILL_MAX = 460 -- a plain toast's widest pill (its line and padding)
local PRIZE_PILL_MAX = 540 -- a prize toast's, with its pictures
local CLEAR_GAP = 12 -- between the HUD's boxes and the stack (#2338)
local EDGE = 16 -- the stack's least room to the screen's sides
local TOP = 148 -- the stack's top: under the tier pill and the corner icons
local STACK_GAP = 6 -- between the toasts
local REWARD_ROW = 400 -- #2479: the reward chips' row, which wraps onto more rows
local CHIP_H = 28
local CAT_LIFETIME = 3 -- #3132
local CAT_FACE = 40
local CAT_TITLE_H = 16
local CAT_LINE_H = 38 -- two rows of textSmall
local CAT_TEXT_W = 230
local CAT_PAD = 7
local CAT_WAIT_TRIES = 30 -- seconds a cat banner waits out a camera cut or a catch
local QUEUE_MAX = 3 -- toasts waiting for room on a short screen; past that the oldest waiting one is dropped

-- Every kind is white outlined text on a coloured pill with a dark border (simulator notifications).
local KIND_COLORS: { [string]: Color3 } = {
	info = Theme.colors.cocoaDeep,
	good = Theme.colors.good,
	warn = Theme.colors.warn,
	announce = Theme.colors.gold,
}

type Waiting = {
	text: string,
	fill: Color3,
	lifetime: number,
	bands: boolean?,
	prize: Types.IndexPrize?,
	oneLine: boolean?, -- #2729
}

local Toasts = {}
Toasts.__index = Toasts

function Toasts.new(parent: Instance): Toasts
	local self = setmetatable({}, Toasts) :: any
	local screenGui: ScreenGui = Create("ScreenGui", {
		Name = "CatCafeToasts",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 30,
	})
	local root: Frame = Create("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = screenGui,
	})
	self._uiScale = Scale.bind(root)
	self._stack = Create("Frame", {
		Name = "Stack",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, TOP), -- _place keeps it clear of the HUD
		Size = UDim2.fromOffset(PRIZE_PILL_MAX, 300),
		Parent = root,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, STACK_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self.screenGui = screenGui
	self._root = root
	self._boxes = nil :: (() -> { Types.Box })?
	self._floor = nil :: (() -> number)?
	self._room = MAX_VISIBLE
	self._said = {} :: { [string]: number } -- #2399: when each line last showed (os.clock)
	self._queue = {} :: { Waiting } -- #2338: toasts waiting for one on screen to go
	self._held = false -- #2408: a camera cut on screen; new toasts wait in _queue
	self._lastAt = nil :: number? -- #2407: when a toast last drew (os.clock), so tips keep clear of it
	self._resized = root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_place()
	end)
	self._catalog = nil :: Types.Catalog?
	self._order = 0
	self._alive = {} :: { Frame }
	self._restart = {} :: { [Frame]: () -> () } -- each live plain toast's "show it again" (the #1435 merge)
	if parent then
		screenGui.Parent = parent
	end
	return self :: Toasts
end

-- Without the server's rarity, a shout-out takes the colour of the last rarity it names as a whole word: the
-- message starts with a DisplayName, so "EpicGamer caught a Common Tabby" is Common (reviewer N58).
local function announceColor(text: string): Color3?
	local best: Color3? = nil
	local bestAt = 0
	for _, rarity in Theme.rarityOrder do
		local from = 1
		while true do
			local at, finish = text:find("%f[%a]" .. rarity .. "%f[%A]", from)
			if not at or not finish then
				break
			end
			if at > bestAt then
				best = Theme.rarityColor(rarity)
				bestAt = at
			end
			from = finish + 1
		end
	end
	return best
end

-- #2399: the same words shown again within ToastRules.REPEAT_SECONDS (and gone already) are dropped; a warning never
-- is. One still up starts its time over instead (_push, #1435).
function Toasts._repeat(self: any, text: string, kind: string?): boolean
	local now = os.clock()
	for line, at in self._said do
		if now - at >= ToastRules.REPEAT_SECONDS then
			self._said[line] = nil
		end
	end
	local up = false
	for _, live in self._alive do
		if live:GetAttribute("Line") == text then
			up = true
		end
	end
	local again = not up and ToastRules.isRepeat(kind, now, self._said[text])
	if not again then
		self._said[text] = now
	end
	return again
end

-- quiet skips the toast's own sound when the moment already has one (a miss hisses); seconds (#2915) keeps it up
-- that long in place of LIFETIME.
function Toasts.show(
	self: any,
	text: string,
	kind: Types.ToastKind?,
	quiet: boolean?,
	seconds: number?
)
	if kind == "announce" then
		self:announce(text)
		return
	end
	-- #2729: the cut lines, whoever shows them (the servers' come through UI.toast, a few client ones come here direct)
	if ToastRules.quiet(text, kind) or self:_repeat(text, kind) then
		return
	end
	-- warn covers can't afford, not allowed and bumps: the gentle bonk; everything else the small pop
	if not quiet then
		Sound.play(if kind == "warn" then "uiError" else "uiToast")
	end
	self:_push(
		text,
		KIND_COLORS[kind or "info"] or KIND_COLORS.info,
		seconds or LIFETIME,
		nil,
		nil,
		ToastRules.oneLine(kind, text)
	)
end

-- Server shout-outs (Pet Simulator 99 style) on the colour of the cat's rarity, a little longer than a toast.
-- Silent: Audio plays the shout-out sting from the Announce remote itself.
function Toasts.announce(self: any, text: string, rarity: string?)
	-- #3470: a Secret's pill is its near black swatch under the white words, not the pale UI colour
	local fill = if rarity == "Secret"
		then Theme.rarity.Secret.text
		elseif rarity and (Theme.rarity :: any)[rarity] then Theme.rarityColor(rarity)
		else announceColor(text) or KIND_COLORS.announce
	self:_push(text, fill, ANNOUNCE_LIFETIME)
end

-- A rainbow stray's shout-out: the announce pill in the cat's rarity colour with the rainbow bands on its edge.
function Toasts.rainbow(self: any, text: string, rarity: string?)
	local fill = if rarity == "Secret"
		then Theme.rarity.Secret.text
		elseif rarity and (Theme.rarity :: any)[rarity] then Theme.rarityColor(rarity)
		else KIND_COLORS.announce
	self:_push(text, fill, ANNOUNCE_LIFETIME, true)
end

-- #2338: boxes gives what the stack keeps clear of (HUD.toastAvoid), floor the top of what the bottom centre stacks,
-- as an offset up from the screen's bottom edge (HUD.bottomTop); each new toast places the stack again.
function Toasts.avoid(self: any, boxes: () -> { Types.Box }, floor: (() -> number)?)
	self._boxes = boxes
	self._floor = floor
	self:_place()
end

-- Where the stack goes, in design pixels: its centre and top. From TOP down, the boxes beside the two-row band under
-- the top split into a left and a right side; the stack takes the middle when the widest pill fits between them,
-- else the nearest spot in the gap; when the gap is too narrow the top moves under the lowest of those boxes.
function Toasts.spot(boxes: { Types.Box }, width: number, pill: number): (number, number)
	local middle = width / 2
	local top = TOP
	for _ = 1, #boxes + 1 do
		local left, right = EDGE, width - EDGE
		local under = top
		for _, box in boxes do
			if box.y1 > top and box.y0 < top + ROW_H * 2 + STACK_GAP then
				if (box.x0 + box.x1) / 2 < middle then
					left = math.max(left, box.x1 + CLEAR_GAP)
				else
					right = math.min(right, box.x0 - CLEAR_GAP)
				end
				under = math.max(under, box.y1 + CLEAR_GAP)
			end
		end
		if right - left >= pill then
			return math.clamp(middle, left + pill / 2, right - pill / 2), top
		end
		top = under
	end
	return middle, top
end

function Toasts._place(self: any)
	local scale = Scale.get()
	local size = self._root.AbsoluteSize / (if scale > 0 then scale else 1)
	local pill = PILL_MAX
	for _, live in self._alive do
		if live:GetAttribute("Prize") then
			pill = PRIZE_PILL_MAX
		end
	end
	local boxes: (() -> { Types.Box })? = self._boxes
	local x, top = Toasts.spot(if boxes then boxes() else {}, size.X, pill)
	self._stack.Position = UDim2.new(0, math.floor(x), 0, top)
	-- as many rows as fit over the bottom row (at least the newest toast)
	local floor: (() -> number)? = self._floor
	local bottom = size.Y + (if floor then floor() else -EDGE)
	self._room =
		math.clamp(math.floor((bottom - top + STACK_GAP) / (ROW_H + STACK_GAP)), 1, MAX_VISIBLE)
end

function Toasts.setCatalog(self: any, catalog: Types.Catalog)
	self._catalog = catalog
end

function Toasts.prize(self: any, text: string, prize: Types.IndexPrize?)
	if ToastRules.quiet(text, "good") then
		return -- #3080, #3054: a claim shows no bubble; the counters say it
	end
	self:_push(text, KIND_COLORS.good, PRIZE_LIFETIME, false, prize)
end

-- #3132: the cat banner. One at a time; a new one replaces the last. While a camera cut holds the toasts or a catch
-- runs it waits, a second at a time, and gives up after CAT_WAIT_TRIES.
function Toasts.cat(self: any, card: CatCard, tries: number?)
	if self._held or self._focus then
		local waited = (tries or 0) + 1
		if waited <= CAT_WAIT_TRIES then
			task.delay(1, function()
				if self._stack.Parent then
					self:cat(card, waited)
				end
			end)
		end
		return
	end
	local last: GuiObject? = self._catToast
	if last then
		last:Destroy()
	end
	self._order += 1
	self._lastAt = os.clock()
	local height = CAT_PAD * 2 + CAT_TITLE_H + CAT_LINE_H
	local toast: TextButton = Create("TextButton", {
		Name = "CatToast",
		AutoButtonColor = false,
		BackgroundColor3 = KIND_COLORS.info,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(CAT_PAD * 2 + CAT_FACE + 10 + CAT_TEXT_W + 8, height),
		LayoutOrder = self._order,
		Text = "",
		Parent = self._stack,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 18) }) })
	local border = Outline.border(toast)
	border.Transparency = 1
	local disc: Frame = Create("Frame", {
		Name = "Face",
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.colors.paper,
		BorderSizePixel = 0,
		Position = UDim2.new(0, CAT_PAD + 2, 0.5, 0),
		Size = UDim2.fromOffset(CAT_FACE, CAT_FACE),
		Parent = toast,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(
		disc,
		Theme.sizes.outline,
		Theme.rarityColor(if card.def then card.def.rarity else nil)
	)
	local portrait = CatPortrait.new({
		parent = disc,
		size = UDim2.fromScale(1, 1),
		still = true,
		head = true,
	})
	portrait:set(card.def, card.shiny == true)
	local left = CAT_PAD + 2 + CAT_FACE + 10
	local title: TextLabel = Create("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(left, CAT_PAD),
		Size = UDim2.fromOffset(CAT_TEXT_W, CAT_TITLE_H),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.colors.gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = card.title,
		Parent = toast,
	})
	Outline.text(title)
	local line: TextLabel = Create("TextLabel", {
		Name = "Line",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(left, CAT_PAD + CAT_TITLE_H),
		Size = UDim2.fromOffset(CAT_TEXT_W, CAT_LINE_H),
		FontFace = Theme.fonts.display,
		RichText = true,
		TextSize = Theme.sizes.textLarge,
		TextColor3 = Theme.colors.white,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = card.line,
		Parent = toast,
	})
	-- the name whole: it shrinks to textSmall, then takes the second row; never "…"
	FitText.shrink(line, Theme.sizes.textSmall)
	Outline.text(line)
	self._catToast = toast
	table.insert(self._alive, toast)
	self:_place()
	Tween.to(toast, Tween.FAST, { BackgroundTransparency = 0 })
	Tween.to(border, Tween.FAST, { Transparency = 0 })
	Tween.popIn(toast, 0.8)
	local tapped = toast.Activated:Connect(function()
		if card.onTap then
			card.onTap()
		end
	end)
	-- pushed off the stack by newer toasts, replaced or timed out: one clean-up
	toast.Destroying:Once(function()
		tapped:Disconnect()
		portrait:destroy()
		local index = table.find(self._alive, toast)
		if index then
			table.remove(self._alive, index)
		end
		if self._catToast == toast then
			self._catToast = nil
		end
	end)
	task.delay(card.seconds or CAT_LIFETIME, function()
		if not toast.Parent then
			return
		end
		Tween.to(border, Tween.SETTLE, { Transparency = 1 })
		local out = Tween.to(toast, Tween.SETTLE, { BackgroundTransparency = 1 })
		disc.Visible = false
		title.Visible = false
		line.Visible = false
		out.Completed:Once(function()
			toast:Destroy()
		end)
	end)
end

function Toasts._push(
	self: any,
	text: string,
	fill: Color3,
	lifetime: number,
	bands: boolean?,
	prize: Types.IndexPrize?,
	oneLine: boolean?
)
	-- #2408: held (a camera cut on screen): it waits in the queue and shows when the hold ends. #2724/#2727: so does
	-- any but a warning or the catch's own "Try again" while the catch circles or the rescue bar run (setFocus)
	local focusWait = self._focus
		and fill ~= KIND_COLORS.warn
		and string.sub(text, 1, 9) ~= "Try again"
	if self._held or focusWait then
		for _, waiting in self._queue do
			if waiting.text == text and prize == nil then
				return
			end
		end
		table.insert(self._queue, {
			text = text,
			fill = fill,
			lifetime = lifetime,
			bands = bands,
			prize = prize,
			oneLine = oneLine,
		})
		if #self._queue > QUEUE_MAX then
			table.remove(self._queue, 1)
		end
		return
	end
	-- the same words already up (and not fading out): that toast again, never a copy under it (#1435)
	if prize == nil then
		for _, live in self._alive do
			local restart: (() -> ())? = self._restart[live]
			if restart and live:GetAttribute("Line") == text then
				restart()
				return
			end
		end
	end
	-- #2338: a short screen with every row taken keeps it until one goes (the same words wait only once)
	self:_place()
	if self._room < MAX_VISIBLE and #self._alive >= self._room then
		for _, waiting in self._queue do
			if waiting.text == text and prize == nil then
				return
			end
		end
		table.insert(self._queue, {
			text = text,
			fill = fill,
			lifetime = lifetime,
			bands = bands,
			prize = prize,
			oneLine = oneLine,
		})
		if #self._queue > QUEUE_MAX then
			table.remove(self._queue, 1)
		end
		return
	end
	self._order += 1
	self._lastAt = os.clock()
	local toast: Frame = Create("Frame", {
		Name = "Toast",
		BackgroundColor3 = fill,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 40),
		LayoutOrder = self._order,
		Parent = self._stack,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18) }),
		Create(
			"UISizeConstraint",
			{ MaxSize = Vector2.new(if prize ~= nil then 540 else 460, ROW_H) }
		),
	})
	local border = Outline.border(toast)
	border.Transparency = 1
	if bands then
		border.Thickness += 1
		Rainbow.stroke(border)
	end
	local message: TextLabel = Create("TextLabel", {
		Name = "Text",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 1,
		TextColor3 = Theme.colors.white,
		TextTransparency = 1,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = text,
		Parent = toast,
	}, {
		Create("UISizeConstraint", {
			MaxSize = Vector2.new(if prize ~= nil then PRIZE_TEXT_MAX else TEXT_MAX, ROW_H),
		}),
	})
	-- #2729 (Derek2: "big claims of index and quests cap at one line and put …"): a good or info toast stays one row
	-- and ends in "…" (TextTruncate), the claims too; the reward chips (#2479) and the wrap are for the rest
	local title, rewards = nil, nil
	if prize == nil and fill == KIND_COLORS.good and not oneLine then
		title, rewards = RewardList.split(text)
	end
	if oneLine then
		local _, list = RewardList.split(text)
		if list ~= nil then
			lifetime = math.max(lifetime, PRIZE_LIFETIME) -- a claim's one line holds a little longer
		end
	elseif title ~= nil and rewards ~= nil then
		message.Text = title
		Toasts._rewardRows(toast, message, rewards)
		lifetime = RewardList.lifetime(#rewards, math.max(lifetime, PRIZE_LIFETIME))
	else
		Toasts._wrap(toast, message, if prize ~= nil then PRIZE_TEXT_MAX else TEXT_MAX)
	end
	local textOutline = Outline.text(message)
	textOutline.Transparency = 1
	local chips: PrizeChips.PrizeChips? = nil
	if prize ~= nil then
		-- the line, then the pictures on the same pill
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = toast,
		})
		message.LayoutOrder = 1
		local row = PrizeChips.new({
			parent = toast,
			name = "Prize",
			tile = PRIZE_TILE,
			textSize = Theme.sizes.textSmall,
			outlined = true,
			maxPictures = 2,
			showBonus = false,
			layoutOrder = 2,
		})
		local catalog: Types.Catalog? = self._catalog
		if catalog then
			row:setCatalog(catalog)
		end
		row:set(prize)
		chips = row
	end
	table.insert(self._alive, toast)
	if prize ~= nil then
		toast:SetAttribute("Prize", true)
	end
	self:_place()
	while #self._alive > self._room do
		local oldest = table.remove(self._alive :: { Frame }, 1)
		if oldest then
			self._restart[oldest] = nil
			oldest:Destroy()
		end
	end
	Tween.to(toast, Tween.FAST, { BackgroundTransparency = 0 })
	Tween.to(border, Tween.FAST, { Transparency = 0 })
	Tween.to(message, Tween.FAST, { TextTransparency = 0 })
	Tween.to(textOutline, Tween.FAST, { Transparency = 0 })
	Tween.popIn(toast, 0.8)
	local generation = 0
	local expire: (number) -> ()
	if prize == nil then
		toast:SetAttribute("Line", text)
		self._restart[toast] = function()
			generation += 1
			self._order += 1
			toast.LayoutOrder = self._order
			local index = table.find(self._alive, toast)
			if index then
				table.remove(self._alive, index)
			end
			table.insert(self._alive, toast)
			Tween.popIn(toast, 0.9)
			expire(generation)
		end
	end
	expire = function(mine: number)
		task.delay(lifetime, function()
			if mine == generation then
				self:_fade(toast, border, message, textOutline, chips)
			end
		end)
	end
	expire(generation)
end

-- #2479: the reward toast's shape: a taller pill, the title centred on top and under it the chips, each a darker
-- rounded tag with its picture and words, wrapping onto more rows within REWARD_ROW.
function Toasts._rewardRows(toast: Frame, message: TextLabel, rewards: { string })
	toast.AutomaticSize = Enum.AutomaticSize.XY
	toast.Size = UDim2.fromOffset(0, 0)
	local pillCap = toast:FindFirstChildOfClass("UISizeConstraint") :: UISizeConstraint?
	if pillCap then
		pillCap.MaxSize = Vector2.new(PILL_MAX, math.huge)
	end
	local pad = toast:FindFirstChildOfClass("UIPadding") :: UIPadding?
	if pad then
		pad.PaddingTop = UDim.new(0, WRAP_PAD)
		pad.PaddingBottom = UDim.new(0, WRAP_PAD + 2)
	end
	local corner = toast:FindFirstChildOfClass("UICorner") :: UICorner?
	if corner then
		corner.CornerRadius = UDim.new(0, ROW_H / 2)
	end
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = toast,
	})
	message.LayoutOrder = 1
	message.Size = UDim2.fromOffset(0, 26)
	local row: Frame = Create("Frame", {
		Name = "Rewards",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromOffset(REWARD_ROW, 0),
		LayoutOrder = 2,
		Parent = toast,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Wraps = true,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for index, reward in rewards do
		local chip: TextLabel = Create("TextLabel", {
			Name = "Reward",
			BackgroundColor3 = Theme.colors.black,
			BackgroundTransparency = 0.72,
			BorderSizePixel = 0,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, CHIP_H),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textSmall + 1,
			TextColor3 = Theme.colors.white,
			Text = RewardList.icon(reward) .. " " .. reward,
			LayoutOrder = index,
			Parent = row,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Create("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9) }),
		})
		Outline.text(chip, 1.5)
	end
end

-- A line wider than its row (in the label's own font and size) wraps: the label takes the row's full width and
-- grows down, and the pill grows with it, keeping its rounded ends at the one-row radius. GetTextBoundsAsync
-- yields, so a long line shows cut for a moment first and then opens up; a short line never changes.
function Toasts._wrap(toast: Frame, message: TextLabel, widest: number)
	local text = message.Text
	task.spawn(function()
		local ok, bounds = pcall(function()
			local params = Instance.new("GetTextBoundsParams")
			params.Text = text
			params.Font = message.FontFace
			params.Size = message.TextSize
			params.Width = 100000 -- one row
			return game:GetService("TextService"):GetTextBoundsAsync(params)
		end)
		if not ok or not bounds or bounds.X <= widest or not message.Parent then
			return
		end
		message.TextTruncate = Enum.TextTruncate.None
		message.TextWrapped = true
		message.AutomaticSize = Enum.AutomaticSize.Y
		message.Size = UDim2.fromOffset(widest, 0)
		local lineCap = message:FindFirstChildOfClass("UISizeConstraint") :: UISizeConstraint?
		if lineCap then
			lineCap.MaxSize = Vector2.new(widest, math.huge)
		end
		toast.AutomaticSize = Enum.AutomaticSize.XY
		local pillCap = toast:FindFirstChildOfClass("UISizeConstraint") :: UISizeConstraint?
		if pillCap then
			pillCap.MaxSize = Vector2.new(pillCap.MaxSize.X, math.huge)
		end
		local pad = toast:FindFirstChildOfClass("UIPadding") :: UIPadding?
		if pad then
			pad.PaddingTop = UDim.new(0, WRAP_PAD)
			pad.PaddingBottom = UDim.new(0, WRAP_PAD)
		end
		local corner = toast:FindFirstChildOfClass("UICorner") :: UICorner?
		if corner then
			corner.CornerRadius = UDim.new(0, ROW_H / 2)
		end
	end)
end

-- A toast's time is up: it fades and goes (or just goes, when it was pushed off the top already).
function Toasts._fade(
	self: any,
	toast: Frame,
	border: UIStroke,
	message: TextLabel,
	textOutline: UIStroke,
	chips: PrizeChips.PrizeChips?
)
	self._restart[toast] = nil -- fading: a new toast with its words is a new toast
	if not toast.Parent then
		if chips then
			chips:destroy()
		end
		return
	end
	if chips then
		chips.frame.Visible = false
	end
	local rewards = toast:FindFirstChild("Rewards") :: GuiObject? -- #2479
	if rewards then
		rewards.Visible = false
	end
	Tween.to(border, Tween.SETTLE, { Transparency = 1 })
	Tween.to(message, Tween.SETTLE, { TextTransparency = 1 })
	Tween.to(textOutline, Tween.SETTLE, { Transparency = 1 })
	local out = Tween.to(toast, Tween.SETTLE, { BackgroundTransparency = 1 })
	out.Completed:Once(function()
		local index = table.find(self._alive, toast)
		if index then
			table.remove(self._alive, index)
		end
		if chips then
			chips:destroy()
		end
		toast:Destroy()
		local waiting = table.remove(self._queue, 1)
		if waiting then
			self:_push(
				waiting.text,
				waiting.fill,
				waiting.lifetime,
				waiting.bands,
				waiting.prize,
				waiting.oneLine
			)
		end
	end)
end

-- #2408 (Derek2: "because of so many pop ups on cafe tier up its hard to see the cutscene showing next place
-- unlocked"): while held, new toasts wait (QUEUE_MAX at most, the newest kept) instead of drawing over a camera cut;
-- the hold's end shows them, as many as fit, the rest as rows free up.
function Toasts.setHeld(self: any, held: boolean)
	if self._held == held then
		return
	end
	self._held = held
	if held then
		return
	end
	local waiting: { Waiting } = table.clone(self._queue)
	table.clear(self._queue)
	for _, line in waiting do
		self:_push(line.text, line.fill, line.lifetime, line.bands, line.prize, line.oneLine)
	end
end

-- #2724 (Derek2: "remove the extra hud clutter when doing catching so its easier to see / focus") and #2727
-- ("remove the pop up bubbles when catching cats"): toasts that come mid-catch wait and show when it ends.
function Toasts.setFocus(self: any, on: boolean)
	if self._focus == on then
		return
	end
	self._focus = on
	if on or self._held then
		return
	end
	local waiting: { Waiting } = table.clone(self._queue)
	table.clear(self._queue)
	for _, line in waiting do
		self:_push(line.text, line.fill, line.lifetime, line.bands, line.prize, line.oneLine)
	end
end

-- #3701: a piece that is not a toast (the cafe rest banner) at the head of the stack, so it sits top centre, clear of
-- the HUD, and the toasts line up under it. Its own Visible decides whether it takes room.
function Toasts.pin(self: any, piece: GuiObject)
	piece.LayoutOrder = 0
	piece.Parent = self._stack
	self:_place()
end

function Toasts.isHeld(self: any): boolean
	return self._held == true
end

-- #2407: when a toast last drew (os.clock), or nil if none has; the tip pump keeps TipQueue.TOAST_QUIET clear of it.
function Toasts.lastShown(self: any): number?
	return self._lastAt
end

function Toasts.destroy(self: any)
	self._resized:Disconnect()
	Scale.unbind(self._uiScale)
	self.screenGui:Destroy()
end

return Toasts
