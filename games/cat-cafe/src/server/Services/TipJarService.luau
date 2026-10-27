--!strict
-- The Tip Jar (F47, data-model section 11b): twelve playtime gifts a session, each with its own Claim button. The
-- session starts when the profile loads, at Workspace:GetServerTimeNow() (the clock the client counts down against),
-- and lives only in this service's memory, so leaving resets the jar. A rejoin to farm the early steps pays less
-- than the rejoin costs in tips, which is why nothing is saved.
-- ClaimTipJar(step) pays a step once the session has run its minutes and it is unclaimed; coins are worked out from
-- the day rate at claim time, so the client's figure is only an estimate. Since F68 each step's prize is in the Index
-- prize shape and Payout pays it (step 9 at an hour and step 12 at two hours pay several things). Every claim and every refused
-- claim answers with TipJarState, so a client that drifted gets the server's view back.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CafeService = require(script.Parent.CafeService)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local DataService = require(script.Parent.DataService)
local Guard = require(script.Parent.Parent.Util.Guard)
local Net = require(script.Parent.Net)
local Payout = require(script.Parent.Payout)
local Telemetry = require(script.Parent.Telemetry)
local TipJar = require(ReplicatedStorage.Shared.TipJar)
local Types = require(ReplicatedStorage.Shared.Types)

local TipJarService = {}

type Session = {
	startedAt: number,
	claimed: { boolean },
}

local sessions: { [Player]: Session } = {}

local function send(player: Player, session: Session)
	local state: Types.TipJarState = {
		sessionStartedAt = session.startedAt,
		claimed = table.clone(session.claimed),
	}
	Net.fire(player, "TipJarState", state)
end

-- Pays a step's prize (F68: the Index prize shape) through Payout, with one toast naming all of it, "Tip Jar: +$1200,
-- +10 golden fish, 1 spin". Spins past SpinBankCap are dropped and the toast says so; the rest still pays.
local function pay(player: Player, profile: Types.PlayerProfile, def: Types.TipJarStep)
	local paid = Payout.pay(player, profile, def.prize, "tip_jar", "TimedReward")
	if #paid > 0 then
		Net.toast(player, "Tip Jar: " .. table.concat(paid, ", "), "good")
	end
end

local function onClaimTipJar(player: Player, rawStep: unknown)
	local step = Guard.int(rawStep, 1, #Catalog.tipJar)
	local session = sessions[player]
	local profile = DataService.get(player)
	if step == nil or session == nil or profile == nil then
		return
	end
	local def = Catalog.tipJar[step]
	if
		session.claimed[step]
		or not TipJar.isReady(def, session.startedAt, Workspace:GetServerTimeNow())
	then
		send(player, session)
		return
	end
	session.claimed[step] = true
	pay(player, profile, def)
	profile.stats.tipJarClaims += 1
	Telemetry.custom(player, "tip_jar", step, { TipJar.kind(def) })
	send(player, session)
	CafeService.sync(player)
end

function TipJarService.start()
	DataService.onLoaded:Connect(function(player: Player)
		local session: Session =
			{ startedAt = Workspace:GetServerTimeNow(), claimed = TipJar.unclaimed() }
		sessions[player] = session
		send(player, session)
	end)
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)
	Net.on("ClaimTipJar", onClaimTipJar)
end

-- Studio-only test hook: moves this session's start `minutes` earlier, so steps unlock without waiting. Returns the
-- session minutes now played, or -1 before the profile loads.
function TipJarService.debugAge(player: Player, minutes: number): number
	assert(RunService:IsStudio(), "debugAge is Studio only")
	local session = sessions[player]
	if session == nil then
		return -1
	end
	session.startedAt -= minutes * 60
	send(player, session)
	return (Workspace:GetServerTimeNow() - session.startedAt) / 60
end

return TipJarService
