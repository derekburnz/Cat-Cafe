--!strict
-- #3573 (shared/AfkCafe): resting in your own cafe. Once a second each loaded player is checked: resting while
-- the client last said it has had no input (AfkIdle), the character has stood still for
-- Config.AfkCafeSeconds as this server saw it, it stands in its own cafe or on its doorstep (the home landing), and
-- the player carries no cat and is in no trade. A rest starts and ends on a settle, so every second is paid at the
-- rate it was earned at (Economy.setResting, Economy.moneyFor). The Player's CafeRest attribute tells the HUD's chip.
-- Ending a rest says what the cafe paid meanwhile, once. While a player past the tutorial stands in their rest zone
-- the Player's CafeRestZone attribute says so, for the client's rest banner (#3701).
-- #3602: behind the `autoRejoin` switch a resting player with no input for Config.AutoRejoinSeconds is teleported to this same
-- place, ahead of Roblox's 20 minute idle disconnect; the arrival (marked in its join data) takes the rest up again
-- once it stands at its cafe. Never in Studio (teleports do not run there) or in a private server (a public
-- teleport would take the player out of it).
-- #4346: AFK mode (shared/AfkCafe, behind `afkButton`): the AfkMode remote takes the player home and rests them as
-- soon as they stand there, input or not; the rejoin carries the mode. Walking off or AfkMode(false) ends it.
-- The client is trusted only for "no input": a client that lies and says idle still has to stand still in its own
-- cafe to rest, which is what resting is.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local AfkCafe = require(ReplicatedStorage.Shared.AfkCafe)
local CafeRoom = require(ReplicatedStorage.Shared.CafeRoom)
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
	arrivedAt: number?, -- #3602: os.clock() a rest's rejoin joined, until it rests again or its window ends
	idleSince: number?, -- #3602: os.clock() the player's last input, as far as the server knows; nil while not idle
	rejoinTry: number?, -- #3602: os.clock() of the last rejoin teleport since then
	modeSince: number?, -- #4346: os.clock() AFK mode came on, nil while it is off
	modeRested: boolean, -- #4346: a rest has started in this AFK mode
	modeRestAt: number?, -- #5310: os.clock() this AFK mode's first rest began (a step after it ends the mode)
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
		arrivedAt = nil,
		idleSince = nil,
		rejoinTry = nil,
		modeSince = nil,
		modeRested = false,
		modeRestAt = nil,
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
	profile.stats.restSeconds += math.floor(os.clock() - since) -- #3694 section 3: the resting achievement
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

-- #3602: sends a resting player back into this place. The save is released as they leave (DataService), after
-- beforeRelease has settled the rest. A failed teleport leaves them here, resting, for the next try.
local function rejoin(player: Player)
	if RunService:IsStudio() or game.PrivateServerId ~= "" then
		return
	end
	Telemetry.custom(player, "afk_rejoin", 1)
	task.spawn(function()
		local options = Instance.new("TeleportOptions")
		local watch = watches[player]
		options:SetTeleportData(
			AfkCafe.teleportData(watch ~= nil and watch.modeSince ~= nil) :: any
		)
		local ok, problem = pcall(function()
			TeleportService:TeleportAsync(game.PlaceId, { player }, options)
		end)
		if not ok then
			warn("[AfkCafeService] rejoin teleport failed: " .. tostring(problem))
		end
	end)
end

-- #3602: whether this join is a rest's rejoin (its join data, which a client can forge: see shared/AfkCafe).
local function noteArrival(player: Player)
	local ok, data = pcall(function()
		return player:GetJoinData()
	end)
	-- #5322: a restart's hop: on to a fresh public server, still in AFK mode, retried until it goes
	local reserved = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
	if ok and data ~= nil and AfkCafe.arrivedHop(data.TeleportData, reserved) then
		task.spawn(function()
			task.wait(AfkCafe.HOP_SECONDS)
			while player.Parent == Players do
				local options = Instance.new("TeleportOptions")
				options:SetTeleportData(AfkCafe.teleportData(true) :: any)
				local sent, problem = pcall(function()
					TeleportService:TeleportAsync(game.PlaceId, { player }, options)
				end)
				if not sent then
					warn("[AfkCafeService] hop back failed: " .. tostring(problem))
				end
				task.wait(AfkCafe.HOP_RETRY_SECONDS)
			end
		end)
		return
	end
	if
		ok
		and data ~= nil
		and AfkCafe.arrivedResting(data.TeleportData, data.SourcePlaceId, game.PlaceId)
	then
		local watch = watchOf(player)
		watch.arrivedAt = os.clock()
		watch.told = true -- the rest line was this visit's already
		player:SetAttribute(AfkCafe.REJOIN_ATTRIBUTE, true)
		if AfkCafe.arrivedInMode(data.TeleportData) then
			-- #4346: AFK mode carries on; its idle clock runs from this join, as the rest's does
			watch.modeSince = os.clock()
			watch.modeRested = false
			watch.idleSince = os.clock()
			player:SetAttribute(AfkCafe.MODE_ATTRIBUTE, true)
		end
	end
end

-- #5322: the saved AFK mode mark (settings.afkMode), kept while the afkStay switch is on
local function save(player: Player, on: boolean)
	if not LiveFlagService.on(AfkCafe.STAY_FLAG) then
		return
	end
	local profile = DataService.get(player)
	if profile ~= nil and profile.settings.afkMode ~= on then
		profile.settings.afkMode = on
		CafeService.sync(player)
	end
end

-- #4346: AFK mode on or off. Off ends the rest it held (input ends a rest in the usual way from then on).
-- #5322: on is saved; off is saved when the player turned it off (`keep` false: the button, or walking off after it
-- rested), not when a mode that never got to rest lapses (a join that landed away from the cafe).
local function setMode(player: Player, watch: Watch, on: boolean, keep: boolean?)
	if on then
		save(player, true)
		watch.modeSince = os.clock()
		watch.modeRested = false
		watch.modeRestAt = nil
		watch.idleSince = os.clock() -- the tap was input: Roblox's idle clock starts now
		watch.rejoinTry = nil
		player:SetAttribute(AfkCafe.MODE_ATTRIBUTE, true)
		return
	end
	if watch.modeSince == nil then
		return
	end
	if keep ~= true then
		save(player, false)
	end
	watch.modeSince = nil
	watch.modeRested = false
	watch.modeRestAt = nil
	player:SetAttribute(AfkCafe.MODE_ATTRIBUTE, nil)
	if not watch.idle then
		stop(player, watch)
	end
