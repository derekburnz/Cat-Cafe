--!strict
-- #3573 (shared/AfkCafe): resting in your own cafe. Once a second each loaded player is checked: resting while the
-- `afkCafe` switch is on, the client last said it has had no input (AfkIdle), the character has stood still for
-- Config.AfkCafeSeconds as this server saw it, it stands in its own cafe or on its doorstep (the home landing), and
-- the player carries no cat and is in no trade. A rest starts and ends on a settle, so every second is paid at the
-- rate it was earned at (Economy.setResting, Economy.moneyFor). The Player's CafeRest attribute tells the HUD's chip.
-- Ending a rest says what the cafe paid meanwhile, once. The first time each session a player past the tutorial
-- walks into their own cafe, AfkCafe.LINE says that resting pays, once.
-- The client is trusted only for "no input": a client that lies and says idle still has to stand still in its own
-- cafe to rest, which is what resting is.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AfkCafe = require(ReplicatedStorage.Shared.AfkCafe)
local CafeService = require(script.Parent.CafeService)
local ClockService = require(script.Parent.ClockService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local LiveFlagService = require(script.Parent.LiveFlagService)
local Net = require(script.Parent.Net)
local PlotService = require(script.Parent.PlotService)
local ShortNumber = require(ReplicatedStorage.Shared.ShortNumber)
local Telemetry = require(script.Parent.Telemetry)
local TravelService = require(script.Parent.TravelService)

local AfkCafeService = {}

type Watch = {
	idle: boolean, -- the client's last word
	at: Vector3?, -- where the character stood when it was last seen to move
	stillSince: number, -- os.clock() of that
	restSince: number?, -- os.clock() the rest started, nil while not resting
	told: boolean, -- AfkCafe.LINE was said this session
}

local TUTORIAL_DONE = 5 -- the tutorial's last step (the client's TutorialHints.DONE)

local watches: { [Player]: Watch } = {}

local function watchOf(player: Player): Watch
	local known = watches[player]
	if known ~= nil then
		return known
	end
	local watch: Watch = {
		idle = false,
		at = nil,
		stillSince = os.clock(),
		restSince = nil,
		told = false,
	}
	watches[player] = watch
	return watch
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root :: BasePart else nil
end

local function busy(player: Player): boolean
	local character = player.Character
	return player:GetAttribute("Trading") == true
		or (character ~= nil and character:GetAttribute("CarryingCatId") ~= nil)
end

-- Ends the rest: settles what it earned, then says and logs it.
local function stop(player: Player, watch: Watch)
	local since = watch.restSince
	if since == nil then
		return
	end
	watch.restSince = nil
	player:SetAttribute(AfkCafe.ATTRIBUTE, nil)
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	Economy.settle(profile, os.time(), ClockService.epoch())
	Economy.setResting(profile, false)
	local earned = math.floor(Economy.takeRestEarned(profile))
	Telemetry.custom(player, "afk_end", math.floor(os.clock() - since))
	Telemetry.custom(player, "afk_pay", earned)
	if earned > 0 then
		Net.toast(player, AfkCafe.welcome("$" .. ShortNumber.format(earned)), "good")
	end
	CafeService.sync(player)
end

local function start(player: Player, watch: Watch)
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	Economy.settle(profile, os.time(), ClockService.epoch())
	Economy.takeRestEarned(profile)
	Economy.setResting(profile, true)
	watch.restSince = os.clock()
	local doubled = AfkCafe.doubled(Economy.eventMoney())
	player:SetAttribute(AfkCafe.ATTRIBUTE, doubled)
	Telemetry.custom(player, "afk_start", 1, { if doubled then "doubled" else "party" })
	CafeService.sync(player)
end

local function check(player: Player, now: number)
	local watch = watchOf(player)
	local plot = PlotService.get(player)
	local profile = DataService.get(player)
	local root = rootOf(player)
	if plot == nil or profile == nil or root == nil then
		watch.at = nil
		watch.stillSince = now
		stop(player, watch)
		return
	end
	local position = root.Position
	local at = watch.at
	if at == nil or (position - at).Magnitude > AfkCafe.MOVE_STUDS then
		watch.at = position
		watch.stillSince = now
	end
	local W = Config.World
	local front = TravelService.homeFront(player)
	local inZone = AfkCafe.inZone(
		plot.cframe:PointToObjectSpace(position),
		if front ~= nil then plot.cframe:PointToObjectSpace(front.Position) else nil,
		W.PlotWidth,
		W.PlotDepth
	)
	local on = LiveFlagService.on(AfkCafe.FLAG)
	-- the once a session line, the first time a player past the tutorial is inside their cafe
	if
		on
		and not watch.told
		and profile.tutorialStep >= TUTORIAL_DONE
		and AfkCafe.inZone(plot.cframe:PointToObjectSpace(position), nil, W.PlotWidth, W.PlotDepth)
	then
		watch.told = true
		Net.toast(player, AfkCafe.LINE, "info")
	end
	local resting = on and AfkCafe.resting(watch.idle, now - watch.stillSince, inZone, busy(player))
	if resting and watch.restSince == nil then
		start(player, watch)
	elseif not resting and watch.restSince ~= nil then
		stop(player, watch)
	elseif resting then
		-- a party starting or ending during a rest changes what the chip may say
		local doubled = AfkCafe.doubled(Economy.eventMoney())
		if player:GetAttribute(AfkCafe.ATTRIBUTE) ~= doubled then
			player:SetAttribute(AfkCafe.ATTRIBUTE, doubled)
		end
	end
end

function AfkCafeService.start()
	Net.on("AfkIdle", function(player: Player, raw: unknown)
		if type(raw) ~= "boolean" then
			return
		end
		local watch = watchOf(player)
		watch.idle = raw
		if not raw then
			stop(player, watch) -- any input ends it at once
		end
	end)
	DataService.beforeRelease(function(player: Player)
		local watch = watches[player]
		if watch ~= nil then
			stop(player, watch) -- settled at the rest's rate before the save
		end
		watches[player] = nil
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		task.defer(function()
			watches[player] = nil
		end)
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed < AfkCafe.TICK_SECONDS then
			return
		end
		elapsed = 0
		local now = os.clock()
		for _, player in DataService.loadedPlayers() do
			check(player, now)
		end
	end)
end

return AfkCafeService
