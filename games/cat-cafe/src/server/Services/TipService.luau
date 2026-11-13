--!strict
-- Context tips, the feedback faces and the "Need a hand?" card's saved half (F87, easy-start.md sections 2g, 3, 4
-- and 6; shared/Tips). The client times and shows every tip; this service decides the ones the server can see and
-- keeps what is saved:
--   ShowTip(id)                 S -> C  a tip whose moment came: once a second from `Tips.due` (the save and the
--                                       clock), and at their events through `TipService.show` (second_cat and tackle
--                                       at a check-in, dropped on a knock loose). F96 (starter-cat.md section 3): an
--                                       ask (notify, favorite, like or F92's invite) from `Tips.dueAsk`, one a
--                                       session. Each id goes at most once a session until it is seen.
--   (#3430: TipSeen("mystic_intro") starts the Mystic Pool's cutscene and saves its mark; TipSeen("mystic_intro",
--   skipped, seconds) ends it and logs mystic_intro)
--   TipSeen(id, skipped?)       C -> S  1 a second: a tip shown (saved in tipsSeen and logged once as tip_shown, at
--                                       most #LIST a session), an ask this session sent (saved in tipsSeen and logged
--                                       as ask_shown; the notification ask's first showing only sets notifyAskAt, and
--                                       skipped, Roblox would not prompt, puts it away and frees the session's ask),
--                                       the slide-in ask shown (feedbackAsked) or the help card shown
--                                       (stuckHelpShown for the current tutorialStep)
--   ClearTips()                 C -> S  1 per 10 s: Settings' "Show tips again" (Tips.cleared keeps the asks)
--   SendFeedback(face, chip?)   C -> S  1 per 10 s and FeedbackSessionLimit a session: logs `feedback`,
--                                       feedback_ctx and feedback_env, and the open feedback_v1 run's steps (#2681)
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
local LiveFlagService = require(script.Parent.LiveFlagService)
local Net = require(script.Parent.Net)
local PlayTime = require(script.Parent.Parent.Util.PlayTime)
local SessionFeedback = require(ReplicatedStorage.Shared.SessionFeedback)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Telemetry = require(script.Parent.Telemetry)
local Tips = require(ReplicatedStorage.Shared.Tips)
local Traits = require(ReplicatedStorage.Shared.Traits)
local Types = require(ReplicatedStorage.Shared.Types)

type Profile = Types.PlayerProfile

local TipService = {}

TipService.changed = Signal.new() :: Signal.Signal<Player>

type Session = {
	loadedAt: number, -- os.clock()
	sent: { [string]: boolean }, -- ids sent this session and not seen yet
	feedback: number, -- SendFeedback calls taken this session
	logged: number, -- tip_shown events logged this session (review S103: ClearTips must not refill the budget)
	asked: boolean, -- F96: this session's one ask went out
	introAt: number?, -- #3430: os.clock() the Mystic Pool cutscene started this session, until its end is logged
}

-- tip_shown events a session: every tip once. Past it tips are still saved, just not logged.
local TIP_LOGS_PER_SESSION = #Tips.LIST

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
	local clock = os.time()
	local day = clock // 86400
	for player, session in sessions do
		local profile = DataService.get(player)
		if profile ~= nil and now - session.loadedAt >= Config.TipStartSeconds then
			for _, id in Tips.due(profile, at) do
				TipService.show(player, id)
			end
			-- F96: at most one ask a session, when its moment has come
			if not session.asked then
				local ask = Tips.dueAsk(
					profile,
					clock,
					day,
					PlayTime.seconds(player, profile),
					now - session.loadedAt -- #2553: this session's seconds, for the return path
				)
				if ask ~= nil and TipService.show(player, ask) then
					session.asked = true
				end
			end
		end
	end
end

-- An ask the client answered for (F96). `skipped`: Roblox would not prompt (the notification ask to a player under
-- 13 or already opted in), so it is put away for good and the session may ask something else.
local function askSeen(
	player: Player,
	profile: Profile,
	session: Session,
	id: string,
	skipped: boolean
)
	if skipped then
		profile.tipsSeen[id] = true
		session.asked = false
		return
	end
	if id == Tips.NOTIFY_ASK and profile.notifyAskAt <= 0 then
		profile.notifyAskAt = os.time() -- shown once; it may come back once after NOTIFY_RETRY_SECONDS
	else
		profile.tipsSeen[id] = true
	end
	Telemetry.custom(
		player,
		"ask_shown",
		1,
		{ string.sub(id, 1, #id - #"_ask"), tostring(profile.stats.sessions) }
	)
	if id == Tips.LIKE_ASK then
		Telemetry.likeAskShown(player, profile) -- #2681
	end
end

-- #3430: the Mystic Pool's cutscene. The first TipSeen (no `skipped`) is its start: the mark is saved then, so a
-- skip, a crash or a rejoin never plays it twice, and only while the pool is open to this player. The second (with
-- `skipped`) is its end: `mystic_intro` is logged once with watched or skipped and the seconds seen, never more than
-- the server's own clock allows.
local MYSTIC_INTRO_MAX_SECONDS = 30
local function mysticIntro(
	player: Player,
	profile: Profile,
	session: Session,
	rawSkipped: unknown,
	rawSeconds: unknown
)
	local skipped = Guard.bool(rawSkipped)
	if skipped == nil then
		local open = LiveFlagService.on(Traits.FLAG) and Traits.openAt(Economy.tier(profile))
		if open and profile.tipsSeen[Tips.MYSTIC_INTRO] ~= true then
			profile.tipsSeen[Tips.MYSTIC_INTRO] = true
			session.introAt = os.clock()
		end
		return
	end
	local startedAt = session.introAt
	if startedAt == nil then
		return
	end
	session.introAt = nil
	local seconds = math.min(os.clock() - startedAt, MYSTIC_INTRO_MAX_SECONDS)
	if type(rawSeconds) == "number" and rawSeconds == rawSeconds and rawSeconds >= 0 then
		seconds = math.min(seconds, rawSeconds)
	end
	Telemetry.custom(
		player,
		"mystic_intro",
		math.floor(seconds + 0.5),
		{ if skipped then "skipped" else "watched" }
	)
end

local function onTipSeen(player: Player, rawId: unknown, rawSkipped: unknown, rawSeconds: unknown)
	local id = Guard.id(rawId)
	local profile = DataService.get(player)
	local session = sessionOf(player)
	if id == nil or profile == nil or session == nil or not Tips.seenId(id) then
		return
	end
	local wasSent = session.sent[id] == true
	session.sent[id] = nil
	if Tips.isAsk(id) then
		-- only an ask this session sent, so a client cannot log or put one away at will
		if wasSent and profile.tipsSeen[id] ~= true then
			askSeen(player, profile, session, id, Guard.bool(rawSkipped) == true)
		end
		return
	end
	if id == Tips.FEEDBACK_ASK then
		profile.feedbackAsked = true
		Telemetry.feedbackAsked(player, profile) -- #2681: opens a feedback_v1 run, capped a session
		return
	end
	if id == Tips.MYSTIC_INTRO then
		mysticIntro(player, profile, session, rawSkipped, rawSeconds)
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
	if session.logged >= TIP_LOGS_PER_SESSION then
		return
	end
	session.logged += 1
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
	Telemetry.feedbackAnswered(player, profile, face, chip) -- #2681: feedback_ctx, feedback_env, feedback_v1
end

-- #3272: the once-a-day session ask's answer (a face or "skipped"); a second one the same UTC day is dropped. Logs
-- session_feedback only: no reward, and it does not count as the F87 ask or its feedback.
local function onSessionFeedback(player: Player, rawAnswer: unknown)
	local answer = Guard.oneOf(rawAnswer, SessionFeedback.ANSWERS :: { string })
	local profile = DataService.get(player)
	if answer == nil or profile == nil then
		return
	end
	local today = SessionFeedback.day(os.time())
	if profile.sessionFeedbackDay >= today then
		return
	end
	profile.sessionFeedbackDay = today
	Telemetry.sessionFeedback(player, profile, answer)
	TipService.changed:Fire(player)
end

-- Studio hook (Debug.tips): forgets every tip, the asks and the help cards, and this session's sends.
function TipService.debugReset(player: Player, profile: Profile): number
	local n = 0
	for _ in profile.tipsSeen do
		n += 1
	end
	profile.tipsSeen = {}
	profile.feedbackAsked = false
	profile.sessionFeedbackDay = 0 -- #3272
	profile.stuckHelpShown = {}
	profile.notifyAskAt = 0
	local session = sessionOf(player)
	if session ~= nil then
		session.sent = {}
		session.feedback = 0
		session.logged = 0
		session.asked = false
	end
	TipService.changed:Fire(player)
	return n
end

function TipService.start()
	DataService.onLoaded:Connect(function(player: Player)
		sessions[player] =
			{ loadedAt = os.clock(), sent = {}, feedback = 0, logged = 0, asked = false }
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		sessions[player] = nil
	end)
	Net.on("TipSeen", onTipSeen)
	Net.on("ClearTips", onClearTips)
	Net.on("SendFeedback", onSendFeedback)
	Net.on("SessionFeedback", onSessionFeedback)
	task.spawn(function()
		while true do
			task.wait(1)
			watch()
		end
	end)
end

-- Studio-only test hook (UI-Engineer for Desktop-Tester, 2026-11-07): forgets tip `id` was seen or sent this session
-- and sends it again now, the way its own moment would. False when the id is unknown or the player is not loaded.
function TipService.debugResend(player: Player, id: string): boolean
	assert(game:GetService("RunService"):IsStudio(), "debugResend is Studio only")
	local session = sessionOf(player)
	local profile = DataService.get(player)
	if session == nil or profile == nil or not Tips.seenId(id) then
		return false
	end
	profile.tipsSeen[id] = nil
	session.sent[id] = nil
	TipService.changed:Fire(player)
	return TipService.show(player, id)
end

return TipService
