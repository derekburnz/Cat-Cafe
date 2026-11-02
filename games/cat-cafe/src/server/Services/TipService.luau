--!strict
-- Context tips, the feedback faces and the "Need a hand?" card's saved half (F87, easy-start.md sections 2g, 3, 4
-- and 6; shared/Tips). The client times and shows every tip; this service decides the ones the server can see and
-- keeps what is saved:
--   ShowTip(id)                 S -> C  a tip whose moment came: once a second from `Tips.due` (the save and the
--                                       clock), and at their events through `TipService.show` (second_cat and tackle
--                                       at a check-in, dropped on a knock loose, the like ask at Tier 2 or a first
--                                       Legendary or better). Each id goes at most once a session until it is seen.
--   TipSeen(id, skipped?)       C -> S  1 a second: a tip or the like ask shown (saved in tipsSeen and logged once as
--                                       tip_shown), the slide-in ask shown (feedbackAsked) or the help card shown
--                                       (stuckHelpShown for the current tutorialStep)
--   ClearTips()                 C -> S  1 per 10 s: Settings' "Show tips again" (Tips.cleared keeps the like ask)
--   SendFeedback(face, chip?)   C -> S  1 per 10 s and FeedbackSessionLimit a session: logs `feedback`
-- Requires no gameplay service, so CafeService and ShoveService can require it; `changed` fires after ClearTips so
-- CafeService sends the new tipsSeen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ClockService = require(script.Parent.ClockService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Guard = require(script.Parent.Parent.Util.Guard)
local Net = require(script.Parent.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Telemetry = require(script.Parent.Telemetry)
local Tips = require(ReplicatedStorage.Shared.Tips)
local Types = require(ReplicatedStorage.Shared.Types)

type Profile = Types.PlayerProfile

local TipService = {}

TipService.changed = Signal.new() :: Signal.Signal<Player>

type Session = {
	loadedAt: number, -- os.clock()
	sent: { [string]: boolean }, -- ids sent this session and not seen yet
	feedback: number, -- SendFeedback calls taken this session
}

local sessions: { [Player]: Session } = {}

local function sessionOf(player: Player): Session?
	return sessions[player]
end

-- Sends ShowTip(id) unless the tip is seen or already went out this session. Returns whether it was sent.
function TipService.show(player: Player, id: string): boolean
	local session = sessionOf(player)
	local profile = DataService.get(player)
	if session == nil or profile == nil or not Tips.seenId(id) then
		return false
	end
	if profile.tipsSeen[id] == true or session.sent[id] then
		return false
	end
	session.sent[id] = true
	Net.fire(player, "ShowTip", id)
	return true
end

-- The clock as Tips.due reads it.
local function moment(): Tips.Moment
	local night = ClockService.isNight()
	local left = ClockService.phaseEndsAt() - Workspace:GetServerTimeNow()
	return { duskWarning = not night and left <= Config.DuskWarningSeconds, night = night }
end

local function watch()
	local now = os.clock()
	local at = moment()
	for player, session in sessions do
		local profile = DataService.get(player)
		if profile ~= nil and now - session.loadedAt >= Config.TipStartSeconds then
			for _, id in Tips.due(profile, at) do
				TipService.show(player, id)
			end
		end
	end
end

local function onTipSeen(player: Player, rawId: unknown, rawSkipped: unknown)
	local id = Guard.id(rawId)
	local profile = DataService.get(player)
	local session = sessionOf(player)
	if id == nil or profile == nil or session == nil or not Tips.seenId(id) then
		return
	end
	session.sent[id] = nil
	if id == Tips.FEEDBACK_ASK then
		profile.feedbackAsked = true
		return
	end
	if id == Tips.STUCK_HELP then
		profile.stuckHelpShown[tostring(math.clamp(profile.tutorialStep, 0, 5))] = true
		return
	end
	if profile.tipsSeen[id] == true then
		return -- logged once
	end
	profile.tipsSeen[id] = true
	local skipped = Guard.bool(rawSkipped) == true
	Telemetry.custom(player, "tip_shown", 1, { id, if skipped then "yes" else "no" })
end

local function onClearTips(player: Player)
	local profile = DataService.get(player)
	local session = sessionOf(player)
	if profile == nil or session == nil then
		return
	end
	profile.tipsSeen = Tips.cleared(profile.tipsSeen)
	session.sent = {}
	TipService.changed:Fire(player)
end

local function onSendFeedback(player: Player, rawFace: unknown, rawChip: unknown)
	local face = Guard.oneOf(rawFace, Tips.FACES :: { string })
	local chip = if rawChip == nil then nil else Guard.oneOf(rawChip, Tips.CHIPS :: { string })
	local profile = DataService.get(player)
	local session = sessionOf(player)
	if face == nil or (rawChip ~= nil and chip == nil) or profile == nil or session == nil then
		return
	end
	if session.feedback >= Config.FeedbackSessionLimit then
		return
	end
	session.feedback += 1
	-- an answer from the Feedback button counts as the one ask too, so the faces never slide in after it
	profile.feedbackAsked = true
	Telemetry.custom(
		player,
		"feedback",
		1,
		{ face, chip or "none", tostring(Economy.tier(profile)) }
	)
end

-- Studio hook (Debug.tips): forgets every tip, the ask and the help cards, and this session's sends.
function TipService.debugReset(player: Player, profile: Profile): number
	local n = 0
	for _ in profile.tipsSeen do
		n += 1
	end
	profile.tipsSeen = {}
	profile.feedbackAsked = false
	profile.stuckHelpShown = {}
	local session = sessionOf(player)
	if session ~= nil then
		session.sent = {}
		session.feedback = 0
	end
	TipService.changed:Fire(player)
	return n
end

function TipService.start()
	DataService.onLoaded:Connect(function(player: Player)
		sessions[player] = { loadedAt = os.clock(), sent = {}, feedback = 0 }
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		sessions[player] = nil
	end)
	Net.on("TipSeen", onTipSeen)
	Net.on("ClearTips", onClearTips)
	Net.on("SendFeedback", onSendFeedback)
	task.spawn(function()
		while true do
			task.wait(1)
			watch()
		end
	end)
end

return TipService