end

local function modeOn(): boolean
	return LiveFlagService.on(AfkCafe.BUTTON_FLAG)
end

local function check(player: Player, now: number)
	local watch = watchOf(player)
	local plot = PlotService.get(player)
	local profile = DataService.get(player)
	local root = rootOf(player)
	if plot == nil or profile == nil or root == nil then
		watch.at = nil
		watch.stillSince = now
		player:SetAttribute(AfkCafe.ZONE_ATTRIBUTE, nil)
		stop(player, watch)
		return
	end
	local position = root.Position
	local at = watch.at
	if at == nil or (position - at).Magnitude > AfkCafe.MOVE_STUDS then
		watch.at = position
		watch.stillSince = now
	end
	-- #4543: the room standing now, about its own middle (a grown room's middle is further back)
	local room = plot.cframe * CFrame.new(0, 0, CafeRoom.centre(plot.room.depth))
	local front = TravelService.homeFront(player)
	local inZone = AfkCafe.inZone(
		room:PointToObjectSpace(position),
		if front ~= nil then room:PointToObjectSpace(front.Position) else nil,
		plot.room.width,
		plot.room.depth
	)
	-- #3701: the rest banner's zone, for a player past the tutorial. It replaces the once a session line (Derek
	-- 2026-11-12: it "only pops up once not everytime your in cafe and also gets cut off"): the client's banner
	-- shows on every walk in (Components/RestBannerLogic).
	local zone: boolean? = nil
	if inZone and profile.tutorialStep >= TUTORIAL_DONE then
		zone = AfkCafe.doubled(Economy.eventMoney())
	end
	if player:GetAttribute(AfkCafe.ZONE_ATTRIBUTE) ~= zone then
		player:SetAttribute(AfkCafe.ZONE_ATTRIBUTE, zone)
	end
	-- #3602: a rest's rejoin takes the rest up again without the wait, once it stands still at its cafe
	local arrivedAt = watch.arrivedAt
	if arrivedAt ~= nil then
		if now - arrivedAt > AfkCafe.ARRIVAL_SECONDS then
			watch.arrivedAt = nil
		elseif
			AfkCafe.arrivalRests(now - arrivedAt, now - watch.stillSince, inZone, busy(player))
		then
			watch.arrivedAt = nil
			watch.idle = true
			watch.idleSince = arrivedAt -- this session's idle clock started as it joined
			watch.rejoinTry = nil
			watch.stillSince = now - Config.AfkCafeSeconds
			player:SetAttribute(AfkCafe.ARRIVED_ATTRIBUTE, true)
		end
	end
	local resting = AfkCafe.resting(watch.idle, now - watch.stillSince, inZone, busy(player))
	-- #4346: AFK mode rests without the wait and whatever the input, and ends once its rest does (walked off)
	local modeSince = watch.modeSince
	if modeSince ~= nil then
		-- #5310 (Review-QA): the quick rest has no wait, so a step after it began is what ends the mode
		local restAt = watch.modeRestAt
		local modeResting = LiveFlagService.on(AfkCafe.BUTTON_FLAG)
			and AfkCafe.modeRests(
				now - watch.stillSince,
				inZone,
				busy(player),
				LiveFlagService.on(AfkCafe.QUICK_FLAG),
				restAt ~= nil and watch.stillSince > restAt + AfkCafe.QUICK_SETTLE_SECONDS
			)
		if AfkCafe.modeEnds(watch.modeRested, modeResting, now - modeSince) then
			setMode(player, watch, false, not watch.modeRested) -- #5322: a lapse keeps the saved mark
		else
			resting = resting or modeResting
			if modeResting then
				watch.modeRested = true
				watch.modeRestAt = watch.modeRestAt or now
			end
		end
	end
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
		local since = watch.idleSince
		if since ~= nil and AfkCafe.rejoinDue(now - since, watch.rejoinTry, now) then
			watch.rejoinTry = now
			rejoin(player)
		end
	end
