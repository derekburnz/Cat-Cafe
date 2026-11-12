--!strict
-- A Secret stray's tag (#3470 section 5): a black pill with a white edge reading "SECRET" in white, and under the word
-- the cat's name as the server shows it: "???" until someone has caught it once (the stray's CatName attribute; a
-- Secret a tackle knocked loose keeps its real name). Over any stray whose Rarity attribute is "Secret", within
-- SecretTagLogic.RANGE studs and on top of walls, so the cat can be told from the others once the sky beam (Effects)
-- has brought a player to it. It hides while a net holds the cat (the catch "!" takes that spot) and comes back if
-- it bolts, and goes with the model. It never moves, so Reduce Motion has nothing to stop.
--   SecretTags.new()   watches the Stray tag
--   tags:destroy()
--
-- Roblox terms: a BillboardGui draws 2D UI at a point in the world, facing the camera; AlwaysOnTop draws it over
-- walls, MaxDistance hides it past that many studs, and SizeOffset moves it by a share of its own size (here up).

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Create = require(script.Parent.Parent.Components.Create)
local Outline = require(script.Parent.Parent.Components.Outline)
local SecretTagLogic = require(script.Parent.Parent.Components.SecretTagLogic)
local Theme = require(script.Parent.Parent.Theme)

export type SecretTags = {
	destroy: (self: SecretTags) -> (),
}

type Entry = {
	part: BasePart,
	billboard: BillboardGui,
	name: TextLabel,
}

local TAG = "Stray"
local WIDTH = 160 -- px, the billboard; the pill inside is as wide as its word
local PILL = 28 -- px, the pill: about the mood icons' size
local NAME = 20 -- px, the name's line under it
local TEXT_SIZE = 17
local NAME_SIZE = 15
local HEIGHT = PILL + NAME
-- above the 56 px mood icon box (centred 0.8 studs over the cat's head) with 6 px between
local RAISE = (28 + 6 + HEIGHT / 2) / HEIGHT
local LIFT = 0.8 -- studs over the top of the cat, as the mood icon

local BLACK = Theme.rarity.Secret.text -- the rarity's own near black swatch (#16161D)

local SecretTags = {}
SecretTags.__index = SecretTags

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

function SecretTags.new(): SecretTags
	local self = setmetatable({}, SecretTags) :: any
	self._entries = {} :: { [Instance]: Entry }
	self._watched = {} :: { [Instance]: { RBXScriptConnection } }
	self._connections = {} :: { RBXScriptConnection }
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
	return self :: SecretTags
end

-- The parts can come after the model with streaming (as PityTags, #2099), so every stray is watched and its tag
-- made or dropped to match.
function SecretTags._watch(self: any, stray: Instance)
	if self._watched[stray] then
		return
	end
	local refresh = function()
		if self._watched[stray] ~= nil then -- a deferred refresh after the stray went does nothing
			self:_refresh(stray)
		end
	end
	self._watched[stray] = {
		stray:GetAttributeChangedSignal("Rarity"):Connect(refresh),
		stray:GetAttributeChangedSignal("CatName"):Connect(refresh),
		stray:GetAttributeChangedSignal("LockedBy"):Connect(refresh),
		stray.DescendantAdded:Connect(function(child: Instance)
			if self._entries[stray] == nil and child:IsA("BasePart") then
				task.defer(refresh)
			end
		end),
		stray.DescendantRemoving:Connect(function(child: Instance)
			local entry: Entry? = self._entries[stray]
			if entry ~= nil and child == (entry.part :: Instance) then
				self:_drop(stray)
				task.defer(refresh)
			end
		end),
		stray.AncestryChanged:Connect(function()
			if not stray:IsDescendantOf(Workspace) then
				self:_unwatch(stray)
			end
		end),
	}
	self:_refresh(stray)
end

function SecretTags._unwatch(self: any, stray: Instance)
	local watched = self._watched[stray]
	if watched then
		for _, connection in watched do
			connection:Disconnect()
		end
		self._watched[stray] = nil
	end
	self:_drop(stray)
end

function SecretTags._refresh(self: any, stray: Instance)
	if not SecretTagLogic.tagged(stray:GetAttribute("Rarity")) then
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
	entry.name.Text = SecretTagLogic.name(stray:GetAttribute("CatName"))
	entry.billboard.Enabled = SecretTagLogic.shows(stray:GetAttribute("LockedBy"))
end

function SecretTags._make(self: any, stray: Instance): Entry?
	local part, height = anchorOf(stray)
	if not part then
		return nil
	end
	assert(part, "part")
	local billboard: BillboardGui = Create("BillboardGui", {
		Name = "CatCafeSecretTag",
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		SizeOffset = Vector2.new(0, RAISE),
		StudsOffsetWorldSpace = Vector3.new(0, height + LIFT, 0),
		AlwaysOnTop = true,
		MaxDistance = SecretTagLogic.RANGE,
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
		Size = UDim2.fromOffset(0, PILL),
		BackgroundColor3 = BLACK,
		BorderSizePixel = 0,
		Parent = billboard,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
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
		Size = UDim2.fromOffset(0, PILL),
		FontFace = Theme.fonts.display,
		TextSize = TEXT_SIZE,
		TextColor3 = Theme.colors.white,
		Text = SecretTagLogic.TEXT,
		Parent = pill,
	})
	Outline.text(label, 1)
	local name: TextLabel = Create("TextLabel", {
		Name = "CatName",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, PILL),
		Size = UDim2.new(1, 0, 0, NAME),
		FontFace = Theme.fonts.display,
		TextSize = NAME_SIZE,
		TextColor3 = Theme.colors.white,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = SecretTagLogic.UNKNOWN,
		Parent = billboard,
	})
	Outline.text(name, 2)
	local entry: Entry = { part = part, billboard = billboard, name = name }
	self._entries[stray] = entry
	return entry
end

function SecretTags._drop(self: any, stray: Instance)
	local entry: Entry? = self._entries[stray]
	if entry then
		entry.billboard:Destroy()
		self._entries[stray] = nil
	end
end

function SecretTags.destroy(self: any)
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

return SecretTags
