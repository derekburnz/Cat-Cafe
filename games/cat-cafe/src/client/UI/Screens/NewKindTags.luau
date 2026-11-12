--!strict
-- The "NEW" tag (#3529, shared/NewKind): a small pill in the rarity's colour reading "NEW 🐾" over every stray and
-- stuck cat whose kind this player has never owned, above its name tag, so a new player can tell which cats move
-- "five different cats" on. Each player sees their own tags: it is drawn here from the Index the client already has
-- (state.collection). It shows within NewKind.RANGE studs, hides inside NewKind.NEAR (the name tag is enough up
-- close), while a net holds the cat and while this player is on a catch or rescue bar. A Secret cat never gets it
-- (it keeps its "???"), nor a pity cat (its own tag has that spot). Off with the `newKindTag` live switch.
--   NewKindTags.new()
--   tags:set(on, collection)   the switch and the collection (catId -> anything) as they stand now
--   tags:setBusy(busy)         this player is on a catch or rescue bar
--   tags:nearest(area)         the part of the nearest tagged stray in wild area `area` (strays only, for the trail)
--   tags:destroy()
-- It never moves, so Reduce Motion has nothing to stop.
--
-- Roblox terms: a BillboardGui draws 2D UI at a point in the world, facing the camera; MaxDistance hides it past
-- that many studs, and SizeOffset moves it by a share of its own size (here up).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Create = require(script.Parent.Parent.Components.Create)
local Outline = require(script.Parent.Parent.Components.Outline)
local Theme = require(script.Parent.Parent.Theme)

local NewKind = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("NewKind"))

export type NewKindTags = {
	set: (self: NewKindTags, on: boolean, collection: { [string]: any }?) -> (),
	setBusy: (self: NewKindTags, busy: boolean) -> (),
	nearest: (self: NewKindTags, area: string) -> BasePart?,
	destroy: (self: NewKindTags) -> (),
}

type Entry = {
	part: BasePart,
	billboard: BillboardGui,
	pill: Frame,
	label: TextLabel,
}

