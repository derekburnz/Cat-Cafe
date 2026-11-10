--!strict
-- The "your cats earned X while you were away" notification (#2768, Derek2 2026-11-10: "Yes, once a day, 12 h after
-- leaving"). Pure. Roblox terms: an experience notification is a message in a player's Roblox notifications that
-- opens the game; only players aged 13 and up who turned notifications on for the game ever receive one, and
-- Roblox itself delivers at most one a day per player per game.
--
-- When a player leaves, the server notes when their message is due and what it will say (AwayNotifyService, in the
-- MemoryStore sorted map MAP: key the user id, value the amount's text, sort key the due time). Coming back takes
-- the note out. A scheduled workflow (tools/opencloud/away-notify.sh) sends the due ones through Open Cloud, so
-- no key is in the game. One note per time away, so a player hears from us once per absence at most.
--
-- The amount is true: the same sum the welcome back card pays (Economy.offlineGain at the day rate the save keeps
-- at logout, the Long Nap pass's rate and cap when owned), counted to the moment the message is due.
--
--   plan(profile, now) -> Plan?   what to note at logout, or nil for nothing (off, or too little earned)
--   key(userId) -> string         the map key
local Config = require(script.Parent.Config)
local Economy = require(script.Parent.Economy)
local JoinSource = require(script.Parent.JoinSource)
local ShortNumber = require(script.Parent.ShortNumber)
local Types = require(script.Parent.Types)

local AwayNotify = {}

AwayNotify.MAP = "CatCafe_AwayNotify" -- the sender reads the same name
AwayNotify.LAUNCH_DATA = JoinSource.NOTIFY -- what a join from the message carries, so funnels can tell it apart

export type Plan = {
	dueAt: number, -- os.time() the message may go out
	text: string, -- the amount as the message shows it, "$1.24M"
	ttl: number, -- seconds the note lives: past this the message is too late to be worth sending
}

function AwayNotify.key(userId: number): string
	return tostring(userId)
end

function AwayNotify.plan(profile: Types.PlayerProfile, now: number): Plan?
	if not Config.AwayNotifyOn then
		return nil
	end
	local longNap = Economy.passes(profile).longNap == true
	local amount = Economy.offlineGain(
		Economy.incomePerSecond(profile),
		now,
		now + Config.AwayNotifySeconds,
		longNap
	)
	if amount < Config.AwayNotifyMinCoins then
		return nil
	end
	return {
		dueAt = now + Config.AwayNotifySeconds,
		text = "$" .. ShortNumber.format(amount),
		ttl = Config.AwayNotifySeconds + Config.AwayNotifyGraceSeconds,
	}
end

return AwayNotify
