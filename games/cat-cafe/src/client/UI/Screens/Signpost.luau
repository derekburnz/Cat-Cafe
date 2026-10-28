--!strict
-- The town signpost by the fountain (F77, town-layout-v3.md section 7): four arms pointing at the four gates, each
-- with its area's icon and name in the area's colour. An arm for an area the player's tier has not opened is dimmed
-- with a "🔒 Tier 3" pill, so a new player sees from the middle of town which way each area is and what it needs.
--
-- The signpost is the server's model tagged "TownSignpost" (CatCafe_Square_Signpost). Its arms are the parts with
-- a string `Area` attribute, or parts named "...Arm_Woods" / "...ArmWoods" (Wayfinding.armArea); an optional
-- `RequiresTier` number on an arm overrides the catalog's tier. Each arm gets a local SurfaceGui on its Front and
-- Back faces, so the arm runs along its X axis, thin in Z. Any SurfaceGui the server put on the arms is hidden on
-- this client only and comes back if this screen goes away. View only: the gates check the tier anyway.
--
-- Roblox terms: a SurfaceGui draws 2D UI flat on one face of a part. With PixelsPerStud sizing, its canvas is the
-- face's size in studs times that number, so the layout below works in scale and fits any arm.

local CollectionService = game:GetService("CollectionService")

local Create = require(script.Parent.Parent.Components.Create)
local Format = require(script.Parent.Parent.Components.Format)
local Outline = require(script.Parent.Parent.Components.Outline)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)
local Wayfinding = require(script.Parent.Parent.Components.Wayfinding)

export type Signpost = {
	setCatalog: (self: Signpost, catalog: Types.Catalog) -> (),
	render: (self: Signpost, state: Types.PlayerState) -> (),
	destroy: (self: Signpost) -> (),
}

local TAG = "TownSignpost"
local PIXELS_PER_STUD = 50
local MAX_DISTANCE = 120 -- the whole square: the signpost is how a new player finds the gates
local FACES = { Enum.NormalId.Front, Enum.NormalId.Back }
local LOCKED_DIM = 0.45 -- how far a locked arm's colour goes toward ink

type Face = { gui: SurfaceGui, card: Frame, name: TextLabel, lock: Frame, lockText: TextLabel }
type Arm = { source: Instance, board: BasePart, areaId: string, faces: { Face } } -- source: the part or model
type Post = {
	model: Instance,
	arms: { [BasePart]: Arm },
	hidden: { SurfaceGui }, -- the server's own arm text, hidden on this client
	queued: boolean,
	connections: { RBXScriptConnection },
}

local Signpost = {}
Signpost.__index = Signpost

local function text(props: { [string]: any }, outline: number): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.display,
		TextScaled = true,
		TextColor3 = Theme.colors.white,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	local label: TextLabel = Create("TextLabel", merged)
	Outline.text(label, outline)
	return label
end

-- The part to draw on: the arm itself, or the biggest part of an arm that is a model.
local function boardOf(arm: Instance): BasePart?
	if arm:IsA("BasePart") then
		return arm :: BasePart
	end
	local best: BasePart? = nil
	local bestSize = 0
	for _, descendant in arm:GetDescendants() do
		if descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			local size = part.Size.X * part.Size.Y
			if size > bestSize then
				best, bestSize = part, size
			end
		end
	end
	return best
end

local function findArea(catalog: Types.Catalog?, areaId: string): Types.AreaDef?
	local areas: { Types.AreaDef } = if catalog then catalog.areas or {} else {}
	for _, area in areas do
		if area.id == areaId then
			return area
		end
	end
	return nil
end

