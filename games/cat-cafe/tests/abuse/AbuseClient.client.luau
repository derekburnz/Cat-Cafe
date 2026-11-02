--!strict
--[[
	AbuseClient: QA's hostile client for the abuse pass (docs/playtests/test-plan.md section 4.3).

	It only exists in a build made from tests.project.json (StarterPlayer.StarterPlayerScripts.TestsAbuse) and
	only runs inside Studio. It fires remotes the way an exploiter would and prints what the server did about it,
	so a tester, or Claude Code over Studio MCP (get_console_output), can read the verdicts in the output window.

	In a Play Solo or Clients and Servers session:
	  press ` (backquote) to arm it, the menu prints, then one key per case:
	  1 fake stray      2 far swing         3 press without begin  4 bad presses   5 press with a time
	  6 no press        7 scripted perfect  8 far press            [ second swing  ; retry after a miss
	  ' press spam      . unlimited tries   9 bad ids              0 shop gates    - ownership
	  I swing flood
	  = double spend    , travel            / tackle               \ rename         Insert telemetry
	  Home drop         End unequip all     PageUp settings        PageDown saved settings
	  J tip jar         K index rewards     L spin wheel           R bug report
	  P fish market     O fresh catch       T codes             X tips              Backspace flood
	  ] run everything
	Or from a client-context command bar: _G.CatCafeAbuse.run("fakeStray"), _G.CatCafeAbuse.runAll().

	Since F93 (catch-rework.md section 1) a catch starts with a net swing: SwingNet() with no arguments, judged where
	the character stands and faces when the net lands. The cases stand SWING_STUDS from a stray, facing it, and read
	the NetSwung the server sends back; a refused swing (carrying, mid catch, flying, in a camp, inside the cooldown)
	gets no NetSwung at all.

	Every line starts with [Abuse]. RESULT lines say PASS, FAIL, SKIP or CHECK. After a run, read the SERVER
	output too: any "[Net] <remote> handler failed" line means the server errored on bad input, a major ticket
	on its own, and the "[Catch]" lines show how the server graded each circle. Anything the server accepted
	that the tables in test plan section 4.4 say it must refuse is a blocker.

	Owner: qa-playtester. Never ships: it is not in default.project.json.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

if not RunService:IsStudio() then
	return
end

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BugReport = require(Shared:WaitForChild("BugReport"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Circles = require(Shared:WaitForChild("Circles"))
local Codes = require(Shared:WaitForChild("Codes"))
local Config = require(Shared:WaitForChild("Config"))
local Crates = require(Shared:WaitForChild("Crates"))
local FreshCatch = require(Shared:WaitForChild("FreshCatch"))
local NetSwing = require(Shared:WaitForChild("NetSwing"))
local Prizes = require(Shared:WaitForChild("Prizes"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Spin = require(Shared:WaitForChild("Spin"))
local Types = require(Shared:WaitForChild("Types"))

local player = Players.LocalPlayer

-- What the server sent back, newest last --------------------------------------------------------------------

-- `at` is os.clock(), `server` the synced server clock (Workspace:GetServerTimeNow) the circle times use. `id` is
-- the stray or spot the event is about; `data` keeps a CatchSchedule or CatchResult for the cases to read.
type Event = { at: number, server: number, name: string, text: string, id: string?, data: any }

-- What CatchSchedule and CatchResult carry (design v0.5: no paws, tries are unlimited). `grades` runs up to and
-- including the first Miss, which ends the catch and sends the stray running; every circle Good or Perfect is a sure
-- catch.
type Schedule = { circles: { Types.CatchCircle }, windows: Types.CatchWindows }
type Outcome = {
	grades: { Types.CircleGrade },
	success: boolean,
	charmGain: number,
}
-- What ShoveResult carries (F41, v0.11 F74): "refused" and "miss" go to the tackler alone with target 0, a refusal
-- with no position or direction.
type Shoved = {
	outcome: string,
	shover: number,
	target: number,
	position: Vector3?,
	direction: Vector3?,
}

local events: { Event } = {}
local state: Types.PlayerState? = nil
local tipJar: Types.TipJarState? = nil -- the newest TipJarState (F47)
local freshStock: Types.FreshCatchStock? = nil -- the newest FreshCatchStock (F94), nil at night
local running: string? = nil
local lastSyncAt = 0 -- os.clock() of the newest ProfileSync
local lastSwingAt = -math.huge -- os.clock() of the newest SwingNet this script fired
local lastTravelAt = -math.huge -- os.clock() of the newest Travel this script fired

local function log(text: string)
	print("[Abuse] " .. text)
end

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function describe(...: any): string
	local parts = {}
	for index = 1, select("#", ...) do
		local value = select(index, ...)
		if type(value) == "string" then
			table.insert(
				parts,
				string.format(
					"%q",
					if #value > 24 then string.sub(value, 1, 21) .. "..." else value
				)
			)
		else
			table.insert(parts, tostring(value))
		end
	end
	return table.concat(parts, ", ")
end

local function record(name: string, text: string, id: string?, data: any?)
	table.insert(
		events,
		{ at = os.clock(), server = serverNow(), name = name, text = text, id = id, data = data }
	)
	if #events > 300 then
		table.remove(events, 1)
	end
	if running ~= nil then
		log(string.format("    <- %s %s", name, text))
	end
end

local function fire(name: string, ...: any)
	log(string.format("    -> %s(%s)", name, describe(...)))
	if name == "SwingNet" then
		lastSwingAt = os.clock()
	elseif name == "Travel" then
		lastTravelAt = os.clock()
	end
	Remotes.event(name):FireServer(...)
end

local function since(startedAt: number, name: string?): { Event }
	local found = {}
	for _, event in events do
		if event.at >= startedAt and (name == nil or event.name == name) then
			table.insert(found, event)
		end
	end
	return found
end

local function waitFor(
	startedAt: number,
	name: string,
	timeout: number,
	matches: ((Event) -> boolean)?
): Event?
	local deadline = os.clock() + timeout
	while os.clock() < deadline do
		for _, event in since(startedAt, name) do
			if matches == nil or matches(event) then
				return event
			end
		end
		task.wait(0.05)
	end
	return nil
end

local function money(): number
	return if state ~= nil then state.money else -1
end

local function catCount(): number
	local count = 0
	if state ~= nil then
		for _ in state.cats do
			count += 1
		end
	end
	return count
end

-- Coins against income. Every ProfileSync carries settled income (whole seconds of os.time on the server) and the
-- server's refusal paths sync too, so a correct server can show more coins than `before` at any check. A case
-- takes a wallet before it fires and allows the income the cafe could have earned since that sync.
type Wallet = { money: number, rate: number, at: number }

local function wallet(): Wallet
	return {
		money = money(),
		rate = if state ~= nil then state.incomePerSecond else 0,
		at = lastSyncAt,
	}
end

-- Asks for a sync first so the allowance stays small. RequestSync is limited to 1 per 2 s; when the server drops
-- the request, the older sync stands and the allowance grows with its age.
local function freshWallet(): Wallet
	local startedAt = os.clock()
	fire("RequestSync")
	waitFor(startedAt, "ProfileSync", 2.5)
	return wallet()
end

-- The most income that can have landed since `before`: the higher of the two rates, one extra second for the
-- server's whole-second clock and one coin for rounding.
local function incomeSince(before: Wallet): number
	local rate = math.max(before.rate, if state ~= nil then state.incomePerSecond else 0)
	return rate * (os.clock() - before.at + 1) + 1
end

-- True when coins rose by `expected` plus at most the income since `before`; the text goes on the RESULT line.
-- A spend still shows as a drop and a second payout as a second `expected`.
local function coinsMovedBy(before: Wallet, expected: number): (boolean, string)
	local gained = money() - before.money
	local allowance = incomeSince(before)
	local ok = gained >= expected and gained <= expected + allowance
	return ok,
		string.format(
			"coins moved by %d (allowed %d to %d with income)",
			gained,
			expected,
			math.floor(expected + allowance)
		)
end

-- The character and the world --------------------------------------------------------------------------------

local function rootPart(): BasePart?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root :: BasePart else nil
end

local function horizontal(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function teleportTo(position: Vector3)
	local root = rootPart()
	if root ~= nil then
		root.CFrame = CFrame.new(position + Vector3.new(0, 3, 0))
		task.wait(0.3) -- let the new position replicate before the server measures distance
	end
end

-- Like teleportTo, facing `lookAt` on the ground plane: the server judges a swing from the root's facing (F93).
local function teleportFacing(position: Vector3, lookAt: Vector3)
	local root = rootPart()
	if root ~= nil then
		local from = position + Vector3.new(0, 3, 0)
		root.CFrame = CFrame.lookAt(from, Vector3.new(lookAt.X, from.Y, lookAt.Z))
		task.wait(0.3)
	end
end

type StrayInfo = { id: string, model: Model, rarity: Types.Rarity }

-- Nearest stray nobody holds or reserved, of those `accept` takes. The server marks every stray model with these
-- attributes. A Dropped stray has no circles (v0.8 F56; since F93 a swing that lands on it picks it up), so the catch
-- cases never pick one; the drop case finds its own with droppedStray.
local function nearestStray(accept: ((StrayInfo) -> boolean)?): StrayInfo?
	local root = rootPart()
	local origin = if root ~= nil then root.Position else Vector3.zero
	local best: StrayInfo? = nil
	local bestDistance = math.huge
	for _, instance in Workspace:GetDescendants() do
		if not instance:IsA("Model") then
			continue
		end
		local id = instance:GetAttribute("StrayId")
		if type(id) ~= "string" then
			continue
		end
		local lockedBy = instance:GetAttribute("LockedBy")
		if (lockedBy ~= nil and lockedBy ~= 0) or instance:GetAttribute("Dropped") == true then
			continue
		end
		local distance = (instance:GetPivot().Position - origin).Magnitude
		if distance < bestDistance then
			local rarity = instance:GetAttribute("Rarity")
			local info: StrayInfo = {
				id = id,
				model = instance :: Model,
				rarity = (if type(rarity) == "string" then rarity else "Common") :: Types.Rarity,
			}
			if accept == nil or accept(info) then
				best = info
				bestDistance = distance
			end
		end
	end
	return best
end

-- How far from a stray the cases stand to swing at it: well inside NetReachStuds (7, plus NetSlackStuds), with room
-- for a stray that wanders a step while the teleport replicates.
local SWING_STUDS = 4

-- Stands SWING_STUDS from the stray, facing it, so a swing lands on it.
local function standNextTo(stray: StrayInfo)
	local at = stray.model:GetPivot().Position
	teleportFacing(at + Vector3.new(SWING_STUDS, 0, 0), at)
end

local function ownDoor(): BasePart?
	if state == nil or state.plotIndex == 0 then
		return nil
	end
	local world = Workspace:FindFirstChild("World")
	local plots = if world ~= nil then world:FindFirstChild("Plots") else nil
	local plot = if plots ~= nil then plots:FindFirstChild("Plot_" .. state.plotIndex) else nil
	local door = if plot ~= nil then plot:FindFirstChild("Door") else nil
	return if door ~= nil and door:IsA("BasePart") then door :: BasePart else nil
end

-- A carrying player's swing is refused, so the catch loops check the cat in between attempts.
local function checkInIfCarrying(): boolean
	if state == nil or state.carrying == nil then
		return true
	end
	local door = ownDoor()
	if door == nil then
		log("    carrying a cat but no own door found; check in by hand and rerun")
		return false
	end
	local startedAt = os.clock()
	teleportTo(door.Position + Vector3.new(0, 0, 3))
	fire("CheckIn")
	local synced = waitFor(startedAt, "ProfileSync", 3, function()
		return state ~= nil and state.carrying == nil
	end)
	return synced ~= nil
end

-- Cases -------------------------------------------------------------------------------------------------------

type Verdict = "PASS" | "FAIL" | "SKIP" | "CHECK"
type Case = { name: string, key: Enum.KeyCode, title: string, run: () -> (Verdict, string) }

-- The Debug hooks, from the command bar in Server view: never a require there, which gets unstarted copies (PR #50).
local DEBUG = "game.ServerStorage.CatCafeDebug:Invoke"

-- Since F66 the strays come in one wave at sunrise and the areas close at night, where a swing lands on nothing, so a
-- run wants a fresh day first.
local NO_STRAY = string.format(
	'no free stray nearby; on the server run %s("spawnStray", "tabby") or %s("setPhase", "day") for a fresh wave',
	DEBUG,
	DEBUG
)

local cases: { Case } = {}

local function case(name: string, key: Enum.KeyCode, title: string, run: () -> (Verdict, string))
	table.insert(cases, { name = name, key = key, title = title, run = run })
end

-- Catching (closing circles; design v0.5 chase) ---------------------------------------------------------------

local function circlesOf(rarity: Types.Rarity): number
	local def = Catalog.rarities[rarity]
	return if def ~= nil then def.circles else 1
end

local function targetOf(circle: Types.CatchCircle): number
	return circle.startsAt + circle.shrinkSeconds
end

-- When the server resolves a catch whose last circle nobody pressed: its target, the good window and the
-- latency cap (Circles.endsAt).
local function endsAt(schedule: Schedule): number
	local last = schedule.circles[#schedule.circles]
	return targetOf(last) + schedule.windows.good + Config.CatchLatencyCapSeconds
end

local function waitUntilServer(at: number)
	local left = at - serverNow()
	if left > 0 then
		task.wait(left)
	end
end

local function about(id: string): (Event) -> boolean
	return function(event: Event): boolean
		return event.id == id
	end
end

local function countAbout(startedAt: number, name: string, id: string): number
	local count = 0
	for _, event in since(startedAt, name) do
		if event.id == id then
			count += 1
		end
	end
	return count
end

local function toasted(startedAt: number, text: string): boolean
	for _, event in since(startedAt, "Toast") do
		if string.find(event.text, text, 1, true) ~= nil then
			return true
		end
	end
	return false
end

-- The server holds NetSwingCooldown between a player's swings and GrabCooldownSeconds between two catch starts, so a
-- case waits both out before a swing it means to land.
local function swingReady()
	local spacing = math.max(Config.NetSwingCooldown, Config.GrabCooldownSeconds) + 0.15
	local left = lastSwingAt + spacing - os.clock()
	if left > 0 then
		task.wait(left)
	end
end

-- My NetSwungs since `startedAt`: one for each swing of mine that landed (F93), none for a refused one.
local function swungSince(startedAt: number): { Event }
	return since(startedAt, "NetSwung")
end

-- How the server answered a swing fired at `startedAt`, once its NetSwung came (NetSmackDelay after it arrived): the
-- CatchSchedule it started, the warn toast that refused the stray it landed on, or the NetSwung itself when it hit
-- nothing. Nil when no NetSwung came: the server refused the swing and says nothing.
local function swingAnswer(startedAt: number, timeout: number): Event?
	local landed = waitFor(startedAt, "NetSwung", timeout)
	if landed == nil then
		return nil
	end
	for _, event in since(startedAt) do
		if
			event.name == "CatchSchedule"
			or (event.name == "Toast" and string.find(event.text, "[warn]", 1, true) ~= nil)
		then
			return event
		end
	end
	return landed
end

-- A swing at the stray from SWING_STUDS away, facing it. Returns the schedule the server sent (or nil and why not)
-- and when it fired. A stray that wandered off while the teleport replicated gets one more swing (laptop run
-- 2026-10-27).
local function beginCatch(stray: StrayInfo): (Schedule?, string, number)
	local why, startedAt = "", os.clock()
	for _ = 1, 2 do
		swingReady()
		standNextTo(stray)
		startedAt = os.clock()
		fire("SwingNet")
		local answer = swingAnswer(startedAt, 2)
		if answer == nil then
			return nil,
				"no NetSwung within 2 s of SwingNet: the swing was refused (carrying, mid catch, in a camp?)",
				startedAt
		end
		if answer.name == "CatchSchedule" then
			if answer.id ~= stray.id then
				return nil, "the swing landed on another stray, " .. tostring(answer.id), startedAt
			end
			return answer.data :: Schedule, answer.text, startedAt
		end
		if answer.name == "Toast" then
			return nil, "the swing landed but the catch was refused: " .. answer.text, startedAt
		end
		why = "the swing hit nothing (NetSwung hit=false)"
		log("    the stray moved off; standing by it again")
	end
	return nil, why, startedAt
end

-- The CatchResult of the catch that started at `startedAt`, waiting until a little past the schedule's end.
local function outcomeOf(startedAt: number, id: string, schedule: Schedule): (Outcome?, Event?)
	local event = waitFor(
		startedAt,
		"CatchResult",
		math.max(0, endsAt(schedule) - serverNow()) + 1.5,
		about(id)
	)
	return if event ~= nil then event.data :: Outcome else nil, event
end

-- A press the moment the circle reaches its target on the synced clock, which is what a player watching it sees.
-- The server takes half the ping off the arrival, so this grades Perfect.
local function pressOnTarget(id: string, index: number, circle: Types.CatchCircle)
	waitUntilServer(targetOf(circle))
	fire("CatchPress", id, index)
end

local function gradesText(grades: { Types.CircleGrade }): string
	return "{" .. table.concat(grades, ", ") .. "}"
end

-- Seconds until the stray stops running after a miss (its FleeingUntil, server time); 0 when it is not running.
local function fleeLeft(model: Model): number
	local fleeingUntil = model:GetAttribute("FleeingUntil")
	return if type(fleeingUntil) == "number" then math.max(0, fleeingUntil - serverNow()) else 0
end

-- fleeLeft once a miss's FleeingUntil has arrived. The server sets the attribute just after it fires CatchResult,
-- so it can land a frame after the result, and until then the model still holds the last miss's time.
local function fleeAfterMiss(model: Model): number
	local deadline = os.clock() + 0.5
	local left = fleeLeft(model)
	while left <= 0 and os.clock() < deadline do
		task.wait(0.05)
		left = fleeLeft(model)
	end
	return left
end

-- Waits out the sprint itself, so the stray stands still for StrayRestSeconds where it stopped.
local function waitForSprint(model: Model)
	task.wait(math.max(0, fleeAfterMiss(model) - Config.StrayRestSeconds + 0.1))
end

-- True when all `count` circles were graded and none was a Miss: a sure catch (v0.4).
local function allGraded(outcome: Outcome, count: number): boolean
	if #outcome.grades ~= count then
		return false
	end
	for _, grade in outcome.grades do
		if grade == "miss" then
			return false
		end
	end
	return true
end

-- A press just after circle 1 starts is most of a shrink early: a Miss, which ends the catch at once (v0.4).
local function missOnPurpose(id: string, schedule: Schedule)
	waitUntilServer(schedule.circles[1].startsAt + 0.15)
	fire("CatchPress", id, 1)
end

-- Presses every circle on its target in the background, so a case can act while the catch runs. A circle nobody
-- presses is a Miss at its deadline (v0.4), which would end the catch too soon for a mid-catch check.
local function pressAllOnTarget(id: string, schedule: Schedule)
	task.spawn(function()
		for index, circle in schedule.circles do
			pressOnTarget(id, index, circle)
		end
	end)
end

-- The worse of two verdicts, for cases that collect several checks.
local function downgrade(current: Verdict, level: Verdict): Verdict
	if level == "FAIL" or (level == "CHECK" and current == "PASS") then
		return level
	end
	return current
end

-- A catch that outlasts the 2 s between catch starts wants a Rare or rarer stray (F93: Common 3 circles, Rare 4).
local function longCatch(info: StrayInfo): boolean
	return circlesOf(info.rarity) >= 2
end

local NO_LONG_STRAY = string.format('spawn a Rare with %s("spawnStray", "calico") and rerun', DEBUG)

case(
	"fakeStray",
	Enum.KeyCode.One,
	"Fake stray: CatchPress on an id that does not exist (F93: a swing names no stray, so there is no id to fake)",
	function()
		local startedAt = os.clock()
		fire("CatchPress", "not_a_stray", 1)
		fire("CatchPress", "not_a_stray", 2)
		task.wait(1)
		local reactions = #since(startedAt, "GrabResult")
			+ #since(startedAt, "CatchSchedule")
			+ #since(startedAt, "CatchResult")
			+ #since(startedAt, "Toast")
		if reactions == 0 then
			return "PASS", "ignored, no schedule, result or toast"
		end
		return "FAIL", string.format("%d reaction(s) to a fake id", reactions)
	end
)

-- F93 reach: a swing lands on a stray within NetReachStuds plus NetSlackStuds (8.5) of the root and within
-- NetArcDegrees (60) of its facing. A swing that lands on nothing makes free strays within NetMissHopStuds (12) hop,
-- unless the player has not caught a cat yet, so each probe waits for the stray to stand still again.
case(
	"farSwing",
	Enum.KeyCode.Two,
	"Far swing: from 200 studs, 4 studs behind facing away and 9 studs ahead; none lands, the near misses make it hop",
	function()
		if not checkInIfCarrying() then
			return "SKIP", "carrying a cat that could not be checked in"
		end
		local stray = nearestStray()
		if stray == nil then
			return "SKIP", NO_STRAY
		end
		local root = rootPart()
		if root == nil then
			return "SKIP", "no character"
		end
		local home = root.Position
		local verdict: Verdict = "PASS"
		local notes = {}
		local probes: { { name: string, offset: number, facing: boolean, near: boolean } } = {
			{ name = "200 studs off", offset = 200, facing = true, near = false },
			{ name = "4 studs behind", offset = 4, facing = false, near = true },
			{ name = "9 studs ahead", offset = 9, facing = true, near = true },
		}
		for _, probe in probes do
			if stray.model.Parent == nil then
				verdict = downgrade(verdict, "CHECK")
				table.insert(notes, probe.name .. ": skipped, the stray left")
				break
			end
			task.wait(fleeLeft(stray.model) + 0.2) -- a hopping cat cannot be hit anyway
			swingReady()
			local at = stray.model:GetPivot().Position
			local stand = at + Vector3.new(probe.offset, 0, 0)
			teleportFacing(stand, if probe.facing then at else stand + Vector3.new(probe.offset, 0, 0))
			local hopBefore = stray.model:GetAttribute("HopAt")
			local startedAt = os.clock()
			fire("SwingNet")
			local answer = swingAnswer(startedAt, 1.5)
			task.wait(0.3)
			if answer == nil then
				verdict = downgrade(verdict, "CHECK")
				table.insert(notes, probe.name .. ": no NetSwung (refused? read the server output)")
			elseif answer.name == "CatchSchedule" then
				outcomeOf(startedAt, tostring(answer.id), answer.data :: Schedule)
				teleportTo(home)
				return "FAIL",
					string.format(
						"a swing %s started a catch on %s",
						probe.name,
						tostring(answer.id)
					)
			else
				local hopped = stray.model:GetAttribute("HopAt") ~= hopBefore
				local text = probe.name .. ": hit nothing"
				if probe.near and not hopped then
					-- right before the first catch, and for a cat up on a perch
					verdict = downgrade(verdict, "CHECK")
					text ..= ", but the stray did not hop (expected unless I have caught no cat yet or it is perched)"
				elseif not probe.near and hopped then
					verdict = downgrade(verdict, "FAIL")
					text ..= ", but the stray hopped from a swing 200 studs off"
				elseif hopped then
					text ..= ", it hopped"
				end
				table.insert(notes, text)
			end
		end
		teleportTo(home)
		return verdict, table.concat(notes, "; ")
	end
)

case(
	"pressWithoutBegin",
	Enum.KeyCode.Three,
	"Press without begin: CatchPress on a stray nobody is catching",
	function()
		local stray = nearestStray()
		if stray == nil then
			return "SKIP", NO_STRAY
		end
		standNextTo(stray)
		local startedAt = os.clock()
		fire("CatchPress", stray.id, 1)
		fire("CatchPress", stray.id, 2)
		task.wait(1)
		local reactions = #since(startedAt, "GrabResult")
			+ #since(startedAt, "CatchSchedule")
			+ #since(startedAt, "CatchResult")
		if reactions == 0 then
			return "PASS", "ignored, no catch started or scored"
		end
		return "FAIL", string.format("%d reaction(s) to a press with no catch running", reactions)
	end
)

case(
	"badPresses",
	Enum.KeyCode.Four,
	"Bad presses: bad indexes, out of order, early and repeated; the on-target presses must still catch it",
	function()
		if not checkInIfCarrying() then
			return "SKIP", "carrying a cat that could not be checked in"
		end
		local stray = nearestStray()
		if stray == nil then
			return "SKIP", NO_STRAY
		end
		local schedule, why, startedAt = beginCatch(stray)
		if schedule == nil then
			return "CHECK", why
		end
		local notes = {}
		-- Dropped by Guard.int before the attempt is read: outside 1 to 5, not whole, not a number. CatchPress
		-- allows 10 calls a second, so this burst and the next stay under the limit and every call reaches Guard.
		fire("CatchPress", stray.id, 0)
		fire("CatchPress", stray.id, 99)
		fire("CatchPress", stray.id, -1)
		fire("CatchPress", stray.id, 1.5)
		fire("CatchPress", stray.id, 0 / 0)
		fire("CatchPress", stray.id, "1")
		fire("CatchPress", stray.id, {})
		fire("CatchPress", stray.id, nil)
		task.wait(0.25)
		-- Out of order (circle 2 before circle 1 is judged), then circle 1 before it starts: both ignored, neither
		-- a Miss.
		local first = schedule.circles[1]
		if serverNow() < first.startsAt - 0.1 then
			fire("CatchPress", stray.id, 2)
			fire("CatchPress", stray.id, 1)
		else
			table.insert(notes, "early presses skipped: circle 1 had already started")
		end
		-- Every circle pressed on target. Before each later one, the previous index again once this circle is open:
		-- had the server counted that repeat here, this circle would be a Miss and the catch would end.
		for index, circle in schedule.circles do
			if index > 1 then
				waitUntilServer(circle.startsAt + 0.15)
				fire("CatchPress", stray.id, index - 1)
			end
			pressOnTarget(stray.id, index, circle)
		end
		fire("CatchPress", stray.id, #schedule.circles) -- after the last circle: nothing left to judge
		local outcome = outcomeOf(startedAt, stray.id, schedule)
		task.wait(0.3)
		local results = countAbout(startedAt, "CatchResult", stray.id)
		checkInIfCarrying()
		if outcome == nil then
			return "FAIL", "no CatchResult after every circle was pressed"
		end
		if results ~= 1 then
			return "FAIL", string.format("%d CatchResults for one catch", results)
		end
		if not allGraded(outcome, #schedule.circles) or not outcome.success then
			return "FAIL",
				string.format(
					"grades %s, success=%s for %d circles pressed on target: a bad, early or repeated press was counted, or an on-target press missed (read the [Catch] lines)",
					gradesText(outcome.grades),
					tostring(outcome.success),
					#schedule.circles
				)
		end
		local text = string.format(
			"every on-target press graded %s and it was caught (charmGain %d); the bad, early and repeated presses counted for nothing",
			gradesText(outcome.grades),
			outcome.charmGain
		)
		if #notes > 0 then
			return "CHECK", text .. " (" .. table.concat(notes, "; ") .. ")"
		end
		return "PASS", text
	end
)

case(
	"pressWithTime",
	Enum.KeyCode.Five,
	'Press with a time: an early CatchPress(id, 1, target, "perfect")',
	function()
		if not checkInIfCarrying() then
			return "SKIP", "carrying a cat that could not be checked in"
		end
		local stray = nearestStray()
		if stray == nil then
			return "SKIP", NO_STRAY
		end
		local schedule, why, startedAt = beginCatch(stray)
		if schedule == nil then
			return "CHECK", why
		end
		local first = schedule.circles[1]
		local target = targetOf(first)
		-- Circle 1 has started, so the server judges this press, and on its own clock it is most of a shrink early.
		waitUntilServer(first.startsAt + 0.15)
		local early = target - serverNow()
		fire("CatchPress", stray.id, 1, target, "perfect", Config.CircleScorePerfect)
		local outcome = outcomeOf(startedAt, stray.id, schedule)
		checkInIfCarrying()
		if outcome == nil then
			return "FAIL", "no CatchResult"
		end
		if outcome.grades[1] ~= "miss" or outcome.success then
			return "FAIL",
				string.format(
					"circle 1 graded %s, success=%s from a press %.2f s early: the server used the time or grade the client sent",
					tostring(outcome.grades[1]),
					tostring(outcome.success),
					early
				)
		end
		if #outcome.grades > 1 then
			return "FAIL", "the catch went on after the Miss: grades " .. gradesText(outcome.grades)
		end
		return "PASS",
			string.format(
				"circle 1 was a Miss on the server's clock (%.2f s early) and ended the catch; the time and grade sent with it were ignored",
				early
			)
	end
)

case("noPress", Enum.KeyCode.Six, "No press: swing and never press", function()
	if not checkInIfCarrying() then
		return "SKIP", "carrying a cat that could not be checked in"
	end
	local stray = nearestStray()
	if stray == nil then
		return "SKIP", NO_STRAY
	end
	local schedule, why, startedAt = beginCatch(stray)
	if schedule == nil then
		return "CHECK", why
	end
	local from = stray.model:GetPivot().Position
	local outcome, event = outcomeOf(startedAt, stray.id, schedule)
	if outcome == nil or event == nil then
		return "FAIL",
			"no CatchResult: an unpressed circle must be a Miss at its deadline and end the catch"
	end
	-- v0.4: circle 1's deadline (target + good + latency cap) ends the catch; the server checks just after it.
	local deadline = targetOf(schedule.circles[1])
		+ schedule.windows.good
		+ Config.CatchLatencyCapSeconds
	local offBy = event.server - deadline
	local running = fleeAfterMiss(stray.model)
	-- v0.5: the sprint runs at StrayFleeSpeed; measure once it has stopped, before it wanders again (N52)
	task.wait(math.max(0.7, running - Config.StrayRestSeconds + 0.1))
	if stray.model.Parent == nil then
		return "FAIL", "the stray despawned after a miss; it stays and runs off (v0.5)"
	end
	local lockedBy = stray.model:GetAttribute("LockedBy")
	if lockedBy ~= nil and lockedBy ~= 0 then
		return "FAIL",
			string.format("the stray is still locked by %s after the result", tostring(lockedBy))
	end
	if outcome.success or #outcome.grades ~= 1 or outcome.grades[1] ~= "miss" then
		return "FAIL",
			string.format(
				"grades %s, success=%s; expected { miss } and no catch",
				gradesText(outcome.grades),
				tostring(outcome.success)
			)
	end
	local verdict: Verdict = "PASS"
	local notes = {}
	-- v0.5: the miss sets FleeingUntil, the sprint plus the breather, so nobody can grab it while it runs.
	if running <= 0 then
		verdict = "FAIL"
		table.insert(notes, "no FleeingUntil in the future after the miss")
	else
		table.insert(notes, string.format("running for %.1f s", running))
	end
	if outcome.charmGain ~= 0 then
		verdict = "FAIL"
		table.insert(notes, string.format("charmGain %d on a miss", outcome.charmGain))
	end
	local ran = horizontal(stray.model:GetPivot().Position, from)
	local fleeStuds = Catalog.rarities[stray.rarity].fleeStuds
	if ran < 2 or ran > fleeStuds + 2 then
		verdict = downgrade(verdict, "CHECK")
		table.insert(
			notes,
			string.format(
				"it ran %.1f studs, expected up to %d (less is right at an area edge or a prop)",
				ran,
				fleeStuds
			)
		)
	else
		table.insert(notes, string.format("ran %.1f of %d studs", ran, fleeStuds))
	end
	table.insert(notes, string.format("resolved %+.2f s from circle 1's deadline", offBy))
	if offBy < -0.1 or offBy > 0.5 then
		verdict = downgrade(verdict, "CHECK")
		table.insert(notes, "expected within -0.10 to +0.50 s")
	end
	return verdict,
		string.format("%s %s: ", stray.rarity, gradesText(outcome.grades)) .. table.concat(
			notes,
			"; "
		)
end)

-- Perfect circles in a row that perfectFarm pressed this session. The server flags autoPress once the last 50
-- judged circles are over 95% Perfect, so from 50 in a row a Purrfect catch must earn no charm (v0.4).
local perfectStreak = 0

case(
	"perfectFarm",
	Enum.KeyCode.Seven,
	"Scripted perfect: 10 catches that press every circle on its target",
	function()
		local catches, caught, circles, perfect = 0, 0, 0, 0
		local gains = {}
		local problems = {}
		local stop: string? = nil
		for _ = 1, 10 do
			if not checkInIfCarrying() then
				stop = "carrying a cat that could not be checked in"
				break
			end
			local stray = nearestStray()
			if stray == nil then
				break
			end
			local schedule, why, startedAt = beginCatch(stray)
			if schedule == nil then
				stop = why
				break
			end
			catches += 1
			local streakBefore = perfectStreak
			for index, circle in schedule.circles do
				pressOnTarget(stray.id, index, circle)
			end
			local outcome = outcomeOf(startedAt, stray.id, schedule)
			if outcome == nil then
				return "FAIL", "no CatchResult after every circle was pressed on target"
			end
			circles += #outcome.grades
			local purrfect = #outcome.grades == #schedule.circles
			for _, grade in outcome.grades do
				if grade == "perfect" then
					perfect += 1
				else
					purrfect = false
				end
			end
			if outcome.success then
				caught += 1
			end
			if not allGraded(outcome, #schedule.circles) or not outcome.success then
				table.insert(
					problems,
					string.format(
						"%s %s not caught, though every circle was pressed on target",
						stray.rarity,
						gradesText(outcome.grades)
					)
				)
			end
			table.insert(gains, tostring(outcome.charmGain))
			if purrfect then
				if streakBefore >= Circles.AUTO_PRESS_WINDOW and outcome.charmGain > 0 then
					table.insert(
						problems,
						string.format(
							"charmGain %d after %d Perfect circles in a row: the autoPress flag must zero it",
							outcome.charmGain,
							streakBefore
						)
					)
				end
				perfectStreak += #outcome.grades
			else
				perfectStreak = 0
			end
		end
		checkInIfCarrying()
		if catches == 0 then
			return "SKIP", stop or NO_STRAY
		end
		local text = string.format(
			"%d of %d caught, %d of %d circles Perfect, charmGain per catch {%s}%s. %d Perfect circles in a row this session; "
				.. 'the server warns "[CatService] autopress_flag set for <userId>" once the last 50 are over 95%%, and from then '
				.. "every charmGain must be 0%s",
			caught,
			catches,
			perfect,
			circles,
			table.concat(gains, ", "),
			if stop ~= nil then " (stopped early: " .. stop .. ")" else "",
			perfectStreak,
			if perfectStreak >= Circles.AUTO_PRESS_WINDOW
				then "; look for the warn line in the server output now"
				else "; run this case again until the count passes 50"
		)
		if #problems > 0 then
			return "FAIL", table.concat(problems, "; ") .. ". " .. text
		end
		-- Accepted by design: a script that presses on time catches every cat; the flag only takes the charm away.
		return "CHECK", text
	end
)

case(
	"farPress",
	Enum.KeyCode.Eight,
	"Far press: start in range, teleport 200 studs away, press every circle on target",
	function()
		if not checkInIfCarrying() then
			return "SKIP", "carrying a cat that could not be checked in"
		end
		local stray = nearestStray()
		if stray == nil then
			return "SKIP", NO_STRAY
		end
		local root = rootPart()
		if root == nil then
			return "SKIP", "no character"
		end
		local home = root.Position
		local schedule, why, startedAt = beginCatch(stray)
		if schedule == nil then
			return "CHECK", why
		end
		teleportTo(stray.model:GetPivot().Position + Vector3.new(200, 0, 0))
		for index, circle in schedule.circles do
			pressOnTarget(stray.id, index, circle)
		end
		local outcome = outcomeOf(startedAt, stray.id, schedule)
		task.wait(0.3)
		local tooFar = toasted(startedAt, "Too far")
		teleportTo(home)
		checkInIfCarrying()
		if outcome == nil then
			return "FAIL", "no CatchResult"
		end
		if outcome.success then
			return "FAIL", "caught from 200 studs away: " .. gradesText(outcome.grades)
		end
		-- Walking out of range is a Miss (reviewer S33), so the stray runs off like after any other (v0.5).
		local text = string.format("not caught, grades %s", gradesText(outcome.grades))
		if stray.model.Parent ~= nil and fleeLeft(stray.model) <= 0 then
			return "FAIL", text .. ": walking away must send the stray running like a Miss"
		end
		if not tooFar then
			return "CHECK", text .. ", but no Too far away toast; read the server output"
		end
		return "PASS", "forfeit as a Miss: " .. text .. ", toast Too far away"
	end
)

case(
	"secondSwing",
	Enum.KeyCode.LeftBracket,
	"Second swing: at once and after 2 s while a catch runs; neither lands, nothing restarts, one CatchResult",
	function()
		if not checkInIfCarrying() then
			return "SKIP", "carrying a cat that could not be checked in"
		end
		local notes = {}
		local verdict: Verdict = "PASS"
		-- F93: a player in a catch cannot swing (NetSwing.refusal "busy"), so neither swing gets a NetSwung, the
		-- circles never restart and no other stray starts a catch. The circles are pressed on target in the
		-- background, since an unpressed circle would end the catch at its deadline (v0.4).
		local stray = nearestStray(longCatch) or nearestStray()
		if stray == nil then
			return "SKIP", NO_STRAY
		end
		local schedule, why, startedAt = beginCatch(stray)
		if schedule == nil then
			return "CHECK", why
		end
		pressAllOnTarget(stray.id, schedule)
		task.wait(0.3) -- the catch's own NetSwung has come
		local midAt = os.clock()
		fire("SwingNet")
		task.wait(math.max(0, startedAt + Config.GrabCooldownSeconds + 0.15 - os.clock()))
		if serverNow() > endsAt(schedule) - 0.3 then
			verdict = downgrade(verdict, "CHECK")
			table.insert(notes, "the swing after 2 s skipped: the catch ended inside 2 s; " .. NO_LONG_STRAY)
		else
			fire("SwingNet")
		end
		outcomeOf(startedAt, stray.id, schedule)
		task.wait(0.3)
		local swung = #swungSince(midAt)
		local schedules = #since(midAt, "CatchSchedule")
		local results = countAbout(startedAt, "CatchResult", stray.id)
		if schedules > 0 then
			verdict = downgrade(verdict, "FAIL")
			table.insert(notes, string.format("%d CatchSchedule(s) from swings during the catch", schedules))
		end
		if swung > 0 then
			verdict = downgrade(verdict, "FAIL")
			table.insert(notes, string.format("%d swing(s) during the catch landed (NetSwung)", swung))
		else
			table.insert(notes, "swings during the catch: no NetSwung, refused")
		end
		if results ~= 1 then
			verdict = downgrade(verdict, "FAIL")
			table.insert(notes, string.format("%d CatchResults for one catch", results))
		end
		checkInIfCarrying()
		return verdict, table.concat(notes, "; ")
	end
)

case(
	"retry",
	Enum.KeyCode.Semicolon,
	"Retry: miss a Common, swing at it while it runs; miss it again, swing at it in my extra second; then catch it",
	function()
		if not checkInIfCarrying() then
			return "SKIP", "carrying a cat that could not be checked in"
		end
		local stray = nearestStray(function(info)
			return info.rarity == "Common"
		end)
		if stray == nil then
			return "SKIP",
				string.format('no free Common nearby; %s("spawnStray", "tabby") and rerun', DEBUG)
		end
		-- v0.5 (F40, S44): after a miss the stray runs and rests until FleeingUntil, and the player who missed waits
		-- StraySelfRetrySeconds more. F93: a swing at a running stray lands on nothing (NetSwung hit=false, no toast);
		-- one in my extra second lands and is refused with "Catch your breath". Catch starts are 2 s apart, too few
		-- for both checks after one miss, so the running check follows miss 1 and the extra-second check miss 2.
		local notes = {}
		local verdict: Verdict = "PASS"
		for round = 1, 2 do
			local schedule, why, startedAt = beginCatch(stray)
			if schedule == nil then
				if round == 1 then
					return "CHECK", why
				end
				return "FAIL",
					table.concat(notes, "; ") .. "; miss 2 after my extra second: " .. why
			end
			missOnPurpose(stray.id, schedule)
			local outcome = outcomeOf(startedAt, stray.id, schedule)
			if outcome == nil then
				return "FAIL", string.format("no CatchResult for miss %d", round)
			end
			if outcome.success then
				checkInIfCarrying()
				return "FAIL", "an early press on the only circle still caught the cat"
			end
			if stray.model.Parent == nil then
				return "FAIL", "the Common despawned after a miss"
			end
			-- The stray stands still while it catches its breath, so stand by it and wait out the swing spacing.
			waitForSprint(stray.model)
			standNextTo(stray)
			swingReady()
			local probe: string
			if round == 1 then
				probe = "while it ran"
			else
				probe = "in my extra second"
				task.wait(fleeLeft(stray.model) + 0.1)
			end
			local window = if round == 1
				then fleeLeft(stray.model)
				else (stray.model:GetAttribute("FleeingUntil") :: number? or 0)
					+ Config.StraySelfRetrySeconds
					- serverNow()
			if window < 0.2 then
				verdict = downgrade(verdict, "CHECK")
				table.insert(notes, probe .. ": skipped, too little of the window left to probe")
			else
				local probeAt = os.clock()
				fire("SwingNet")
				local answer = swingAnswer(probeAt, 1.5)
				local expected = if round == 1 then "hit=false" else "Catch your breath"
				if answer ~= nil and answer.name == "CatchSchedule" and answer.id ~= stray.id then
					outcomeOf(probeAt, tostring(answer.id), answer.data)
					verdict = downgrade(verdict, "CHECK")
					table.insert(notes, probe .. ": the swing landed on another stray nearby, so not probed")
				elseif answer ~= nil and answer.name == "CatchSchedule" then
					outcomeOf(probeAt, stray.id, answer.data)
					return "FAIL",
						string.format(
							"a new catch started %s (%.1f s of the window left)",
							probe,
							window
						)
				elseif answer ~= nil and string.find(answer.text, expected, 1, true) ~= nil then
					table.insert(
						notes,
						string.format("%s (%.1f s left): %s", probe, window, answer.text)
					)
				else
					verdict = downgrade(verdict, "CHECK")
					table.insert(
						notes,
						probe .. ": " .. (if answer ~= nil then answer.text else "no answer")
					)
				end
			end
			-- Then I may try again, as often as I like.
			task.wait(fleeLeft(stray.model) + Config.StraySelfRetrySeconds + 0.2)
		end
		local schedule3, why3, startedAt3 = beginCatch(stray)
		if schedule3 == nil then
			return "FAIL", table.concat(notes, "; ") .. "; after two misses: " .. why3
		end
		for index, circle in schedule3.circles do
			pressOnTarget(stray.id, index, circle)
		end
		local outcome3 = outcomeOf(startedAt3, stray.id, schedule3)
		checkInIfCarrying()
		if outcome3 == nil or not outcome3.success then
			verdict = downgrade(verdict, "FAIL")
			table.insert(notes, "after two misses: pressed on target but not caught")
		else
			table.insert(notes, "after two misses: a new schedule, caught on target")
		end
		return verdict, table.concat(notes, "; ")
	end
)

case(
	"pressSpam",
	Enum.KeyCode.Quote,
	"Press spam: CatchPress every 0.1 s from the swing, moving on once a circle has started",
	function()
		if not checkInIfCarrying() then
			return "SKIP", "carrying a cat that could not be checked in"
		end
		local stray = nearestStray()
		if stray == nil then
			return "SKIP", NO_STRAY
		end
		local schedule, why, startedAt = beginCatch(stray)
		if schedule == nil then
			return "CHECK", why
		end
		local index, sent = 1, 0
		local stopAt = endsAt(schedule) + 0.5
		-- Quiet on purpose: one log line for the burst, not one per call. It stops once the catch has ended.
		while
			index <= #schedule.circles
			and serverNow() < stopAt
			and countAbout(startedAt, "CatchResult", stray.id) == 0
		do
			Remotes.event("CatchPress"):FireServer(stray.id, index)
			sent += 1
			if serverNow() > schedule.circles[index].startsAt then
				index += 1
			end
			task.wait(0.1)
		end
		log(string.format("    -> CatchPress(%q, i) x%d, one every 0.1 s", stray.id, sent))
		local outcome = outcomeOf(startedAt, stray.id, schedule)
		checkInIfCarrying()
		if outcome == nil then
			return "FAIL", "no CatchResult"
		end
		-- The first press after circle 1 starts is most of a shrink early: a Miss that ends the catch (v0.4).
		if outcome.success or #outcome.grades ~= 1 or outcome.grades[1] ~= "miss" then
			return "FAIL",
				string.format(
					"mashing gave grades %s, success=%s; expected { miss } and the catch over",
					gradesText(outcome.grades),
					tostring(outcome.success)
				)
		end
		return "PASS",
			string.format(
				"%d presses; circle 1 was graded from the first press after it started, a Miss that ended the catch",
				sent
			)
	end
)

case(
	"unlimitedTries",
	Enum.KeyCode.Period,
	"Unlimited tries: miss one stray three times, each after it stops running; every swing starts a catch",
	function()
		if not checkInIfCarrying() then
			return "SKIP", "carrying a cat that could not be checked in"
		end
		-- v0.5 (F40): no paws. A Legendary or Mythical ran out after one miss in v0.4, so they show it best.
		local stray = nearestStray(function(info)
			return info.rarity == "Legendary" or info.rarity == "Mythical"
		end) or nearestStray()
		if stray == nil then
			return "SKIP",
				string.format('%s; or %s("spawnStray", "void") for a Legendary', NO_STRAY, DEBUG)
		end
		local misses = 0
		for _ = 1, 3 do
			local schedule, why, startedAt = beginCatch(stray)
			if schedule == nil then
				return "FAIL", string.format("after %d miss(es): %s", misses, why)
			end
			missOnPurpose(stray.id, schedule)
			local outcome = outcomeOf(startedAt, stray.id, schedule)
			if outcome == nil then
				return "FAIL", "no CatchResult for a Miss"
			end
			if outcome.success then
				checkInIfCarrying()
				return "FAIL", "an early press still caught the cat"
			end
			misses += 1
			if stray.model.Parent == nil then
				return "FAIL", string.format("the stray despawned after %d miss(es)", misses)
			end
			task.wait(fleeAfterMiss(stray.model) + Config.StraySelfRetrySeconds + 0.2)
		end
		local schedule, why, startedAt = beginCatch(stray)
		if schedule == nil then
			return "FAIL", string.format("after %d misses: %s", misses, why)
		end
		outcomeOf(startedAt, stray.id, schedule)
		-- The v0.4 paw attributes went with the paws.
		local leftover = {}
		for _, name in { "Patience", "Paws_" .. player.UserId } do
			if stray.model:GetAttribute(name) ~= nil then
				table.insert(leftover, name)
			end
		end
		if #leftover > 0 then
			return "FAIL",
				"v0.4 paw attributes still on the stray: " .. table.concat(leftover, ", ")
		end
		return "PASS",
			string.format(
				"%s: %d misses and a fourth catch still started; no paws, no trust lost",
				stray.rarity,
				misses
			)
	end
)

-- The nearest camp's landing pad (F84): a camp is a safe zone, where a swing is refused.
local function campPad(): BasePart?
	local root = rootPart()
	local origin = if root ~= nil then root.Position else Vector3.zero
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, instance in Workspace:GetDescendants() do
		if instance.Name == "LandingPad" and instance:IsA("BasePart") then
			local pad = instance :: BasePart
			local distance = (pad.Position - origin).Magnitude
			if distance < bestDistance then
				best, bestDistance = pad, distance
			end
		end
	end
	return best
end

case(
	"swingFlood",
	Enum.KeyCode.I,
	"Swing flood: 10 SwingNet in a frame, one every 0.2 s for 3 s with junk arguments at my door, one in a camp",
	function()
		if not checkInIfCarrying() then
			return "SKIP", "carrying a cat that could not be checked in"
		end
		local door = ownDoor()
		if door == nil then
			return "SKIP", "no own door found (no plot yet?)"
		end
		local root = rootPart()
		local home = if root ~= nil then root.Position else door.Position
		local notes = {}
		local verdict: Verdict = "PASS"
		-- In town, where no stray is: every swing that lands hits nothing. The server keeps NetSwingCooldown (0.8 s,
		-- less 0.1 of slack) between a player's swings and its limiter takes 3 a second, so ten in a frame land once.
		teleportTo(door.Position + Vector3.new(0, 0, 6))
		swingReady()
		local burstAt = os.clock()
		for _ = 1, 10 do
			Remotes.event("SwingNet"):FireServer()
		end
		lastSwingAt = os.clock()
		log("    -> SwingNet() x10 in one frame")
		task.wait(1)
		local burst = #swungSince(burstAt)
		if burst ~= 1 then
			verdict = downgrade(verdict, if burst > 1 then "FAIL" else "CHECK")
		end
		table.insert(notes, string.format("ten in one frame: %d landed", burst))

		-- One every 0.2 s for 3 s, every other one with a junk argument: at most one lands per 0.7 s.
		local junk: { any } = { "x", 1e9, 0 / 0, {}, true, string.rep("a", 300), Vector3.zero }
		local streamAt = os.clock()
		local sent = 0
		while os.clock() < streamAt + 3 do
			sent += 1
			if sent % 2 == 0 then
				Remotes.event("SwingNet"):FireServer(junk[(sent // 2 - 1) % #junk + 1])
			else
				Remotes.event("SwingNet"):FireServer()
			end
			task.wait(0.2)
		end
		lastSwingAt = os.clock()
		log(string.format("    -> SwingNet(...) x%d, one every 0.2 s, junk in every other", sent))
		task.wait(0.5)
		local stream = swungSince(streamAt)
		local most = 1 + math.ceil(3 / (Config.NetSwingCooldown - NetSwing.COOLDOWN_SLACK))
		local closest = math.huge
		for index = 2, #stream do
			closest = math.min(closest, stream[index].server - stream[index - 1].server)
		end
		if #stream > most then
			verdict = downgrade(verdict, "FAIL")
		elseif #stream == 0 then
			verdict = downgrade(verdict, "CHECK")
		end
		if closest < Config.NetSwingCooldown - NetSwing.COOLDOWN_SLACK - 0.15 then
			verdict = downgrade(verdict, "FAIL")
		end
		table.insert(
			notes,
			string.format(
				"%d over 3 s: %d landed (at most %d), the closest two %s apart",
				sent,
				#stream,
				most,
				if closest == math.huge then "-" else string.format("%.2f s", closest)
			)
		)

		-- In a camp, a safe zone: refused, no NetSwung.
		local pad = campPad()
		if pad == nil then
			verdict = downgrade(verdict, "CHECK")
			table.insert(notes, "camp swing skipped: no LandingPad in the world (a build before F84)")
		else
			teleportTo(pad.Position)
			swingReady()
			local campAt = os.clock()
			fire("SwingNet")
			task.wait(1)
			if #swungSince(campAt) > 0 then
				verdict = downgrade(verdict, "FAIL")
				table.insert(notes, "a swing in a camp landed")
			else
				table.insert(notes, "a swing in a camp: refused")
			end
		end
		teleportTo(home)
		return verdict,
			table.concat(notes, "; ")
				.. ". Read the server output: a [Net] SwingNet handler failed line is a major."
				.. " A swing in a flight is S62's, by hand"
	end
)

case(
	"badIds",
	Enum.KeyCode.Nine,
	"Bad ids: malformed values, then well-formed ids that do not exist",
	function()
		if state == nil then
			return "SKIP", "no ProfileSync yet"
		end
		local before = freshWallet()
		-- Malformed: wrong type, bad pattern or too long. Guard drops each one before the handler reads the profile.
		local malformedAt = os.clock()
		fire("BuyUpgrade", string.rep("a", Config.MaxIdLength + 1))
		fire("BuyUpgrade", 123)
		fire("BuyUpgrade", nil)
		fire("BuyUpgrade", {})
		fire("BuyUpgrade", true)
		fire("BuyDecor", "Neon Sign")
		fire("PlaceCat", 123, "waiter_1")
		fire("ToggleDecor", "plants", "yes")
		fire("UseLure", 7)
		fire("ResolveBait", "keep")
		fire("TutorialAdvance", "two")
		task.wait(1.2) -- TutorialAdvance allows 1 call per second; wait out the bucket so Guard.int's range check runs
		fire("TutorialAdvance", 1e9)
		task.wait(1)
		local malformedToasts = {}
		for _, event in since(malformedAt, "Toast") do
			table.insert(malformedToasts, event.text)
		end
		-- Well formed but unknown: the server may refuse with a warn toast, since every refused action says why.
		-- A good toast or a new entry in the profile would be a purchase.
		local unknownAt = os.clock()
		local baitBefore = if state.bait ~= nil then state.bait.lureId else "empty"
		fire("BuyUpgrade", "jetpack")
		fire("BuyDecor", "jetpack")
		fire("UseLure", "jetpack")
		task.wait(1.5)
		local unknownToasts = {}
		local baitAfter = if state.bait ~= nil then state.bait.lureId else "empty"
		local bought = state.upgradeLevels["jetpack"] ~= nil
			or state.decorOwned["jetpack"] ~= nil
			or state.lures["jetpack"] ~= nil
			or baitAfter ~= baitBefore
		for _, event in since(unknownAt, "Toast") do
			table.insert(unknownToasts, event.text)
			if string.find(event.text, "[good]", 1, true) ~= nil then
				bought = true
			end
		end
		local coinsOk, coinsText = coinsMovedBy(before, 0)
		if not coinsOk then
			return "FAIL", coinsText .. " on bad input"
		end
		if #malformedToasts > 0 then
			return "FAIL",
				"malformed input got a toast, so it reached the handler: " .. table.concat(
					malformedToasts,
					" | "
				)
		end
		if bought then
			return "FAIL", "an unknown id was bought: " .. table.concat(unknownToasts, " | ")
		end
		return "CHECK",
			string.format(
				"%s; malformed: no toast; unknown ids: %s. Now read the server output: a [Net] ... handler failed line is a major",
				coinsText,
				if #unknownToasts > 0 then table.concat(unknownToasts, " | ") else "no toast"
			)
	end
)

case(
	"shop",
	Enum.KeyCode.Zero,
	"Shop gates and unaffordable: Tier 2 and 3 buys and a Tier 2 slot at Tier 1, tables with no coins",
	function()
		if state == nil then
			return "SKIP", "no ProfileSync yet"
		end
		local before = freshWallet()
		local startedAt = os.clock()
		local notes = {}
		-- What a buy or placement would change, read from the state instead of toast wording.
		local function owned(now: Types.PlayerState): string
			local onLocked = false
			for _, view in now.cats do
				onLocked = onLocked or view.spotId == "waiter_2"
			end
			return string.format(
				"tier %d, tables %d, net %d, plants %s, neon_sign %s, waiter_2 %s",
				now.tier,
				now.upgradeLevels["tables"] or 0,
				now.upgradeLevels["net"] or 0,
				tostring(now.decorOwned["plants"] == true),
				tostring(now.decorOwned["neon_sign"] == true),
				if onLocked then "taken" else "free"
			)
		end
		local ownedBefore = owned(state)
		-- Tier 1 (data-model 5b): plants need Tier 2, the neon sign Tier 3, net level 2 Tier 2, waiter_2 opens at Tier 2.
		if state.tier == 1 then
			fire("BuyDecor", "plants")
			fire("BuyDecor", "neon_sign")
			if (state.upgradeLevels["net"] or 0) == 1 then
				fire("BuyUpgrade", "net")
			else
				table.insert(notes, "net cap skipped: net is not at level 1")
			end
			local anyUid: string? = nil
			for uid in state.cats do
				anyUid = uid
				break
			end
			if anyUid ~= nil then
				fire("PlaceCat", anyUid, "waiter_2")
			end
		else
			table.insert(
				notes,
				string.format(
					'gates skipped: tier is %d, not 1; run %s("setTier", nil, 1) and rerun',
					state.tier,
					DEBUG
				)
			)
		end
		local tables = Catalog.getUpgrade("tables")
		local nextCost = if tables ~= nil
			then tables.costs[(state.upgradeLevels["tables"] or 0) + 1]
			else nil
		-- Unaffordable even after a few seconds of income, so a correct server cannot sell it before the call lands.
		if nextCost ~= nil and before.money + before.rate * 3 + 1 < nextCost then
			fire("BuyUpgrade", "tables")
		else
			table.insert(
				notes,
				string.format(
					'unaffordable skipped: tables is affordable; on the server run %s("setCoins", nil, 0) and rerun',
					DEBUG
				)
			)
		end
		task.wait(1.5)
		local coinsOk, coinsText = coinsMovedBy(before, 0)
		if not coinsOk then
			return "FAIL", coinsText
		end
		local ownedAfter = owned(state)
		if ownedAfter ~= ownedBefore then
			return "FAIL",
				string.format(
					"a gated or unaffordable buy went through: %s became %s",
					ownedBefore,
					ownedAfter
				)
		end
		local seen = {}
		for _, event in since(startedAt, "Toast") do
			table.insert(seen, event.text)
		end
		local verdict: Verdict = if #seen > 0 then "PASS" else "CHECK"
		return verdict,
			string.format(
				"%s; toasts: %s%s",
				coinsText,
				if #seen > 0 then table.concat(seen, " | ") else "none",
				if #notes > 0 then " (" .. table.concat(notes, "; ") .. ")" else ""
			)
	end
)

case(
	"ownership",
	Enum.KeyCode.Minus,
	"Ownership: place, sell and unplace a cat uid that is not mine",
	function()
		if state == nil then
			return "SKIP", "no ProfileSync yet"
		end
		local before, cats = freshWallet(), catCount()
		local startedAt = os.clock()
		fire("PlaceCat", "not_my_cat", "waiter_1")
		fire("SellCat", "not_my_cat")
		fire("UnplaceCat", "not_my_cat")
		task.wait(1.5)
		local coinsOk, coinsText = coinsMovedBy(before, 0)
		if not coinsOk or catCount() ~= cats then
			return "FAIL", string.format("%s, cats %d -> %d", coinsText, cats, catCount())
		end
		if #since(startedAt, "Toast") > 0 then
			return "FAIL", "the server answered a uid that is not mine"
		end
		return "PASS", string.format("ignored, no toast, cats unchanged, %s", coinsText)
	end
)

-- F62 (engineer PR #493): a locked cat cannot be sold; LockCat takes only the player's own uid and a boolean.
case(
	"catLock",
	Enum.KeyCode.RightBracket,
	"Cat lock: lock a resting cat, SellCat it, LockCat junk and another uid, then unlock (F62)",
	function()
		if state == nil then
			return "SKIP", "no ProfileSync yet"
		end
		local uid: string? = nil
		for candidate, instance in state.cats do
			if instance.spotId == nil and instance.locked ~= true then
				uid = candidate
				break
			end
		end
		if uid == nil or catCount() < 2 then
			return "SKIP",
				string.format('needs a resting, unlocked cat and one more; on the server run %s("giveCat", nil, "tabby")', DEBUG)
		end
		local id = uid :: string
		local function locked(): boolean?
			local instance = if state ~= nil then state.cats[id] else nil
			return if instance ~= nil then instance.locked == true else nil
		end
		local startedAt = os.clock()
		fire("LockCat", id, true)
		task.wait(1.2)
		if locked() ~= true then
			return "FAIL", "LockCat(uid, true) did not lock my own resting cat"
		end
		local before, cats = freshWallet(), catCount()
		local sellAt = os.clock()
		fire("SellCat", id)
		task.wait(1.5)
		local coinsOk, coinsText = coinsMovedBy(before, 0)
		if catCount() ~= cats or locked() == nil or not coinsOk then
			return "FAIL", string.format("a locked cat was sold: %s, cats %d -> %d", coinsText, cats, catCount())
		end
		local notes = { "SellCat refused" .. (if toasted(sellAt, "locked") then " with the locked toast" else "") }
		-- junk, 0.3 s apart so the 4 a second limit drops none: the cat stays locked and nobody answers
		local junkAt = os.clock()
		for _, args in { { id, "no" }, { id, 0 }, { id, nil }, { "not_my_cat", false }, { 5, false } } do
			fire("LockCat", args[1], args[2])
			task.wait(0.3)
		end
		task.wait(1)
		if locked() ~= true then
			return "FAIL", "a junk LockCat unlocked the cat"
		end
		if #since(junkAt, "Toast") > 0 then
			table.insert(notes, "a junk LockCat got a toast (CHECK)")
		end
		fire("LockCat", id, false)
		task.wait(1.2)
		if locked() ~= false then
			return "FAIL", "LockCat(uid, false) did not unlock it again"
		end
		table.insert(notes, "junk ignored, unlocked again")
		local verdict: Verdict = if toasted(sellAt, "locked") then "PASS" else "CHECK"
		return verdict, table.concat(notes, "; ") .. string.format(" (%s, run %.1f s)", coinsText, os.clock() - startedAt)
	end
)

case(
	"doubleSpend",
	Enum.KeyCode.Equals,
	"Double spend: SellCat twice in one frame, ClaimOffline twice 2 s apart",
	function()
		if state == nil then
			return "SKIP", "no ProfileSync yet"
		end
		local notes = {}
		local verdict: Verdict = "PASS"
		if catCount() >= 2 then
			local uid: string? = nil
			local value = 0
			for candidate, instance in state.cats do
				local def = Catalog.getCat(instance.catId)
				-- F62: a locked cat is never sold, so this case takes an unlocked one
				if def ~= nil and instance.locked ~= true and (uid == nil or instance.spotId == nil) then
					uid = candidate
					value = Catalog.rarities[def.rarity].sellValue
				end
			end
			if uid ~= nil then
				local before, cats = freshWallet(), catCount()
				log("    selling one cat on purpose (test profile)")
				fire("SellCat", uid)
				fire("SellCat", uid)
				task.wait(1.5)
				local coinsOk, coinsText = coinsMovedBy(before, value)
				local lost = cats - catCount()
				if coinsOk and lost == 1 then
					table.insert(
						notes,
						string.format(
							"one sale for $%d, second call added nothing (%s)",
							value,
							coinsText
						)
					)
				else
					verdict = "FAIL"
					table.insert(
						notes,
						string.format(
							"sell: %s and %d cat(s) gone for one cat worth $%d",
							coinsText,
							lost,
							value
						)
					)
				end
			end
		else
			table.insert(notes, "sell skipped: fewer than 2 cats")
		end
		-- ClaimOffline allows 1 call per 2 s, so the second call waits out the bucket and reaches the handler, which
		-- must have zeroed the pending amount on the first.
		local startedAt = os.clock()
		fire("ClaimOffline")
		task.wait(2.2)
		fire("ClaimOffline")
		task.wait(1.5)
		local welcomes = 0
		for _, event in since(startedAt, "Toast") do
			if string.find(event.text, "Welcome back", 1, true) then
				welcomes += 1
			end
		end
		if welcomes > 1 then
			verdict = "FAIL"
			table.insert(notes, "offline earnings were paid twice")
		else
			table.insert(notes, string.format("offline paid %d time(s)", welcomes))
		end
		return verdict, table.concat(notes, "; ")
	end
)

-- Fast travel (features F19, reviewer N47) --------------------------------------------------------------------

-- What TravelResult carries.
type Travelled = { ok: boolean, reason: string? }

-- The Travel remote takes 1 call per second, so a case spaces the calls it means to land.
local function travelReady()
	local left = lastTravelAt + 1.15 - os.clock()
	if left > 0 then
		task.wait(left)
	end
end

-- One Travel the limiter lets through: the TravelResult (nil if none came within 1 s) and how far the character
-- moved.
local function travel(destination: any): (Travelled?, number)
	travelReady()
	local root = rootPart()
	local from = if root ~= nil then root.Position else Vector3.zero
	local startedAt = os.clock()
	fire("Travel", destination)
	local event = waitFor(startedAt, "TravelResult", 1)
	task.wait(0.3) -- let a move replicate
	local now = rootPart()
	local moved = if now ~= nil then horizontal(now.Position, from) else 0
	return if event ~= nil then event.data :: Travelled else nil, moved
end

local function add(list: { string }, pattern: string, ...: any)
	table.insert(list, string.format(pattern, ...))
end

-- The area model WorldBuilder made for `id`, read for its floor so a landing can be checked against it.
local function areaFloor(id: string): BasePart?
	for _, instance in Workspace:GetDescendants() do
		if instance:IsA("Model") and instance:GetAttribute("Area") == id then
			local floor = instance:FindFirstChild("Floor")
			return if floor ~= nil and floor:IsA("BasePart") then floor :: BasePart else nil
		end
	end
	return nil
end

case(
	"travel",
	Enum.KeyCode.Comma,
	"Travel: bad ids, a flood, a locked area, while carrying, mid-catch, home, then again inside the cooldown",
	function()
		if state == nil then
			return "SKIP", "no ProfileSync yet"
		end
		if Remotes.folder():FindFirstChild("Travel") == nil then
			return "SKIP", "no Travel remote on this build (features F19)"
		end
		local failures = {}
		local checks = {}
		local notes = {}
		-- A refusal must not move the character; its reason should name why (`expected` is a plain substring).
		local function refused(label: string, result: Travelled?, moved: number, expected: string)
			if moved > 4 then
				add(failures, "%s moved the character %d studs", label, math.floor(moved))
			elseif result == nil then
				table.insert(failures, label .. ": no TravelResult")
			elseif result.ok then
				table.insert(failures, label .. ": TravelResult ok=true")
			elseif string.find(result.reason or "", expected, 1, true) == nil then
				add(
					checks,
					"%s refused with %q, expected %q",
					label,
					tostring(result.reason),
					expected
				)
			else
				add(notes, "%s refused (%s)", label, tostring(result.reason))
			end
		end

		-- 1. Malformed ids: Guard.id drops each one before the handler, so no TravelResult, no toast and no move. The
		-- calls are spaced so every one passes the limiter and reaches Guard.
		local root = rootPart()
		local from = if root ~= nil then root.Position else Vector3.zero
		local malformedAt = os.clock()
		local tooLong = string.rep("a", Config.MaxIdLength + 1)
		local malformed: { any } = { "", "HOME", "../x", 123, {}, true, tooLong }
		for _, bad in malformed do
			travelReady()
			fire("Travel", bad)
		end
		travelReady()
		fire("Travel", nil)
		task.wait(1)
		local after = rootPart()
		local malformedMoved = if after ~= nil then horizontal(after.Position, from) else 0
		local malformedAnswers = #since(malformedAt, "TravelResult") + #since(malformedAt, "Toast")
		if malformedMoved > 4 or malformedAnswers > 0 then
			add(
				failures,
				"malformed ids reached the handler: %d answer(s), moved %d studs",
				malformedAnswers,
				math.floor(malformedMoved)
			)
		else
			table.insert(notes, "malformed ids dropped")
		end

		-- 2. Flood: ten well-formed calls in one frame. The limiter lets one through, which the handler refuses.
		travelReady()
		local floodAt = os.clock()
		for _ = 1, 10 do
			Remotes.event("Travel"):FireServer("moon")
		end
		lastTravelAt = os.clock()
		log('    -> Travel("moon") x10')
		task.wait(1)
		local floodAnswers = #since(floodAt, "TravelResult")
		if floodAnswers > 1 then
			add(failures, "%d TravelResult from 10 calls in one frame", floodAnswers)
		elseif floodAnswers == 0 then
			table.insert(checks, "no TravelResult for the one flood call the limiter lets through")
		else
			table.insert(notes, "flood: one answer from ten calls")
		end

		-- 3. An area this tier has not opened.
		local tier = state.tier
		local locked: Types.AreaDef? = nil
		for _, area in Catalog.areas do
			local nearer = locked == nil or area.tier < (locked :: Types.AreaDef).tier
			if area.tier > tier and nearer then
				locked = area
			end
		end
		if locked ~= nil then
			local result, moved = travel(locked.id)
			local label = string.format("%s at Tier %d", locked.id, tier)
			refused(label, result, moved, "opens at Tier")
		else
			add(
				notes,
				'locked area skipped: tier %d opens every area; run %s("setTier", nil, 1)',
				tier,
				DEBUG
			)
		end

		-- 4. Carrying: walking the cat home is the loop and carry bumps depend on it.
		if state.carrying ~= nil then
			local result, moved = travel("home")
			refused("home while carrying", result, moved, "Walk your cat home")
			if not checkInIfCarrying() then
				return "FAIL",
					"could not check the carried cat in; " .. table.concat(failures, "; ")
			end
		else
			table.insert(notes, "carrying skipped: not carrying (catch a cat by hand, then rerun)")
		end

		-- 5. Mid-catch (reviewer N47): leaving would dodge the Miss.
		local stray = nearestStray()
		if stray ~= nil then
			local schedule, why, startedAt = beginCatch(stray)
			if schedule ~= nil then
				local result, moved = travel("home")
				refused("home mid-catch", result, moved, "Finish this catch")
				outcomeOf(startedAt, stray.id, schedule) -- the catch ends unpressed
			else
				table.insert(notes, "mid-catch skipped: " .. why)
			end
		else
			table.insert(notes, "mid-catch skipped: " .. NO_STRAY)
		end

		-- 6. Home lands outside the own door; a second travel inside TravelCooldownSeconds is refused; once the
		-- cooldown is over an open area lands inside its floor.
		local door = ownDoor()
		if door == nil then
			table.insert(notes, "home skipped: no own plot or door found")
		else
			local result = travel("home")
			local landed = rootPart()
			local fromDoor = if landed ~= nil
				then horizontal(landed.Position, door.Position)
				else math.huge
			if result == nil or not result.ok then
				local why = if result ~= nil then tostring(result.reason) else "no TravelResult"
				add(failures, "home refused: %s", why)
			elseif fromDoor > 12 then
				add(
					failures,
					"home answered ok but landed %d studs from the door",
					math.floor(fromDoor)
				)
			else
				add(notes, "home landed %d studs from the door", math.floor(fromDoor))
				local homeAt = lastTravelAt
				local again, movedAgain = travel("alley")
				refused("alley 1 s after home", again, movedAgain, "breath")
				-- Config.TravelCooldownSeconds is new with F19; 3 s in design v0.4
				local cooldown = (Config :: any).TravelCooldownSeconds or 3
				local left = homeAt + cooldown + 0.2 - os.clock()
				if left > 0 then
					task.wait(left)
				end
				local alley, movedAlley = travel("alley")
				local floor = areaFloor("alley")
				local inside = rootPart()
				if alley == nil or not alley.ok then
					local why = if alley ~= nil then tostring(alley.reason) else "no TravelResult"
					add(failures, "alley after the cooldown refused: %s", why)
				elseif floor == nil or inside == nil then
					add(
						checks,
						"alley ok, moved %d studs; no alley floor to check against",
						math.floor(movedAlley)
					)
				else
					local offset = floor.CFrame:PointToObjectSpace(inside.Position)
					local outside = math.abs(offset.X) > floor.Size.X / 2
						or math.abs(offset.Z) > floor.Size.Z / 2
					if outside then
						add(
							failures,
							"alley answered ok but the character is outside the alley floor"
						)
					else
						table.insert(notes, "alley landed inside the alley after the cooldown")
					end
				end
			end
		end

		local detail = table.concat(failures, "; ")
			.. (if #failures > 0 and #checks + #notes > 0 then "; " else "")
			.. table.concat(checks, "; ")
			.. (if #checks > 0 and #notes > 0 then "; " else "")
			.. table.concat(notes, "; ")
		if #failures > 0 then
			return "FAIL", detail
		end
		if #checks > 0 then
			return "CHECK", detail
		end
		return "PASS",
			detail .. ". Now read the server output for [Net] Travel handler failed lines"
	end
)

-- Rename (F33, data-model section 4, reviewer S30 and S47) ------------------------------------------------------

case(
	"rename",
	Enum.KeyCode.BackSlash,
	"Rename: uids that are not mine, bad names, the cooldown, then 10 renames in one frame",
	function()
		if state == nil then
			return "SKIP", "no ProfileSync yet"
		end
		-- A caught cat first: its uid is generated, unlike starter_tabby, and generated uids were once dropped by
		-- Guard.id (laptop run 2026-10-27). Working if possible, so its DisplayName over the model can be checked too.
		local uid: string? = nil
		local best = -1
		for candidate, view in state.cats do
			local caught = if candidate ~= "starter_tabby" then 2 else 0
			local score = caught + (if view.spotId ~= nil then 1 else 0)
			if score > best then
				uid, best = candidate, score
			end
		end
		if uid == nil then
			return "SKIP", "no cat to rename: catch one first"
		end
		local mine = uid :: string
		local function shownName(): string?
			local view = if state ~= nil then state.cats[mine] else nil
			return if view ~= nil then view.name else nil
		end
		local failures, checks, notes = {}, {}, {}
		-- RenameCat takes 1 call a second, so each call a step means to land waits the bucket out.
		local function send(uidValue: any, name: any)
			fire("RenameCat", uidValue, name)
			task.wait(1.05)
		end

		-- 1. Not my cat, or not a uid at all: dropped without a word.
		local quietAt = os.clock()
		local badUids: { any } = { "nil", 5, {}, "NOT_MINE", "not_my_cat", string.rep("a", 500) }
		for _, value in badUids do
			send(if value == "nil" then nil else value, "Probe")
		end
		for _, event in since(quietAt, "Toast") do
			add(failures, "a uid that is not mine got an answer: %s", event.text)
		end

		-- 2. Bad names on my own cat: each refused in its own words before the filter, and the name stays.
		local before = shownName()
		local bad = "characters we can't use"
		local badNames: { { value: any, label: string, reason: string } } = {
			{ value = "nil", label = "nil", reason = "Type a name first" },
			{ value = 42, label = "a number", reason = "Type a name first" },
			{ value = {}, label = "a table", reason = "Type a name first" },
			{ value = "   ", label = "spaces", reason = "Type a name first" },
			{
				value = string.rep("a", Config.CatNameMaxLength + 1),
				label = "one too long",
				reason = "Names can be up to",
			},
			{ value = string.rep("a", 5000), label = "5000 bytes", reason = bad },
			{ value = "Mo\255chi", label = "invalid UTF-8", reason = bad },
			{ value = "Mo\nchi", label = "a newline", reason = bad },
			{ value = "<b>Mochi</b>", label = "rich text tags", reason = bad },
			{ value = "Mo\u{202E}chi", label = "a bidi override", reason = bad },
			{ value = "\u{3164}", label = "a Hangul filler", reason = bad },
		}
		for _, entry in badNames do
			local at = os.clock()
			send(mine, if entry.value == "nil" then nil else entry.value)
			if toasted(at, "Renamed") then
				add(failures, "%s was accepted", entry.label)
			elseif not toasted(at, entry.reason) then
				add(checks, 'no "%s" toast for %s', entry.reason, entry.label)
			end
		end
		if shownName() ~= before then
			add(
				failures,
				"the shown name moved from %s to %s",
				tostring(before),
				tostring(shownName())
			)
		end

		-- 3. One good rename, and a second inside RenameCooldownSeconds. The filter is a web call, so its answer
		-- is collected over a few seconds; the cooldown starts before it.
		local goodAt = os.clock()
		send(mine, "Probe")
		local renamedAt = goodAt
		send(mine, "Probe Two")
		task.wait(3)
		local filtered = toasted(goodAt, "Renamed to")
		if toasted(goodAt, "Couldn't check that name") then
			add(
				checks,
				"the filter failed here: use Play Solo signed in to Studio for the rename itself"
			)
		elseif not filtered then
			add(checks, 'no "Renamed to" toast for Probe')
		end
		if not toasted(goodAt, "Wait a moment before renaming again") then
			add(failures, "a second rename 1 s after the first was not refused by the cooldown")
		end
		if #since(goodAt, "Toast") > 2 then
			add(failures, "%d toasts for two renames", #since(goodAt, "Toast"))
		end
		if filtered then
			if shownName() == "Probe" then
				table.insert(notes, 'renamed to "Probe" and the cat room view shows it')
			else
				add(checks, 'renamed, but the view shows %s, not "Probe"', tostring(shownName()))
			end
		end

		-- 4. Ten in one frame once the cooldown is over: the flood guard lets one through.
		local left = renamedAt + Config.RenameCooldownSeconds + 0.3 - os.clock()
		if left > 0 then
			task.wait(left)
		end
		local burstAt = os.clock()
		for n = 1, 10 do
			Remotes.event("RenameCat"):FireServer(mine, "Burst" .. n)
		end
		log(string.format('    -> RenameCat(%q, "BurstN") x10', mine))
		task.wait(3)
		local answers = #since(burstAt, "Toast")
		local renames = 0
		for _, event in since(burstAt, "Toast") do
			if string.find(event.text, "Renamed", 1, true) ~= nil then
				renames += 1
			end
		end
		if renames > 1 or answers > 1 then
			add(failures, "10 renames in one frame: %d renamed, %d toasts", renames, answers)
		else
			add(notes, "burst: %d of 10 answered", answers)
		end

		local detail = table.concat(failures, "; ")
			.. (if #failures > 0 and #checks + #notes > 0 then "; " else "")
			.. table.concat(checks, "; ")
			.. (if #checks > 0 and #notes > 0 then "; " else "")
			.. table.concat(notes, "; ")
		if #failures > 0 then
			return "FAIL", detail
		end
		if #checks > 0 then
			return "CHECK", detail
		end
		return "PASS",
			"uids not mine: silent; every bad name refused in words; cooldown holds; "
				.. detail
				.. ". The test cat keeps its new name. Now read the server output for [Net] RenameCat handler failed lines"
	end
)

-- Analytics reports (F16, data-model section 15) --------------------------------------------------------------

case(
	"telemetry",
	Enum.KeyCode.Insert,
	"Telemetry: names, devices and screens off the allow list, a second device, then one good screen",
	function()
		-- TelemetryReport takes 10 calls a minute and the client has already sent its device and maybe a screen or
		-- two, so this sends 8 bad calls and one good one. The server logs nothing back to the client: the verdict
		-- is in the server's own telemetry log.
		local bad: { { any } } = {
			{ "nil", "pc" },
			{ 5, "pc" },
			{ "DEVICE", "pc" },
			{ "catch_circles", 1e308 },
			{ "device", "toaster" },
			{ "device", "console" }, -- allowed, but this session's device is already reported
			{ "ui_opened", "upgrades" }, -- the server's names are the UI's ScreenNames, case and all
			{ "ui_opened", {} },
		}
		local startedAt = os.clock()
		for _, call in bad do
			fire("TelemetryReport", if call[1] == "nil" then nil else call[1], call[2])
		end
		fire("TelemetryReport", "ui_opened", "Dealer")
		task.wait(1)
		local answers = since(startedAt, "Toast")
		if #answers > 0 then
			return "FAIL", "TelemetryReport answered with a toast: " .. answers[1].text
		end
		return "CHECK",
			"sent 8 bad reports and ui_opened Dealer. On the server run "
				.. "print(table.concat("
				.. DEBUG
				.. '("telemetry", 40), "\\n")): '
				.. "PASS when the newest lines hold one custom ui_opened [dealer] and nothing for toaster, console, "
				.. "upgrades or catch_circles, and the onboarding joined line carries [pc], not [unknown]; no ui_opened "
				.. "line at all means the limiter was spent, so rerun after a minute. Also no "
				.. "[Net] TelemetryReport handler failed line"
	end
)

-- Drop and Unequip All (Derek 2026-10-27; engineer PRs #162 and #175) -----------------------------------------

-- Catches the nearest free stray with every circle on target. Returns why not, or "" once the carry has synced.
local function catchOne(): string
	local stray = nearestStray()
	if stray == nil then
		return NO_STRAY
	end
	local schedule, why, startedAt = beginCatch(stray)
	if schedule == nil then
		return why
	end
	pressAllOnTarget(stray.id, schedule)
	local outcome = outcomeOf(startedAt, stray.id, schedule)
	if outcome == nil or not outcome.success then
		return "the catch did not land"
	end
	local synced = waitFor(startedAt, "ProfileSync", 3, function()
		return state ~= nil and state.carrying ~= nil
	end)
	return if synced ~= nil then "" else "caught, but no ProfileSync shows the carry"
end

-- The Drop's two toasts: "You let <Cat> go." in a catching area, "<Cat> ran back to the <Area>." anywhere else.
local function dropToasts(startedAt: number): number
	local count = 0
	for _, event in since(startedAt, "Toast") do
		local text = event.text
		if string.find(text, " go.", 1, true) or string.find(text, "ran back to the", 1, true) then
			count += 1
		end
	end
	return count
end

-- The nearest Dropped stray (v0.8 F56: Dropped and PickUp set; F93: a swing that lands on it picks it up) of cat
-- `catId` within `radius` studs of me, and its StrayId.
local function droppedStray(catId: string?, radius: number): (Model?, string?)
	local root = rootPart()
	if root == nil then
		return nil, nil
	end
	local best: Model? = nil
	local bestId: string? = nil
	local bestDistance = radius
	for _, instance in Workspace:GetDescendants() do
		if
			instance:IsA("Model")
			and instance:GetAttribute("Dropped") == true
			and instance:GetAttribute("PickUp") == true
			and (catId == nil or instance:GetAttribute("CatId") == catId)
		then
			local id = instance:GetAttribute("StrayId")
			local distance = horizontal(instance:GetPivot().Position, root.Position)
			if type(id) == "string" and distance <= bestDistance then
				best, bestId, bestDistance = instance :: Model, id, distance
			end
		end
	end
	return best, bestId
end

case(
	"drop",
	Enum.KeyCode.Home,
	"Drop: not carrying, junk arguments, CheckIn and 10 DropCat in one frame at my door, then a drop in the alley, its pick up and its walk home (F67)",
	function()
		if not checkInIfCarrying() then
			return "SKIP", "carrying a cat that could not be checked in"
		end
		local verdict: Verdict = "PASS"
		local notes = {}
		-- 1. Not carrying: DropCat reads no arguments and does nothing at all. 1 call a second, so spaced.
		local quietAt = os.clock()
		fire("DropCat")
		task.wait(1.05)
		fire("DropCat", "x", 5, {})
		task.wait(1.2)
		local quiet = #since(quietAt, "Toast")
		if quiet > 0 then
			verdict = "FAIL"
			table.insert(notes, string.format("DropCat while not carrying got %d toast(s)", quiet))
		end
		-- 2. At my door: CheckIn, then 10 DropCat in the same frame. Exactly one may happen: the cat checks in, or
		-- it runs back to its area. Both would be a duplicate cat, neither a lost one.
		local why = catchOne()
		if why ~= "" then
			return "SKIP", "could not catch a cat to drop: " .. why
		end
		local door = ownDoor()
		if door == nil then
			return "SKIP", "no own door found"
		end
		teleportTo(door.Position + Vector3.new(0, 0, 3))
		task.wait(1.05)
		local cats = catCount()
		local raceAt = os.clock()
		Remotes.event("CheckIn"):FireServer()
		for _ = 1, 10 do
			Remotes.event("DropCat"):FireServer()
		end
		log("    -> CheckIn(), DropCat() x10")
		waitFor(raceAt, "ProfileSync", 3, function()
			return state ~= nil and state.carrying == nil
		end)
		task.wait(1)
		local checkedIn, drops = catCount() - cats, dropToasts(raceAt)
		if state ~= nil and state.carrying ~= nil then
			verdict = "FAIL"
			table.insert(notes, "still carrying after CheckIn and 10 DropCat")
		elseif checkedIn + drops ~= 1 then
			verdict = "FAIL"
			table.insert(
				notes,
				string.format(
					"door race: %d cat(s) checked in and %d drop toast(s)",
					checkedIn,
					drops
				)
			)
		else
			table.insert(
				notes,
				if drops == 1 then "door race: dropped once" else "door race: checked in once"
			)
		end
		-- 3. In the alley, away from where it was caught: the cat lands at my feet as a Dropped stray with no circles
		-- that a swing picks up (v0.8 F56, F93). Since F67 (engineer PR #502) it walks back to where it was caught
		-- at DropReturnWalkSpeed, so the drop is made DROP_AWAY studs along the back alley from there and every check
		-- below reads where the cat is now. Swings from too far, with junk arguments or all together in one frame
		-- beside it start one carry of the same cat at most, a miss never makes a Dropped cat hop, and with the cat
		-- in my arms a swing is refused.
		why = catchOne()
		if why ~= "" then
			table.insert(notes, "alley drop skipped: " .. why)
			return verdict, table.concat(notes, "; ")
		end
		local catId = if state ~= nil then state.carrying else nil
		local caughtRoot = rootPart()
		local caughtAt = if caughtRoot ~= nil then caughtRoot.Position else Vector3.zero
		-- along the back alley (it runs north and south between AlleySouthZ and AlleyNorthZ), toward its middle
		local DROP_AWAY = 80
		local awayZ = if math.abs(caughtAt.Z) >= DROP_AWAY / 2
			then caughtAt.Z - math.sign(caughtAt.Z) * DROP_AWAY
			else caughtAt.Z + (if caughtAt.Z >= 0 then DROP_AWAY else -DROP_AWAY)
		awayZ = math.clamp(awayZ, Config.World.AlleySouthZ + 8, Config.World.AlleyNorthZ - 8)
		teleportTo(Vector3.new(caughtAt.X, caughtAt.Y, awayZ))
		task.wait(1.05)
		local awayRoot = rootPart()
		local away = if awayRoot ~= nil then horizontal(awayRoot.Position, caughtAt) else 0
		if away < DROP_AWAY / 2 then
			verdict = downgrade(verdict, "CHECK")
			table.insert(
				notes,
				string.format("dropped only %.0f studs from the catch, so a walking-home cat may beat the checks", away)
			)
		end
		local alleyAt = os.clock()
		fire("DropCat")
		waitFor(alleyAt, "ProfileSync", 3, function()
			return state ~= nil and state.carrying == nil
		end)
		task.wait(0.5)
		if not toasted(alleyAt, " go.") then
			verdict = "FAIL"
			table.insert(notes, 'alley drop: no "You let <Cat> go." toast')
		end
		local dropped, dropId = droppedStray(catId, 30)
		if dropped == nil or dropId == nil then
			table.insert(
				notes,
				string.format(
					"alley drop: no %s with Dropped and PickUp within 30 studs",
					tostring(catId)
				)
			)
			return "FAIL", table.concat(notes, "; ")
		end
		local droppedModel = dropped :: Model
		local strayId = dropId :: string
		-- F67: Returning while it walks home; nil on a server from before F67, where it stays put
		local walksHome = droppedModel:GetAttribute("Returning") == true
		table.insert(
			notes,
			if walksHome
				then "the dropped cat is walking home"
				else "no Returning attribute (a server before F67), so the walk home is not checked"
		)
		local function here(): Vector3
			return droppedModel:GetPivot().Position
		end
		-- still a Dropped stray anyone can pick up, so the pick up checks still mean something
		local function stillDropped(): boolean
			return droppedModel:IsDescendantOf(Workspace)
				and droppedModel:GetAttribute("Dropped") == true
				and droppedModel:GetAttribute("PickUp") == true
		end
		local function tooLate(step: string): (Verdict, string)
			table.insert(
				notes,
				string.format("the cat was home before %s (drop it farther from the catch)", step)
			)
			return downgrade(verdict, "CHECK"), table.concat(notes, "; ")
		end

		-- From too far, facing it (GrabRangeStuds plus 8, past the swing's reach), with no arguments, then with
		-- junk ones a cooldown apart (quick, while the cat walks home): SwingNet takes none, so each is a swing that
		-- lands on nothing, and a Dropped cat never hops (F93).
		if not stillDropped() then
			return tooLate("the far swings")
		end
		local spot = here()
		teleportFacing(spot + Vector3.new(Config.GrabRangeStuds + 8, 0, 0), spot)
		local root = rootPart()
		local farOff = if root ~= nil then horizontal(root.Position, here()) else 0
		if farOff <= NetSwing.reach() + 2 then
			verdict = downgrade(verdict, "CHECK")
			table.insert(
				notes,
				string.format(
					"could not stand far from the cat (settled %.1f studs out), far swings not tried",
					farOff
				)
			)
		else
			local farAt = os.clock()
			local junk: { any } = { "none", strayId, 0 / 0, {} }
			swingReady()
			for index, value in junk do
				if index > 1 then
					task.wait(Config.NetSwingCooldown + 0.15)
				end
				if value == "none" then
					fire("SwingNet")
				else
					fire("SwingNet", value)
				end
			end
			task.wait(0.6)
			if (state ~= nil and state.carrying ~= nil) or droppedModel.Parent == nil then
				return "FAIL",
					table.concat(notes, "; ")
						.. string.format("; a swing from %.1f studs picked the cat up", farOff)
			end
			local swung = #swungSince(farAt)
			if swung ~= #junk then
				verdict = downgrade(verdict, "CHECK")
				table.insert(
					notes,
					string.format(
						"%d swings a cooldown apart from %.1f studs, %d NetSwung (read the server output for a"
							.. " [Net] SwingNet handler failed line)",
						#junk,
						farOff,
						swung
					)
				)
			else
				table.insert(
					notes,
					string.format(
						"%d far swings from %.1f studs, junk arguments in 3, picked nothing up",
						#junk,
						farOff
					)
				)
			end
			if droppedModel:GetAttribute("HopAt") ~= nil then
				verdict = "FAIL"
				table.insert(notes, "the Dropped cat hopped from a swing that missed")
			end
		end

		-- Beside it, facing it: ten SwingNet in one frame start one carry of the same cat, the stray is gone, and only
		-- one of them lands (the cooldown refuses the rest without a word).
		if not stillDropped() then
			return tooLate("the pick up")
		end
		swingReady()
		local near = here()
		teleportFacing(near + Vector3.new(SWING_STUDS, 0, 0), near)
		local pickAt = os.clock()
		for _ = 1, 10 do
			Remotes.event("SwingNet"):FireServer()
		end
		lastSwingAt = os.clock()
		log("    -> SwingNet() x10")
		waitFor(pickAt, "ProfileSync", 3, function()
			return state ~= nil and state.carrying ~= nil
		end)
		local gone = os.clock() + 3
		while droppedModel:IsDescendantOf(Workspace) and os.clock() < gone do
			task.wait(0.1)
		end
		task.wait(0.5)
		local picked = 0
		for _, event in since(pickAt, "Toast") do
			if string.find(event.text, "You picked up", 1, true) ~= nil then
				picked += 1
			end
		end
		local carried = if state ~= nil then state.carrying else nil
		if carried == nil then
			return "FAIL",
				table.concat(notes, "; ") .. "; ten swings beside the Dropped cat picked nothing up"
		end
		if catId ~= nil and carried ~= catId then
			return "FAIL",
				table.concat(notes, "; ") .. string.format(
					"; picked up %s, but the dropped cat was %s",
					carried,
					catId
				)
		end
		if picked ~= 1 then
			verdict = "FAIL"
			table.insert(
				notes,
				string.format('%d "You picked up" toasts from ten swings in one frame', picked)
			)
		end
		local landed = #swungSince(pickAt)
		if landed ~= 1 then
			verdict = "FAIL"
			table.insert(notes, string.format("%d of ten swings in one frame landed (NetSwung)", landed))
		end
		if droppedModel:IsDescendantOf(Workspace) then
			verdict = "FAIL"
			table.insert(notes, "the Dropped stray is still in the world after the pick up")
		end
		table.insert(notes, string.format("ten swings in one frame carried %s once", carried))

		-- With the cat in my arms the net is away: a swing gets no NetSwung.
		swingReady()
		local armsAt = os.clock()
		fire("SwingNet")
		task.wait(1)
		if #swungSince(armsAt) > 0 then
			verdict = "FAIL"
			table.insert(notes, "a swing while carrying landed")
		else
			table.insert(notes, "a swing while carrying: refused")
		end

		-- 4. F67: let go again and it walks all the way home, to where it was first caught (a pick up keeps that),
		-- and is a normal stray there: not Dropped, not Returning, no Pick up prompt.
		if walksHome then
			task.wait(1.05)
			local againAt = os.clock()
			fire("DropCat")
			waitFor(againAt, "ProfileSync", 3, function()
				return state ~= nil and state.carrying == nil
			end)
			task.wait(0.5)
			local walker, walkerId = droppedStray(catId, 30)
			if walker == nil or walkerId == nil then
				verdict = "FAIL"
				table.insert(notes, "the second drop left no Dropped cat at my feet")
			else
				local model = walker :: Model
				local from = horizontal(model:GetPivot().Position, caughtAt)
				-- the path can wind, so allow twice the straight walk plus a margin, never past the server's cap
				-- (read loosely, so this client still checks against a build from before F67)
				local loose: any = Config
				local speed = loose.DropReturnWalkSpeed or 8
				local cap = loose.DropReturnMaxSeconds or 60
				local limit = math.min(2 * from / speed + 5, cap + 5)
				local deadline = os.clock() + limit
				while
					model:IsDescendantOf(Workspace)
					and model:GetAttribute("Returning") == true
					and os.clock() < deadline
				do
					task.wait(0.25)
				end
				local left = horizontal(model:GetPivot().Position, caughtAt)
				if not model:IsDescendantOf(Workspace) then
					verdict = downgrade(verdict, "CHECK")
					table.insert(notes, "the walking cat left the world before it got home (picked up, or dusk)")
				elseif model:GetAttribute("Returning") == true then
					verdict = "FAIL"
					table.insert(notes, string.format("still walking home %.0f s after the drop, %.0f studs out", limit, left))
				elseif
					model:GetAttribute("Dropped") == true
					or model:GetAttribute("PickUp") == true
					or left > Config.GrabRangeStuds + 4
				then
					verdict = "FAIL"
					table.insert(
						notes,
						string.format(
							"home: Dropped %s, PickUp %s, %.1f studs from where it was caught",
							tostring(model:GetAttribute("Dropped")),
							tostring(model:GetAttribute("PickUp")),
							left
						)
					)
				else
					table.insert(
						notes,
						string.format(
							"walked %.0f studs home in %.1f s and is a normal stray %.1f studs from its catch",
							from,
							os.clock() - againAt,
							left
						)
					)
				end
			end
			return verdict, table.concat(notes, "; ")
		end
		local cats = catCount()
		if checkInIfCarrying() then
			waitFor(pickAt, "ProfileSync", 3, function()
				return catCount() > cats
			end)
			table.insert(notes, string.format("checked in (cats %d to %d)", cats, catCount()))
		end
		return verdict, table.concat(notes, "; ")
	end
)

case(
	"unequip",
	Enum.KeyCode.End,
	"Unequip All: junk arguments and 10 calls in one frame, then Equip Best puts the cats back",
	function()
		local function working(): number
			local count = 0
			if state ~= nil then
				for _, view in state.cats do
					if view.spotId ~= nil then
						count += 1
					end
				end
			end
			return count
		end
		if working() == 0 then
			fire("EquipBest")
			task.wait(2.2)
		end
		local before = working()
		if before == 0 then
			return "SKIP", "no cat can work: catch one first"
		end
		local floodAt = os.clock()
		Remotes.event("UnequipAll"):FireServer("x", 5, {})
		for _ = 1, 9 do
			Remotes.event("UnequipAll"):FireServer()
		end
		log('    -> UnequipAll("x", 5, {}), UnequipAll() x9')
		task.wait(1.5)
		local toasts = {}
		for _, event in since(floodAt, "Toast") do
			table.insert(toasts, event.text)
		end
		local after = working()
		local rate = if state ~= nil then state.incomePerSecond else -1
		task.wait(1.2) -- EquipBest takes 1 call per 2 s
		local restoreAt = os.clock()
		fire("EquipBest")
		waitFor(restoreAt, "ProfileSync", 3)
		task.wait(0.3)
		local restored = working()
		if after ~= 0 or rate ~= 0 then
			return "FAIL",
				string.format(
					"after Unequip All %d cat(s) still work and the rate is %s",
					after,
					tostring(rate)
				)
		end
		if #toasts ~= 1 then
			return "FAIL",
				string.format(
					"%d toasts for 10 calls in one frame: %s",
					#toasts,
					table.concat(toasts, " | ")
				)
		end
		if restored < before then
			return "CHECK", string.format("Equip Best put back %d of %d cats", restored, before)
		end
		return "PASS",
			string.format(
				"%d cat(s) rested with one toast (%s), rate 0, then Equip Best put them back",
				before,
				toasts[1]
			)
	end
)

-- Tackle (v0.11 F74, data-model section 10c; the code keeps the Shove names) ---------------------------------------

-- My presses' ShoveResult answers since `startedAt`, counted by outcome: "refused", "miss", "shove", "loose", "held".
local function tackleAnswers(startedAt: number): { [string]: number }
	local counts: { [string]: number } = {}
	for _, event in since(startedAt, "ShoveResult") do
		local shoved = event.data :: Shoved
		if shoved.shover == player.UserId then
			counts[shoved.outcome] = (counts[shoved.outcome] or 0) + 1
		end
	end
	return counts
end

-- Presses that lunged: every answer but a refusal.
local function lunges(counts: { [string]: number }): number
	local total = 0
	for outcome, count in counts do
		if outcome ~= "refused" then
			total += count
		end
	end
	return total
end

local function answersText(counts: { [string]: number }): string
	local parts: { string } = {}
	for outcome, count in counts do
		table.insert(parts, string.format("%d %s", count, outcome))
	end
	table.sort(parts)
	return if #parts > 0 then table.concat(parts, ", ") else "no answer"
end

-- The server time of my last press that was not refused (display only, for the lunge pose), or nil.
local function tackleAt(): any
	local character = player.Character
	return if character ~= nil then character:GetAttribute("TackleAt") else nil
end

-- The server time my last lunge ended with no hit (display only, for the belly slide), or nil.
local function tackleMissAt(): any
	local character = player.Character
	return if character ~= nil then character:GetAttribute("TackleMissAt") else nil
end

case(
	"tackle",
	Enum.KeyCode.Slash,
	"Tackle: on the street, alone in the Alleyway, 10 in one frame, the 8 s cooldown, while carrying",
	function()
		if not checkInIfCarrying() then
			return "SKIP", "carrying a cat that could not be checked in"
		end
		local floor = areaFloor("alley")
		if floor == nil then
			return "SKIP", "no Alleyway floor found"
		end
		local root = rootPart()
		local home = if root ~= nil then root.Position else nil
		local function done(verdict: Verdict, detail: string): (Verdict, string)
			if home ~= nil then
				teleportTo(home)
			end
			return verdict, detail
		end
		local verdict: Verdict = "PASS"
		local notes: { string } = {}

		-- 1. On the street by my door: refused with a toast and ShoveResult "refused", nothing lunges, and the
		-- refusal spends no cooldown (step 2 lunges at once).
		local door = ownDoor()
		if door == nil then
			table.insert(notes, "no own door, so the street press was not tried")
		else
			teleportTo(door.Position + Vector3.new(0, 0, 3))
			task.wait(0.6)
			local streetAt = os.clock()
			local before = tackleAt()
			fire("Tackle")
			task.wait(1.2)
			local street = tackleAnswers(streetAt)
			if lunges(street) > 0 or tackleAt() ~= before then
				return done("FAIL", "a Tackle on the street lunged: " .. answersText(street))
			end
			if
				(street.refused or 0) ~= 1
				or not toasted(streetAt, "You can only tackle inside a catching area")
			then
				verdict = downgrade(verdict, "CHECK")
				table.insert(
					notes,
					string.format(
						'street press answered %s, not one refused with "You can only tackle inside a catching area"',
						answersText(street)
					)
				)
			else
				table.insert(notes, "street press refused")
			end
		end

		-- 2. Alone in the Alleyway, with junk arguments (Tackle reads none): a real press that misses, answered to me
		-- alone with target 0 once the lunge and its grace (0.6 s) are over.
		teleportTo(floor.Position)
		task.wait(1.05)
		local pressAt = os.clock()
		local pressedBefore, missedBefore = tackleAt(), tackleMissAt()
		fire("Tackle", "x", 5, {})
		waitFor(pressAt, "ShoveResult", 2.5, function(event: Event): boolean
			return (event.data :: Shoved).outcome ~= "refused"
		end)
		task.wait(0.3)
		local pressed = tackleAnswers(pressAt)
		if (pressed.refused or 0) > 0 then
			if toasted(pressAt, "Catch your breath") then
				return done(
					"FAIL",
					table.concat(notes, "; ")
						.. "; the first press in the Alleyway met a cooldown the street refusal should not have spent"
				)
			end
			return done(
				"CHECK",
				table.concat(notes, "; ")
					.. "; a press in the Alleyway was refused (night, or a tier that has not opened it?); run by day"
			)
		end
		if (pressed.miss or 0) ~= 1 or lunges(pressed) ~= 1 then
			return done(
				"CHECK",
				table.concat(notes, "; ")
					.. string.format(
						"; a press alone in the Alleyway answered %s, not one miss (run with nobody else near)",
						answersText(pressed)
					)
			)
		end
		if tackleAt() == pressedBefore or tackleMissAt() == missedBefore then
			verdict = downgrade(verdict, "CHECK")
			table.insert(
				notes,
				"a press alone missed, but TackleAt or TackleMissAt did not change on my character"
			)
		else
			table.insert(notes, "a press alone missed")
		end

		-- 3. Ten presses in one frame inside the cooldown: the limiter lets 2 through and both are refused with
		-- "Catch your breath before the next tackle"; nothing lunges.
		task.wait(1.05)
		local floodAt = os.clock()
		local lungedAt = tackleAt()
		for _ = 1, 10 do
			Remotes.event("Tackle"):FireServer()
		end
		log("    -> Tackle() x10")
		task.wait(1.5)
		local flood = tackleAnswers(floodAt)
		if lunges(flood) > 0 or tackleAt() ~= lungedAt then
			return done(
				"FAIL",
				table.concat(notes, "; ")
					.. "; a press inside the cooldown lunged: "
					.. answersText(flood)
			)
		end
		if (flood.refused or 0) > 2 then
			verdict = "FAIL"
			table.insert(
				notes,
				string.format(
					"%d refusals from 10 presses in one frame (the limiter allows 2)",
					flood.refused
				)
			)
		elseif not toasted(floodAt, "Catch your breath before the next tackle") then
			verdict = downgrade(verdict, "CHECK")
			table.insert(
				notes,
				'presses inside the cooldown refused without "Catch your breath before the next tackle"'
			)
		else
			table.insert(
				notes,
				string.format(
					"10 presses in one frame: %d refused, none lunged",
					flood.refused or 0
				)
			)
		end

		-- 4. The cooldown runs TackleCooldownSeconds from the press, hit or miss: just inside it a press is refused,
		-- just past it one lunges again.
		task.wait(math.max(0, pressAt + Config.TackleCooldownSeconds - 0.6 - os.clock()))
		local insideAt = os.clock()
		fire("Tackle")
		task.wait(0.4)
		local inside = tackleAnswers(insideAt)
		if lunges(inside) > 0 then
			return done(
				"FAIL",
				table.concat(notes, "; ")
					.. string.format("; a press %.1f s after the last lunged", insideAt - pressAt)
			)
		end
		task.wait(math.max(0, pressAt + Config.TackleCooldownSeconds + 0.4 - os.clock()))
		local pastAt = os.clock()
		fire("Tackle")
		waitFor(pastAt, "ShoveResult", 2.5, function(event: Event): boolean
			return (event.data :: Shoved).outcome ~= "refused"
		end)
		local past = tackleAnswers(pastAt)
		if lunges(past) ~= 1 then
			verdict = downgrade(verdict, "CHECK")
			table.insert(
				notes,
				string.format(
					"a press %.1f s after the last answered %s, not a lunge",
					pastAt - pressAt,
					answersText(past)
				)
			)
		else
			table.insert(
				notes,
				string.format(
					"refused at %.1f s and lunged at %.1f s after the press",
					insideAt - pressAt,
					pastAt - pressAt
				)
			)
		end

		-- 5. Carrying a cat: refused with "Check in the cat you are carrying first", which comes before the cooldown
		-- that step 4 just started, and nothing lunges.
		local why = catchOne()
		if why ~= "" then
			table.insert(notes, "carrying press skipped: " .. why)
			return done(verdict, table.concat(notes, "; "))
		end
		task.wait(0.6)
		local carryAt = os.clock()
		local carryBefore = tackleAt()
		fire("Tackle")
		task.wait(1)
		local carried = tackleAnswers(carryAt)
		if lunges(carried) > 0 or tackleAt() ~= carryBefore then
			verdict = "FAIL"
			table.insert(notes, "a press while carrying lunged: " .. answersText(carried))
		elseif not toasted(carryAt, "Check in the cat you are carrying first") then
			verdict = downgrade(verdict, "CHECK")
			table.insert(
				notes,
				'a press while carrying refused without "Check in the cat you are carrying first"'
			)
		else
			table.insert(notes, "a press while carrying refused")
		end
		if state == nil or state.carrying == nil then
			verdict = "FAIL"
			table.insert(notes, "the refused press while carrying lost the cat")
		end
		checkInIfCarrying()
		table.insert(notes, "a hit needs two players (section 4.3 item 2)")
		return done(verdict, table.concat(notes, "; "))
	end
)

-- Settings (engineer PR #202, reviewer N110) ---------------------------------------------------------------------

case(
	"settings",
	Enum.KeyCode.PageUp,
	"Settings: SetSetting with bad keys and values, then a flip, then 10 in one frame",
	function()
		local function settings(): { music: boolean, sfx: boolean }?
			local current = if state ~= nil then (state :: any).settings else nil
			return if type(current) == "table" then current else nil
		end
		local function same(
			a: { music: boolean, sfx: boolean },
			b: { music: boolean, sfx: boolean }
		): boolean
			return a.music == b.music and a.sfx == b.sfx
		end
		freshWallet()
		local start = settings()
		if start == nil then
			return "SKIP", "the ProfileSync carries no settings (needs engineer PR #202)"
		end
		local before = { music = start.music, sfx = start.sfx }

		-- Bad keys and values, 0.3 s apart so the 4 a second limit drops none: no change, no toast.
		local bad: { { key: any, value: any } } = {
			{ key = "volume", value = true },
			{ key = nil, value = true },
			{ key = {}, value = false },
			{ key = "MUSIC", value = not before.music },
			{ key = 5, value = true },
			{ key = "music", value = "false" },
			{ key = "music", value = 0 },
			{ key = "sfx", value = nil },
			{ key = "sfx", value = {} },
		}
		local badAt = os.clock()
		for _, call in bad do
			fire("SetSetting", call.key, call.value)
			task.wait(0.3)
		end
		task.wait(0.5)
		local badToasts = #since(badAt, "Toast")
		local badSyncs = #since(badAt, "ProfileSync")
		local afterBad = settings()

		-- One real flip, then put it back.
		task.wait(1.1)
		local flipAt = os.clock()
		fire("SetSetting", "music", not before.music)
		local flipped = waitFor(flipAt, "ProfileSync", 2, function()
			local now = settings()
			return now ~= nil and now.music == not before.music
		end)
		task.wait(1.1)
		local backAt = os.clock()
		fire("SetSetting", "music", before.music)
		waitFor(backAt, "ProfileSync", 2)

		-- 10 in one frame: at most 4 get through (plus a periodic sync), and the last one through decides sfx.
		task.wait(1.1)
		local floodAt = os.clock()
		for i = 1, 10 do
			Remotes.event("SetSetting"):FireServer("sfx", i % 2 == 0)
		end
		log('    -> SetSetting("sfx", false or true) x10 in one frame')
		task.wait(1.5)
		local floodSyncs = #since(floodAt, "ProfileSync")
		task.wait(1.1)
		local restoreAt = os.clock()
		fire("SetSetting", "sfx", before.sfx)
		waitFor(restoreAt, "ProfileSync", 2)
		local final = settings()

		if afterBad == nil or not same(afterBad, before) then
			return "FAIL", "a bad key or value changed the settings"
		end
		if badToasts > 0 then
			return "FAIL", string.format("%d toast(s) for bad SetSetting calls", badToasts)
		end
		if flipped == nil then
			return "FAIL", 'SetSetting("music", flip) sent no ProfileSync with music changed'
		end
		if floodSyncs > 5 then
			return "FAIL",
				string.format(
					"%d ProfileSync back from 10 SetSetting calls in one frame",
					floodSyncs
				)
		end
		if final == nil or not same(final, before) then
			return "CHECK", "the settings did not come back to where they started; set them by hand"
		end
		local note = if badSyncs > 1
			then string.format(
				"; %d ProfileSync during the bad calls (one may be the periodic sync)",
				badSyncs
			)
			else ""
		return "PASS",
			string.format(
				"9 bad calls changed nothing and toasted nothing, the flip synced, the flood got %d sync(s)%s; read the server output for no [Net] SetSetting handler failed line",
				floodSyncs,
				note
			)
	end
)

-- Saved settings (engineer PR #215): every key of shared/Settings is saved. A volume clamps to 0 to 1 at two
-- decimals and refuses NaN, infinities and text; the new switches take only a boolean; the same value again sends
-- no sync.

case(
	"savedSettings",
	Enum.KeyCode.PageDown,
	"Saved settings: volumes clamp, bad volumes and switch values refused, a repeat sends no sync",
	function()
		-- tutorialButton since F72, shopAlerts since F94 (engineer PR #699)
		local SWITCHES = { "screenShake", "lowPerformance", "showOtherCats", "markers", "tutorialButton", "shopAlerts" }
		local VOLUMES = { "musicVolume", "sfxVolume" }
		local function saved(): { [string]: any }?
			local current = if state ~= nil then (state :: any).settings else nil
			return if type(current) == "table" then current else nil
		end
		-- One call 0.3 s after the last, so the 4 a second limit drops none; true when a ProfileSync shows `expected`.
		local function set(key: string, value: any, expected: any): boolean
			task.wait(0.3)
			local at = os.clock()
			fire("SetSetting", key, value)
			return waitFor(at, "ProfileSync", 2, function()
				local now = saved()
				return now ~= nil and now[key] == expected
			end) ~= nil
		end
		freshWallet()
		local start = saved()
		if start == nil or start.musicVolume == nil then
			return "SKIP", "the ProfileSync carries no volumes (needs engineer PR #215)"
		end
		local before = table.clone(start)
		local function restore()
			for key, value in before do
				local now = saved()
				if now ~= nil and now[key] ~= value then
					set(key, value, value)
				end
			end
		end

		-- Volumes: from a middle value, 2 saves as 1, -1 as 0 and 0.333333 as 0.33.
		for _, key in VOLUMES do
			local middle = if before[key] == 0.5 then 0.6 else 0.5
			if not set(key, middle, middle) then
				restore()
				return "FAIL",
					string.format("SetSetting(%q, %s) did not save", key, tostring(middle))
			end
		end
		local clamps: { { key: string, value: number, expected: number } } = {
			{ key = "musicVolume", value = 2, expected = 1 },
			{ key = "musicVolume", value = -1, expected = 0 },
			{ key = "sfxVolume", value = 7, expected = 1 },
			{ key = "sfxVolume", value = 0.333333, expected = 0.33 },
		}
		for _, call in clamps do
			if not set(call.key, call.value, call.expected) then
				restore()
				return "FAIL",
					string.format(
						"SetSetting(%q, %s) did not save as %s",
						call.key,
						tostring(call.value),
						tostring(call.expected)
					)
			end
		end

		-- Bad values for every volume and every new switch: nothing changes and nothing toasts.
		local held = table.clone(saved() :: { [string]: any })
		local badAt = os.clock()
		for _, key in VOLUMES do
			for _, value in { 0 / 0, math.huge, -math.huge, "0.5", true, {} } :: { any } do
				task.wait(0.3)
				fire("SetSetting", key, value)
			end
		end
		for _, key in SWITCHES do
			for _, value in { 1, "true", {} } :: { any } do
				task.wait(0.3)
				fire("SetSetting", key, value)
			end
		end
		task.wait(0.5)
		local badToasts = #since(badAt, "Toast")
		local afterBad = saved()
		local moved: { string } = {}
		for key, value in held do
			if afterBad == nil or afterBad[key] ~= value then
				table.insert(moved, key)
			end
		end

		-- Each new switch saves a flip and comes back.
		local unsaved: { string } = {}
		for _, key in SWITCHES do
			if
				not set(key, not before[key], not before[key])
				or not set(key, before[key], before[key])
			then
				table.insert(unsaved, key)
			end
		end

		-- The same value three times: no sync for any of them (one may be the 10 s periodic sync).
		task.wait(1.1)
		local repeatAt = os.clock()
		for _ = 1, 3 do
			fire("SetSetting", "markers", before.markers)
			task.wait(0.3)
		end
		task.wait(0.5)
		local repeatSyncs = #since(repeatAt, "ProfileSync")

		restore()
		local final = saved()
		if #moved > 0 then
			return "FAIL", "a bad value changed " .. table.concat(moved, ", ")
		end
		if badToasts > 0 then
			return "FAIL", string.format("%d toast(s) for bad SetSetting calls", badToasts)
		end
		if #unsaved > 0 then
			return "FAIL", "a flip did not save for " .. table.concat(unsaved, ", ")
		end
		if repeatSyncs > 1 then
			return "FAIL",
				string.format(
					"%d ProfileSync back from SetSetting with the value already saved",
					repeatSyncs
				)
		end
		for key, value in before do
			if final == nil or final[key] ~= value then
				return "CHECK",
					"the settings did not come back to where they started; set them by hand"
			end
		end
		return "PASS",
			"volumes clamped to 1, 0 and 0.33, NaN, infinities and text refused, the new switches took only booleans and saved their flips, a repeat sent no sync; read the server output for no [Net] SetSetting handler failed line"
	end
)

-- Context tips and the feedback faces (F87 part 3, engineer PR #705, easy-start.md sections 3, 4 and 6) ---------
-- TipSeen(id, skipped?) takes 1 a second and only a shared/Tips id or one of its three asks; ClearTips takes 1 per
-- 10 s and keeps the like ask; SendFeedback(face, chip?) takes 1 per 10 s, only Tips.FACES and Tips.CHIPS, and
-- FeedbackSessionLimit a session. TipSeen sends no ProfileSync of its own, so the case reads tipsSeen and
-- feedbackAsked from the next one (the periodic sync comes every SyncIntervalSeconds, or ClearTips sends one).

case(
	"tips",
	Enum.KeyCode.X,
	"Tips: TipSeen junk and floods, ClearTips keeps the like ask, SendFeedback junk and the session cap",
	function()
		local function seen(): { [string]: boolean }?
			local current = if state ~= nil then (state :: any).tipsSeen else nil
			return if type(current) == "table" then current else nil
		end
		local function asked(): boolean?
			local current = if state ~= nil then (state :: any).feedbackAsked else nil
			return if type(current) == "boolean" then current else nil
		end
		local function keys(map: { [string]: boolean }): string
			local out: { string } = {}
			for key in map do
				table.insert(out, key)
			end
			table.sort(out)
			return if #out > 0 then table.concat(out, ", ") else "none"
		end
		-- The next ProfileSync after `at`: the periodic one, or the one ClearTips sends.
		local function nextSync(at: number): boolean
			return waitFor(at, "ProfileSync", Config.SyncIntervalSeconds + 2) ~= nil
		end
		if seen() == nil or asked() == nil then
			return "SKIP", "the ProfileSync carries no tipsSeen or feedbackAsked (needs engineer PR #705)"
		end
		local verdict: Verdict = "PASS"
		local notes: { string } = {}

		-- 1. Junk ids, 1.1 s apart so the 1 a second limit drops none: nothing new in tipsSeen.
		local before = table.clone(seen() :: { [string]: boolean })
		local junk: { any } = {
			"not_a_tip",
			"Bowl",
			"bowl ",
			"",
			string.rep("a", 5000),
			5,
			{},
			"__index",
		}
		local junkAt = os.clock()
		fire("TipSeen", nil)
		for _, id in junk do
			task.wait(1.1)
			fire("TipSeen", id, "yes")
		end
		task.wait(0.5)
		local junkToasts = #since(junkAt, "Toast")
		if not nextSync(os.clock()) then
			return "CHECK", "no ProfileSync came within the sync interval to read tipsSeen from"
		end
		local afterJunk = seen() :: { [string]: boolean }
		for key in afterJunk do
			if before[key] == nil then
				return "FAIL", string.format("TipSeen junk saved %q in tipsSeen", key)
			end
		end
		if junkToasts > 0 then
			verdict = downgrade(verdict, "CHECK")
			table.insert(notes, string.format("%d toast(s) for junk TipSeen calls", junkToasts))
		else
			table.insert(notes, string.format("%d junk TipSeen ids saved nothing", #junk + 1))
		end

		-- 2. Ten real client tip ids in one frame: the 1 a second limit takes at most two.
		local fresh: { string } = {}
		for _, id in { "stuck_cat", "codes_cat", "luck", "offline", "bowl", "night", "potion", "dealer" } do
			if afterJunk[id] ~= true then
				table.insert(fresh, id)
			end
		end
		if #fresh < 3 then
			verdict = downgrade(verdict, "CHECK")
			table.insert(
				notes,
				string.format('flood skipped: %d unseen tips (on the server run %s("tips"))', #fresh, DEBUG)
			)
		else
			task.wait(1.1)
			local floodAt = os.clock()
			for _, id in fresh do
				Remotes.event("TipSeen"):FireServer(id)
			end
			log(string.format("    -> TipSeen(each of %d unseen tips) in one frame", #fresh))
			task.wait(0.5)
			nextSync(floodAt + 0.5)
			local saved = 0
			for _, id in fresh do
				if (seen() :: { [string]: boolean })[id] == true then
					saved += 1
				end
			end
			if saved > 2 then
				verdict = "FAIL"
				table.insert(notes, string.format("%d of %d TipSeen in one frame were saved", saved, #fresh))
			elseif saved == 0 then
				verdict = downgrade(verdict, "CHECK")
				table.insert(notes, "no TipSeen of the flood was saved, not even the first")
			else
				table.insert(notes, string.format("%d of %d TipSeen in one frame saved", saved, #fresh))
			end
		end

		-- 3. ClearTips: tipsSeen keeps only the like ask; five more in a frame send at most one sync.
		local likeBefore = (seen() :: { [string]: boolean }).like_ask == true
		task.wait(1.1)
		local clearAt = os.clock()
		fire("ClearTips")
		local cleared = waitFor(clearAt, "ProfileSync", 3, function()
			local now = seen()
			if now == nil then
				return false
			end
			for key in now do
				if key ~= "like_ask" then
					return false
				end
			end
			return true
		end)
		if cleared == nil then
			verdict = "FAIL"
			table.insert(notes, "ClearTips sent no ProfileSync with tipsSeen cleared: " .. keys(seen() or {}))
		elseif ((seen() :: { [string]: boolean }).like_ask == true) ~= likeBefore then
			verdict = "FAIL"
			table.insert(notes, "ClearTips changed the like ask")
		else
			table.insert(notes, "ClearTips left " .. keys(seen() :: { [string]: boolean }))
		end
		task.wait(0.5)
		local clearFloodAt = os.clock()
		for _ = 1, 5 do
			Remotes.event("ClearTips"):FireServer()
		end
		log("    -> ClearTips() x5 in one frame")
		task.wait(1.5)
		local clearSyncs = #since(clearFloodAt, "ProfileSync")
		if clearSyncs > 2 then
			verdict = "FAIL"
			table.insert(notes, string.format("%d ProfileSync from 5 ClearTips in one frame", clearSyncs))
		end

		-- 4. SendFeedback junk, 10.5 s apart so the 1 per 10 s limit drops none: feedbackAsked stays false. A
		-- real face then sets it. With feedbackAsked already true the junk half cannot be read.
		if asked() == true then
			verdict = downgrade(verdict, "CHECK")
			table.insert(
				notes,
				string.format('feedback skipped: feedbackAsked is already true (on the server run %s("tips"))', DEBUG)
			)
			return verdict, table.concat(notes, "; ")
		end
		local badFeedback: { { face: any, chip: any } } = {
			{ face = "LOVE", chip = nil },
			{ face = "love", chip = "I typed a sentence here" },
			{ face = {}, chip = nil },
			{ face = "ok", chip = 5 },
		}
		for _, call in badFeedback do
			task.wait(10.5)
			fire("SendFeedback", call.face, call.chip)
		end
		nextSync(os.clock())
		if asked() ~= false then
			verdict = "FAIL"
			table.insert(notes, "a junk SendFeedback set feedbackAsked")
		else
			table.insert(notes, string.format("%d junk SendFeedback calls changed nothing", #badFeedback))
		end
		task.wait(10.5)
		local goodAt = os.clock()
		fire("SendFeedback", "ok", "other")
		task.wait(0.5)
		nextSync(goodAt + 0.5)
		if asked() ~= true then
			verdict = "FAIL"
			table.insert(notes, 'SendFeedback("ok", "other") did not set feedbackAsked')
		else
			table.insert(notes, "a real face set feedbackAsked")
		end
		table.insert(
			notes,
			string.format(
				'the session cap (%d) shows only in %s("telemetry") on the server: at most that many feedback events',
				Config.FeedbackSessionLimit,
				DEBUG
			)
		)
		return verdict, table.concat(notes, "; ")
	end
)

-- Tip Jar (F47, engineer PR #206, data-model 11b) ----------------------------------------------------------------

-- The first step of this session's jar that has (`ready` true) or has not yet run its minutes and is unclaimed.
local function tipStep(ready: boolean): number?
	local jar = tipJar
	if jar == nil then
		return nil
	end
	local played = serverNow() - jar.sessionStartedAt
	for index, def in Catalog.tipJar do
		if not jar.claimed[index] and (played >= def.minutes * 60) == ready then
			return index
		end
	end
	return nil
end

-- "Tip Jar: ..." toasts since `startedAt`, the server's word that a step paid. Steps 11 and 12 also bank a spin
-- with a toast of its own ("Tip Jar: +1 spin", F49) and step 12 pays golden fish in another ("Tip Jar: +5 golden
-- fish", F52), both left out here.
local function tipToasts(startedAt: number): { Event }
	local found = {}
	for _, event in since(startedAt, "Toast") do
		if
			string.find(event.text, "Tip Jar:", 1, true) ~= nil
			and string.find(event.text, "Tip Jar: %+%d+ spin") == nil
			and string.find(event.text, "Tip Jar: %+%d+ golden fish") == nil
		then
			table.insert(found, event)
		end
	end
	return found
end

local function foods(): number
	local total = 0
	if state ~= nil then
		for _, count in state.lures do
			total += count
		end
	end
	return total
end

local function fish(): number
	return if state ~= nil and state.goldenFish ~= nil then state.goldenFish else 0
end

local function crateCount(crateId: string): number
	return if state ~= nil and state.crates ~= nil then state.crates[crateId] or 0 else 0
end

-- Foods, golden fish and banked crates (F52, F53), so a case can tell what a call paid or that a refusal paid none.
type Holdings = { lures: { [string]: number }, fish: number, crates: { [string]: number } }

local function holdings(): Holdings
	return {
		lures = if state ~= nil then table.clone(state.lures) else {},
		fish = fish(),
		crates = if state ~= nil and state.crates ~= nil then table.clone(state.crates) else {},
	}
end

local function holdingsText(held: Holdings): string
	local lures, crates = 0, 0
	for _, count in held.lures do
		lures += count
	end
	for _, count in held.crates do
		crates += count
	end
	return string.format("%d foods, %d golden fish, %d crates", lures, held.fish, crates)
end

case("tipJar", Enum.KeyCode.J, "Tip Jar: bad steps, a locked step, a double claim", function()
	if tipJar == nil then
		return "SKIP", "no TipJarState yet (needs engineer PR #206)"
	end
	-- Bad steps, 1.1 s apart for the 1 a second limit: nothing pays.
	local before = freshWallet()
	local foodsBefore = foods()
	local badAt = os.clock()
	for _, step in { 0, -1, 13, 1.5, "1", 0 / 0, {} } :: { any } do
		fire("ClaimTipJar", step)
		task.wait(1.1)
	end
	fire("ClaimTipJar")
	task.wait(1.1)
	local badPaid = #tipToasts(badAt) > 0
		or money() - before.money > incomeSince(before)
		or foods() ~= foodsBefore
	local badStates = #since(badAt, "TipJarState")

	-- A step whose minutes have not run: answered with TipJarState, still unclaimed, nothing paid.
	local locked = tipStep(false)
	local lockedPaid = false
	local lockedAnswered = true
	if locked ~= nil then
		local lockedAt = os.clock()
		local w = freshWallet()
		local f = foods()
		fire("ClaimTipJar", locked)
		lockedAnswered = waitFor(lockedAt, "TipJarState", 2) ~= nil
		task.wait(1.1)
		local jar = tipJar :: Types.TipJarState
		lockedPaid = #tipToasts(lockedAt) > 0
			or jar.claimed[locked] == true
			or money() - w.money > incomeSince(w)
			or foods() ~= f
	end

	if badPaid then
		return "FAIL", "a bad step paid (a Tip Jar toast, coins or food)"
	end
	if lockedPaid then
		return "FAIL", string.format("step %d paid before its minutes had run", locked :: number)
	end
	if not lockedAnswered then
		return "FAIL", string.format("no TipJarState back for locked step %d", locked :: number)
	end

	-- A ready step: twice in one frame, then again after a second. Exactly one payout.
	local ready = tipStep(true)
	if ready == nil then
		return "CHECK",
			string.format(
				'bad and locked steps paid nothing; no ready gift for the double claim, so on the server run %s("tipJar", nil, 130) and run again',
				DEBUG
			)
	end
	local def = Catalog.tipJar[ready]
	local stepPrize = def.prize -- F68: the Index prize shape
	local w = freshWallet()
	local stepLures: { [string]: number } = stepPrize.lures or {}
	local luresBefore: { [string]: number } = {}
	local before = state
	for lureId in stepLures do
		luresBefore[lureId] = if before ~= nil then before.lures[lureId] or 0 else 0
	end
	local bankedBefore = if state ~= nil and (state :: any).spin ~= nil
		then state.spin.banked
		else nil
	local fishBefore = fish()
	local claimAt = os.clock()
	fire("ClaimTipJar", ready)
	Remotes.event("ClaimTipJar"):FireServer(ready)
	log(string.format("    -> ClaimTipJar(%d) again in the same frame", ready))
	waitFor(claimAt, "ProfileSync", 2)
	task.wait(1.1)
	local againAt = os.clock()
	fire("ClaimTipJar", ready)
	local answered = waitFor(againAt, "TipJarState", 2) ~= nil
	task.wait(0.5)
	local toasts = tipToasts(claimAt)
	local jar = tipJar :: Types.TipJarState
	if #toasts ~= 1 then
		return "FAIL",
			string.format("%d Tip Jar toasts for one ready step claimed three times", #toasts)
	end
	if not jar.claimed[ready] then
		return "FAIL", string.format("step %d paid but TipJarState does not show it claimed", ready)
	end
	if not answered then
		return "FAIL", string.format("no TipJarState back for the claimed step %d", ready)
	end
	local prize: string
	if stepPrize.coins ~= nil then
		local paid = tonumber(string.match(toasts[1].text, "%+%$(%d+)")) or 0
		local gained = money() - w.money
		local floor: number = stepPrize.coins or 0
		if paid < floor then
			return "FAIL",
				string.format("step %d paid $%d, under its floor of $%d", ready, paid, floor)
		end
		if gained < paid or gained > paid + incomeSince(w) then
			return "FAIL",
				string.format(
					"step %d toasted $%d but coins moved by %d",
					ready,
					paid,
					math.floor(gained)
				)
		end
		prize = string.format("$%d", paid)
	else
		prize = ""
		local after = state
		for lureId, count in stepLures do
			local lureAfter = if after ~= nil then after.lures[lureId] or 0 else 0
			local gave = lureAfter - (luresBefore[lureId] or 0)
			if gave ~= count then
				return "FAIL",
					string.format(
						"step %d should give %d %s and gave %d",
						ready,
						count,
						lureId,
						gave
					)
			end
			prize ..= string.format("%s%d %s", if prize == "" then "" else " and ", count, lureId)
		end
	end
	-- Steps 9, 11 and 12 bank spins too (F49, v0.10), unless the bank is full, which the toast says.
	local spins = stepPrize.spins
	if spins ~= nil and bankedBefore ~= nil then
		local banked = (if state ~= nil then state.spin.banked else 0) - bankedBefore
		if banked ~= spins and not toasted(claimAt, "Spins full") then
			return "FAIL",
				string.format("step %d should bank %d spin and banked %d", ready, spins, banked)
		end
		prize ..= string.format(" and %d spin", banked)
	end
	-- Steps 9 and 12 also pay golden fish (F52, v0.10).
	local stepFish = stepPrize.fish
	if stepFish ~= nil then
		local gained = fish() - fishBefore
		if gained ~= stepFish then
			return "FAIL",
				string.format(
					"step %d should pay %d golden fish and paid %d",
					ready,
					stepFish,
					gained
				)
		end
		prize ..= string.format(" and %d golden fish", gained)
	end
	return "PASS",
		string.format(
			"8 bad steps paid nothing (%d TipJarState back)%s; step %d paid %s once for three claims",
			badStates,
			if locked ~= nil
				then string.format(", locked step %d refused", locked)
				else ", no locked step left",
			ready,
			prize
		)
end)

-- Index rewards (F48, engineer PR #211, data-model 11b) ----------------------------------------------------------

-- What a page counts for a track, the way the Index counts it (F54): the area's cats, or every area's on the All
-- Cats page "all", in the collection or the gold collection; on a Decor Index page "decor_<pool>" the pool's crate
-- pieces owned.
local function pageCount(areaId: string, track: string): number
	local s = state
	if s == nil then
		return 0
	end
	local count = 0
	if track == "decor" then
		for _, def in Catalog.crateDecor do
			if "decor_" .. tostring(def.crate) == areaId and s.decorOwned[def.id] then
				count += 1
			end
		end
		return count
	end
	local collection = if track == "gold" then s.goldCollection else s.collection
	for _, def in Catalog.cats do
		if (areaId == "all" or def.area == areaId) and collection[def.id] ~= nil then
			count += 1
		end
	end
	return count
end

-- Every Index page with prizes: the areas in order, then All Cats and the Decor Index pages by id.
local function indexPages(): { string }
	local pages: { string } = {}
	for _, area in Catalog.areas do
		if Catalog.indexPrizes[area.id] ~= nil then
			table.insert(pages, area.id)
		end
	end
	local rest: { string } = {}
	for areaId in Catalog.indexPrizes do
		if Catalog.getArea(areaId) == nil then
			table.insert(rest, areaId)
		end
	end
	table.sort(rest)
	for _, areaId in rest do
		table.insert(pages, areaId)
	end
	return pages
end

local function rewardClaimed(areaId: string, milestoneId: string): boolean
	local claims = if state ~= nil then state.indexRewards[areaId] else nil
	return claims ~= nil and claims[milestoneId] == true
end

-- Claims, foods, golden fish, banked crates and spins, and the forever bonuses, so a case can tell that a refused
-- call marked or paid nothing.
local function indexHoldings(): string
	local claims = 0
	if state ~= nil then
		for _, area in state.indexRewards do
			for _, claimed in area do
				claims += if claimed then 1 else 0
			end
		end
	end
	return string.format(
		"%d claims, %s, %d spins banked, gold luck %s, bait speed %s",
		claims,
		holdingsText(holdings()),
		if state ~= nil then state.spin.banked else 0,
		tostring(if state ~= nil then state.goldLuck else nil),
		tostring(if state ~= nil then state.baitSpeed else nil)
	)
end

type IndexMilestone = { areaId: string, id: string, left: number, track: string }

-- The first unclaimed milestone, in page order, that has its cats or pieces (`ready` true) or is still short.
local function indexMilestone(ready: boolean): IndexMilestone?
	for _, areaId in indexPages() do
		local prizes = Catalog.indexPrizes[areaId]
		for _, milestone in Catalog.indexMilestones do
			if prizes[milestone.id] == nil or rewardClaimed(areaId, milestone.id) then
				continue
			end
			local left = milestone.needs - pageCount(areaId, milestone.track)
			if (left <= 0) == ready then
				return { areaId = areaId, id = milestone.id, left = left, track = milestone.track }
			end
		end
	end
	return nil
end

-- The refusal for a milestone still short: "Find 2 more cats first", "... gold cats ...", "... pieces ...".
local function shortText(milestone: IndexMilestone): string
	local plural = if milestone.left == 1 then "" else "s"
	if milestone.track == "decor" then
		return string.format("Find %d more piece%s first", milestone.left, plural)
	end
	return string.format(
		"Find %d more%s cat%s first",
		milestone.left,
		if milestone.track == "gold" then " gold" else "",
		plural
	)
end

-- The day rate the server prices coinSeconds with: the synced rate is the phase's (data-model section 9).
local function dayRateOf(rate: number): number
	local clock = ReplicatedStorage:FindFirstChild("Clock")
	local night = clock ~= nil and clock:GetAttribute("Phase") == "night"
	return if night then rate / Config.NightIncomeMultiplier else rate
end

local function rewardToasts(startedAt: number): number
	local count = 0
	for _, event in since(startedAt, "Toast") do
		if string.find(event.text, "Index reward:", 1, true) ~= nil then
			count += 1
		end
	end
	return count
end

case("indexReward", Enum.KeyCode.K, "Index rewards: bad, locked and double claims", function()
	if state == nil then
		return "SKIP", "no ProfileSync yet"
	end
	if (state :: any).indexRewards == nil then
		return "SKIP", "the ProfileSync carries no indexRewards (needs engineer PR #211)"
	end
	-- Bad arguments, 1.1 s apart for the 1 a second limit: nothing pays and nothing is marked claimed.
	local bad: { { any } } = {
		{},
		{ "alley" },
		{ "alley", "cats99" },
		{ "moon", "cats3" },
		{ "ALLEY", "cats3" },
		{ "alley", "Cats3" },
		{ 3, "cats3" },
		{ "alley", {} },
		{ "alley", 0 / 0 },
		{ string.rep("a", 300), "cats3" },
		-- F54 pages: a milestone on another page's track, odd page ids
		{ "all", "cats3" },
		{ "alley", "total5" },
		{ "alley", "decor5" },
		{ "decor_alley", "cats3" },
		{ "decor_", "decor5" },
		{ "decor_moon", "decor5" },
		{ "ALL", "total5" },
		{ "all", "total55" },
	}
	local before = freshWallet()
	local held = indexHoldings()
	local badAt = os.clock()
	for _, args in bad do
		fire("ClaimIndexReward", table.unpack(args))
		task.wait(1.1)
	end
	if
		rewardToasts(badAt) > 0
		or money() - before.money > incomeSince(before)
		or indexHoldings() ~= held
	then
		return "FAIL",
			string.format(
				"a bad call paid or claimed something: %s before, %s after",
				held,
				indexHoldings()
			)
	end

	-- A milestone still short of its cats: refused with a toast that says how many to go, nothing paid.
	local verdict: Verdict = "PASS"
	local lockedNote = ", no milestone short of its cats"
	local locked = indexMilestone(false)
	if locked ~= nil then
		local w = freshWallet()
		local h = indexHoldings()
		local expected = shortText(locked)
		local lockedAt = os.clock()
		fire("ClaimIndexReward", locked.areaId, locked.id)
		local answer = waitFor(lockedAt, "Toast", 2)
		task.wait(1.1)
		if
			rewardToasts(lockedAt) > 0
			or money() - w.money > incomeSince(w)
			or indexHoldings() ~= h
		then
			return "FAIL",
				string.format(
					"%s %s paid with %d still to find",
					locked.areaId,
					locked.id,
					locked.left
				)
		end
		if answer == nil then
			verdict = downgrade(verdict, "CHECK")
			lockedNote =
				string.format(", %s %s refused but no toast said why", locked.areaId, locked.id)
		elseif not toasted(lockedAt, expected) then
			verdict = downgrade(verdict, "CHECK")
			lockedNote = string.format(
				', %s %s refused with "%s", expected "%s"',
				locked.areaId,
				locked.id,
				answer.text,
				expected
			)
		else
			lockedNote =
				string.format(', %s %s refused with "%s"', locked.areaId, locked.id, expected)
		end
	end

	-- A milestone with its cats: twice in one frame, then again a second later. Exactly one payout.
	local ready = indexMilestone(true)
	if ready == nil then
		return "CHECK",
			string.format(
				'%d bad calls paid nothing%s; no milestone ready for the double claim, so on the server run %s("fillIndex", nil, "alley", 3) (after %s("resetProfile") if every page is claimed) and run again',
				#bad,
				lockedNote,
				DEBUG,
				DEBUG
			)
	end
	local areaId, milestoneId = ready.areaId, ready.id
	local name = areaId .. " " .. milestoneId
	local prize = Catalog.indexPrizes[areaId][milestoneId]
	local w = freshWallet()
	local s0 = state :: Types.PlayerState
	local held = holdings()
	local bankedBefore = s0.spin.banked
	local luckBefore, speedBefore = s0.goldLuck or 0, s0.baitSpeed or 0
	local bowlBefore = if s0.bait ~= nil then s0.bait.readyAt else nil
	local tier = s0.tier
	local claimAt = os.clock()
	fire("ClaimIndexReward", areaId, milestoneId)
	Remotes.event("ClaimIndexReward"):FireServer(areaId, milestoneId)
	log(
		string.format(
			'    -> ClaimIndexReward("%s", "%s") again in the same frame',
			areaId,
			milestoneId
		)
	)
	waitFor(claimAt, "ProfileSync", 2, function()
		return rewardClaimed(areaId, milestoneId)
	end)
	task.wait(1.1)
	local againAt = os.clock()
	fire("ClaimIndexReward", areaId, milestoneId)
	waitFor(againAt, "Toast", 2)
	task.wait(0.5)
	local paid = rewardToasts(claimAt)
	if paid ~= 1 then
		return "FAIL",
			string.format("%d Index reward toasts for %s claimed three times", paid, name)
	end
	if not rewardClaimed(areaId, milestoneId) then
		return "FAIL", string.format("%s paid but the ProfileSync does not show it claimed", name)
	end
	local s1 = state :: Types.PlayerState
	local toast = ""
	for _, event in since(claimAt, "Toast") do
		if string.find(event.text, "Index reward:", 1, true) ~= nil then
			toast = event.text
		end
	end
	local notes = ""
	-- Coins (F54): at least `coins`, or seconds of the day rate (Prizes.coins); the toast says what was paid.
	local paidCoins = tonumber(string.match(toast, "%+%$(%d+)")) or 0
	if paidCoins < (prize.coins or 0) then
		return "FAIL",
			string.format("%s paid $%d, under its $%d", name, paidCoins, prize.coins or 0)
	end
	local coinsOk, coinsText = coinsMovedBy(w, paidCoins)
	if not coinsOk then
		return "FAIL", string.format("%s toasted $%d but %s", name, paidCoins, coinsText)
	end
	if prize.coinSeconds ~= nil then
		local low = Prizes.coins(
			prize.coins,
			prize.coinSeconds,
			dayRateOf(math.min(w.rate, s1.incomePerSecond))
		)
		local high = Prizes.coins(
			prize.coins,
			prize.coinSeconds,
			dayRateOf(math.max(w.rate, s1.incomePerSecond))
		)
		if paidCoins < low or paidCoins > high + 1 then
			verdict = downgrade(verdict, "CHECK")
			notes ..= string.format(
				", $%d paid where the day rate gives $%d to $%d",
				paidCoins,
				low,
				high
			)
		end
	end
	local prizeLures: { [string]: number } = prize.lures or {}
	for lureId, count in prizeLures do
		local gained = (s1.lures[lureId] or 0) - (held.lures[lureId] or 0)
		if gained ~= count then
			return "FAIL",
				string.format("%s should give %d %s and gave %d", name, count, lureId, gained)
		end
	end
	local gainedFish = fish() - held.fish
	if gainedFish ~= (prize.fish or 0) then
		return "FAIL",
			string.format(
				"%s should pay %d golden fish and paid %d",
				name,
				prize.fish or 0,
				gainedFish
			)
	end
	-- Spins bank up to SpinBankCap and the rest are dropped, which the toast says ("1 of 2 spins (Spins full)").
	local spins = prize.spins or 0
	local banked = s1.spin.banked - bankedBefore
	local fits = math.max(0, math.min(spins, Config.SpinBankCap - bankedBefore))
	if banked ~= fits then
		return "FAIL",
			string.format("%s should bank %d of %d spins and banked %d", name, fits, spins, banked)
	end
	if fits < spins and string.find(toast, "Spins full", 1, true) == nil then
		verdict = downgrade(verdict, "CHECK")
		notes ..= string.format(
			', %d spins dropped at the cap but the toast never said "Spins full"',
			spins - fits
		)
	elseif spins > 0 and fits == spins then
		notes ..= string.format(
			' (bank was %d; %s("spins", nil, %d) first shows the cap)',
			bankedBefore,
			DEBUG,
			Config.SpinBankCap
		)
	end
	-- Crates (F54): banked for the Market; "highest" is the plain crate of the highest zone the tier opens.
	local wantCrates: { [string]: number } = {}
	local prizeCrates: { [string]: number } = prize.crates or {}
	for crateId, count in prizeCrates do
		local paidId = Prizes.crateFor(crateId, tier)
		if paidId == nil then
			return "FAIL",
				string.format("%s names crate %s, which tier %d cannot get", name, crateId, tier)
		end
		wantCrates[paidId] = (wantCrates[paidId] or 0) + count
	end
	for crateId, count in wantCrates do
		local gained = crateCount(crateId) - (held.crates[crateId] or 0)
		if gained ~= count then
			return "FAIL",
				string.format("%s should bank %d %s and banked %d", name, count, crateId, gained)
		end
	end
	-- The forever bonuses come in ProfileSync, capped (GoldLuckMax, BaitSpeedMax).
	local luckWant = math.min(Config.GoldLuckMax, luckBefore + (prize.goldLuck or 0))
	local speedWant = math.min(Config.BaitSpeedMax, speedBefore + (prize.baitSpeed or 0))
	if
		math.abs((s1.goldLuck or 0) - luckWant) > 1e-6
		or math.abs((s1.baitSpeed or 0) - speedWant) > 1e-6
	then
		return "FAIL",
			string.format(
				"%s: gold luck %s and bait speed %s, expected %s and %s",
				name,
				tostring(s1.goldLuck),
				tostring(s1.baitSpeed),
				tostring(luckWant),
				tostring(speedWant)
			)
	end
	-- A claim never moves food already in the bowl: UseLure fixed its readyAt (F54).
	if bowlBefore ~= nil and s1.bait ~= nil and s1.bait.readyAt ~= bowlBefore then
		return "FAIL",
			string.format(
				"%s moved the filling bowl from %d to %d",
				name,
				bowlBefore,
				s1.bait.readyAt
			)
	end
	if bowlBefore ~= nil then
		notes ..= ", the filling bowl kept its time"
	end
	if not toasted(againAt, "Already claimed") then
		verdict = downgrade(verdict, "CHECK")
		notes ..= ', but the third claim got no "Already claimed" toast'
	end
	return verdict,
		string.format(
			'%d bad calls paid nothing%s; %s paid once for three claims ("%s", %s)%s',
			#bad,
			lockedNote,
			name,
			toast,
			coinsText,
			notes
		)
end)

-- Spin Wheel (F49, engineer PR #223, data-model 11c) -------------------------------------------------------------

type Spun = { slice: number, amount: number }

-- The model tagged `tag` nearest the character, or nil.
local function nearestTagged(tag: string): Model?
	local root = rootPart()
	local origin = if root ~= nil then root.Position else Vector3.zero
	local best: Model? = nil
	local bestDistance = math.huge
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsA("Model") and instance:IsDescendantOf(Workspace) then
			local distance = (instance:GetPivot().Position - origin).Magnitude
			if distance < bestDistance then
				best = instance :: Model
				bestDistance = distance
			end
		end
	end
	return best
end

local function spinStation(): Model?
	return nearestTagged("SpinWheel")
end

local function spinsLeft(): number
	return if state ~= nil then Spin.available(state.spin, serverNow()) else 0
end

local function sliceRow(slice: number): Types.SpinSlice?
	for _, row in Catalog.spinWheel do
		if row.slice == slice then
			return row
		end
	end
	return nil
end

-- The SpinResult answers since `startedAt`: the paid ones, and how many were refusals (0, 0).
local function spinAnswers(startedAt: number): ({ Spun }, number)
	local paid: { Spun } = {}
	local refused = 0
	for _, event in since(startedAt, "SpinResult") do
		local spun = event.data :: Spun
		if spun.slice > 0 then
			table.insert(paid, spun)
		else
			refused += 1
		end
	end
	return paid, refused
end

-- True when one paid spin moved coins, the slice's food, golden fish or crate (F54) by exactly what SpinResult said,
-- and the slice and amount are ones the wheel can pay; the text goes on the RESULT line.
local function spinPaid(spun: Spun, before: Wallet, held: Holdings): (boolean, string)
	local row = sliceRow(spun.slice)
	if row == nil then
		return false, string.format("slice %d is not on the wheel", spun.slice)
	end
	if row.kind == "coins" then
		if spun.amount < (row.minCoins or 0) then
			return false,
				string.format("slice %d paid $%d, under its floor", spun.slice, spun.amount)
		end
		local ok, text = coinsMovedBy(before, spun.amount)
		return ok, string.format("slice %d $%d, %s", spun.slice, spun.amount, text)
	end
	if row.kind == "fish" then
		local gained = fish() - held.fish
		local ok = spun.amount == (row.count or 1) and gained == spun.amount
		return ok,
			string.format("slice %d %d golden fish, fish up by %d", spun.slice, spun.amount, gained)
	end
	if row.kind == "crate" then
		local tier = if state ~= nil then state.tier else 1
		local crateId = Prizes.crateFor(row.crate or Prizes.HIGHEST, tier)
		if crateId == nil then
			return false,
				string.format("slice %d names a crate tier %d cannot get", spun.slice, tier)
		end
		local gained = crateCount(crateId) - (held.crates[crateId] or 0)
		local ok = spun.amount == (row.count or 1) and gained == spun.amount
		return ok,
			string.format(
				"slice %d %d %s, banked up by %d",
				spun.slice,
				spun.amount,
				crateId,
				gained
			)
	end
	local lureId = row.lureId :: string
	local gained = (if state ~= nil then state.lures[lureId] or 0 else 0)
		- (held.lures[lureId] or 0)
	local ok = spun.amount == (row.count or 1) and gained == spun.amount
	return ok,
		string.format("slice %d %d %s, food up by %d", spun.slice, spun.amount, lureId, gained)
end

-- Stands the character `studs` from the station's pivot along the ground, trying the front, back and both sides in
-- turn in case one is a wall, and waits for the move to reach the server before anything fires (laptop run
-- 2026-10-27: a spin right after the teleport was measured from the spawn, 12.4 studs out, and paid). Returns how far
-- the character settled, on the ground plane.
local function standFromStation(station: Model, studs: number): number
	local pivot = station:GetPivot()
	local look = Vector3.new(pivot.LookVector.X, 0, pivot.LookVector.Z)
	look = if look.Magnitude > 0.1 then look.Unit else Vector3.xAxis
	local right = Vector3.new(-look.Z, 0, look.X)
	local settled = 0
	local directions: { Vector3 } = { look, -look, right, -right }
	for _, direction in directions do
		teleportTo(pivot.Position + direction * studs)
		task.wait(0.5)
		local root = rootPart()
		settled = if root ~= nil then horizontal(root.Position, pivot.Position) else 0
		if math.abs(settled - studs) <= 2 then
			break
		end
	end
	return settled
end

case("spinWheel", Enum.KeyCode.L, "Spin Wheel: far, double, cooldown, none left", function()
	if state == nil then
		return "SKIP", "no ProfileSync yet"
	end
	if (state :: any).spin == nil then
		return "SKIP", "the ProfileSync carries no spin (needs engineer PR #223)"
	end
	local station = spinStation()
	if station == nil then
		return "SKIP", "no station tagged SpinWheel in the world"
	end
	local root = rootPart()
	local home = if root ~= nil then root.Position else nil
	local function done(verdict: Verdict, detail: string): (Verdict, string)
		if home ~= nil then
			teleportTo(home)
		end
		return verdict, detail
	end

	-- 20 studs out (SpinStationRange is 14): refused with SpinResult(0, 0), nothing paid, no spin used.
	local far = standFromStation(station, 20)
	if far < Config.SpinStationRange + 4 then
		return done(
			"CHECK",
			string.format(
				"could not stand 20 studs from the wheel on any side (settled %.1f studs out); stand there and run again",
				far
			)
		)
	end
	local w = freshWallet()
	local f, left = holdingsText(holdings()), spinsLeft()
	local farAt = os.clock()
	fire("SpinWheel")
	local farAnswer = waitFor(farAt, "SpinResult", 2)
	task.wait(0.5)
	local farPaid = spinAnswers(farAt)
	if
		#farPaid > 0
		or money() - w.money > incomeSince(w)
		or holdingsText(holdings()) ~= f
		or spinsLeft() ~= left
	then
		return done("FAIL", string.format("a SpinWheel from %.1f studs paid or used a spin", far))
	end
	local verdict: Verdict = if farAnswer ~= nil then "PASS" else "CHECK"
	local notes = if farAnswer ~= nil
		then string.format("%.1f studs refused", far)
		else string.format("%.1f studs paid nothing but got no SpinResult(0, 0)", far)

	-- Beside the wheel: two spins in one frame. One paid answer, one refusal, one spin used.
	local near = standFromStation(station, 6)
	if near > Config.SpinStationRange - 4 then
		return done(
			"CHECK",
			string.format(
				"%s; could not stand by the wheel (settled %.1f studs out); stand there and run again",
				notes,
				near
			)
		)
	end
	if spinsLeft() < 1 then
		return done(
			"CHECK",
			string.format(
				'%s; no spin left for the rest, so on the server run %s("spins", nil, 1, true) and run again',
				notes,
				DEBUG
			)
		)
	end
	w = freshWallet()
	left = spinsLeft()
	local held = holdings()
	local spinAt = os.clock()
	fire("SpinWheel")
	Remotes.event("SpinWheel"):FireServer()
	log("    -> SpinWheel() again in the same frame")
	waitFor(spinAt, "ProfileSync", 2, function()
		return spinsLeft() < left
	end)
	task.wait(0.5)
	local paid, refused = spinAnswers(spinAt)
	if #paid ~= 1 then
		return done(
			"FAIL",
			string.format("%d paid SpinResults for two SpinWheel calls in one frame", #paid)
		)
	end
	if spinsLeft() ~= left - 1 then
		return done(
			"FAIL",
			string.format("spins went from %d to %d for one paid spin", left, spinsLeft())
		)
	end
	local ok, paidText = spinPaid(paid[1], w, held)
	if not ok then
		return done("FAIL", paidText)
	end
	notes ..= string.format("; double spin paid once (%s)", paidText)
	if refused ~= 1 then
		verdict = downgrade(verdict, "CHECK")
		notes ..= string.format(", %d SpinResult(0, 0) for the second call", refused)
	end
	if station:GetAttribute("LastSlice") ~= paid[1].slice then
		verdict = downgrade(verdict, "CHECK")
		notes ..= string.format(
			", but the station's LastSlice is %s",
			tostring(station:GetAttribute("LastSlice"))
		)
	end

	-- Inside SpinCooldownSeconds: refused, even with a spin left.
	local coolAt = os.clock()
	fire("SpinWheel")
	waitFor(coolAt, "SpinResult", 2)
	if #(spinAnswers(coolAt)) > 0 then
		return done("FAIL", string.format("a spin %.1f s after the last one paid", coolAt - spinAt))
	end
	notes ..= string.format("; %.1f s later refused (%d left)", coolAt - spinAt, spinsLeft())

	-- After the cooldown: a spin left pays once; with none left the spin is refused.
	local function afterCooldown()
		local wait = spinAt + Config.SpinCooldownSeconds + 0.5 - os.clock()
		if wait > 0 then
			task.wait(wait)
		end
	end
	if spinsLeft() >= 1 then
		afterCooldown()
		w = freshWallet()
		held = holdings()
		left = spinsLeft()
		spinAt = os.clock()
		fire("SpinWheel")
		waitFor(spinAt, "ProfileSync", 2, function()
			return spinsLeft() < left
		end)
		task.wait(0.3)
		local later = spinAnswers(spinAt)
		if #later ~= 1 then
			return done(
				"FAIL",
				string.format("%d paid SpinResults after the cooldown with %d left", #later, left)
			)
		end
		local nextOk, nextText = spinPaid(later[1], w, held)
		if not nextOk then
			return done("FAIL", nextText)
		end
		notes ..= string.format("; after the cooldown paid once (%s)", nextText)
	end
	if spinsLeft() >= 1 then
		return done(
			verdict,
			string.format(
				'%s; %d spins still left, so the none-left refusal was not tried (%s("spins", nil, 1, true) leaves two)',
				notes,
				spinsLeft(),
				DEBUG
			)
		)
	end
	afterCooldown()
	w = freshWallet()
	f = holdingsText(holdings())
	local noneAt = os.clock()
	fire("SpinWheel")
	local noneAnswer = waitFor(noneAt, "SpinResult", 2)
	task.wait(0.3)
	if
		#(spinAnswers(noneAt)) > 0
		or money() - w.money > incomeSince(w)
		or holdingsText(holdings()) ~= f
	then
		return done("FAIL", "a spin with none left paid")
	end
	if noneAnswer == nil then
		verdict = downgrade(verdict, "CHECK")
		notes ..= "; none left paid nothing but got no SpinResult(0, 0)"
	else
		notes ..= "; none left refused"
	end
	return done(verdict, notes)
end)

-- Golden Fish Market (F53, engineer PR #316, golden-fish.md sections 3, 4 and 8) ---------------------------------

-- What CrateResult carries: decorId "" when the open was refused.
type Opened = { crateId: string, decorId: string, duplicate: boolean, refund: number }

local function crateAnswers(startedAt: number): ({ Opened }, number)
	local opened: { Opened } = {}
	local refused = 0
	for _, event in since(startedAt, "CrateResult") do
		local answer = event.data :: Opened
		if answer.decorId ~= "" then
			table.insert(opened, answer)
		else
			refused += 1
		end
	end
	return opened, refused
end

local function perkLevel(perkId: string): number
	return if state ~= nil and state.fishPerks ~= nil then state.fishPerks[perkId] or 0 else 0
end

-- Fish, crates, foods, pieces owned, crate luck and perk levels in one line, so a case can tell that a refused call
-- changed none of them.
local function marketHoldings(): string
	local s = state
	if s == nil then
		return "no ProfileSync"
	end
	local owned, luck, perks = 0, 0, 0
	for _, flag in s.decorOwned do
		owned += if flag then 1 else 0
	end
	for _, count in s.crateLuck do
		luck += count
	end
	for _, level in s.fishPerks do
		perks += level
	end
	return string.format(
		"%s, %d pieces, %d crate luck, %d perk levels",
		holdingsText(holdings()),
		owned,
		luck,
		perks
	)
end

local function toastCount(startedAt: number, text: string): number
	local count = 0
	for _, event in since(startedAt, "Toast") do
		if string.find(event.text, text, 1, true) ~= nil then
			count += 1
		end
	end
	return count
end

-- A crate the player could open now: a banked one in an open zone (plain first), else a plain one they can buy.
local function openableCrate(): Types.CrateDef?
	local s = state
	if s == nil then
		return nil
	end
	local function open(crate: Types.CrateDef): boolean
		if crate.area == "classic" then
			return true
		end
		local area = Catalog.getArea(crate.area)
		return area ~= nil and s.tier >= area.tier
	end
	for _, golden in { false, true } do
		for _, crate in Catalog.crates do
			if crate.golden == golden and open(crate) and crateCount(crate.id) > 0 then
				return crate
			end
		end
	end
	for _, crate in Catalog.crates do
		if not crate.golden and open(crate) and fish() >= (crate.price or math.huge) then
			return crate
		end
	end
	return nil
end

case(
	"fishMarket",
	Enum.KeyCode.P,
	"Golden Fish Market: far, bad ids, locked, double open, perk past max",
	function()
		if state == nil then
			return "SKIP", "no ProfileSync yet"
		end
		if (state :: any).crates == nil then
			return "SKIP", "the ProfileSync carries no crates (needs engineer PR #316)"
		end
		local stall = nearestTagged("FishMarket")
		if stall == nil then
			return "SKIP", "no stall tagged FishMarket in the world"
		end
		local root = rootPart()
		local home = if root ~= nil then root.Position else nil
		local function done(verdict: Verdict, detail: string): (Verdict, string)
			if home ~= nil then
				teleportTo(home)
			end
			return verdict, detail
		end
		local verdict: Verdict = "PASS"

		-- 24 studs out (FishMarketRange is 14): both remotes refused, nothing opened or bought.
		local far = standFromStation(stall, 24)
		if far < Config.FishMarketRange + 4 then
			return done(
				"CHECK",
				string.format(
					"could not stand 24 studs from the stall on any side (settled %.1f studs out); stand there and run again",
					far
				)
			)
		end
		local held = marketHoldings()
		local farAt = os.clock()
		fire("OpenCrate", "alley_crate")
		task.wait(1.1)
		fire("BuyFishItem", "star_treat")
		task.wait(1)
		if #(crateAnswers(farAt)) > 0 or marketHoldings() ~= held then
			return done(
				"FAIL",
				string.format(
					"a Market call from %.1f studs opened or bought something: %s before, %s after",
					far,
					held,
					marketHoldings()
				)
			)
		end
		local walks = toastCount(farAt, "Walk to the Golden Fish Market first")
		local notes = string.format("%.1f studs refused", far)
		if walks ~= 2 then
			verdict = downgrade(verdict, "CHECK")
			notes ..= string.format(
				' with %d of 2 "Walk to the Golden Fish Market first" toasts',
				walks
			)
		end

		-- Beside the stall: bad ids for both remotes, nothing opens or sells.
		local near = standFromStation(stall, 6)
		if near > Config.FishMarketRange - 4 then
			return done(
				"CHECK",
				string.format(
					"%s; could not stand by the stall (settled %.1f studs out); stand there and run again",
					notes,
					near
				)
			)
		end
		local badIds: { { any } } = {
			{},
			{ "" },
			{ "ALLEY_CRATE" },
			{ "moon_crate" },
			{ "alley_crate " },
			{ string.rep("a", 300) },
			{ 7 },
			{ 0 / 0 },
			{ {} },
			{ true },
		}
		held = marketHoldings()
		local badAt = os.clock()
		for _, args in badIds do
			fire("OpenCrate", table.unpack(args))
			task.wait(1.1)
		end
		local badBuys: { { any } } = table.clone(badIds)
		table.insert(badBuys, { "alley_crate" }) -- a crate row: crates open through OpenCrate
		table.insert(badBuys, { "alley_golden_crate" })
		table.insert(badBuys, { "kibble" }) -- a food the Market does not sell
		for _, args in badBuys do
			fire("BuyFishItem", table.unpack(args))
			task.wait(0.6)
		end
		task.wait(0.5)
		if #(crateAnswers(badAt)) > 0 or marketHoldings() ~= held then
			return done(
				"FAIL",
				string.format(
					"a bad Market id opened or bought something: %s before, %s after",
					held,
					marketHoldings()
				)
			)
		end
		notes ..= string.format("; %d bad ids paid nothing", #badIds + #badBuys)

		-- Blocked opens: a zone the tier has not opened, a golden crate with none banked, a plain crate without
		-- the fish. Each answers CrateResult with "" and a toast that says why.
		local s = state :: Types.PlayerState
		local blocked: { { id: string, text: string } } = {}
		for _, crate in Catalog.crates do
			local area = if crate.area ~= "classic" then Catalog.getArea(crate.area) else nil
			local locked = area ~= nil and s.tier < area.tier
			if locked and #blocked == 0 then
				table.insert(blocked, { id = crate.id, text = "Unlock this zone first" })
			end
		end
		for _, crate in Catalog.crates do
			local area = if crate.area ~= "classic" then Catalog.getArea(crate.area) else nil
			local open = area == nil or s.tier >= area.tier
			if crate.golden and open and crateCount(crate.id) == 0 then
				table.insert(blocked, { id = crate.id, text = "Golden crates come from the Index" })
				break
			end
		end
		if crateCount("alley_crate") == 0 and fish() < 60 then
			table.insert(blocked, { id = "alley_crate", text = "Not enough golden fish" })
		end
		held = marketHoldings()
		for _, entry in blocked do
			local at = os.clock()
			fire("OpenCrate", entry.id)
			local answer = waitFor(at, "CrateResult", 2)
			task.wait(1.1)
			if #(crateAnswers(at)) > 0 or marketHoldings() ~= held then
				return done(
					"FAIL",
					string.format("%s opened when it should say %q", entry.id, entry.text)
				)
			end
			if answer == nil or not toasted(at, entry.text) then
				verdict = downgrade(verdict, "CHECK")
				notes ..= string.format(", %s refused but not with %q", entry.id, entry.text)
			else
				notes ..= string.format(", %s %q", entry.id, entry.text)
			end
		end

		-- One open: twice in one frame (OpenCrate allows 1 a second), then again inside CrateOpenCooldownSeconds.
		-- One piece, paid once.
		local crate = openableCrate()
		if crate == nil then
			return done(
				if verdict == "PASS" then "CHECK" else verdict,
				string.format(
					'%s; nothing to open, so on the server run %s("giveCrate", nil, "alley_crate", 3) or %s("setFish", nil, 1000) and run again',
					notes,
					DEBUG,
					DEBUG
				)
			)
		end
		s = state :: Types.PlayerState
		local bankedBefore = crateCount(crate.id)
		local fishBefore = fish()
		local luckBefore = s.crateLuck[crate.area] or 0
		local ownedBefore = table.clone(s.decorOwned)
		local openAt = os.clock()
		fire("OpenCrate", crate.id)
		Remotes.event("OpenCrate"):FireServer(crate.id)
		log(string.format('    -> OpenCrate("%s") again in the same frame', crate.id))
		waitFor(openAt, "CrateResult", 3, function(event: Event): boolean
			return (event.data :: Opened).decorId ~= ""
		end)
		task.wait(1.1)
		local coolAt = os.clock()
		fire("OpenCrate", crate.id)
		waitFor(coolAt, "CrateResult", 2)
		task.wait(0.5)
		local opened = crateAnswers(openAt)
		if #opened ~= 1 then
			return done(
				"FAIL",
				string.format("%d pieces for three OpenCrate(%s) calls in 1.1 s", #opened, crate.id)
			)
		end
		local piece = opened[1]
		local def = Catalog.getDecor(piece.decorId)
		if def == nil or def.crate ~= crate.area then
			return done(
				"FAIL",
				string.format("%s gave %q, not one of its pool's pieces", crate.id, piece.decorId)
			)
		end
		local rarity = def.rarity or "Common"
		local rank = Catalog.rarityRank[rarity] or 0
		if crate.golden and rank < Catalog.rarityRank.Epic then
			return done("FAIL", string.format("%s gave a %s piece", crate.id, rarity))
		end
		local wasOwned = ownedBefore[piece.decorId] == true
		local refund = if wasOwned then Config.CrateDuplicateRefund[rarity] or 0 else 0
		if piece.duplicate ~= wasOwned or piece.refund ~= refund then
			return done(
				"FAIL",
				string.format(
					"%s: duplicate=%s refund %d for a piece %s, expected refund %d",
					piece.decorId,
					tostring(piece.duplicate),
					piece.refund,
					if wasOwned then "already owned" else "new",
					refund
				)
			)
		end
		local paidWith = if bankedBefore > 0 then "a banked crate" else "fish"
		local wantFish = fishBefore + refund - (if bankedBefore > 0 then 0 else crate.price or 0)
		local wantBanked = if bankedBefore > 0 then bankedBefore - 1 else 0
		if fish() ~= wantFish or crateCount(crate.id) ~= wantBanked then
			return done(
				"FAIL",
				string.format(
					"%s paid with %s: fish %d -> %d (expected %d), banked %d -> %d (expected %d)",
					crate.id,
					paidWith,
					fishBefore,
					fish(),
					wantFish,
					bankedBefore,
					crateCount(crate.id),
					wantBanked
				)
			)
		end
		s = state :: Types.PlayerState
		local luckWant = if rank >= Catalog.rarityRank.Epic
			then 0
			else math.min(luckBefore + 1, Config.CrateLuckyEvery - 1)
		if (s.crateLuck[crate.area] or 0) ~= luckWant or s.decorOwned[piece.decorId] ~= true then
			return done(
				"FAIL",
				string.format(
					"after a %s piece the %s luck is %d (expected %d) and owned=%s",
					rarity,
					crate.area,
					s.crateLuck[crate.area] or 0,
					luckWant,
					tostring(s.decorOwned[piece.decorId])
				)
			)
		end
		notes ..= string.format(
			"; double open paid once with %s (%s %s%s)",
			paidWith,
			rarity,
			piece.decorId,
			if wasOwned then string.format(", duplicate +%d fish", refund) else ""
		)
		if not toasted(coolAt, "One crate at a time") then
			verdict = downgrade(verdict, "CHECK")
			notes ..= ', but the open 1.1 s later got no "One crate at a time"'
		end

		-- Perks: one at its top level is refused; one level short of the top, two buys in one frame (the limit
		-- allows 2 a second) take exactly one level and its cost.
		local maxed: Types.FishShopRow? = nil
		local last: Types.FishShopRow? = nil
		for _, row in Catalog.fishShop do
			if row.kind ~= "perk" then
				continue
			end
			local level = perkLevel(row.id)
			local top = row.maxLevel or 1
			if level >= top and maxed == nil then
				maxed = row
			elseif level == top - 1 and last == nil then
				last = row
			end
		end
		if last ~= nil then
			local perkId = last.id
			local costs = last.costs or {}
			local cost = costs[perkLevel(perkId) + 1] or math.huge
			if fish() >= cost then
				local levelBefore, fishAt = perkLevel(perkId), fish()
				local buyAt = os.clock()
				fire("BuyFishItem", perkId)
				Remotes.event("BuyFishItem"):FireServer(perkId)
				log(string.format('    -> BuyFishItem("%s") again in the same frame', perkId))
				waitFor(buyAt, "ProfileSync", 2, function()
					return perkLevel(perkId) > levelBefore
				end)
				task.wait(0.6)
				if perkLevel(perkId) ~= levelBefore + 1 or fish() ~= fishAt - cost then
					return done(
						"FAIL",
						string.format(
							"two BuyFishItem(%s) in a frame: level %d -> %d, fish %d -> %d (cost %d)",
							perkId,
							levelBefore,
							perkLevel(perkId),
							fishAt,
							fish(),
							cost
						)
					)
				end
				notes ..= string.format(
					"; %s bought once for %d fish from two calls (yours forever in this Studio save)",
					perkId,
					cost
				)
				maxed = maxed or last
			end
		end
		if maxed ~= nil then
			held = marketHoldings()
			local topAt = os.clock()
			fire("BuyFishItem", maxed.id)
			task.wait(1)
			if marketHoldings() ~= held then
				return done(
					"FAIL",
					string.format(
						"%s at its top level sold another: %s",
						maxed.id,
						marketHoldings()
					)
				)
			end
			if not toasted(topAt, "Already at the top level") then
				verdict = downgrade(verdict, "CHECK")
				notes ..= string.format(
					', %s at the top refused but not with "Already at the top level"',
					maxed.id
				)
			else
				notes ..= string.format(", %s at the top refused", maxed.id)
			end
		else
			notes ..= string.format(
				'; no perk at or one short of its top level, so the past-max buy was not tried (%s("setFish", nil, 1000) lets this case buy the Big Bowl)',
				DEBUG
			)
		end
		return done(verdict, notes)
	end
)

-- Codes Cat (F65, engineer PRs #318 and #319, data-model section 11d) ---------------------------------------------

-- What CodeResult carries: whether it paid, the code box's message and the prize when it paid.
type Answered = { ok: boolean, message: string, prize: Types.IndexPrize? }

local function codeAnswers(startedAt: number): { Answered }
	local answers: { Answered } = {}
	for _, event in since(startedAt, "CodeResult") do
		table.insert(answers, event.data :: Answered)
	end
	return answers
end

local function bankedSpins(): number
	return if state ~= nil and state.spin ~= nil then state.spin.banked else 0
end

-- Foods, golden fish, crates and banked spins in one line, so a case can tell that a refused code paid none of them.
-- Coins are checked apart with coinsMovedBy, since income moves them on its own.
local function codeHoldings(): string
	return string.format("%s, %d banked spins", holdingsText(holdings()), bankedSpins())
end

-- One RedeemCode and its answer's message ("no answer" when none came in 2 s), spaced so the next call clears
-- the remote's limit of 1 per 2 s.
local function redeem(text: any): string
	local at = os.clock()
	fire("RedeemCode", text)
	local answer = waitFor(at, "CodeResult", 2)
	task.wait(math.max(0, at + 2.1 - os.clock()))
	return if answer ~= nil then (answer.data :: Answered).message else "no answer"
end

-- True when the prize moved coins, foods, golden fish, crates and banked spins by exactly what it pays (spins up to
-- SpinBankCap, crates by Prizes.crateFor at the player's tier); the text goes on the RESULT line.
local function codePaid(
	prize: Types.IndexPrize,
	before: Wallet,
	held: Holdings,
	banked: number
): (boolean, string)
	local dayRate = before.rate
	local coinsOk, coinsText =
		coinsMovedBy(before, Prizes.coins(prize.coins, prize.coinSeconds, dayRate))
	local wrong: { string } = {}
	local prizeLures: { [string]: number } = prize.lures or {}
	local now = state
	for lureId, count in prizeLures do
		local gained = (if now ~= nil then now.lures[lureId] or 0 else 0)
			- (held.lures[lureId] or 0)
		if gained ~= count then
			table.insert(wrong, string.format("%s up by %d of %d", lureId, gained, count))
		end
	end
	local gainedFish = fish() - held.fish
	if gainedFish ~= (prize.fish or 0) then
		table.insert(
			wrong,
			string.format("golden fish up by %d of %d", gainedFish, prize.fish or 0)
		)
	end
	local tier = if state ~= nil then state.tier else 1
	local wantCrates: { [string]: number } = {}
	local prizeCrates: { [string]: number } = prize.crates or {}
	for crateId, count in prizeCrates do
		local paidId = Prizes.crateFor(crateId, tier)
		if paidId ~= nil then
			wantCrates[paidId] = (wantCrates[paidId] or 0) + count
		end
	end
	for crateId, count in wantCrates do
		local gained = crateCount(crateId) - (held.crates[crateId] or 0)
		if gained ~= count then
			table.insert(wrong, string.format("%s up by %d of %d", crateId, gained, count))
		end
	end
	local wantSpins = math.min(Config.SpinBankCap, banked + (prize.spins or 0)) - banked
	if bankedSpins() - banked ~= wantSpins then
		table.insert(
			wrong,
			string.format("banked spins up by %d of %d", bankedSpins() - banked, wantSpins)
		)
	end
	if not coinsOk then
		table.insert(wrong, coinsText)
	end
	if #wrong > 0 then
		return false, table.concat(wrong, ", ")
	end
	return true,
		string.format("%s, %s, %d banked spins", coinsText, holdingsText(holdings()), bankedSpins())
end

-- The Fresh Catch shelf (F94, rewards-and-shops.md section 3, engineer PR #679): potions and now and then a cheap
-- Classic Crate for golden fish, by day, at the Golden Fish Market, each row up to its amount per player per stock
-- window. BuyFreshCatch(itemId, window) sends back the window the player saw; the server answers every call that gets
-- past its argument checks with a FreshCatchStock, and refuses with a warn toast.

local function freshWindow(): number
	local stock = freshStock
	return if stock ~= nil then stock.window else FreshCatch.window(math.floor(serverNow()))
end

-- Potions in the bag and crates in the bank, what a Fresh Catch buy adds to.
local function freshHeld(): string
	local s: any = state
	if s == nil then
		return "no ProfileSync"
	end
	local potions = 0
	for _, count in s.potions or {} do
		potions += count
	end
	local crates = 0
	for _, count in s.crates or {} do
		crates += count
	end
	return string.format("%d potions, %d crates, %d golden fish", potions, crates, fish())
end

-- This window's amount and my buys of `itemId`, from the newest FreshCatchStock.
local function freshRow(itemId: string): (number, number)
	local stock = freshStock
	if stock == nil then
		return FreshCatch.amountOf(freshWindow(), itemId), 0
	end
	for _, item in stock.stock do
		if item.itemId == itemId then
			return item.amount, item.bought
		end
	end
	return 0, 0
end

case(
	"freshCatch",
	Enum.KeyCode.O,
	"Fresh Catch: far, bad ids and windows, a stale window, past the amount, without the fish, 5 in a frame, at night",
	function()
		if state == nil then
			return "SKIP", "no ProfileSync yet"
		end
		local stall = nearestTagged("FishMarket")
		if stall == nil then
			return "SKIP", "no stall tagged FishMarket in the world"
		end
		local root = rootPart()
		local home = if root ~= nil then root.Position else nil
		local notes = {}
		local verdict: Verdict = "PASS"
		local function done(level: Verdict, detail: string?): (Verdict, string)
			if detail ~= nil then
				table.insert(notes, detail)
			end
			if home ~= nil then
				teleportTo(home)
			end
			return downgrade(verdict, level), table.concat(notes, "; ")
		end
		local clock = ReplicatedStorage:FindFirstChild("Clock")
		local night = clock ~= nil and clock:GetAttribute("Phase") == "night"
		local window = freshWindow()
		-- a row in stock this window, the cheapest first
		local pick: Types.FreshCatchRow? = nil
		for _, row in Catalog.freshCatch do
			if FreshCatch.amountOf(window, row.id) > 0 and (pick == nil or row.fish < (pick :: any).fish) then
				pick = row
			end
		end
		local itemId = if pick ~= nil then pick.id else Catalog.freshCatch[1].id

		-- 24 studs out (FishMarketRange is 14): refused, nothing bought.
		local far = standFromStation(stall, 24)
		if far < Config.FishMarketRange + 4 then
			return done("CHECK", string.format("could not stand 24 studs from the stall (settled %.1f studs out)", far))
		end
		local held = freshHeld()
		local farAt = os.clock()
		fire("BuyFreshCatch", itemId, window)
		task.wait(1)
		if freshHeld() ~= held then
			return done(
				"FAIL",
				string.format("a buy from %.1f studs went through: %s, then %s", far, held, freshHeld())
			)
		end
		local farText = if night then "The Fresh Catch is back at sunrise" else "Walk to the Golden Fish Market first"
		if toastCount(farAt, farText) ~= 1 then
			verdict = downgrade(verdict, "CHECK")
			table.insert(notes, string.format('far buy: no "%s" toast', farText))
		else
			table.insert(notes, string.format("far buy from %.1f studs refused", far))
		end

		local near = standFromStation(stall, 6)
		if near > Config.FishMarketRange - 4 then
			return done("CHECK", string.format("could not stand by the stall (settled %.1f studs out)", near))
		end

		-- At night every buy is refused; the rest needs the day.
		if night then
			local nightAt = os.clock()
			held = freshHeld()
			fire("BuyFreshCatch", itemId, window)
			task.wait(1)
			if freshHeld() ~= held then
				return done("FAIL", "a Fresh Catch buy went through at night")
			end
			if toastCount(nightAt, "back at sunrise") ~= 1 then
				return done("CHECK", 'night buy: refused, but no "back at sunrise" toast')
			end
			return done(
				"CHECK",
				string.format(
					'night buy refused; run again by day for the rest (%s("setPhase", "day"))',
					DEBUG
				)
			)
		end

		-- Bad ids and bad windows, 0.55 s apart (2 calls a second): nothing bought. Malformed arguments get only a
		-- FreshCatchStock; a well-formed id off the board gets "That isn't on the Fresh Catch board."
		local bad: { { any } } = {
			{},
			{ "" },
			{ "GOLD_RUSH_POTION" },
			{ "kibble" },
			{ string.rep("a", 300) },
			{ 7 },
			{ 0 / 0 },
			{ {} },
			{ true },
			{ itemId },
			{ itemId, "x" },
			{ itemId, -1 },
			{ itemId, 1.5 },
			{ itemId, 2 ^ 41 },
			{ itemId, 0 / 0 },
		}
		held = freshHeld()
		local badAt = os.clock()
		for _, args in bad do
			fire("BuyFreshCatch", table.unpack(args))
			task.wait(0.55)
		end
		task.wait(0.5)
		if freshHeld() ~= held then
			return done("FAIL", string.format("a bad id or window bought something: %s, then %s", held, freshHeld()))
		end
		local offBoard = toastCount(badAt, "isn't on the Fresh Catch board")
		table.insert(
			notes,
			string.format("%d bad ids and windows bought nothing (%d off the board toasts)", #bad, offBoard)
		)

		-- A stale window: the stock the player saw has rolled over.
		local staleAt = os.clock()
		fire("BuyFreshCatch", itemId, freshWindow() - 1)
		task.wait(0.8)
		if freshHeld() ~= held then
			return done("FAIL", "a buy with last window's number went through")
		end
		if toastCount(staleAt, "A fresh catch just came in") ~= 1 then
			verdict = downgrade(verdict, "CHECK")
			table.insert(notes, 'stale window: refused, but no "A fresh catch just came in" toast')
		else
			table.insert(notes, "stale window refused")
		end

		-- Five in one frame: at most two answered (2 a second).
		local burstAt = os.clock()
		for _ = 1, 5 do
			Remotes.event("BuyFreshCatch"):FireServer("kibble", freshWindow())
		end
		log('    -> BuyFreshCatch("kibble", window) x5 in one frame')
		task.wait(1.2)
		local answered = toastCount(burstAt, "isn't on the Fresh Catch board")
		if answered > 2 then
			verdict = downgrade(verdict, "FAIL")
			table.insert(notes, string.format("%d of 5 in one frame answered; the limit is 2 a second", answered))
		else
			table.insert(notes, string.format("5 in one frame: %d answered", answered))
		end

		-- Past the amount: buy the cheapest row in stock up to its amount, then once more; with too few fish for it,
		-- "Not enough golden fish" and nothing bought.
		if pick == nil then
			return done("CHECK", "no row in stock this window, so the amount checks wait for the next one")
		end
		local row = pick :: Types.FreshCatchRow
		local amount, bought = freshRow(row.id)
		local left = amount - bought
		if fish() < row.fish then
			local poorAt = os.clock()
			held = freshHeld()
			fire("BuyFreshCatch", row.id, freshWindow())
			task.wait(0.8)
			if freshHeld() ~= held then
				return done(
					"FAIL",
					string.format("bought %s with %d golden fish (it costs %d)", row.id, fish(), row.fish)
				)
			end
			if toastCount(poorAt, "Not enough golden fish") ~= 1 then
				verdict = downgrade(verdict, "CHECK")
				table.insert(notes, 'too few fish: refused, but no "Not enough golden fish" toast')
			else
				table.insert(notes, string.format("%s with %d golden fish refused", row.id, fish()))
			end
			return done(
				"CHECK",
				string.format(
					'for the amount checks, %s("setFish", nil, %d) and run again',
					DEBUG,
					row.fish * (left + 1)
				)
			)
		end
		local fishBefore = fish()
		local boughtNow = 0
		for _ = 1, left do
			if fish() < row.fish then
				break
			end
			local buyAt = os.clock()
			fire("BuyFreshCatch", row.id, freshWindow())
			waitFor(buyAt, "FreshCatchStock", 1.5)
			task.wait(0.55) -- 2 a second
			if toastCount(buyAt, "Bought a") == 1 then
				boughtNow += 1
			end
		end
		local overAt = os.clock()
		held = freshHeld()
		fire("BuyFreshCatch", row.id, freshWindow())
		task.wait(0.8)
		if boughtNow == left and freshHeld() ~= held then
			return done("FAIL", string.format("bought %s past its amount of %d", row.id, amount))
		end
		local spent = fishBefore - fish()
		if spent ~= boughtNow * row.fish then
			verdict = downgrade(verdict, "FAIL")
			table.insert(
				notes,
				string.format(
					"%d buys of %s cost %d golden fish, not %d",
					boughtNow,
					row.id,
					spent,
					boughtNow * row.fish
				)
			)
		end
		if boughtNow == left and toastCount(overAt, "You bought") ~= 1 then
			verdict = downgrade(verdict, "CHECK")
			table.insert(notes, 'past the amount: refused, but no "You bought ... this time" toast')
		end
		table.insert(
			notes,
			string.format(
				"%s: %d left of %d this window, bought %d for %d fish, the next refused",
				row.id,
				left,
				amount,
				boughtNow,
				spent
			)
		)
		return done(verdict)
	end
)

case(
	"codes",
	Enum.KeyCode.T,
	"Codes Cat: far, bad texts, the wrong-code lock, a double redeem, used and expired codes",
	function()
		if state == nil then
			return "SKIP", "no ProfileSync yet"
		end
		local playtest = Catalog.codes.playtest
		if playtest == nil then
			return "SKIP", "Catalog.codes has no playtest code (needs engineer PR #318)"
		end
		local station = nearestTagged(Codes.TAG)
		if station == nil then
			return "SKIP", "no station tagged CodesCat in the world"
		end
		local root = rootPart()
		local home = if root ~= nil then root.Position else nil
		local function done(verdict: Verdict, detail: string): (Verdict, string)
			if home ~= nil then
				teleportTo(home)
			end
			return verdict, detail
		end
		local verdict: Verdict = "PASS"
		local reset = string.format('%s("codes")', DEBUG)

		-- 24 studs out (CodesCatRange is 12, flat): the real code is refused and pays nothing. The server measures
		-- before it reads the text, so this try does not count towards the lock.
		local far = standFromStation(station, 24)
		if far < Config.CodesCatRange + 4 then
			return done(
				"CHECK",
				string.format(
					"could not stand 24 studs from the Codes Cat on any side (settled %.1f studs out); stand there and run again",
					far
				)
			)
		end
		local before = freshWallet()
		local held = codeHoldings()
		local farAnswer = redeem("playtest")
		local coinsStill, coinsText = coinsMovedBy(before, 0)
		if codeHoldings() ~= held or not coinsStill then
			return done(
				"FAIL",
				string.format(
					'RedeemCode("playtest") from %.1f studs paid: %s before, %s after, %s',
					far,
					held,
					codeHoldings(),
					coinsText
				)
			)
		end
		if farAnswer == Codes.LOCKED then
			return done(
				"CHECK",
				string.format(
					"the box is locked from an earlier run; wait a minute or run %s on the server, then run again",
					reset
				)
			)
		end
		local notes = string.format("%.1f studs refused", far)
		if farAnswer ~= Codes.FAR then
			verdict = downgrade(verdict, "CHECK")
			notes ..= string.format(' with %q, not "%s"', farAnswer, Codes.FAR)
		end

		-- In the circle (6 studs in front of the station): CodeWrongLimit texts that are not codes, malformed ones
		-- first, since they must count as wrong too or a guesser could send them for free. All but the last answer
		-- "That code doesn't exist"; the last locks the box for CodeLockSeconds.
		local near = standFromStation(station, 6)
		if near > Config.CodesCatRange - 4 then
			return done(
				"CHECK",
				string.format(
					"%s; could not stand by the Codes Cat (settled %.1f studs out); stand there and run again",
					notes,
					near
				)
			)
		end
		local badTexts: { any } = {
			5,
			{},
			string.rep("a", Codes.MAX_BYTES + 1),
			"play test",
			"nopenope",
		}
		while #badTexts < Config.CodeWrongLimit do
			table.insert(badTexts, "nope" .. #badTexts)
		end
		before = freshWallet()
		held = codeHoldings()
		local wrongAt = os.clock()
		local answers: { string } = {}
		local lockedAt = 0
		for index = 1, Config.CodeWrongLimit do
			local answer = redeem(badTexts[index])
			table.insert(answers, answer)
			if answer == Codes.LOCKED then
				lockedAt = os.clock()
				break
			end
		end
		for _, answered in codeAnswers(wrongAt) do
			if answered.ok then
				return done(
					"FAIL",
					string.format("%s; a text that is not a code paid: %q", notes, answered.message)
				)
			end
		end
		coinsStill, coinsText = coinsMovedBy(before, 0)
		if codeHoldings() ~= held or not coinsStill then
			return done(
				"FAIL",
				string.format(
					"%s; wrong codes paid: %s before, %s after, %s",
					notes,
					held,
					codeHoldings(),
					coinsText
				)
			)
		end
		local said = table.concat(answers, " | ")
		if lockedAt == 0 then
			return done(
				"FAIL",
				string.format(
					"%s; %d wrong codes in %.0f s never locked the box (%s), so codes can be guessed",
					notes,
					#answers,
					os.clock() - wrongAt,
					said
				)
			)
		end
		if #answers < Config.CodeWrongLimit then
			verdict = downgrade(verdict, "CHECK")
			notes ..= string.format(
				"; locked after %d of %d wrong codes (%s): a wrong code from the last minute may have counted, wait a minute and run again",
				#answers,
				Config.CodeWrongLimit,
				said
			)
		else
			for index = 1, #answers - 1 do
				if answers[index] ~= Codes.UNKNOWN then
					verdict = downgrade(verdict, "CHECK")
					notes ..= string.format(
						'; wrong code %d said %q, not "%s"',
						index,
						answers[index],
						Codes.UNKNOWN
					)
				end
			end
			notes ..= string.format(
				"; %d wrong codes paid nothing and the last locked the box",
				#answers
			)
		end

		-- Locked: even the real code is refused and pays nothing.
		before = freshWallet()
		held = codeHoldings()
		local lockedAnswer = redeem("playtest")
		coinsStill, coinsText = coinsMovedBy(before, 0)
		if codeHoldings() ~= held or not coinsStill then
			return done(
				"FAIL",
				string.format(
					"%s; the real code paid while the box was locked: %s before, %s after, %s",
					notes,
					held,
					codeHoldings(),
					coinsText
				)
			)
		end
		if lockedAnswer ~= Codes.LOCKED then
			verdict = downgrade(verdict, "CHECK")
			notes ..= string.format(
				'; the real code while locked said %q, not "%s"',
				lockedAnswer,
				Codes.LOCKED
			)
		else
			notes ..= ", the real code refused while locked"
		end

		log(string.format("    waiting out the %d s lock", Config.CodeLockSeconds))
		task.wait(math.max(0, lockedAt + Config.CodeLockSeconds + 1 - os.clock()))

		-- Two redeems of the real code in one frame, typed the way a player might: one "Code redeemed!" and the
		-- prize paid once (RedeemCode allows 1 per 2 s, and CodeService saves the code before it pays).
		before = freshWallet()
		local heldNow = holdings()
		local bankedNow = bankedSpins()
		held = codeHoldings()
		local redeemAt = os.clock()
		fire("RedeemCode", "  PlayTest  ")
		fire("RedeemCode", "  PlayTest  ")
		waitFor(redeemAt, "CodeResult", 3)
		waitFor(redeemAt, "ProfileSync", 3)
		task.wait(2.1)
		local redeemed = codeAnswers(redeemAt)
		local paidCount = 0
		for _, answered in redeemed do
			if answered.ok then
				paidCount += 1
			end
		end
		local alreadyUsed = #redeemed > 0 and redeemed[1].message == Codes.USED
		if paidCount > 1 then
			return done(
				"FAIL",
				string.format("%s; two redeems in one frame paid %d times", notes, paidCount)
			)
		end
		if alreadyUsed then
			coinsStill, coinsText = coinsMovedBy(before, 0)
			if codeHoldings() ~= held or not coinsStill then
				return done(
					"FAIL",
					string.format(
						"%s; a used code paid again: %s before, %s after, %s",
						notes,
						held,
						codeHoldings(),
						coinsText
					)
				)
			end
			verdict = downgrade(verdict, "CHECK")
			notes ..= string.format(
				"; playtest was already used in this Studio save and paid nothing again, so the payout was not checked (run %s on the server and run again)",
				reset
			)
		elseif paidCount == 0 then
			return done(
				"CHECK",
				string.format(
					'%s; the real code after the lock answered %s, not "%s"',
					notes,
					if #redeemed > 0 then string.format("%q", redeemed[1].message) else "nothing",
					Codes.REDEEMED
				)
			)
		else
			local ok, paidText = codePaid(playtest.prize, before, heldNow, bankedNow)
			if not ok then
				return done(
					"FAIL",
					string.format("%s; playtest paid the wrong amounts: %s", notes, paidText)
				)
			end
			if redeemed[1].message ~= Codes.REDEEMED then
				verdict = downgrade(verdict, "CHECK")
				notes ..= string.format(' with %q, not "%s"', redeemed[1].message, Codes.REDEEMED)
			end
			notes ..= string.format(
				'; "  PlayTest  " twice in one frame paid once (%s; yours in this Studio save until %s)',
				paidText,
				reset
			)
		end

		-- Used and expired: the real code again in capitals, and every code that is not live, each refused with its
		-- own reason and nothing paid.
		local refusals: { { text: string, want: string } } = {
			{ text = "PLAYTEST", want = Codes.USED },
		}
		for id, def in Catalog.codes do
			if id ~= "playtest" and Codes.expired(def, os.time()) then
				table.insert(refusals, { text = id, want = Codes.EXPIRED })
			end
		end
		before = freshWallet()
		held = codeHoldings()
		for _, try in refusals do
			local answer = redeem(try.text)
			if answer ~= try.want then
				verdict = downgrade(verdict, "CHECK")
				notes ..= string.format('; %q said %q, not "%s"', try.text, answer, try.want)
			end
		end
		coinsStill, coinsText = coinsMovedBy(before, 0)
		if codeHoldings() ~= held or not coinsStill then
			return done(
				"FAIL",
				string.format(
					"%s; a used or expired code paid: %s before, %s after, %s",
					notes,
					held,
					codeHoldings(),
					coinsText
				)
			)
		end
		notes ..= string.format("; %d used or expired codes paid nothing", #refusals)
		return done(verdict, notes)
	end
)

-- Bug reports (engineer PR #265, docs/playtests/bug-reports.md) ------------------------------------------------

-- ReportBug's toasts by their BugReport.Messages key.
local BUG_ANSWERS: { { key: string, text: string } } = {
	{ key = "sent", text = BugReport.Messages.sent },
	{ key = "failed", text = BugReport.Messages.failed },
	{ key = "short", text = BugReport.Messages.short },
	{ key = "limited", text = BugReport.Messages.limited },
}

-- ReportBug's answers since `startedAt`, counted by key: sent, failed, short and limited.
local function bugAnswers(startedAt: number): { [string]: number }
	local counts: { [string]: number } = { sent = 0, failed = 0, short = 0, limited = 0 }
	for _, event in since(startedAt, "Toast") do
		for _, answer in BUG_ANSWERS do
			if string.find(event.text, answer.text, 1, true) ~= nil then
				counts[answer.key] += 1
			end
		end
	end
	return counts
end

-- Waits up to `timeout` for a saved, failed or too-soon answer (the save can take a moment), then counts.
local function bugAnswered(startedAt: number, timeout: number): { [string]: number }
	waitFor(startedAt, "Toast", timeout, function(event: Event): boolean
		for _, answer in BUG_ANSWERS do
			if answer.key ~= "short" and string.find(event.text, answer.text, 1, true) ~= nil then
				return true
			end
		end
		return false
	end)
	return bugAnswers(startedAt)
end

-- Every report this case sends starts with "[QA abuse]". From Studio they save under s_ keys, apart from the
-- testers' reports (BugReport.prefix).
case("reportBug", Enum.KeyCode.R, "Bug reports: bad texts, huge, flood, 21 s on", function()
	if table.find(Remotes.ClientToServer, "ReportBug") == nil then
		return "SKIP", "no ReportBug remote (engineer PR #265)"
	end
	-- Bad texts, 1.1 s apart for the 1 a second flood guard: each gets the short toast and nothing is written.
	local bad: { any } = { 5, true, {}, "", "   ", "ab", " \n\t ", "a\0b", "broken \255\254 text" }
	local badAt = os.clock()
	fire("ReportBug")
	task.wait(1.1)
	for _, text in bad do
		fire("ReportBug", text, "bug")
		task.wait(1.1)
	end
	local tries = #bad + 1
	local badCounts = bugAnswers(badAt)
	if badCounts.sent + badCounts.failed > 0 then
		return "FAIL",
			string.format(
				"%d of %d bad texts were written",
				badCounts.sent + badCounts.failed,
				tries
			)
	end
	local verdict: Verdict = "PASS"
	local notes = "no bad text written"
	if badCounts.short ~= tries then
		verdict = "CHECK"
		notes ..= string.format(" (%d short toasts for %d bad texts)", badCounts.short, tries)
	end

	-- A huge report: 10,000 bytes, a kind the server does not know, 50 error lines, the first three 10,000 bytes.
	local errors: { string } = {}
	for index = 1, 50 do
		errors[index] = if index <= 3 then string.rep("e", 10000) else "error " .. index
	end
	local bigAt = os.clock()
	fire("ReportBug", "[QA abuse] " .. string.rep("x", 10000), "admin", errors)
	local big = bugAnswered(bigAt, 8)
	if big.limited > 0 then
		return "CHECK",
			notes
				.. "; the big report was refused as too soon: a report in the last 20 s or 10 this session (rejoin)"
	end
	if big.sent + big.failed ~= 1 then
		return "FAIL",
			string.format(
				"%s; the big report got %d saved and %d failed answers",
				notes,
				big.sent,
				big.failed
			)
	end
	notes ..= if big.sent == 1
		then "; big report saved"
		else "; big report answered failed (API access off?)"

	-- 30 in one frame a second later: the flood guard lets one through and the 20 s limit refuses it.
	task.wait(1.1)
	local floodAt = os.clock()
	for _ = 1, 30 do
		Remotes.event("ReportBug"):FireServer("[QA abuse] flood", "bug")
	end
	log('    -> ReportBug("[QA abuse] flood", "bug") x30')
	task.wait(2)
	local flood = bugAnswers(floodAt)
	if flood.sent + flood.failed > 0 then
		return "FAIL",
			string.format(
				"%s; %d of 30 in one frame were written inside 20 s",
				notes,
				flood.sent + flood.failed
			)
	end
	if flood.limited ~= 1 then
		verdict = "CHECK"
		notes ..= string.format("; %d too-soon toasts for 30 in one frame, not 1", flood.limited)
	else
		notes ..= "; 30 in one frame: one too-soon toast, none written"
	end

	-- 21 s after the big report the next one goes through.
	local left = 21 - (os.clock() - bigAt)
	if left > 0 then
		task.wait(left)
	end
	local laterAt = os.clock()
	fire("ReportBug", "[QA abuse] a report 21 s later", "idea")
	local later = bugAnswered(laterAt, 8)
	if later.sent + later.failed ~= 1 then
		return "FAIL",
			string.format(
				"%s; 21 s later: %d saved, %d failed, %d too soon",
				notes,
				later.sent,
				later.failed,
				later.limited
			)
	end
	return verdict,
		notes
			.. "; 21 s later went through. Server output: the big report's [BugReport] line keeps 500 bytes of text, kind bug and 3 client errors of 200 bytes; no [Net] ReportBug handler failed line"
end)

case("flood", Enum.KeyCode.Backspace, "Flood: 30 RequestSync in one frame", function()
	local startedAt = os.clock()
	for _ = 1, 30 do
		Remotes.event("RequestSync"):FireServer()
	end
	log("    -> RequestSync() x30")
	task.wait(1.5)
	local syncs = #since(startedAt, "ProfileSync")
	if syncs <= 2 then
		return "PASS",
			string.format(
				"%d ProfileSync back; the server output should show one rate limit line, not 29",
				syncs
			)
	end
	return "FAIL", string.format("%d ProfileSync back from 30 calls in one frame", syncs)
end)

-- Running -----------------------------------------------------------------------------------------------------

local function run(name: string): (Verdict, string)
	local chosen: Case? = nil
	for _, candidate in cases do
		if candidate.name == name then
			chosen = candidate
		end
	end
	if chosen == nil then
		log("unknown case " .. name)
		return "SKIP", "unknown case"
	end
	if running ~= nil then
		log(string.format("busy with %s", running))
		return "SKIP", "busy"
	end
	running = chosen.name
	log(string.format("CASE %s: %s", chosen.name, chosen.title))
	-- A case can end with a cat in the arms, and the server refuses a carrying player's swing without a word, so
	-- every later catch case would see no answer (laptop run 2026-10-27). Check it in, then come back.
	if state ~= nil and state.carrying ~= nil then
		local root = rootPart()
		local back = if root ~= nil then root.Position else nil
		if not checkInIfCarrying() then
			log("    still carrying after a check-in try; this case's swings may get no NetSwung")
		end
		if back ~= nil then
			teleportTo(back)
		end
	end
	local ok, verdict, detail = pcall(chosen.run)
	running = nil
	if not ok then
		log(
			string.format(
				"RESULT %s: FAIL the case itself errored: %s",
				chosen.name,
				tostring(verdict)
			)
		)
		return "FAIL", tostring(verdict)
	end
	log(string.format("RESULT %s: %s %s", chosen.name, verdict, detail))
	return verdict :: Verdict, detail :: string
end

local function runAll(): { [string]: Verdict }
	local verdicts: { [string]: Verdict } = {}
	for _, entry in cases do
		verdicts[entry.name] = run(entry.name)
		task.wait(0.5)
	end
	log("SUMMARY")
	for _, entry in cases do
		log(string.format("  %-16s %s", entry.name, verdicts[entry.name]))
	end
	log("Now read the server output for [Net] ... handler failed lines.")
	return verdicts
end

local function printMenu()
	log("armed. Keys:")
	for _, entry in cases do
		log(string.format("  %-10s %s", entry.key.Name, entry.title))
	end
	log("  RightBracket run everything;  Backquote disarm")
end

local armed = false

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed or input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end
	if input.KeyCode == Enum.KeyCode.Backquote then
		armed = not armed
		if armed then
			printMenu()
		else
			log("disarmed")
		end
		return
	end
	if not armed then
		return
	end
	if input.KeyCode == Enum.KeyCode.RightBracket then
		task.spawn(runAll)
		return
	end
	for _, entry in cases do
		if entry.key == input.KeyCode then
			task.spawn(run, entry.name)
			return
		end
	end
end)

-- Server events worth seeing. ProfileSync keeps the state the cases compare against.
Remotes.event("ProfileSync").OnClientEvent:Connect(function(s: Types.PlayerState)
	state = s
	lastSyncAt = os.clock()
	record(
		"ProfileSync",
		string.format("money=%d cats=%d carrying=%s", s.money, catCount(), tostring(s.carrying))
	)
end)
Remotes.event("Toast").OnClientEvent:Connect(function(text: string, kind: string?)
	record("Toast", string.format("[%s] %s", tostring(kind), text))
end)
Remotes.event("SpinResult").OnClientEvent:Connect(function(slice: number, amount: number)
	local spun: Spun = { slice = slice, amount = amount }
	record("SpinResult", string.format("slice=%d amount=%d", slice, amount), nil, spun)
end)
Remotes.event("CrateResult").OnClientEvent
	:Connect(function(crateId: string, decorId: string, duplicate: boolean, refund: number)
		local opened: Opened =
			{ crateId = crateId, decorId = decorId, duplicate = duplicate, refund = refund }
		record(
			"CrateResult",
			string.format(
				"%s -> %q duplicate=%s refund=%d",
				crateId,
				decorId,
				tostring(duplicate),
				refund
			),
			crateId,
			opened
		)
	end)
Remotes.event("CodeResult").OnClientEvent
	:Connect(function(ok: boolean, message: string, prize: Types.IndexPrize?)
		local answered: Answered = { ok = ok, message = message, prize = prize }
		record("CodeResult", string.format("ok=%s %q", tostring(ok), message), nil, answered)
	end)
Remotes.event("FreshCatchStock").OnClientEvent:Connect(function(stock: Types.FreshCatchStock?)
	freshStock = stock
	record("FreshCatchStock", if stock ~= nil then string.format("window %d", stock.window) else "nil (night)")
end)
Remotes.event("TipJarState").OnClientEvent:Connect(function(jar: Types.TipJarState)
	tipJar = jar
	local claimed = 0
	for _, flag in jar.claimed do
		if flag then
			claimed += 1
		end
	end
	record("TipJarState", string.format("%d of %d claimed", claimed, #jar.claimed))
end)
Remotes.event("GrabResult").OnClientEvent
	:Connect(function(id: string, ok: boolean, reason: string, retry: boolean)
		record(
			"GrabResult",
			string.format("%s ok=%s reason=%q retry=%s", id, tostring(ok), reason, tostring(retry)),
			id
		)
	end)
-- F93: every landed swing within 150 studs; only mine are kept. A refused swing gets none.
Remotes.event("NetSwung").OnClientEvent:Connect(function(userId: number, hit: boolean)
	if userId == player.UserId then
		record("NetSwung", "hit=" .. tostring(hit), nil, hit)
	end
end)
Remotes.event("CatchSchedule").OnClientEvent
	:Connect(function(strayId: string, circles: { Types.CatchCircle }, windows: Types.CatchWindows)
		local schedule: Schedule = { circles = circles, windows = windows }
		local firstIn = if #circles > 0 then targetOf(circles[1]) - serverNow() else 0
		record(
			"CatchSchedule",
			string.format(
				"%s %d circle(s), first target in %.2f s, perfect +-%d ms, good +-%d ms",
				strayId,
				#circles,
				firstIn,
				math.floor(windows.perfect * 1000 + 0.5),
				math.floor(windows.good * 1000 + 0.5)
			),
			strayId,
			schedule
		)
	end)
Remotes.event("CatchResult").OnClientEvent:Connect(
	function(strayId: string, grades: { Types.CircleGrade }, success: boolean, charmGain: number)
		local outcome: Outcome = { grades = grades, success = success, charmGain = charmGain }
		record(
			"CatchResult",
			string.format(
				"%s grades=%s success=%s charmGain=%d",
				strayId,
				gradesText(grades),
				tostring(success),
				charmGain
			),
			strayId,
			outcome
		)
	end
)
Remotes.event("ShoveResult").OnClientEvent:Connect(
	function(
		outcome: string,
		shover: number,
		target: number,
		position: Vector3?,
		direction: Vector3?
	)
		local shoved: Shoved = {
			outcome = outcome,
			shover = shover,
			target = target,
			position = position,
			direction = direction,
		}
		record(
			"ShoveResult",
			string.format("%s by %d on %d at %s", outcome, shover, target, tostring(position)),
			nil,
			shoved
		)
	end
)
Remotes.event("CatCaught").OnClientEvent:Connect(function(catId: string, isNew: boolean)
	record("CatCaught", string.format("%s new=%s", catId, tostring(isNew)))
end)
Remotes.event("OfflineEarnings").OnClientEvent:Connect(function(amount: number, seconds: number)
	record("OfflineEarnings", string.format("$%d for %d s", amount, seconds))
end)
-- TravelResult is new with fast travel (F19); an older build has no such remote, so this waits a little, not forever.
task.spawn(function()
	local travelResult = Remotes.folder():WaitForChild("TravelResult", 10)
	if travelResult == nil or not travelResult:IsA("RemoteEvent") then
		return
	end
	(travelResult :: RemoteEvent).OnClientEvent:Connect(
		function(destination: string, ok: boolean, reason: string?)
			local travelled: Travelled = { ok = ok, reason = reason }
			record(
				"TravelResult",
				string.format("%s ok=%s reason=%s", destination, tostring(ok), tostring(reason)),
				destination,
				travelled
			)
		end
	)
end)

local names = {}
for _, entry in cases do
	table.insert(names, entry.name)
end
_G.CatCafeAbuse = { run = run, runAll = runAll, cases = names }

Remotes.event("RequestSync"):FireServer()
log(
	"loaded (Studio only). Press ` to arm, or use _G.CatCafeAbuse.run(name) from a client command bar."
)
