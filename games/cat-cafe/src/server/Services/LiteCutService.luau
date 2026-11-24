--!strict
-- #5686: the parkLite switch (shared/LiteCut). Every LiteCut.STEP seconds it reads the switch and, when it has changed,
-- moves each model tagged LiteCut.TAG that stands in the Workspace into ServerStorage (switch on), or puts each held
-- one back under the parent it came from (switch off). The asset templates in ReplicatedStorage.Assets carry the tag
-- too and are left alone. Started after AreaWholeService, whose start cuts the ring into chunks first.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local LiteCut = require(ReplicatedStorage.Shared.LiteCut)
local LiveFlagService = require(script.Parent.LiveFlagService)

local LiteCutService = {}

local held: { [Instance]: Instance? } = {} -- piece -> the parent it came from

local function holdFolder(): Folder
	local found = ServerStorage:FindFirstChild(LiteCut.HOLD)
	if found ~= nil and found:IsA("Folder") then
		return found :: Folder
	end
	local made = Instance.new("Folder")
	made.Name = LiteCut.HOLD
	made.Parent = ServerStorage
	return made
end

local function apply(on: boolean)
	if on then
		local into = holdFolder()
		for _, piece in CollectionService:GetTagged(LiteCut.TAG) do
			if
				piece:IsDescendantOf(Workspace)
				and LiteCut.action(true, held[piece] ~= nil) == "hold"
			then
				held[piece] = piece.Parent :: Instance
				piece.Parent = into
			end
		end
	else
		for piece, from in held do
			if from ~= nil and LiteCut.action(false, true) == "restore" then
				if from.Parent ~= nil then
					piece.Parent = from
				else
					piece:Destroy() -- its old parent left the world (a rebuild): nothing to put it back into
				end
			end
		end
		table.clear(held)
	end
end

function LiteCutService.start()
	task.spawn(function()
		local last: boolean? = nil
		while true do
			local on = LiveFlagService.on(LiteCut.FLAG)
			if on ~= last then
				last = on
				local ok, err = pcall(function(): any
					apply(on)
					return nil :: any -- CI's luau-lsp wants two values from pcall
				end)
				if not ok then
					warn("[LiteCut] " .. tostring(err))
				end
			end
			task.wait(LiteCut.STEP)
		end
	end)
end

return LiteCutService
