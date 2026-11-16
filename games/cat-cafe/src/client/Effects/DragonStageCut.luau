--!strict
-- The Dragon Keep's stage-up cutscene, played live (#4062; Model-Agent found DragonRise.play had no caller). The
-- server fires DragonStage(stage) to the owner for each stage Cinder reaches (DragonKeepService); this plays
-- Effects/DragonRise for it at the DragonKeep-tagged Keep, with the dragon that stands there on this client
-- (Effects/KeepDragon's `KeepDragon` model, #4574) as `info.dragon`, so the cutscene hides him while its own copies
-- play and gives him back after. Several stages at once (a big warmth gain) play one after another, in order.
-- The scale colour comes from ProfileSync's `dragon.colour`. Nothing plays while the dragonKeep switch is off
-- (DragonRise.wanted), or when the Keep is not streamed in. Listening only: no remote is fired.

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local DragonStageCut = {}

local TAG = "DragonKeep" -- WorldBuilder's tag on the Keep model
local DRAGON = "KeepDragon" -- Effects/KeepDragon's model, parented to the Keep
local LIFT = 0.22 -- the yard's paving above the Keep's pivot, as Effects/KeepDragon stands him
local MOST = 5 -- stages: never queue more than the dragon has

local started = false
local colour: string? = nil
local queue: { number } = {}
local busy = false

-- Pure: whether `value` from the remote is a stage to play (a whole number 1 to 5).
function DragonStageCut.valid(value: unknown): boolean
	return type(value) == "number" and value >= 1 and value <= MOST and value == math.floor(value)
end

-- Pure: `queue` with `stage` added, kept in order with no repeats and at most MOST long.
function DragonStageCut.add(list: { number }, stage: number): { number }
	if table.find(list, stage) == nil and #list < MOST then
		table.insert(list, stage)
		table.sort(list)
	end
	return list
end

local function findKeep(): Model?
	for _, instance in CollectionService:GetTagged(TAG) do
		if instance:IsA("Model") and instance:IsDescendantOf(Workspace) then
			return instance :: Model
		end
	end
	return nil
end

local function playNext()
	-- required here, not at load, so the pure parts above load in the unit tests without the cutscene's fonts
	local DragonRise = require(script.Parent.DragonRise) :: any
	if busy or #queue == 0 then
		return
	end
	local stage = table.remove(queue, 1) :: number
	local keep = findKeep()
	if keep == nil or not DragonRise.wanted() then
		table.clear(queue)
		return
	end
	busy = true
	local standing = keep:FindFirstChild(DRAGON)
	DragonRise.play({
		stage = stage,
		keep = keep:GetPivot() * CFrame.new(0, LIFT, 0),
		colour = colour,
		dragon = if standing ~= nil and standing:IsA("Model") then standing :: Model else nil,
	}, function()
		busy = false
		-- his new look at once, not up to a second after the scene (KeepDragon's own check)
		local KeepDragon = require(script.Parent.KeepDragon) :: any
		KeepDragon.refresh()
		task.defer(playNext)
	end)
end

function DragonStageCut.start()
	if started then
		return
	end
	started = true
	local Net = require(script.Parent.Parent.Net)
	Net.on("ProfileSync", function(state: unknown)
		if type(state) ~= "table" then
			return
		end
		local view = (state :: { [string]: any }).dragon
		local picked = if type(view) == "table" then view.colour else nil
		colour = if type(picked) == "string" then picked else nil
	end)
	Net.on("DragonStage", function(stage: unknown)
		if not DragonStageCut.valid(stage) then
			return
		end
		DragonStageCut.add(queue, stage :: number)
		-- a beat for the ProfileSync with the new look (and colour) to land first
		task.delay(0.2, playNext)
	end)
end

return DragonStageCut
