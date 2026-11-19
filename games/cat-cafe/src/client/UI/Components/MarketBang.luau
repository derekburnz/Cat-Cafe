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
-- #4677 (Derek 2026-11-16: "the text here flashes when you walk", the Fish Market's Treats and perks bubble): the
-- billboard now stands on its point (SizeOffset) instead of hanging half below it, so far away, where its pixel
-- minimum makes it taller than its studs, it grows up into the sky rather than down into the stall's roof and sign,
-- which cut through it from frame to frame as the camera moved. Its height over the stall is also held steady: the
-- one-second look only moves it when the stall's top really changed (JUMP_STUDS), not for a part that sways.

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Create = require(script.Parent.Create)
local MarketBangLogic = require(script.Parent.MarketBangLogic)
local Outline = require(script.Parent.Outline)
local Scale = require(script.Parent.Parent.Scale)
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
MarketBang.LIFT = 0.5 -- studs from the top of the stall to the bubble's bottom edge (as before #4677 up close)
MarketBang.STAND = 0.5 -- #4677: SizeOffset.Y, the billboard's bottom edge on its point
MarketBang.JUMP_STUDS = 0.75 -- #4677: a smaller change in the stall's top leaves the "!" where it is
MarketBang.BOB_STUDS = 1
MarketBang.BOB_SECONDS = 2 -- one full bob, up and back down
MarketBang.LOOK_SECONDS = 1 -- a stall not streamed in yet is looked for again

export type Bang = { gui: BillboardGui, line: TextLabel, bob: Tween? }

-- The stall's main part and how far over it the top of the stall is, or nil while it is streamed out. The offset goes
-- into the BillboardGui's StudsOffsetWorldSpace, which is in the Adornee's own axes, so it is turned into the part's
-- space: a part exported upside down (the Mystery wagon's hood, #2645/#2649) no longer flips the "!" down into it.
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
	local up = Vector3.new(0, top - (part :: BasePart).Position.Y + MarketBang.LIFT, 0)
	local lift: Vector3 = (part :: BasePart).CFrame:VectorToObjectSpace(up)
	return part, lift
end

-- The red "!" over a dark bubble with one line; also the rescue spots' (Components/RescueBang).
function MarketBang.build(parent: Instance, name: string?): Bang
	local gui: BillboardGui = Create("BillboardGui", {
		Name = name or "CatCafeMarketBang",
		-- studs up close, never smaller than 130 x 64 px far away, so it reads across the plaza; #2762: a size smaller
		-- on a phone
		Size = UDim2.new(
			6 * Scale.phoneStuds(),
			Scale.billboard(130),
			3 * Scale.phoneStuds(),
			Scale.billboard(64)
		),
		LightInfluence = 0,
		AlwaysOnTop = false, -- walls in front hide it, as they hide the stall
		MaxDistance = MarketBang.RANGE,
		-- #2770 (Laptop-Tester: one close to the camera covered half a phone's screen): no bigger than at this many studs
		DistanceLowerLimit = Scale.BUBBLE_NEAR,
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
	}, {
		-- #4328: never scaled down to nothing while the billboard has no size yet (no Adornee)
		Create("UITextSizeConstraint", { MinTextSize = 8, MaxTextSize = 100 }),
	})
	Outline.text(line, 1.5)
	MarketBang.fixText(line)
	return { gui = gui, line = line, bob = nil }
end

-- #5390 (Derek 2026-11-19: "this fish market text missing issue is still there"): TextScaled inside a BillboardGui
-- sized in studs (its pixel size changes with every camera move) sometimes draws nothing while TextBounds still reads
-- a size, so #5261's zero-bounds check never fired. With the bangFixedText switch on the line is not scaled by the
-- engine: its TextSize is worked out here from the label's pixel size and its words, again whenever either changes.
MarketBang.FIXED_FLAG = "LiveFlag_bangFixedText"
function MarketBang.fixText(line: TextLabel)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local lastW, lastH, lastText = -1, -1, nil :: string?
	local function fit()
		if ReplicatedStorage:GetAttribute(MarketBang.FIXED_FLAG) ~= true then
			if not line.TextScaled then
				line.TextScaled = true
			end
			lastText = nil
			return
		end
		local size = line.AbsoluteSize
		if
			lastText == line.Text
			and math.abs(size.X - lastW) < 2
			and math.abs(size.Y - lastH) < 2
			and not line.TextScaled
		then
			return
		end
		lastW, lastH, lastText = size.X, size.Y, line.Text
		line.TextScaled = false
		line.TextWrapped = false
		line.TextSize = MarketBangLogic.fitSize(line.Text, size.X, size.Y)
	end
	line:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	line:GetPropertyChangedSignal("Text"):Connect(fit)
	local flag = ReplicatedStorage:GetAttributeChangedSignal(MarketBang.FIXED_FLAG):Connect(fit)
	line.Destroying:Connect(function()
		flag:Disconnect()
	end)
	fit()
end

-- #4328: sets a label's text again so a TextScaled label measured while its billboard had no size is laid out anew.
function MarketBang.relayout(line: TextLabel, words: string)
	line.Text = ""
	task.defer(function()
		if line.Parent ~= nil and line.Text == "" then
			line.Text = words
		end
	end)
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
			local made = MarketBang.build(self._parent, self._name)
			made.gui.SizeOffset = Vector2.new(0, MarketBang.STAND) -- #4677
			bang = made
			self._bangs[model] = made
		end
		if bang ~= nil then
			local anchor: BasePart?, lift = nil, Vector3.zero
			if words ~= nil then
				anchor, lift = anchorOf(model)
			end
			local gui: any = bang.gui
			local moved = gui.Adornee ~= anchor
			if moved then
				gui.Adornee = anchor -- nil while hidden, so a streamed-out stall isn't held on to
			end
			-- #4677: a new stall part, or a top that moved more than JUMP_STUDS; a part that sways leaves it be
			local held: Vector3? = gui.StudsOffsetWorldSpace -- (nil in the UI gate's stand-in billboards)
			if moved or held == nil or (held - lift).Magnitude > MarketBang.JUMP_STUDS then
				gui.StudsOffsetWorldSpace = lift
			end
			local on = anchor ~= nil
			local was = gui.Enabled
			gui.Enabled = on
			if words ~= nil and bang.line.Text ~= words then
				bang.line.Text = words
			elseif
				on
				and words ~= nil
				and (
					not was
					or (
						bang.line.TextBounds.X < 1
						and game:GetService("ReplicatedStorage")
								:GetAttribute("LiveFlag_bangRelayout")
							~= false
					)
				)
			then
				-- #4328 (Derek 2026-11-14: "sometimes banner text above fish market goes blank"): a billboard that
				-- comes back (its stall streamed in again) lays its scaled text out afresh.
				-- #5261 (Derek 2026-11-18: "this text bug above fish market for players is still there"): a bubble
				-- that is showing with its words but laid out to nothing (zero TextBounds) lays them out again at the
				-- next look; the bangRelayout switch, on unless set false, turns that part off
				MarketBang.relayout(bang.line, words)
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