local function buildFace(
	parent: Instance,
	board: BasePart,
	areaId: string,
	face: Enum.NormalId
): Face
	local gui: SurfaceGui = Create("SurfaceGui", {
		Name = ("Signpost_%s_%s"):format(areaId, face.Name),
		Adornee = board,
		Face = face,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = PIXELS_PER_STUD,
		LightInfluence = 0,
		MaxDistance = MAX_DISTANCE,
		ClipsDescendants = true,
		ResetOnSpawn = false,
		ZOffset = 1,
		Parent = parent,
	})
	local card: Frame = Create("Frame", {
		Name = "Card",
		BackgroundColor3 = Theme.areaColors[areaId] or Theme.colors.cocoaDeep,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.96, 0.84),
		Parent = gui,
	}, { Create("UICorner", { CornerRadius = UDim.new(0.25, 0) }) })
	Outline.border(card, 3)
	Outline.shade(card, 0.2)
	local name = text({
		Name = "Name",
		Position = UDim2.fromScale(0.04, 0.12),
		Size = UDim2.fromScale(0.92, 0.76),
		Parent = card,
	}, 3)
	-- the lock pill on the right of a locked arm
	local lock: Frame = Create("Frame", {
		Name = "Lock",
		BackgroundColor3 = Theme.colors.ink,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(0.97, 0.5),
		Size = UDim2.fromScale(0.36, 0.7),
		Visible = false,
		Parent = card,
	}, { Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	Outline.border(lock, 2)
	local lockText = text({
		Name = "Text",
		Position = UDim2.fromScale(0.08, 0.14),
		Size = UDim2.fromScale(0.84, 0.72),
		TextColor3 = Theme.colors.gold,
		Parent = lock,
	}, 2)
	return { gui = gui, card = card, name = name, lock = lock, lockText = lockText }
end

function Signpost.new(parent: Instance): Signpost
	local self = setmetatable({}, Signpost) :: any
	self._parent = parent
	self._posts = {} :: { [Instance]: Post }
	self._catalog = nil :: Types.Catalog?
	self._state = nil :: Types.PlayerState?
	self._connections = {} :: { RBXScriptConnection }

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
	return self :: Signpost
end

function Signpost._attach(self: any, model: Instance)
	if self._posts[model] then
		return
	end
	local post: Post = { model = model, arms = {}, hidden = {}, queued = false, connections = {} }
	self._posts[model] = post
	-- arms and their parts stream in after the model, and can stream out again: rescan once per frame of changes
	local function queue()
		if post.queued then
			return
		end
		post.queued = true
		task.defer(function()
			post.queued = false
			if self._posts[model] == post then
				self:_scan(post)
			end
		end)
	end
	table.insert(post.connections, model.DescendantAdded:Connect(queue))
	table.insert(post.connections, model.DescendantRemoving:Connect(queue))
	self:_scan(post)
end

-- Finds the arms, adds faces for new ones, drops faces for arms that left, and hides the server's arm text.
function Signpost._scan(self: any, post: Post)
	-- parts that streamed out come back as new instances, so forget the old ones
	for index = #post.hidden, 1, -1 do
		if not post.hidden[index]:IsDescendantOf(post.model) then
			table.remove(post.hidden, index)
		end
	end
	-- once the catalog lists its areas, a helper part that only looks like an arm ("ArmCap") gets no board (N220)
	local catalog: Types.Catalog? = self._catalog
	local listed: { Types.AreaDef } = if catalog then catalog.areas or {} else {}
	local known = #listed > 0
	local found: { [BasePart]: { source: Instance, areaId: string } } = {}
	for _, descendant in post.model:GetDescendants() do
		if descendant:IsA("SurfaceGui") then
			local serverGui = descendant :: SurfaceGui
			if serverGui.Enabled and not table.find(post.hidden, serverGui) then
				serverGui.Enabled = false
				table.insert(post.hidden, serverGui)
			end
		elseif descendant:IsA("BasePart") or descendant:IsA("Model") then
			local areaId = Wayfinding.armArea(descendant:GetAttribute("Area"), descendant.Name)
			if areaId and known and not findArea(catalog, areaId) then
				areaId = nil
			end
			local board = if areaId then boardOf(descendant) else nil
			if areaId and board and not found[board] then
				found[board] = { source = descendant, areaId = areaId }
			end
		end
	end
	for board, arm in post.arms do
		local now = found[board]
		if not now or now.areaId ~= arm.areaId or not board:IsDescendantOf(post.model) then
			for _, face in arm.faces do
				face.gui:Destroy()
			end
			post.arms[board] = nil
		end
	end
	for board, entry in found do
		local arm: Arm? = post.arms[board]
		if arm then
			arm.source = entry.source
		else
			local faces: { Face } = {}
			for _, normal in FACES do
				table.insert(faces, buildFace(self._parent, board, entry.areaId, normal))
			end
			local source, areaId = entry.source, entry.areaId
			local new: Arm = { source = source, board = board, areaId = areaId, faces = faces }
			post.arms[board] = new
			self:_renderArm(new)
		end
	end
end

function Signpost._renderArm(self: any, arm: Arm)
	local state: Types.PlayerState? = self._state
	local catalog: Types.Catalog? = self._catalog
	local area = findArea(catalog, arm.areaId)
	-- the override on the arm itself, else on its board, so a model arm can carry it (N221)
	local source, board = arm.source, arm.board
	local override = source:GetAttribute("RequiresTier") or board:GetAttribute("RequiresTier")
	local needs: number = if type(override) == "number"
		then override
		elseif area then area.tier
		else 1
	-- before the first state the arm shows its name with no lock, never a wrong one
	local lockText = if state then Wayfinding.armLock(needs, state.tier or 1) else nil
	local name = if area then area.name else Format.areaName(arm.areaId)
	local icon: string? = (Theme.icons :: any)[arm.areaId]
	local color = Theme.areaColors[arm.areaId] or Theme.colors.cocoaDeep
	for _, face in arm.faces do
		face.name.Text = if icon then icon .. " " .. name else name
		face.card.BackgroundColor3 = if lockText
			then color:Lerp(Theme.colors.ink, LOCKED_DIM)
			else color
		face.lock.Visible = lockText ~= nil
		face.lockText.Text = lockText or ""
		if lockText then
			face.name.Size = UDim2.fromScale(0.54, 0.76)
			face.name.TextXAlignment = Enum.TextXAlignment.Left
		else
			face.name.Size = UDim2.fromScale(0.92, 0.76)
			face.name.TextXAlignment = Enum.TextXAlignment.Center
		end
	end
end

function Signpost._renderAll(self: any)
	for _, post in self._posts do
		for _, arm in post.arms do
			self:_renderArm(arm)
		end
	end
end

function Signpost.setCatalog(self: any, catalog: Types.Catalog)
	self._catalog = catalog
	-- the catalog's areas decide which arms are real (N220)
	for _, post in self._posts do
		self:_scan(post)
	end
	self:_renderAll()
end

function Signpost.render(self: any, state: Types.PlayerState)
	self._state = state
	self:_renderAll()
end

function Signpost._detach(self: any, model: Instance)
	local post: Post? = self._posts[model]
	if not post then
		return
	end
	assert(post, "post missing")
	self._posts[model] = nil
	for _, connection in post.connections do
		connection:Disconnect()
	end
	for _, arm in post.arms do
		for _, face in arm.faces do
			face.gui:Destroy()
		end
	end
	for _, serverGui in post.hidden do
		serverGui.Enabled = true
	end
end

function Signpost.destroy(self: any)
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	local models = {}
	for model in self._posts do
		table.insert(models, model)
	end
	for _, model in models do
		self:_detach(model)
	end
end

return Signpost
