--!strict
-- Index Boards (F50, areas-and-stations B4): a noticeboard inside each area's gate with that player's own page of
-- the Index on it. The area's name, "6 / 10" and the gold count, its ten cats (dark silhouettes until found,
-- rarest last, like the Index), a red dot while a reward waits, and along the bottom the next reward with its
-- prize as little pictures with amounts under it ("Next reward · 6 cats · 2 to go", then the food "x3", a crate
-- "x1" and "+2% tips forever"; Derek 2026-10-27). A big prize shrinks to fit the board. A locked area's board
-- still shows from outside the gate with "Opens at Tier 3" over the cats, as a teaser.
--
-- Boards are models tagged "IndexBoard" with an `Area` attribute and a `Screen` part, 8 x 5 studs, whose Front face
-- shows the page (a `Face` attribute on Screen, such as "Back", turns it). Holding E on the board's "Index" prompt
-- opens the Index on that area's page, where the Claim buttons are, so the board needs no remote. When the model
-- has no ProximityPrompt this player gets a local one on Screen.
--
-- Roblox terms: a SurfaceGui is 2D UI drawn on one face of a part. Each player sees their own page, so the
-- SurfaceGui lives in PlayerGui with its Adornee set to the board's Screen (a SurfaceGui must sit in PlayerGui to
-- take input); when the board streams out and back in, the tag fires again and the page is hung on the new copy
-- (reviewer N129). A ProximityPrompt made on the client only exists, and only fires, for this player.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CatPortrait = require(script.Parent.Parent.Components.CatPortrait)
local Create = require(script.Parent.Parent.Components.Create)
local IndexRewards = require(script.Parent.Parent.Components.IndexRewards)
local Outline = require(script.Parent.Parent.Components.Outline)
local PrizeChips = require(script.Parent.Parent.Components.PrizeChips)
local Theme = require(script.Parent.Parent.Theme)
local TipJarLogic = require(script.Parent.Parent.Components.TipJarLogic)
local Types = require(script.Parent.Parent.Types)

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any

export type Callbacks = {
	open: (areaId: string) -> (), -- the board's prompt: open the Index on this area's page
}

export type IndexBoards = {
	setCatalog: (self: IndexBoards, catalog: Types.Catalog) -> (),
	render: (self: IndexBoards, state: Types.PlayerState) -> (),
	setNight: (self: IndexBoards, night: boolean) -> (),
	destroy: (self: IndexBoards) -> (),
}

local TAG = "IndexBoard"
local PIXELS_PER_STUD = 64 -- an 8 x 5 stud Screen is 512 x 320
local MAX_DISTANCE = 90 -- studs; past this the page is not drawn
local NEAR_CHECK_SECONDS = 1 -- how often a board not yet seen checks whether the player has come near
local PROMPT_DISTANCE = 10
local HOLD_SECONDS = 0.5
local COLUMNS = 5
local MARGIN = 10
local HEADER = 56
local FOOTER = 88 -- the next reward's line and its prize pictures under it
local TILE = 38 -- a prize picture
local FALLBACK_AREA = "alley" -- a cat without an area is an Alleyway cat, as in the Index
local NIGHT_SHARE: number = Config.NightIncomeMultiplier or 0.6

type Cell = { def: Types.CatDef, portrait: CatPortrait.CatPortrait, loaded: boolean }
type Board = {
	model: Instance,
	areaId: string,
	gui: SurfaceGui,
	header: Frame,
	name: TextLabel,
	count: TextLabel,
	gold: TextLabel,
	dot: Frame,
	cells: { Cell },
	grid: Frame,
	lock: TextLabel,
	nextLabel: TextLabel,
	chips: PrizeChips.PrizeChips,
	prompt: ProximityPrompt?,
	ownPrompt: boolean, -- made here, so destroyed here
	hung: boolean, -- the page is on a Screen part
	near: boolean, -- the player has come within MAX_DISTANCE once, so its cats are cloned (review N157)
	connections: { RBXScriptConnection },
}

local IndexBoards = {}
IndexBoards.__index = IndexBoards

