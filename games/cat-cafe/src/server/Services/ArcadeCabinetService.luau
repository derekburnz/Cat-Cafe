--!strict
-- #3443 (Derek 2026-11-12: "remove the arcade machine and its circle for now"): whether the Cat Arcade's cabinet and
-- its floor ring are in the world. They stand only while the arcade has a game to play: the `arcade` switch on and
-- one of `circleStreak` or `mouseDash` on. Otherwise both wait in ServerStorage, so no client has the machine, its
-- ring or its prompt. The switches are read every CHECK_SECONDS, so the machine goes and comes back in every
-- running server with no publish and no restart. Nothing about the games, the saves, the board or the prizes
-- changes here; ArcadeService still finds the cabinet by its tag while it is put away.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Arcade = require(ReplicatedStorage.Shared.Arcade)
local LiveFlagService = require(script.Parent.LiveFlagService)
local MouseDash = require(ReplicatedStorage.Shared.MouseDash)
local WalkUp = require(ReplicatedStorage.Shared.WalkUp)

local ArcadeCabinetService = {}

local CHECK_SECONDS = 2
local STORE = "ArcadeCabinetAway"

type Cabinet = { model: Model, ring: Instance?, home: Instance }

local cabinet: Cabinet? = nil
local shown: boolean? = nil -- whether the cabinet stands; nil before the first pass

local function store(): Folder
	local found = ServerStorage:FindFirstChild(STORE)
	if found ~= nil and found:IsA("Folder") then
		return found :: Folder
	end
	local made = Instance.new("Folder")
	made.Name = STORE
	made.Parent = ServerStorage
	return made
end

-- Finds the cabinet once, while it still stands where WorldBuilder built it; false until it is built.
local function find(): boolean
	if cabinet == nil then
		local model: Instance? = CollectionService:GetTagged(Arcade.TAG)[1]
		local home = if model ~= nil then model.Parent else nil
		if model ~= nil and model:IsA("Model") and home ~= nil then
			local link = model:FindFirstChild(WalkUp.CIRCLE)
			local ring: Instance? = nil
			if link ~= nil and link:IsA("ObjectValue") then
				ring = (link :: ObjectValue).Value
			end
			cabinet = { model = model :: Model, ring = ring, home = home :: Instance }
		end
	end
	return cabinet ~= nil
end

-- One pass. Returns whether the cabinet stands.
function ArcadeCabinetService.apply(): boolean
	if not find() then
		return false
	end
	local on = Arcade.cabinetStands(
		LiveFlagService.on(Arcade.FLAG),
		LiveFlagService.on(MouseDash.CIRCLE_FLAG),
		LiveFlagService.on(MouseDash.FLAG)
	)
	if shown ~= on then
		shown = on
		local found = cabinet :: Cabinet
		local parent: Instance = if on then found.home else store()
		found.model.Parent = parent
		if found.ring ~= nil then
			found.ring.Parent = parent
		end
	end
	return on
end

function ArcadeCabinetService.start()
	task.spawn(function()
		while true do
			local ok, err = pcall(ArcadeCabinetService.apply)
			if not ok then
				warn("[ArcadeCabinetService] " .. tostring(err))
			end
			task.wait(CHECK_SECONDS)
		end
	end)
end

return ArcadeCabinetService
