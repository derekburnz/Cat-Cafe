--!strict
-- The pity cat's tag (#2099, luck-and-rare-moments.md 1j): a small rounded "Pity cat" tag with a paw-star icon over
-- any stray wearing the server's `PityCat` attribute, so it can be told from the other Legendaries around it. Gold
-- with dark brown words for a Legendary, violet with a thin rainbow edge and white words for a Mythical. It shows
-- within PityTagLogic.RANGE (150) studs on top of walls and bushes, and past ICON_STUDS (60) it is only the icon.
-- It sits above where the mood icon goes, clear of the cat's face, hides while a net holds the cat (the catch "!"
-- takes that spot) and comes back if it bolts, and goes with the attribute or the model. It never moves, so Reduce
-- Motion has nothing to stop. VFX's Effects/Pity draws the ground ring and the sparkles.
--   PityTags.new()   watches the Stray tag
--   tags:destroy()
--
-- Roblox terms: a BillboardGui draws 2D UI at a point in the world, facing the camera; AlwaysOnTop draws it over
-- walls, MaxDistance hides it past that many studs, and SizeOffset moves it by a share of its own size (here up).

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Create = require(script.Parent.Parent.Components.Create)
local Outline = require(script.Parent.Parent.Components.Outline)
local PityTagLogic = require(script.Parent.Parent.Components.PityTagLogic)
local Theme = require(script.Parent.Parent.Theme)

export type PityTags = {
	destroy: (self: PityTags) -> (),
}

type Entry = {
	part: BasePart,
	billboard: BillboardGui,
	tag: Frame,
	stroke: UIStroke,
	rainbow: UIGradient,
	icon: TextLabel,
	label: TextLabel,
	kind: string?,
}

local TAG = "Stray"
local ATTRIBUTE = "PityCat" -- shared/Pity.ATTRIBUTE
local WIDTH = 140 -- px, the billboard; the tag inside is as wide as its words
local HEIGHT = 28 -- px, the tag: about the mood icons' size
local ICON = 20 -- px, the paw-star
local TEXT_SIZE = 16
-- above the 56 px mood icon box (centred 0.8 studs over the cat's head) with 6 px between: (28 + 6 + 14) / 28
local RAISE = 48 / HEIGHT
local LIFT = 0.8 -- studs over the top of the cat, as the mood icon
local LOOK_SECONDS = 0.25 -- how often the distance (word or icon only) is looked at again

local VIOLET = Color3.fromHex("8A47EA") -- Theme.button.purple.bottom
local BROWN = Color3.fromHex("4A2E12")

local PityTags = {}
PityTags.__index = PityTags

local function anchorOf(model: Instance): (BasePart?, number)
	local part: BasePart? = nil
	if model:IsA("Model") then
		part = (model :: Model).PrimaryPart
	end
	if not part then
		local found = model:FindFirstChildWhichIsA("BasePart", true)
		part = if found then found :: BasePart else nil
	end
	if not part then
		return nil, 0
	end
	assert(part, "anchor part")
	local top = part.Position.Y + part.Size.Y / 2
	if model:IsA("Model") then
		local boxCFrame, boxSize = (model :: Model):GetBoundingBox()
		top = math.max(top, boxCFrame.Position.Y + boxSize.Y / 2)
	end
	return part, top - part.Position.Y
end

function PityTags.new(): PityTags
	local self = setmetatable({}, PityTags) :: any
	self._entries = {} :: { [Instance]: Entry }
	self._watched = {} :: { [Instance]: { RBXScriptConnection } }
	self._connections = {} :: { RBXScriptConnection }
	self._loop = nil :: RBXScriptConnection?
	self._lookedAt = 0
	for _, stray in CollectionService:GetTagged(TAG) do
		self:_watch(stray)
	end
	table.insert(
		self._connections,
		CollectionService:GetInstanceAddedSignal(TAG):Connect(function(stray: Instance)
			self:_watch(stray)
		end)
	)
	table.insert(
		self._connections,
		CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(stray: Instance)
			self:_unwatch(stray)
		end)
	)
	return self :: PityTags
end

-- PityCat can arrive after the tag, so every stray is watched and its tag made or dropped to match.
function PityTags._watch(self: any, stray: Instance)
	if self._watched[stray] then
		return
	end
	local refresh = function()
		self:_refresh(stray)
	end
	self._watched[stray] = {
		stray:GetAttributeChangedSignal(ATTRIBUTE):Connect(refresh),
		stray:GetAttributeChangedSignal("LockedBy"):Connect(refresh),
		stray.AncestryChanged:Connect(function()
			if not stray:IsDescendantOf(Workspace) then
				self:_unwatch(stray)
			end
		end),
	}
	self:_refresh(stray)
end

function PityTags._unwatch(self: any, stray: Instance)
	local watched = self._watched[stray]
	if watched then
		for _, connection in watched do
			connection:Disconnect()
		end
		self._watched[stray] = nil
	end
	self:_drop(stray)
end

