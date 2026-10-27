--!strict
-- In-game bug reports for the friends alpha (docs/playtests/bug-reports.md). ReportBug(text, kind?, clientErrors?)
-- from the Settings window is checked by shared/BugReport, held to one per ReportSeconds per player, PlayerCap per
-- player and ServerCap per server, and saved with what the server knows of the moment: who, which build, where,
-- the clock, the cafe's tier, coins and cats, a carried cat, the device and the server's last error lines. Nothing
-- from the client is trusted for any of that. Records go to the BugReports_v1 DataStore under a day prefix
-- (BugReport.key) for the team to read with Debug.bugReports or Open Cloud; in Studio each is also printed as one
-- [BugReport] <json> line, so a run with API access off still shows it. The text is never shown to another player.
--
-- Roblox terms: a DataStore is Roblox's key-value storage for an experience; SetAsync writes one key and can fail
-- (budget, outage, API access off in Studio), so it runs in pcall. LogService.MessageOut is the server's output.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BugReport = require(ReplicatedStorage.Shared.BugReport)
local CatService = require(script.Parent.CatService)
local ClockService = require(script.Parent.ClockService)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Net = require(script.Parent.Net)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local Telemetry = require(script.Parent.Telemetry)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local BugReportService = {}

local REPORT_SECONDS = 20 -- one report per player per this many seconds
local PLAYER_CAP = 10 -- reports per player per server session (kept across a rejoin to the same server)
local SERVER_CAP = 200 -- reports per server session
local LIST_PAGE = 100

export type Record = {
	v: number,
	text: string,
	kind: string,
	clientErrors: { string },
	serverErrors: { string },
	userId: number,
	name: string,
	placeVersion: number,
	jobId: string,
	at: number,
	phase: string,
	area: string,
	position: { number }?,
	tier: number?,
	money: number?,
	cats: number?,
	carrying: boolean,
	device: string,
}

local world: WorldBuilder.World? = nil
local limiter = RateLimiter.new(1, REPORT_SECONDS)
local sentBy: { [number]: number } = {} -- userId -> reports this server session
local sentTotal = 0
local serverErrors: { string } = {} -- the last BugReport.MaxErrors error lines in the server's output

local function store(): DataStore
	return DataStoreService:GetDataStore(BugReport.StoreName)
end

local function onMessage(message: string, messageType: Enum.MessageType)
	if messageType ~= Enum.MessageType.MessageError then
		return
	end
	local line = BugReport.errorLine(message)
	if line == nil then
		return
	end
	table.insert(serverErrors, line)
	if #serverErrors > BugReport.MaxErrors then
		table.remove(serverErrors, 1)
	end
end

local function record(player: Player, text: string, kind: string, clientErrors: { string }): Record
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	local position = if root ~= nil and root:IsA("BasePart")
		then (root :: BasePart).Position
		else nil
	local area = if position ~= nil and world ~= nil
		then WorldBuilder.areaAt(world, position)
		else nil
	local profile = DataService.get(player) -- nil while the profile is still loading; the report still counts
	local cats = 0
	if profile ~= nil then
		for _ in profile.cats do
			cats += 1
		end
	end
	return {
		v = 1,
		text = text,
		kind = kind,
		clientErrors = clientErrors,
		serverErrors = table.clone(serverErrors),
		userId = player.UserId,
		name = player.Name,
		placeVersion = game.PlaceVersion,
		jobId = game.JobId,
		at = os.time(),
		phase = ClockService.phase(),
		area = area or "street",
		position = if position ~= nil
			then { math.round(position.X), math.round(position.Y), math.round(position.Z) }
			else nil,
		tier = if profile ~= nil then Economy.tier(profile) else nil,
		money = if profile ~= nil then math.floor(profile.coins) else nil,
		cats = if profile ~= nil then cats else nil,
		carrying = CatService.isCarrying(player),
		device = Telemetry.device(player) or "unknown",
	}
end

local function onReportBug(player: Player, rawText: unknown, rawKind: unknown, rawErrors: unknown)
	local text = BugReport.text(rawText)
	if text == nil then
		Net.toast(player, BugReport.Messages.short, "warn")
		return
	end
	local userId = player.UserId
	if
		(sentBy[userId] or 0) >= PLAYER_CAP
		or sentTotal >= SERVER_CAP
		or not limiter:allow(userId)
	then
		Net.toast(player, BugReport.Messages.limited, "warn")
		return
	end
	sentBy[userId] = (sentBy[userId] or 0) + 1
	sentTotal += 1
	local report = record(player, text, BugReport.kind(rawKind), BugReport.clientErrors(rawErrors))
	if RunService:IsStudio() then
		print("[BugReport] " .. HttpService:JSONEncode(report))
	end
	local ok, err = pcall(function()
		-- the userId tags the entry, so a data request finds it (review N148)
		store():SetAsync(BugReport.key(report.at, userId), report, { userId })
	end)
	if not ok then
		warn(string.format("[BugReport] save failed for user %d: %s", userId, tostring(err)))
	end
	if player.Parent == nil then
		return -- left while the write ran
	elseif ok then
		Net.toast(player, BugReport.Messages.sent, "good")
	else
		Net.toast(player, BugReport.Messages.failed, "warn")
	end
end

function BugReportService.start(builtWorld: WorldBuilder.World)
	world = builtWorld
	LogService.MessageOut:Connect(onMessage)
	Players.PlayerRemoving:Connect(function(player)
		limiter:forget(player.UserId)
	end)
	Net.on("ReportBug", onReportBug)
end

local function joined(lines: any): string
	return if type(lines) == "table" then table.concat(lines, " / ") else ""
end

-- One saved report as a line: "17:52 bug Derek (40908216) v8 woods pc: the text | client ... | server ...".
local function line(r: any): string
	return string.format(
		"%s %s %s (%s) v%s %s %s: %s | client %s | server %s",
		os.date("!%H:%M", if type(r.at) == "number" then r.at else 0),
		tostring(r.kind),
		tostring(r.name),
		tostring(r.userId),
		tostring(r.placeVersion),
		tostring(r.area),
		tostring(r.device),
		tostring(r.text),
		joined(r.clientErrors),
		joined(r.serverErrors)
	)
end

-- Studio-only test hook (Debug.bugReports): the newest `count` reports of UTC day `day` ("YYYYMMDD", default today),
-- oldest first, one line each. Needs Studio's API access on. Keys sort by time within a day, so the newest are the
-- last listed.
function BugReportService.debugList(count: number?, day: string?): { string }
	assert(RunService:IsStudio(), "debugList is Studio only")
	local wanted = math.max(1, math.floor(count or 20))
	local prefix = "r_" .. (day or BugReport.day(os.time())) .. "_"
	local keys: { string } = {}
	local pages = store():ListKeysAsync(prefix, LIST_PAGE)
	while true do
		for _, entry in pages:GetCurrentPage() do
			table.insert(keys, (entry :: DataStoreKey).KeyName)
			if #keys > wanted then
				table.remove(keys, 1)
			end
		end
		if pages.IsFinished then
			break
		end
		pages:AdvanceToNextPageAsync()
	end
	local lines: { string } = {}
	for _, key in keys do
		local value = store():GetAsync(key)
		if type(value) == "table" then
			table.insert(lines, line(value))
		end
	end
	return lines
end

return BugReportService