local function text(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.display,
		TextSize = 24,
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

local function areaOf(model: Instance): string?
	local area = model:GetAttribute("Area")
	return if type(area) == "string" and area ~= "" then area else nil
end

local function screenOf(model: Instance): BasePart?
	local screen = model:FindFirstChild("Screen", true)
	return if screen and screen:IsA("BasePart") then screen :: BasePart else nil
end

local FACES: { [string]: Enum.NormalId } = {
	Front = Enum.NormalId.Front,
	Back = Enum.NormalId.Back,
	Left = Enum.NormalId.Left,
	Right = Enum.NormalId.Right,
	Top = Enum.NormalId.Top,
	Bottom = Enum.NormalId.Bottom,
}

local function faceOf(screen: BasePart): Enum.NormalId
	local face = screen:GetAttribute("Face")
	return if type(face) == "string" and FACES[face] then FACES[face] else Enum.NormalId.Front
end

-- A prompt the model brought itself (any ProximityPrompt in it but the one made here), or nil.
local function modelPrompt(model: Instance, ours: ProximityPrompt?): ProximityPrompt?
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("ProximityPrompt") and descendant ~= ours then
			return descendant :: ProximityPrompt
		end
	end
	return nil
end

local function rarityRank(rarity: string): number
	return table.find(Theme.rarityOrder, rarity) or #Theme.rarityOrder + 1
end

-- The area's cats as the Index orders them: rarest last, catalog order within a rarity.
local function areaCats(catalog: Types.Catalog, areaId: string): { Types.CatDef }
	local list: { Types.CatDef } = {}
	local order: { [string]: number } = {}
	for index, def in catalog.cats do
		if (def.area or FALLBACK_AREA) == areaId then
			table.insert(list, def)
			order[def.id] = index
		end
	end
	table.sort(list, function(a: Types.CatDef, b: Types.CatDef): boolean
		local ra, rb = rarityRank(a.rarity), rarityRank(b.rarity)
		if ra ~= rb then
			return ra < rb
		end
		return order[a.id] < order[b.id]
	end)
	return list
end

function IndexBoards.new(parent: Instance, callbacks: Callbacks): IndexBoards
	local self = setmetatable({}, IndexBoards) :: any
	self._parent = parent
	self._callbacks = callbacks
	self._catalog = nil :: Types.Catalog?
	self._state = nil :: Types.PlayerState?
	self._night = false
	self._boards = {} :: { [Instance]: Board }
	self._prompts = {} :: { [Instance]: string } -- each board's prompt -> its area
	self._connections = {} :: { RBXScriptConnection }
	self._nearLoop = nil :: thread?

	for _, model in CollectionService:GetTagged(TAG) do
		self:_attach(model)
	end
	table.insert(
		self._connections,
		CollectionService:GetInstanceAddedSignal(TAG):Connect(function(model: Instance)
			self:_attach(model)
		end)
	)
	table.insert(
		self._connections,
		CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(model: Instance)
			self:_detach(model)
		end)
	)
	table.insert(
		self._connections,
		ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
			local areaId = self._prompts[prompt]
			if areaId then
				self._callbacks.open(areaId)
			end
		end)
	)
	-- Each cat on a board is a ViewportFrame with a whole cat model in it, so a board clones its cats only once
	-- the player first comes near enough to see it (review N157).
	self._nearLoop = task.spawn(function()
		while true do
			task.wait(NEAR_CHECK_SECONDS)
			self:_checkNear()
		end
	end)
	return self :: IndexBoards
end