function PityTags._refresh(self: any, stray: Instance)
	local kind = PityTagLogic.kind(stray:GetAttribute(ATTRIBUTE))
	if kind == nil then
		self:_drop(stray)
		return
	end
	local entry: Entry? = self._entries[stray]
	if not entry then
		entry = self:_make(stray)
		if not entry then
			return
		end
	end
	assert(entry, "entry")
	if entry.kind ~= kind then
		entry.kind = kind
		local mythical = kind == "Mythical"
		entry.tag.BackgroundColor3 = if mythical then VIOLET else Theme.colors.gold
		entry.label.TextColor3 = if mythical then Theme.colors.white else BROWN
		entry.stroke.Color = if mythical then Theme.colors.white else Theme.colors.goldDark
		entry.rainbow.Enabled = mythical -- the thin rainbow edge
	end
	entry.billboard.Enabled = PityTagLogic.shows(kind, stray:GetAttribute("LockedBy"))
	self:_look(entry)
	self:_startLoop()
end

function PityTags._make(self: any, stray: Instance): Entry?
	local part, height = anchorOf(stray)
	if not part then
		return nil
	end
	assert(part, "part")
	local billboard: BillboardGui = Create("BillboardGui", {
		Name = "CatCafePityTag",
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		SizeOffset = Vector2.new(0, RAISE),
		StudsOffsetWorldSpace = Vector3.new(0, height + LIFT, 0),
		AlwaysOnTop = true, -- a pity cat in a hiding spot can still be found
		MaxDistance = PityTagLogic.RANGE,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Enabled = false,
		Parent = part,
	})
	local tag: Frame = Create("Frame", {
		Name = "Tag",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, HEIGHT),
		BackgroundColor3 = Theme.colors.gold,
		BorderSizePixel = 0,
		Parent = billboard,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 4),
		}),
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local stroke: UIStroke = Create("UIStroke", {
		Color = Theme.colors.goldDark,
		Thickness = 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = tag,
	})
	local rainbow: UIGradient = Create("UIGradient", {
		Color = Theme.rainbow,
		Enabled = false,
		Parent = stroke,
	})
	-- the paw-star: a paw on a small cream disc with a sparkle on its corner
	local disc: Frame = Create("Frame", {
		Name = "Icon",
		Size = UDim2.fromOffset(ICON, ICON),
		BackgroundColor3 = Theme.colors.cream,
		BorderSizePixel = 0,
		LayoutOrder = 1,
		Parent = tag,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local icon: TextLabel = Create("TextLabel", {
		Name = "Paw",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.fonts.display,
		TextSize = 13,
		Text = "🐾",
		Parent = disc,
	})
	local star: TextLabel = Create("TextLabel", {
		Name = "Star",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.9, 0.12),
		Size = UDim2.fromOffset(10, 10),
		FontFace = Theme.fonts.display,
		TextSize = 11,
		TextColor3 = Theme.colors.gold,
		Text = "✦",
		Parent = disc,
	})
	Outline.text(star, 1)
	local label: TextLabel = Create("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, HEIGHT),
		FontFace = Theme.fonts.display,
		TextSize = TEXT_SIZE,
		TextColor3 = BROWN,
		Text = PityTagLogic.TEXT,
		LayoutOrder = 2,
		Parent = tag,
	}, { Create("UIPadding", { PaddingRight = UDim.new(0, 4) }) })
	local entry: Entry = {
		part = part,
		billboard = billboard,
		tag = tag,
		stroke = stroke,
		rainbow = rainbow,
		icon = icon,
		label = label,
		kind = nil,
	}
	self._entries[stray] = entry
	return entry
end

-- Past ICON_STUDS the words go and the tag is just its paw-star.
function PityTags._look(_self: any, entry: Entry)
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local studs = (camera.CFrame.Position - entry.part.Position).Magnitude
	local words = not PityTagLogic.compact(studs)
	if entry.label.Visible ~= words then
		entry.label.Visible = words
	end
end

-- One Heartbeat looks at each tag's distance every LOOK_SECONDS; it stops itself when no tag is left.
function PityTags._startLoop(self: any)
	if self._loop then
		return
	end
	self._loop = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - self._lookedAt < LOOK_SECONDS then
			return
		end
		self._lookedAt = now
		if next(self._entries) == nil then
			if self._loop then
				self._loop:Disconnect()
				self._loop = nil
			end
			return
		end
		for _, entry: Entry in self._entries do
			if entry.billboard.Enabled then
				self:_look(entry)
			end
		end
	end)
end

function PityTags._drop(self: any, stray: Instance)
	local entry: Entry? = self._entries[stray]
	if entry then
		entry.billboard:Destroy()
		self._entries[stray] = nil
	end
end

function PityTags.destroy(self: any)
	if self._loop then
		self._loop:Disconnect()
		self._loop = nil
	end
	for _, connection in self._connections do
		connection:Disconnect()
	end
	for stray in self._watched do
		self:_unwatch(stray)
	end
	for stray in self._entries do
		self:_drop(stray)
	end
end

return PityTags