local TAGS = { "Stray", "StuckCat" }
local PITY = "PityCat" -- shared/Pity.ATTRIBUTE: a pity cat wears its own tag in this spot
local WIDTH = 120 -- px, the billboard; the pill inside is as wide as its word
local HEIGHT = 22 -- px, smaller than the mood icon and the name
local TEXT_SIZE = 14
-- above the 56 px mood icon box (centred 0.8 studs over the cat's head) with 6 px between
local RAISE = (28 + 6 + HEIGHT / 2) / HEIGHT
local LIFT = 0.8 -- studs over the top of the cat, as the mood icon
local LOOK_SECONDS = 0.25 -- how often the distances are looked at

local NewKindTags = {}
NewKindTags.__index = NewKindTags

local function anchorOf(model: Instance): (BasePart?, number)
	local part: BasePart? = nil
	if model:IsA("Model") then
		part = (model :: Model).PrimaryPart
		if part ~= nil and not part:IsDescendantOf(model) then
			part = nil -- streamed out: the model's old part
		end
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

function NewKindTags.new(): NewKindTags
	local self = setmetatable({}, NewKindTags) :: any
	self._on = false
	self._busy = false
	self._collection = nil :: { [string]: any }?
	self._entries = {} :: { [Instance]: Entry }
	self._watched = {} :: { [Instance]: { RBXScriptConnection } }
	self._connections = {} :: { RBXScriptConnection }
	self._gone = false
	for _, tag in TAGS do
		for _, cat in CollectionService:GetTagged(tag) do
			self:_watch(cat)
		end
		table.insert(
			self._connections,
			CollectionService:GetInstanceAddedSignal(tag):Connect(function(cat: Instance)
				self:_watch(cat)
			end)
		)
		table.insert(
			self._connections,
			CollectionService:GetInstanceRemovedSignal(tag):Connect(function(cat: Instance)
				self:_unwatch(cat)
			end)
		)
	end
	-- near and far: a look a few times a second is plenty for a label, and costs nothing with the switch off
	task.spawn(function()
		while not self._gone do
			task.wait(LOOK_SECONDS)
			if self._on and next(self._entries) ~= nil then
				self:_look()
			end
		end
	end)
	return self :: NewKindTags
end

function NewKindTags.set(self: any, on: boolean, collection: { [string]: any }?)
	self._on = on
	self._collection = collection
	for cat in self._watched do
		self:_refresh(cat)
	end
	self:_look()
end

function NewKindTags.setBusy(self: any, busy: boolean)
	if self._busy ~= busy then
		self._busy = busy
		self:_look()
	end
end

local function rootPosition(): Vector3?
	local player = Players.LocalPlayer
	local character = if player ~= nil then player.Character else nil
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then (root :: BasePart).Position else nil
end

-- Each tag on or off by where the player stands.
function NewKindTags._look(self: any)
	local at = rootPosition()
	for cat, entry: Entry in self._entries do
		local distance = if at ~= nil then (entry.part.Position - at).Magnitude else NewKind.RANGE
		entry.billboard.Enabled =
			NewKind.shows(self._on, self._busy, cat:GetAttribute("LockedBy"), distance)
	end
end

function NewKindTags.nearest(self: any, area: string): BasePart?
	local at = rootPosition()
	if at == nil then
		return nil
	end
	local me = Players.LocalPlayer.UserId
	local best: BasePart? = nil
	local bestDistance = math.huge
	for cat, entry: Entry in self._entries do
		local locked = cat:GetAttribute("LockedBy")
		local beginner = cat:GetAttribute("Beginner")
		if
			CollectionService:HasTag(cat, "Stray")
			and cat:GetAttribute("Area") == area
			and (locked == nil or locked == 0 or locked == me)
			and (beginner == nil or beginner == 0 or beginner == me)
			and entry.part:IsDescendantOf(Workspace)
		then
			local distance = (entry.part.Position - at).Magnitude
			if distance < bestDistance then
				best, bestDistance = entry.part, distance
			end
		end
	end
	return best
end

-- The parts can come after the model with streaming (as PityTags, #2099), so every cat is watched and its tag
-- made or dropped to match.
function NewKindTags._watch(self: any, cat: Instance)
	if self._watched[cat] then
		return
	end
	local refresh = function()
		if self._watched[cat] ~= nil then -- a deferred refresh after the cat went does nothing
			self:_refresh(cat)
		end
	end
	self._watched[cat] = {
		cat:GetAttributeChangedSignal("CatId"):Connect(refresh),
		cat:GetAttributeChangedSignal("Rarity"):Connect(refresh),
		cat:GetAttributeChangedSignal(PITY):Connect(refresh),
		cat:GetAttributeChangedSignal("LockedBy"):Connect(function()
			self:_look()
		end),
		cat.DescendantAdded:Connect(function(child: Instance)
			if self._entries[cat] == nil and child:IsA("BasePart") then
				task.defer(refresh)
			end
		end),
		cat.DescendantRemoving:Connect(function(child: Instance)
			local entry: Entry? = self._entries[cat]
			if entry ~= nil and child == (entry.part :: Instance) then
				self:_drop(cat)
				task.defer(refresh)
			end
		end),
		cat.AncestryChanged:Connect(function()
			if not cat:IsDescendantOf(Workspace) then
				self:_unwatch(cat)
			end
		end),
	}
	self:_refresh(cat)
end

function NewKindTags._unwatch(self: any, cat: Instance)
	local watched = self._watched[cat]
	if watched then
		for _, connection in watched do
			connection:Disconnect()
		end
		self._watched[cat] = nil
	end
	self:_drop(cat)
end

function NewKindTags._refresh(self: any, cat: Instance)
	local rarity = cat:GetAttribute("Rarity")
	if
		not self._on
		or cat:GetAttribute(PITY) ~= nil
		or not NewKind.isNew(self._collection, cat:GetAttribute("CatId"), rarity)
	then
		self:_drop(cat)
		return
	end
	local entry: Entry? = self._entries[cat]
	if not entry then
		entry = self:_make(cat)
		if not entry then
			return
		end
	end
	assert(entry, "entry")
	local name = if type(rarity) == "string" then rarity else nil
	entry.pill.BackgroundColor3 = Theme.rarityColor(name)
	entry.label.TextColor3 = Theme.rarityTextColor(name)
end

function NewKindTags._make(self: any, cat: Instance): Entry?
	local part, height = anchorOf(cat)
	if not part then
		return nil
	end
	assert(part, "part")
	local billboard: BillboardGui = Create("BillboardGui", {
		Name = "CatCafeNewKindTag",
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		SizeOffset = Vector2.new(0, RAISE),
		StudsOffsetWorldSpace = Vector3.new(0, height + LIFT, 0),
		AlwaysOnTop = false,
		MaxDistance = NewKind.RANGE,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Enabled = false,
		Parent = part,
	})
	local pill: Frame = Create("Frame", {
		Name = "Tag",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, HEIGHT),
		BackgroundColor3 = Theme.rarityColor(nil),
		BorderSizePixel = 0,
		Parent = billboard,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}),
		Create("UIStroke", {
			Color = Theme.colors.white,
			Thickness = 2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})
	local label: TextLabel = Create("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, HEIGHT),
		FontFace = Theme.fonts.display,
		TextSize = TEXT_SIZE,
		TextColor3 = Theme.rarityTextColor(nil),
		Text = NewKind.TEXT,
		Parent = pill,
	})
	Outline.text(label, 1)
	local entry: Entry = { part = part, billboard = billboard, pill = pill, label = label }
	self._entries[cat] = entry
	local at = rootPosition()
	local distance = if at ~= nil then (part.Position - at).Magnitude else NewKind.RANGE
	billboard.Enabled =
		NewKind.shows(self._on, self._busy, cat:GetAttribute("LockedBy"), distance)
	return entry
end

function NewKindTags._drop(self: any, cat: Instance)
	local entry: Entry? = self._entries[cat]
	if entry then
		entry.billboard:Destroy()
		self._entries[cat] = nil
	end
end

function NewKindTags.destroy(self: any)
	self._gone = true
	for _, connection in self._connections do
		connection:Disconnect()
	end
	for cat in self._watched do
		self:_unwatch(cat)
	end
	for cat in self._entries do
		self:_drop(cat)
	end
end

return NewKindTags
