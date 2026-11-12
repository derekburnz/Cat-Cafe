--!strict
-- Pet a cat on the server (#3651, the rules are shared/Pet; switch `petCats`, off by default).
--   PetCat(catUid)  C -> S  2 a second and one pet each Config.PetCooldownSeconds: one of the player's own cats, on
--     a job, its model in the player's own cafe, the player within Config.PetRangeStuds of it. The window so far is
--     settled, the cat becomes the happy cat (Pet.pet) and CatPetted goes to everyone for the moment. A refused
--     call is answered with nothing: the prompt just does nothing, and there is no toast either way.
--   CatPetted(userId, cat, from)  S -> C, everyone.
-- The extra pay is Economy.settle's (Economy.petRate); the heart on the cat's money tag follows the model's
-- HappyUntil attribute, which CafeService.markHappy keeps. The switch going on or off settles everyone first, so
-- each second is paid as it was earned.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CafeService = require(script.Parent.CafeService)
local ClockService = require(script.Parent.ClockService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Guard = require(script.Parent.Parent.Util.Guard)
local LiveFlagService = require(script.Parent.LiveFlagService)
local Net = require(script.Parent.Net)
local Pet = require(ReplicatedStorage.Shared.Pet)
local PlotService = require(script.Parent.PlotService)
local Telemetry = require(script.Parent.Telemetry)

local PetService = {}

local RANGE_SLACK = 3 -- studs over PetRangeStuds: the server sees the character a little behind the client

local lastPet: { [Player]: number } = {} -- os.clock() of each player's last pet

local function onPet(player: Player, rawUid: unknown)
	if not LiveFlagService.on(Pet.FLAG) then
		return
	end
	local uid = Guard.id(rawUid)
	local profile = DataService.get(player)
	local plot = PlotService.get(player)
	if uid == nil or profile == nil or plot == nil then
		return
	end
	local now = os.clock()
	local last = lastPet[player]
	if last ~= nil and now - last < Config.PetCooldownSeconds then
		return
	end
	if Pet.blocker(profile.cats, uid) ~= nil then
		return
	end
	local model = plot.cats:FindFirstChild(uid)
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if model == nil or not model:IsA("Model") or root == nil or not root:IsA("BasePart") then
		return
	end
	local away = ((model :: Model):GetPivot().Position - (root :: BasePart).Position).Magnitude
	if away > Config.PetRangeStuds + RANGE_SLACK then
		return
	end
	lastPet[player] = now
	local at = os.time()
	Economy.settle(profile, at, ClockService.epoch()) -- the window so far at its own rate
	local how, previous = Pet.pet(profile, uid, at)
	CafeService.markHappy(player)
	Telemetry.custom(player, "cat_pet", 1, { how })
	local from = if previous ~= nil then plot.cats:FindFirstChild(previous) else nil
	Net.fireAll("CatPetted", player.UserId, model, from)
end

function PetService.start()
	Net.on("PetCat", onPet)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastPet[player] = nil
	end)
	task.spawn(function()
		local on = false
		while true do
			local now = LiveFlagService.on(Pet.FLAG)
			if now ~= on then
				for _, player in DataService.loadedPlayers() do
					local profile = DataService.get(player)
					if profile ~= nil then
						Economy.settle(profile, os.time(), ClockService.epoch())
					end
				end
				on = now
				Economy.setPetOn(on)
				for _, player in DataService.loadedPlayers() do
					CafeService.markHappy(player)
				end
			end
			task.wait(1)
		end
	end)
end

return PetService
