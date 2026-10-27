--!strict
-- The one place models are fetched from. ReplicatedStorage.Assets is Rojo-synced from assets/cat-cafe/rbx/;
-- anything missing there gets a Part placeholder at startup. Swapping a real model in = dropping a file in that folder.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Placeholders = require(script.Parent.Placeholders)

local AssetRegistry = {}

local folder: Folder? = nil

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

-- Fills in a placeholder for every asset name that has no real model yet. Returns how many were created.
function AssetRegistry.ensurePlaceholders(): number
	local assets = AssetRegistry.folder()
	local created = 0
	for _, name in Placeholders.names() do
		if assets:FindFirstChild(name) == nil then
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
	return AssetRegistry.folder():FindFirstChild(name) ~= nil
end

-- True when the named model is in the folder or can be built as a placeholder, so `clone` will not error.
function AssetRegistry.known(name: string): boolean
	return AssetRegistry.has(name) or table.find(Placeholders.names(), name) ~= nil
end

-- Clones the named model. Builds a placeholder on the spot if the name is unknown to the folder but known to us.
function AssetRegistry.clone(name: string): Model
	local assets = AssetRegistry.folder()
	local source = assets:FindFirstChild(name)
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

-- A cat's model: its gold coat (v0.5 F42) when `variant` is "gold" and the asset is there, else the base cat.
function AssetRegistry.cloneCat(catId: string, variant: string?): Model
	if variant == "gold" then
		local gold = Catalog.goldModelName(catId)
		if AssetRegistry.has(gold) then
			return AssetRegistry.clone(gold)
		end
	end
	return AssetRegistry.clone(Catalog.catModelName(catId))
end

return AssetRegistry
