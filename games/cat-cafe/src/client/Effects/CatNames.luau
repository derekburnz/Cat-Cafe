--!strict
-- #5586 (a player's feedback Derek forwarded 2026-11-20: "I would love if you put the names above the cats so you
-- could tell which one it is for collectors"): a small name tag in the cat's rarity colour over the nearest wild
-- strays, under the rarity gem (Effects/Rarity), from NEAR to FAR studs, at most MOST at a time, nearest first. A cat
-- someone else is catching has none. Behind the switch `catNames` (LiveFlags) and the Settings switch "Cat names"
-- (settings.catNames, on unless turned off). Cafe cats already carry their name on the rate tag (UI WorldTags).
--
-- Source: the Stray tag CatService puts on each stray model, its `CatId`, `Rarity` and `LockedBy` attributes, and
-- shared Catalog for the kind's name. Listening only; nothing is sent.
--
-- Roblox terms: a BillboardGui always faces the camera; with a size in pixels it stays the same size on screen, so it
-- reads on a phone at any distance it shows.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Presets = require(script.Parent.Presets)

local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalog"))

local CatNames = {}

local FLAG = "LiveFlag_catNames"
local NEAR = 6 -- studs: closer than this the Catch card names it
local FAR = 45
local MOST = 10
local EVERY = 0.25 -- seconds between looks
local WIDTH, HEIGHT = 160, 22 -- pixels
local BELOW = 0.35 -- studs over the cat's top (the gem sits higher)

type Tag = { gui: BillboardGui, label: TextLabel, model: Model }
type Seen = { model: Model, distance: number }

local tags: { [Model]: Tag } = {}
local shown = true -- the Settings switch
local started = false

-- Pure: whether tags show for a `catNames` setting value (only an explicit false hides them).
function CatNames.wanted(value: unknown): boolean
	return value ~= false
end

-- Pure: the models to tag, nearest first, from { model, distance } pairs: those from `near` to `far`, at most `most`.
function CatNames.pick(seen: { Seen }, near: number, far: number, most: number): { Model }
	local inRange: { Seen } = {}
	for _, entry in seen do
		if entry.distance >= near and entry.distance <= far then
			table.insert(inRange, entry)
		end
	end
	table.sort(inRange, function(a: Seen, b: Seen): boolean
		return a.distance < b.distance
	end)
	local out: { Model } = {}
	for index = 1, math.min(most, #inRange) do
		table.insert(out, inRange[index].model)
	end
	return out
end

local function bodyOf(model: Model): BasePart?
	if model.PrimaryPart ~= nil then
		return model.PrimaryPart
	end
	local part = model:FindFirstChildWhichIsA("BasePart", true)
	return if part ~= nil then part :: BasePart else nil
end

local function build(model: Model): Tag?
	local catId = model:GetAttribute("CatId")
	local def = if type(catId) == "string" then Catalog.getCat(catId) else nil
	local body = bodyOf(model)
	if def == nil or body == nil then
		return nil
	end
	local rarity = model:GetAttribute("Rarity")
	local colour: Color3 = (if type(rarity) == "string" then Presets.rarity[rarity] else nil)
		or Color3.new(1, 1, 1)
	local frame, size = model:GetBoundingBox()
	local top = frame.Position.Y + size.Y / 2
	local gui = Instance.new("BillboardGui")
	gui.Name = "EffectsCatName"
	gui.Adornee = body
	gui.Size = UDim2.fromOffset(WIDTH, HEIGHT)
	gui.StudsOffsetWorldSpace = Vector3.new(0, top - body.Position.Y + BELOW, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = FAR * 1.2
	local label = Instance.new("TextLabel")
	label.Name = "Name"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	label.Text = def.name
	label.TextScaled = true
	label.TextColor3 = colour
	local outline = Instance.new("UIStroke")
	outline.Color = Color3.new(0.12, 0.1, 0.1)
	outline.Thickness = 1.5
	outline.Parent = label
	label.Parent = gui
	gui.Parent = Context.folder()
	return { gui = gui, label = label, model = model }
end

local function drop(model: Model)
	local tag = tags[model]
	if tag ~= nil then
		tags[model] = nil
		tag.gui:Destroy()
	end
end

local function clearAll()
	for model in tags do
		drop(model)
	end
end

local function look()
	if ReplicatedStorage:GetAttribute(FLAG) ~= true or not shown then
		clearAll()
		return
	end
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		clearAll()
		return
	end
	local here = (root :: BasePart).Position
	local me = Players.LocalPlayer.UserId
	local seen: { Seen } = {}
	for _, instance in CollectionService:GetTagged("Stray") do
		if not instance:IsA("Model") or not instance:IsDescendantOf(Workspace) then
			continue
		end
		local locked = instance:GetAttribute("LockedBy")
		if type(locked) == "number" and locked ~= 0 and locked ~= me then
			continue
		end
		local model = instance :: Model
		table.insert(
			seen,
			{ model = model, distance = (model:GetPivot().Position - here).Magnitude }
		)
	end
	local keep: { [Model]: boolean } = {}
	for _, model in CatNames.pick(seen, NEAR, FAR, MOST) do
		keep[model] = true
		local tag = tags[model]
		if tag ~= nil and tag.model:GetAttribute("CatId") == nil then
			drop(model)
			tag = nil
		end
		if tag == nil then
			tags[model] = build(model)
		end
	end
	for model in tags do
		if not keep[model] or model.Parent == nil then
			drop(model)
		end
	end
end

-- The Settings switch (settings.catNames), from Effects.applySettings.
function CatNames.set(value: unknown)
	shown = CatNames.wanted(value)
	if not shown then
		clearAll()
	end
end

function CatNames.start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		while true do
			local ok, problem = pcall(look)
			if not ok then
				warn("[CatNames] " .. tostring(problem))
			end
			task.wait(EVERY)
		end
	end)
end

return CatNames
