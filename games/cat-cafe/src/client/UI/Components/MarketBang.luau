--!strict
-- #2214 (playtester crispi_255, via Derek2 11-07: "make the fish market more obvious that it's the place that has the
-- crate inventory maybe add an exclamation mark above the shop when you have a crate to open"): over each Golden Fish
-- Market stall (the server tags it `FishMarket`) a red "!" over a little bubble, "📦 2 crates to open", while the
-- player has unopened crates (state.crates). None, and it is gone. It bobs a stud every 2 s and holds still with
-- Reduce Motion, as the camp stations' "!" does (Components/ReadyBang). The billboards live in this player's
-- PlayerGui, so only they see theirs.
--
-- Roblox terms: a BillboardGui is 2D UI drawn at a point in the 3D world, always facing the camera. Its Adornee is
-- the part it hangs from, and MaxDistance hides it past that many studs.
--
--   MarketBang.new(parent)       the billboards; :update(crates, storeSeen?) with the player's crates, :destroy()
-- #2571: the Fish Market's own "!" also shows "🍪 Treats and perks to check out!" with no crates while the save's
-- storeSeen says the Treats and perks tab was never opened (MarketBangLogic.treatsNew).
-- The words (and whether it shows at all) are MarketBangLogic's, pure, so the cloud specs check them.
-- #2358 (Derek2: "show an exclamation mark near spin when you have one"): MarketBang.new(parent, options) hangs the
-- same "!" and bubble over other tagged models, options.tag (the Spin Wheel's "SpinWheel"), with options.line(value)
-- for the words or nil for none; :update(value) hands it the value. The words are read again every LOOK_SECONDS too,
-- so a line that depends on the time (the free spin at 00:00 UTC) changes by itself.

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Create = require(script.Parent.Create)
local MarketBangLogic = require(script.Parent.MarketBangLogic)
local Outline = require(script.Parent.Outline)
local Theme = require(script.Parent.Parent.Theme)

export type MarketBang = {
	-- the crates for the Fish Market's (with the save's storeSeen, #2571), or options.line's value
	update: (self: MarketBang, value: any, storeSeen: any?) -> (),
	destroy: (self: MarketBang) -> (),
}

export type Options = {
	tag: string, -- CollectionService tag of the models to hang a "!" over
	line: (value: any) -> string?, -- the bubble's words for the value, nil for no "!"
	name: string?, -- #2501: the billboards' name (default CatCafeMarketBang), so each kind can be told apart
}

local MarketBang = {}
MarketBang.__index = MarketBang

MarketBang.TAG = "FishMarket" -- FishMarketService.TAG
MarketBang.RANGE = 150 -- studs, as the camp stations' "!" (ReadyBangRange)
MarketBang.LIFT = 2 -- studs over the top of the stall
MarketBang.BOB_STUDS = 1
MarketBang.BOB_SECONDS = 2 -- one full bob, up and back down
MarketBang.LOOK_SECONDS = 1 -- a stall not streamed in yet is looked for again

export type Bang = { gui: BillboardGui, line: TextLabel, bob: Tween? }

-- The stall's main part and the world-space offset from it to LIFT studs over the top of the stall, straight over the
-- stall's pivot (its centre, where the services measure their ranges from), or nil while it is streamed out.
-- Laptop-Tester 11-09 (#2645, the real Mystery wagon): the offset was height only, from the main part, so a model whose
-- main part sits off to one side (or low) floated the "!" beside it; it is the pivot's X and Z now.
local function anchorOf(model: Instance): (BasePart?, Vector3)
	if not model:IsA("Model") or not model:IsDescendantOf(Workspace) then
		return nil, Vector3.zero
	end
	local stall = model :: Model
	local part: BasePart? = stall.PrimaryPart
		or stall:FindFirstChildWhichIsA("BasePart", true) :: BasePart?
	if part == nil then
		return nil, Vector3.zero
	end
	local box, size = stall:GetBoundingBox()
	local top = box.Position.Y + size.Y / 2
	local centre = stall:GetPivot().Position
	local from = (part :: BasePart).Position
	return part, Vector3.new(centre.X - from.X, top - from.Y + MarketBang.LIFT, centre.Z - from.Z)
end

-- The red "!" over a dark bubble with one line; also the rescue spots' (Components/RescueBang).
function MarketBang.build(parent: Instance, name: string?): Bang
	local gui: BillboardGui = Create("BillboardGui", {
		Name = name or "CatCafeMarketBang",
		-- studs up close, never smaller than 130 x 64 px far away, so it reads across the plaza
		Size = UDim2.new(6, 130, 3, 64),
		LightInfluence = 0,
		AlwaysOnTop = false, -- walls in front hide it, as they hide the stall
		MaxDistance = MarketBang.RANGE,
		ResetOnSpawn = false,
		Enabled = false,
		Parent = parent,
	})
	-- the red "!" on top
	local dot: Frame = Create("Frame", {
		Name = "Dot",
		BackgroundColor3 = Theme.colors.red,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(0.5, 0.5),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		ZIndex = 3,
		Parent = gui,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(dot, 2)
	local mark: TextLabel = Create("TextLabel", {
		Name = "Mark",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0.1),
		Size = UDim2.fromScale(1, 0.8),
		FontFace = Theme.fonts.display,
		TextScaled = true,
		TextColor3 = Theme.colors.white,
		Text = "!",
		ZIndex = 4,
		Parent = dot,
	})
	Outline.text(mark, 2)
	-- what waits, on a dark bubble under it
	local card: Frame = Create("Frame", {
		Name = "Bubble",
		BackgroundColor3 = Theme.colors.cocoaDeep,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(1, 0.44),
		Parent = gui,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0.4, 0) }),
		Create("UIPadding", {
			PaddingLeft = UDim.new(0.06, 0),
			PaddingRight = UDim.new(0.06, 0),
			PaddingTop = UDim.new(0.14, 0),
			PaddingBottom = UDim.new(0.14, 0),
		}),
	})
	Outline.border(card, 2)
	local line: TextLabel = Create("TextLabel", {
		Name = "Line",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.fonts.display,
		TextScaled = true,
		TextColor3 = Theme.colors.white,
		Text = "",
		Parent = card,
	})
	Outline.text(line, 1.5)
	return { gui = gui, line = line, bob = nil }
