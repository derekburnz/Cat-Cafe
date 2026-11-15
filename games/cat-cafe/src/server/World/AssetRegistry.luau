--!strict
-- The one place models are fetched from. ReplicatedStorage.Assets is Rojo-synced from assets/cat-cafe/rbx/;
-- anything missing there gets a Part placeholder at startup. The templates no client needs are moved to
-- ServerStorage.Assets at start-up (stowServerOnly). Swapping a real model in = dropping a file in that folder.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local GoldTone = require(ReplicatedStorage.Shared.GoldTone)
local Placeholders = require(script.Parent.Placeholders)
local ServerOnlyAssets = require(script.Parent.ServerOnlyAssets)

local AssetRegistry = {}

local folder: Folder? = nil
-- ServerStorage.Assets once stowServerOnly has run: the templates no client needs (#3743)
local vault: Folder? = nil

function AssetRegistry.folder(): Folder
	if folder ~= nil then
		return folder
	end
	local existing = ReplicatedStorage:FindFirstChild("Assets")
	local result: Instance
	if existing == nil then
		local created = Instance.new("Folder")
		created.Name = "Assets"
		created.Parent = ReplicatedStorage
		result = created
	else
		result = existing
	end
	folder = result :: Folder
	return result :: Folder
end

-- The template named `name`, in the shared folder or the server's own.
local function find(name: string): Instance?
	local found = AssetRegistry.folder():FindFirstChild(name)
	if found == nil and vault ~= nil then
		found = vault:FindFirstChild(name)
	end
	return found
end

-- Moves the templates only the server clones (ServerOnlyAssets) out of ReplicatedStorage.Assets into
-- ServerStorage.Assets, so no client is sent them or keeps them in memory (#3743). Run once at start-up, before the
-- world is built; `has`, `known` and `clone` read both folders. Returns how many were moved.
function AssetRegistry.stowServerOnly(): number
	local assets = AssetRegistry.folder()
	local store = vault
	if store == nil then
		local made = Instance.new("Folder")
		made.Name = "Assets"
		made.Parent = ServerStorage
		store = made
		vault = made
	end
	local moved = 0
	for _, child in assets:GetChildren() do
		if ServerOnlyAssets.matches(child.Name) then
			child.Parent = store
			moved += 1
		end
	end
	return moved
end

-- Fills in a placeholder for every asset name that has no real model yet. Returns how many were created.
function AssetRegistry.ensurePlaceholders(): number
	local assets = AssetRegistry.folder()
	local created = 0
	for _, name in Placeholders.names() do
		if find(name) == nil then
			local model = Placeholders.build(name)
			if model ~= nil then
				model.Parent = assets
				created += 1
			end
		end
	end
	return created
end

function AssetRegistry.has(name: string): boolean
	return find(name) ~= nil
end

-- True when the named model is in the folder or can be built as a placeholder, so `clone` will not error.
function AssetRegistry.known(name: string): boolean
	return AssetRegistry.has(name) or table.find(Placeholders.names(), name) ~= nil
end

-- Clones the named model. Builds a placeholder on the spot if the name is unknown to the folder but known to us.
function AssetRegistry.clone(name: string): Model
	local assets = AssetRegistry.folder()
	local source = find(name)
	if source == nil then
		local built = Placeholders.build(name)
		if built == nil then
			error(string.format("[AssetRegistry] no asset or placeholder named %s", name))
		end
		built.Parent = assets
		source = built
	end
	local clone = (source :: Instance):Clone()
	if not clone:IsA("Model") then
		local wrapper = Instance.new("Model")
		wrapper.Name = name
		clone.Parent = wrapper
		if clone:IsA("BasePart") then
			wrapper.PrimaryPart = clone :: BasePart
		end
		return wrapper
	end
	return clone :: Model
end

-- Which body a cat model is: the walking body (A), the seated one (B, the _Sit models) or the standing worker (S,
-- the _Work models).
export type Body = "walk" | "sit" | "work"

-- A cat's model: its gold coat (v0.5 F42) when `variant` is "gold" and the asset is there, else the base cat, which
-- is the walking body (A). `body` "sit" asks for the seated body a resting cat sits on at the odd nap spots, trying
-- the gold seat, the seat, the gold walker and the walker in that order, so a cat whose seat is not exported yet
-- still shows. "work" asks for the standing worker a working cat wears at its station (Model-Agent #826; Derek
-- picked S on 2026-11-02), trying the gold worker and the worker before that seated order. The second result is the
-- body that came back.
function AssetRegistry.cloneCat(catId: string, variant: string?, body: Body?): (Model, Body)
	local base = Catalog.catModelName(catId)
	local gold = Catalog.goldModelName(catId)
	-- #4133: with the goldTone switch on a gold cat is its base model toned (shared/GoldTone), so the _Gold models
	-- are never looked up
	local walkers: { string } = { base }
	local tone = false
	if variant == "gold" then
		walkers, tone = GoldTone.names(gold, base)
	end
	local function take(name: string, which: Body): (Model, Body)
		local model = AssetRegistry.clone(name)
		if tone then
			GoldTone.apply(model)
		end
		return model, which
	end
	if body == "work" then
		for _, name in walkers do
			if AssetRegistry.has(Catalog.workModelName(name)) then
				return take(Catalog.workModelName(name), "work")
			end
		end
	end
	if body == "work" or body == "sit" then
		for _, name in walkers do
			if AssetRegistry.has(Catalog.sitModelName(name)) then
				return take(Catalog.sitModelName(name), "sit")
			end
		end
	end
	for _, name in walkers do
		if AssetRegistry.has(name) then
			return take(name, "walk")
		end
	end
	return take(base, "walk")
end

return AssetRegistry
