--!strict
-- The Tip Jar (F47, data-model section 11b): twelve playtime gifts a session, each with its own Claim button. The
-- session starts when the profile loads, at Workspace:GetServerTimeNow() (the clock the client counts down against),
-- and lives only in this service's memory, so leaving resets the jar. A rejoin to farm the early steps pays less
-- than the rejoin costs in tips, which is why nothing is saved.
-- ClaimTipJar(step) pays a step once the session has run its minutes and it is unclaimed; coins are worked out from
-- the day rate at claim time, so the client's figure is only an estimate. Since F68 each step's prize is in the Index
-- prize shape and Payout pays it (step 9 at an hour and step 12 at two hours pay several things). Every claim and every refused
-- claim answers with TipJarState, so a client that drifted gets the server's view back.
-- Claim all (ClaimAllService): `claimAll(player)` pays every ready, unclaimed step, each as its own Claim would, with
-- one toast, one TipJarState and one sync.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CafeService = require(script.Parent.CafeService)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local ClaimAll = require(ReplicatedStorage.Shared.ClaimAll)
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

-- Marks step `step` claimed and pays its prize (F68: the Index prize shape) through Payout; returns what it paid, for
-- one toast naming all of it, "Tip Jar: +$1200, +10 golden fish, 1 spin". Spins past SpinBankCap are dropped and the
-- toast says so; the rest still pays. The caller has checked that it is ready and unclaimed.
local function pay(
	player: Player,
	profile: Types.PlayerProfile,
	session: Session,
	step: number
): { string }
	local def = Catalog.tipJar[step]
	session.claimed[step] = true
	local paid = Payout.pay(player, profile, def.prize, "tip_jar", "TimedReward")
	profile.stats.tipJarClaims += 1
	Telemetry.custom(player, "tip_jar", step, { TipJar.kind(def) })
	return paid
end

local function toast(player: Player, paid: { string })
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
	toast(player, pay(player, profile, session, step))
	send(player, session)
	CafeService.sync(player)
end

-- Claim all in the Tip Jar: every ready, unclaimed step in order, one toast, one TipJarState, one sync.
function TipJarService.claimAll(player: Player)
	local session = sessions[player]
	local profile = DataService.get(player)
	if session == nil or profile == nil then
		return
	end
	local steps = ClaimAll.tipJar(session.claimed, session.startedAt, Workspace:GetServerTimeNow())
	if #steps == 0 then
		Net.toast(player, ClaimAll.NOTHING, "warn")
		send(player, session)
		return
	end
	local paid: { string } = {}
	for _, step in steps do
		for _, line in pay(player, profile, session, step) do
			table.insert(paid, line)
		end
	end
	toast(player, ClaimAll.merge(paid))
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