end

function MarketBang.new(parent: Instance, options: Options?): MarketBang
	local self = setmetatable({}, MarketBang) :: any
	self._parent = parent
	self._tag = if options then options.tag else MarketBang.TAG
	self._line = if options then options.line else nil -- nil: the Fish Market's own words (MarketBangLogic.line)
	self._name = if options then options.name else nil
	self._bangs = {} :: { [Instance]: Bang }
	self._crates = nil :: { [string]: number }?
	self._treatsNew = false -- #2571
	self._connections = {} :: { RBXScriptConnection }
	local function refresh()
		self:_apply()
	end
	table.insert(
		self._connections,
		CollectionService:GetInstanceAddedSignal(self._tag):Connect(refresh)
	)
	table.insert(
		self._connections,
		CollectionService:GetInstanceRemovedSignal(self._tag):Connect(function(model: Instance)
			local bang = self._bangs[model]
			if bang then
				bang.gui:Destroy()
				self._bangs[model] = nil
			end
		end)
	)
	table.insert(
		self._connections,
		GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(function()
			for _, bang: Bang in self._bangs do
				self:_still(bang)
			end
			refresh()
		end)
	)
	-- a stall streaming in later (or back in) is found within a second
	self._alive = true
	task.spawn(function()
		while self._alive do
			task.wait(MarketBang.LOOK_SECONDS)
			if self._alive then
				self:_apply()
			end
		end
	end)
	return self :: MarketBang
end

function MarketBang.update(self: any, value: any, storeSeen: any?)
	self._crates = value
	self._treatsNew = MarketBangLogic.treatsNew(storeSeen)
	self:_apply()
end

function MarketBang._still(_self: any, bang: Bang)
	local bob = bang.bob
	if bob ~= nil then
		bob:Cancel()
		bang.bob = nil
	end
	bang.gui.StudsOffset = Vector3.zero
end

function MarketBang._apply(self: any)
	local line: ((any) -> string?)? = self._line
	local words = if line ~= nil
		then line(self._crates)
		else MarketBangLogic.line(self._crates, self._treatsNew)
	for _, model in CollectionService:GetTagged(self._tag) do
		local bang: Bang? = self._bangs[model]
		if bang == nil and words ~= nil then
			bang = MarketBang.build(self._parent, self._name)
			self._bangs[model] = bang
		end
		if bang ~= nil then
			local anchor: BasePart?, lift = nil, Vector3.zero
			if words ~= nil then
				anchor, lift = anchorOf(model)
			end
			local gui: any = bang.gui
			if gui.Adornee ~= anchor then
				gui.Adornee = anchor -- nil while hidden, so a streamed-out stall isn't held on to
			end
			if gui.StudsOffsetWorldSpace ~= lift then
				gui.StudsOffsetWorldSpace = lift
			end
			local on = anchor ~= nil
			gui.Enabled = on
			if words ~= nil and bang.line.Text ~= words then
				bang.line.Text = words
			end
			if not on then
				self:_still(bang)
			elseif bang.bob == nil and not GuiService.ReducedMotionEnabled then
				local info = TweenInfo.new(
					MarketBang.BOB_SECONDS / 2,
					Enum.EasingStyle.Sine,
					Enum.EasingDirection.InOut,
					-1,
					true
				)
				local bob = TweenService:Create(
					gui,
					info,
					{ StudsOffset = Vector3.new(0, MarketBang.BOB_STUDS, 0) }
				)
				bob:Play()
				bang.bob = bob
			end
		end
	end
end

function MarketBang.destroy(self: any)
	self._alive = false
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	for _, bang: Bang in self._bangs do
		self:_still(bang)
		bang.gui:Destroy()
	end
	table.clear(self._bangs)
end

return MarketBang