function IndexBoards._attach(self: any, model: Instance)
	-- only boards placed in the world: the tagged templates in ReplicatedStorage.Assets get no page (review S75)
	if self._boards[model] or not model:IsDescendantOf(Workspace) then
		return
	end
	local areaId = areaOf(model)
	if areaId == nil then
		return
	end
	assert(areaId, "board area")
	local gui: SurfaceGui = Create("SurfaceGui", {
		Name = "IndexBoard_" .. areaId,
		ResetOnSpawn = false,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = PIXELS_PER_STUD,
		LightInfluence = 0,
		MaxDistance = MAX_DISTANCE,
		ClipsDescendants = true,
		Enabled = false,
	})
	local color = Theme.areaColors[areaId] or Theme.colors.caramel
	local card: Frame = Create("Frame", {
		Name = "Page",
		BackgroundColor3 = Theme.colors.paper,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(MARGIN, MARGIN),
		Size = UDim2.new(1, -MARGIN * 2, 1, -MARGIN * 2),
		Parent = gui,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 14) }) })
	Outline.border(card, 4)

	local header: Frame = Create("Frame", {
		Name = "Header",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, HEADER),
		Parent = card,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 14) }) })
	Outline.shade(header, 0.2)
	local name = text({
		Name = "Area",
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -200, 1, 0),
		TextSize = 30,
		TextColor3 = Theme.colors.white,
		Parent = header,
	})
	Outline.text(name, 2.5)
	local count = text({
		Name = "Count",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -96, 0, 0),
		Size = UDim2.new(0, 96, 1, 0),
		TextSize = 28,
		TextColor3 = Theme.colors.white,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = header,
	})
	Outline.text(count, 2.5)
	local gold = text({
		Name = "Gold",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 0),
		Size = UDim2.new(0, 76, 1, 0),
		TextSize = 24,
		TextColor3 = Theme.colors.gold,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = header,
	})
	Outline.text(gold, 2.5)
	local dot: Frame = Create("Frame", {
		Name = "Ready",
		BackgroundColor3 = Theme.colors.red,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(26, 26),
		Visible = false,
		ZIndex = 3,
		Parent = card,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(dot, 3)

	local grid: Frame = Create("Frame", {
		Name = "Cats",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, HEADER + 6),
		Size = UDim2.new(1, -24, 1, -(HEADER + FOOTER + 12)),
		Parent = card,
	}, {
		Create("UIGridLayout", {
			CellSize = UDim2.new(1 / COLUMNS, -6, 0.5, -4),
			CellPadding = UDim2.fromOffset(6, 6),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local lock = text({
		Name = "Locked",
		BackgroundColor3 = Theme.colors.ink,
		BackgroundTransparency = 0.25,
		Position = UDim2.fromOffset(12, HEADER + 6),
		Size = UDim2.new(1, -24, 1, -(HEADER + FOOTER + 12)),
		TextSize = 32,
		TextColor3 = Theme.colors.white,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		ZIndex = 2,
		Parent = card,
	})
	Create("UICorner", { CornerRadius = UDim.new(0, 10), Parent = lock })
	Outline.text(lock, 2.5)

	local footer: Frame = Create("Frame", {
		Name = "Next",
		BackgroundColor3 = Theme.colors.cream,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 8, 1, -8),
		Size = UDim2.new(1, -16, 0, FOOTER - 8),
		Parent = card,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 10) }) })
	Outline.border(footer, 2, Theme.modal.cardStroke)
	local nextLabel = text({
		Name = "Label",
		Position = UDim2.fromOffset(12, 4),
		Size = UDim2.new(1, -24, 0, 28),
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = footer,
	})
	local chips = PrizeChips.new({
		parent = footer,
		tile = TILE,
		textSize = 22,
		anchorPoint = Vector2.new(0.5, 0),
		position = UDim2.new(0.5, 0, 0, 34),
		align = Enum.HorizontalAlignment.Center,
		fitTo = footer,
		fitPad = 24,
	})
	local catalog: Types.Catalog? = self._catalog
	if catalog then
		chips:setCatalog(catalog)
	end

	local board: Board = {
		model = model,
		areaId = areaId,
		gui = gui,
		header = header,
		name = name,
		count = count,
		gold = gold,
		dot = dot,
		cells = {},
		grid = grid,
		lock = lock,
		nextLabel = nextLabel,
		chips = chips,
		prompt = nil,
		ownPrompt = false,
		hung = false,
		near = false,
		connections = {},
	}
	self._boards[model] = board
	self:_buildCells(board)
	-- a Screen or prompt that streams in after the model
	table.insert(
		board.connections,
		model.DescendantAdded:Connect(function(descendant: Instance)
			local screen = descendant:IsA("BasePart") and descendant.Name == "Screen"
			-- the model's own prompt arriving after a local one was made: use it instead
			local prompt = descendant:IsA("ProximityPrompt")
				and board.ownPrompt
				and descendant ~= (board.prompt :: any)
			if screen or prompt then
				self:_hang(board)
			end
		end)
	)
	gui.Parent = self._parent
	self:_hang(board)
	self:_renderBoard(board)
end

-- Marks boards the player has come near and draws their cats.
function IndexBoards._checkNear(self: any)
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return
	end
	local position = (root :: BasePart).Position
	for _, board in self._boards do
		if board.near then
			continue
		end
		local screen = screenOf(board.model)
		if screen and (screen.Position - position).Magnitude <= MAX_DISTANCE then
			board.near = true
			self:_renderBoard(board)
		end
	end
end

-- Puts the page on the Screen part and wires the prompt: the model's own, else one made here.
function IndexBoards._hang(self: any, board: Board)
	-- a prompt that went away with the model's parts (streamed out with Screen) is forgotten, so a new one is
	-- found or made when they stream back in (review S72)
	local old: ProximityPrompt? = board.prompt
	if old and not old:IsDescendantOf(board.model) then
		self._prompts[old] = nil
		if board.ownPrompt then
			old:Destroy()
		end
		board.prompt = nil
		board.ownPrompt = false
	end
	local screen = screenOf(board.model)
	board.gui.Adornee = screen :: any
	board.hung = screen ~= nil
	board.gui.Enabled = board.hung and self._state ~= nil
	if screen then
		board.gui.Face = faceOf(screen)
	end
	local current: ProximityPrompt? = board.prompt
	local existing = modelPrompt(board.model, if board.ownPrompt then current else nil)
	if existing and board.ownPrompt and current then
		-- the model brought its own prompt after all: drop the local one
		self._prompts[current] = nil
		current:Destroy()
		board.prompt = nil
		board.ownPrompt = false
	end
	if board.prompt == nil then
		local prompt: ProximityPrompt? = existing
		if prompt == nil and screen then
			prompt = Create("ProximityPrompt", {
				Name = "IndexPrompt",
				ActionText = "Index",
				ObjectText = board.name.Text,
				HoldDuration = HOLD_SECONDS,
				KeyboardKeyCode = Enum.KeyCode.E,
				MaxActivationDistance = PROMPT_DISTANCE,
				RequiresLineOfSight = false,
				Style = Enum.ProximityPromptStyle.Custom,
				Parent = screen,
			})
			board.ownPrompt = true
		end
		if prompt then
			board.prompt = prompt
			self._prompts[prompt] = board.areaId
		end
	end
end

function IndexBoards._buildCells(self: any, board: Board)
	for _, cell in board.cells do
		cell.portrait:destroy()
	end
	table.clear(board.cells)
	for _, child in board.grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local catalog: Types.Catalog? = self._catalog
	if catalog == nil then
		return
	end
	for order, def in areaCats(catalog, board.areaId) do
		local holder: Frame = Create("Frame", {
			Name = def.id,
			BackgroundColor3 = Theme.colors.cream,
			BorderSizePixel = 0,
			LayoutOrder = order,
			Parent = board.grid,
		}, { Create("UICorner", { CornerRadius = UDim.new(0, 10) }) })
		Outline.border(holder, 3, Theme.rarityColor(def.rarity))
		local portrait = CatPortrait.new({
			parent = holder,
			size = UDim2.fromScale(1, 1),
			still = true,
		})
		table.insert(board.cells, { def = def, portrait = portrait, loaded = false })
	end
end

function IndexBoards._renderBoard(self: any, board: Board)
	local catalog: Types.Catalog? = self._catalog
	local state: Types.PlayerState? = self._state
	board.gui.Enabled = catalog ~= nil and state ~= nil and board.hung
	if catalog == nil or state == nil then
		return
	end
	assert(catalog and state, "catalog and state")
	local areaId = board.areaId
	local area: Types.AreaDef? = nil
	local areas: { Types.AreaDef } = catalog.areas or {}
	for _, def in areas do
		if def.id == areaId then
			area = def
		end
	end
	local icon: string = (Theme.icons :: any)[areaId] or Theme.icons.collection
	board.name.Text = icon .. " " .. (if area then area.name else areaId)
	local prompt: ProximityPrompt? = board.prompt
	if board.ownPrompt and prompt then
		prompt.ObjectText = if area then area.name else areaId
	end

	local counts = IndexRewards.counts(catalog, state, areaId)
	board.count.Text = ("%d / %d"):format(counts.found, counts.total)
	board.gold.Text = "★ " .. tostring(counts.gold)
	local collection: { [string]: number } = state.collection or {}
	for _, cell in board.cells do
		if board.near and not cell.loaded then
			cell.portrait:set(cell.def)
			cell.loaded = cell.portrait:hasModel()
		end
		cell.portrait:setSilhouette(collection[cell.def.id] == nil)
	end

	local locked = area ~= nil and (state.tier or 1) < area.tier
	board.lock.Visible = locked
	if area and locked then
		board.lock.Text = ("%s Opens at Tier %d"):format(Theme.icons.lock, area.tier)
	end

	local views = IndexRewards.views(catalog, state, areaId)
	local nextView = IndexRewards.nextView(views)
	local ready = nextView ~= nil and nextView.state == "ready"
	board.dot.Visible = ready
	if nextView == nil then
		board.nextLabel.Text = if #views > 0 then "Every reward claimed!" else ""
		board.nextLabel.TextColor3 = Theme.colors.goodDark
		board.chips:set(nil)
		return
	end
	assert(nextView, "next reward")
	local need = IndexRewards.needLabel(nextView.milestone, counts.total)
	board.nextLabel.Text = if ready
		then ("Reward ready! Open the Index · %s"):format(need)
		else ("Next reward · %s · %d to go"):format(need, IndexRewards.toGo(nextView))
	board.nextLabel.TextColor3 = if ready then Theme.colors.goodDark else Theme.modal.text
	board.chips:set(nextView.prize, {
		gold = IndexRewards.isGold(nextView.milestone),
		dayRate = TipJarLogic.dayRate(state.incomePerSecond, self._night, NIGHT_SHARE),
		spinsBanked = if state.spin then state.spin.banked else nil,
	})
end

function IndexBoards._detach(self: any, model: Instance)
	local board: Board? = self._boards[model]
	if not board then
		return
	end
	assert(board, "board")
	for _, connection in board.connections do
		connection:Disconnect()
	end
	local prompt: ProximityPrompt? = board.prompt
	if prompt then
		self._prompts[prompt] = nil
		if board.ownPrompt then
			prompt:Destroy()
		end
	end
	for _, cell in board.cells do
		cell.portrait:destroy()
	end
	board.chips:destroy()
	board.gui:Destroy()
	self._boards[model] = nil
end

function IndexBoards.setCatalog(self: any, catalog: Types.Catalog)
	self._catalog = catalog
	for _, board in self._boards do
		board.chips:setCatalog(catalog)
		self:_buildCells(board)
		self:_renderBoard(board)
	end
end

function IndexBoards.render(self: any, state: Types.PlayerState)
	self._state = state
	for _, board in self._boards do
		self:_renderBoard(board)
	end
end

-- After dark the synced income is the night share, so a prize that grows with the cafe is priced from the day rate.
function IndexBoards.setNight(self: any, night: boolean)
	self._night = night
	for _, board in self._boards do
		self:_renderBoard(board)
	end
end

function IndexBoards.destroy(self: any)
	if self._nearLoop then
		task.cancel(self._nearLoop)
		self._nearLoop = nil
	end
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	local models: { Instance } = {}
	for model in self._boards do
		table.insert(models, model)
	end
	for _, model in models do
		self:_detach(model)
	end
end

return IndexBoards