end

function AfkCafeService.start()
	Net.on("AfkMode", function(player: Player, raw: unknown)
		if type(raw) ~= "boolean" then
			return
		end
		local watch = watchOf(player)
		if not raw then
			setMode(player, watch, false)
			Net.toast(player, AfkCafe.MODE_OFF_TEXT, "info")
			return
		end
		if not modeOn() or DataService.get(player) == nil or busy(player) then
			return
		end
		if not TravelService.home(player) then
			return -- TravelService said why (a cooldown, a catch, a tackle)
		end
		setMode(player, watch, true)
		watch.at = nil -- the trip home moved the character: stillness counts from the landing
		watch.stillSince = os.clock()
		Telemetry.custom(player, "afk_mode", 1)
		Net.toast(player, AfkCafe.MODE_ON_TEXT, "good")
		-- #5310: look now and again just after the trip home settles, not at the next tick and 3 s of standing
		if LiveFlagService.on(AfkCafe.QUICK_FLAG) then
			check(player, os.clock())
			task.delay(0.3, function()
				if player.Parent ~= nil and watch.modeSince ~= nil then
					check(player, os.clock())
				end
			end)
		end
	end)
	Net.on("AfkIdle", function(player: Player, raw: unknown)
		if type(raw) ~= "boolean" then
			return
		end
		local watch = watchOf(player)
		watch.idle = raw
		-- #3602: the client says idle AfkCafeSeconds after its last input
		watch.idleSince = if raw then os.clock() - Config.AfkCafeSeconds else nil
		watch.rejoinTry = nil
		if not raw and watch.modeSince == nil then
			stop(player, watch) -- any input ends it at once (#4346: not in AFK mode, which walking off ends)
		end
	end)
	DataService.beforeRelease(function(player: Player)
		local watch = watches[player]
		if watch ~= nil then
			stop(player, watch) -- settled at the rest's rate before the save
		end
		watches[player] = nil
	end)
	-- #5322: AFK mode saved on: a join (past the tutorial, not a hop) takes it up again once the character is in
	DataService.onLoaded:Connect(function(player: Player, profile: any)
		if
			not LiveFlagService.on(AfkCafe.STAY_FLAG)
			or not modeOn()
			or profile.settings.afkMode ~= true
			or profile.tutorialStep < TUTORIAL_DONE
			or game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
		then
			return
		end
		task.spawn(function()
			if player.Character == nil then
				player.CharacterAdded:Wait()
			end
			task.wait(AfkCafe.HOP_SECONDS) -- the landing at the front door settles first
			local watch = watches[player]
			if player.Parent ~= Players or (watch ~= nil and watch.modeSince ~= nil) then
				return -- left, or a rejoin's arrival already took the mode up
			end
			watch = watchOf(player)
			setMode(player, watch, true)
			watch.at = nil
			watch.stillSince = os.clock()
			Net.toast(player, AfkCafe.MODE_ON_TEXT, "good")
		end)
	end)
	-- #5322: a restart shuts this server: players in AFK mode hop through a reserved server to a fresh public one
	game:BindToClose(function()
		if
			RunService:IsStudio()
			or game.PrivateServerId ~= ""
			or not LiveFlagService.on(AfkCafe.STAY_FLAG)
		then
			return
		end
		local hopping: { Player } = {}
		for _, player in Players:GetPlayers() do
			local watch = watches[player]
			if watch ~= nil and watch.modeSince ~= nil then
				table.insert(hopping, player)
			end
		end
		if #hopping == 0 then
			return
		end
		for _, player in hopping do
			Telemetry.custom(player, "afk_rejoin", 1, { "restart" })
		end
		-- a reserved server of this place holds them for the few seconds the restart takes (noteArrival hops them back)
		local ok, problem = pcall(function()
			local code = TeleportService:ReserveServer(game.PlaceId)
			TeleportService:TeleportToPrivateServer(
				game.PlaceId,
				code,
				hopping,
				nil,
				AfkCafe.hopData() :: any
			)
		end)
		if not ok then
			warn("[AfkCafeService] restart hop failed: " .. tostring(problem))
		end
	end)
	Players.PlayerAdded:Connect(noteArrival)
	for _, player in Players:GetPlayers() do
		noteArrival(player)
	end
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
