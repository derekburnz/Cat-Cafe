--!strict
--[[
	AbuseClient: QA's hostile client for the abuse pass (docs/playtests/test-plan.md section 4.3).

	It only exists in a build made from tests.project.json (StarterPlayer.StarterPlayerScripts.TestsAbuse) and
	only runs inside Studio. It fires remotes the way an exploiter would and prints what the server did about it,
	so a tester, or Claude Code over Studio MCP (get_console_output), can read the verdicts in the output window.

	In a Play Solo or Clients and Servers session:
	  press ` (backquote) to arm it, the menu prints, then one key per case:
	  1 fake stray      2 far grab          3 press without begin  4 bad presses   5 press with a time
	  6 no press        7 scripted perfect  8 far press            [ second grab   ; retry after a miss
	  ' press spam      . unlimited tries   9 bad ids              0 shop gates    - ownership
	  = double spend    , travel            / shove targets        \ rename         Insert telemetry
	  Home drop         End unequip all     PageUp settings        PageDown saved settings
	  J tip jar         K index rewards     L spin wheel           Backspace flood
	  ] run everything
	Or from a client-context command bar: _G.CatCafeAbuse.run("fakeStray"), _G.CatCafeAbuse.runAll().

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
local Catalog = require(Shared:WaitForChild("Catalog"))
local Circles = require(Shared:WaitForChild("Circles"))
local Config = require(Shared:WaitForChild("Config"))
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
-- What ShoveResult carries (F41): "refused" goes to the shover alone, with no position or direction.
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
local running: string? = nil
local lastSyncAt = 0 -- os.clock() of the newest ProfileSync
local lastGrabAt = -math.huge -- os.clock() of the newest GrabBegin this script fired
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
	if name == "GrabBegin" then
		lastGrabAt = os.clock()
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

type StrayInfo = { id: string, model: Model, rarity: Types.Rarity }

-- Nearest stray nobody holds or reserved, of those `accept` takes. The server marks every stray model with these
-- attributes.
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
		if lockedBy ~= nil and lockedBy ~= 0 then
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

local function standNextTo(stray: StrayInfo)
	teleportTo(stray.model:GetPivot().Position + Vector3.new(4, 0, 0))
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

-- A carrying player cannot grab, so the grab loops check the cat in between attempts.
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

-- From design v0.2 the alley is empty by day apart from the tutorial Common, so a run wants night first.
local NO_STRAY = string.format(
	'no free stray nearby; on the server run %s("spawnStray", "tabby") or %s("setPhase", "night")',
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

-- GrabBegin allows one call per 2 s and the server spaces a player's catch starts GrabCooldownSeconds apart, so a
-- case waits both out before a GrabBegin it means to land.
local function grabReady()
	local spacing = math.max(Config.GrabRateLimitSeconds, Config.GrabCooldownSeconds) + 0.15
	local left = lastGrabAt + spacing - os.clock()
	if left > 0 then
		task.wait(left)
	end
end

-- The server's first answer to a GrabBegin on `id`: a CatchSchedule, or the GrabResult that refused it.
local function answerTo(startedAt: number, id: string, timeout: number): Event?
	local deadline = os.clock() + timeout
	while os.clock() < deadline do
		for _, event in since(startedAt) do
			if event.id == id and (event.name == "CatchSchedule" or event.name == "GrabResult") then
				return event
			end
		end
		task.wait(0.05)
	end
	return nil
end

-- GrabBegin next to the stray. Returns the schedule the server sent (or nil and why not) and when it fired. A stray
-- that wandered on while the teleport replicated gets one more try from beside it (laptop run 2026-10-27).
local function beginCatch(stray: StrayInfo): (Schedule?, string, number)
	local why, startedAt = "", os.clock()
	for _ = 1, 2 do
		grabReady()
		standNextTo(stray)
		startedAt = os.clock()
		fire("GrabBegin", stray.id)
		local answer = answerTo(startedAt, stray.id, 2)
		if answer == nil then
			return nil, "no CatchSchedule or GrabResult within 2 s of GrabBegin", startedAt
		end
		if answer.name ~= "GrabResult" then
			return answer.data :: Schedule, answer.text, startedAt
		end
		why = "GrabBegin refused: " .. answer.text
		if answer.text ~= "Too far away" then
			break
		end
		log("    the stray moved off; standing next to it again")
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

-- Commons have one circle; a catch that outlasts the 2 s GrabBegin limit wants a Rare or rarer stray.
local function longCatch(info: StrayInfo): boolean
	return circlesOf(info.rarity) >= 2
end

local NO_LONG_STRAY = string.format('spawn a Rare with %s("spawnStray", "calico") and rerun', DEBUG)

case(
	"fakeStray",
	Enum.KeyCode.One,
	"Fake stray: GrabBegin and CatchPress on an id that does not exist",
	function()
		grabReady()
		local startedAt = os.clock()
		fire("GrabBegin", "not_a_stray")
		fire("CatchPress", "not_a_stray", 1)
		task.wait(1)
		local reactions = #since(startedAt, "GrabResult")
			+ #since(startedAt, "CatchSchedule")
			+ #since(startedAt, "CatchResult")
			+ #since(startedAt, "Toast")
		if reactions == 0 then
			return "PASS", "ignored, no GrabResult, schedule, result or toast"
		end
		return "FAIL", string.format("%d reaction(s) to a fake id", reactions)
	end
)

case("farGrab", Enum.KeyCode.Two, "Far grab: GrabBegin from 200 studs away", function()
	local stray = nearestStray()
	if stray == nil then
		return "SKIP", NO_STRAY
	end
	local root = rootPart()
	if root == nil then
		return "SKIP", "no character"
	end
	local home = root.Position
	grabReady()
	teleportTo(stray.model:GetPivot().Position + Vector3.new(200, 0, 0))
	local startedAt = os.clock()
	fire("GrabBegin", stray.id)
	local answer = answerTo(startedAt, stray.id, 1.5)
	teleportTo(home)
	if answer == nil then
		return "CHECK", "no answer at all; expected GrabResult Too far away. Read the server output"
	end
	if answer.name == "CatchSchedule" then
		return "FAIL", "the server started circles for a player 200 studs away"
	end
	if string.find(answer.text, "Too far", 1, true) ~= nil then
		return "PASS", "refused with Too far away, no schedule"
	end
	return "CHECK", "refused, but not as Too far away: " .. answer.text
end)

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

case("noPress", Enum.KeyCode.Six, "No press: GrabBegin and never press", function()
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
	"secondGrab",
	Enum.KeyCode.LeftBracket,
	"Second grab: another stray at once, the same stray again after 2 s, another stray after 2 s",
	function()
		if not checkInIfCarrying() then
			return "SKIP", "carrying a cat that could not be checked in"
		end
		local root = rootPart()
		if root == nil then
			return "SKIP", "no character"
		end
		local home = root.Position
		local notes = {}
		local verdict: Verdict = "PASS"

		-- Catch 1: a GrabBegin on another stray within 2 s is dropped by the rate limit; the same stray again
		-- after 2 s, while its circles run, is refused and never restarts them. The circles are pressed on target
		-- in the background, since an unpressed circle would end the catch at its deadline (v0.4).
		local stray = nearestStray(longCatch) or nearestStray()
		if stray == nil then
			return "SKIP", NO_STRAY
		end
		local first = stray
		local other = nearestStray(function(info)
			return info.id ~= first.id
		end)
		local schedule, why, startedAt = beginCatch(stray)
		if schedule == nil then
			return "CHECK", why
		end
		pressAllOnTarget(stray.id, schedule)
		if other ~= nil then
			local otherAt = os.clock()
			fire("GrabBegin", other.id)
			task.wait(1)
			local answer = answerTo(otherAt, other.id, 0.1)
			if answer ~= nil and answer.name == "CatchSchedule" then
				verdict = downgrade(verdict, "FAIL")
				table.insert(notes, "a second catch started at once on another stray")
			elseif answer ~= nil then
				verdict = downgrade(verdict, "CHECK")
				table.insert(
					notes,
					"another stray within 1 s got an answer, so the GrabBegin limit let it through: "
						.. answer.text
				)
			else
				table.insert(notes, "another stray within 1 s: no answer (rate limit)")
			end
		else
			table.insert(notes, "at-once check skipped: no second stray")
		end
		task.wait(math.max(0, startedAt + Config.GrabRateLimitSeconds + 0.15 - os.clock()))
		if serverNow() > endsAt(schedule) - 0.3 then
			verdict = downgrade(verdict, "CHECK")
			table.insert(
				notes,
				"same-stray check skipped: the catch ended inside 2 s; " .. NO_LONG_STRAY
			)
		else
			local againAt = os.clock()
			fire("GrabBegin", stray.id)
			local answer = waitFor(againAt, "GrabResult", 1.5, about(stray.id))
			if countAbout(againAt, "CatchSchedule", stray.id) > 0 then
				verdict = downgrade(verdict, "FAIL")
				table.insert(notes, "a second GrabBegin on the same stray restarted the circles")
			elseif answer ~= nil and string.find(answer.text, "Keep going", 1, true) ~= nil then
				table.insert(notes, "same stray after 2 s: Keep going, no new schedule")
			else
				verdict = downgrade(verdict, "CHECK")
				table.insert(
					notes,
					"same stray after 2 s: " .. (if answer ~= nil then answer.text else "no answer")
				)
			end
		end
		outcomeOf(startedAt, stray.id, schedule)
		task.wait(0.3)
		local results = countAbout(startedAt, "CatchResult", stray.id)
		if results ~= 1 then
			verdict = downgrade(verdict, "FAIL")
			table.insert(notes, string.format("%d CatchResults for catch 1", results))
		end
		checkInIfCarrying()

		-- Catch 2: one catch at a time. After 2 s, stand by another stray and GrabBegin it while catch 2 runs.
		local second = nearestStray(longCatch) or nearestStray()
		if second == nil then
			verdict = downgrade(verdict, "CHECK")
			table.insert(notes, "one-at-a-time check skipped: no stray for catch 2")
			teleportTo(home)
			return verdict, table.concat(notes, "; ")
		end
		local secondId = second.id
		local schedule2, why2, startedAt2 = beginCatch(second)
		local third = nearestStray(function(info)
			return info.id ~= secondId
		end)
		if schedule2 == nil then
			verdict = downgrade(verdict, "CHECK")
			table.insert(notes, "catch 2 did not start: " .. why2)
		elseif third == nil then
			verdict = downgrade(verdict, "CHECK")
			table.insert(notes, "one-at-a-time check skipped: no other stray")
			pressAllOnTarget(secondId, schedule2)
			outcomeOf(startedAt2, secondId, schedule2)
		else
			pressAllOnTarget(secondId, schedule2)
			-- Just before the limit allows the GrabBegin, stand where both strays are in grab range if they are close
			-- enough, so catch 2 is not forfeit by its range check (a forfeit is a Miss); else by the third stray.
			task.wait(math.max(0, startedAt2 + Config.GrabRateLimitSeconds - 0.3 - os.clock()))
			local secondPosition = second.model:GetPivot().Position
			local thirdPosition = third.model:GetPivot().Position
			if horizontal(secondPosition, thirdPosition) <= 2 * (Config.GrabRangeStuds - 1) then
				teleportTo((secondPosition + thirdPosition) / 2)
			else
				standNextTo(third)
				table.insert(
					notes,
					"catch 2 may be forfeit as too far away (the other stray is not close by)"
				)
			end
			task.wait(math.max(0, startedAt2 + Config.GrabRateLimitSeconds + 0.15 - os.clock()))
			if serverNow() > endsAt(schedule2) - 0.3 then
				verdict = downgrade(verdict, "CHECK")
				table.insert(
					notes,
					"one-at-a-time check skipped: catch 2 ended inside 2 s; " .. NO_LONG_STRAY
				)
			else
				local thirdAt = os.clock()
				fire("GrabBegin", third.id)
				local answer = answerTo(thirdAt, third.id, 1.5)
				if answer ~= nil and answer.name == "CatchSchedule" then
					verdict = downgrade(verdict, "FAIL")
					table.insert(notes, "a second catch started while catch 2 was running")
				elseif
					answer ~= nil
					and string.find(answer.text, "Finish this catch", 1, true) ~= nil
				then
					table.insert(notes, "another stray during catch 2: Finish this catch first")
				else
					verdict = downgrade(verdict, "CHECK")
					table.insert(
						notes,
						"another stray during catch 2: "
							.. (if answer ~= nil then answer.text else "no answer")
					)
				end
			end
			outcomeOf(startedAt2, secondId, schedule2)
		end
		teleportTo(home)
		checkInIfCarrying()
		return verdict, table.concat(notes, "; ")
	end
)

case(
	"retry",
	Enum.KeyCode.Semicolon,
	"Retry: miss a Common, GrabBegin it while it runs; miss it again, GrabBegin it in my extra second; then catch it",
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
		-- v0.5 (F40, S44): after a miss GrabBegin is "It's running!" for everyone until FleeingUntil, and the player
		-- who missed waits StraySelfRetrySeconds more. GrabBegin takes one call per 2 s, too few for both checks
		-- after one miss, so the running check follows miss 1 and the extra-second check follows miss 2.
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
			-- The stray stands still while it catches its breath, so stand by it and wait out the GrabBegin limit.
			waitForSprint(stray.model)
			standNextTo(stray)
			grabReady()
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
				fire("GrabBegin", stray.id)
				local answer = answerTo(probeAt, stray.id, 1.5)
				local expected = if round == 1 then "It's running!" else "Catch your breath"
				if answer ~= nil and answer.name == "CatchSchedule" then
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
	"Press spam: CatchPress every 0.1 s from GrabBegin, moving on once a circle has started",
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
	"Unlimited tries: miss one stray three times, each after it stops running; every GrabBegin starts a catch",
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
				if def ~= nil and (uid == nil or instance.spotId == nil) then
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

-- Shove (v0.5 F41, data-model section 10c; the remote keeps the Bump name) ---------------------------------------

case(
	"shove",
	Enum.KeyCode.Slash,
	"Shove: malformed and unknown targets, then myself, then 10 self shoves in one frame",
	function()
		-- Bump takes 2 calls a second, so the bad values go in pairs with the bucket refilled in between; a value the
		-- limiter drops would never reach Guard.int. Malformed or nobody on this server: no ShoveResult, no toast.
		local quietAt = os.clock()
		local bad: { any } = { "nil", "1", 1.5, 0 / 0, math.huge, {}, 987654321 }
		for index, value in bad do
			fire("Bump", if value == "nil" then nil else value)
			if index % 2 == 0 then
				task.wait(1.05)
			end
		end
		task.wait(1.2)
		local quiet = {}
		for _, event in since(quietAt) do
			if event.name == "ShoveResult" or event.name == "Toast" then
				table.insert(quiet, event.text)
			end
		end
		-- Myself: refused in words, to me alone, and nothing lands on my character.
		local character = player.Character
		local shovedBefore = if character ~= nil then character:GetAttribute("ShovedAt") else nil
		local selfAt = os.clock()
		fire("Bump", player.UserId)
		local refused = waitFor(selfAt, "ShoveResult", 2)
		task.wait(0.3)
		local selfToast = toasted(selfAt, "You can't shove yourself")
		local shovedAfter = if character ~= nil then character:GetAttribute("ShovedAt") else nil
		-- Flood: 10 in one frame from a full bucket; the limiter lets 2 through.
		task.wait(1.2)
		local floodAt = os.clock()
		for _ = 1, 10 do
			Remotes.event("Bump"):FireServer(player.UserId)
		end
		log(string.format("    -> Bump(%d) x10", player.UserId))
		task.wait(1.5)
		local answers = #since(floodAt, "ShoveResult")

		if #quiet > 0 then
			return "FAIL",
				"a malformed or unknown target got an answer: " .. table.concat(quiet, " | ")
		end
		if refused == nil then
			return "FAIL", "no ShoveResult for a shove at myself"
		end
		local result = refused.data :: Shoved
		if
			result.outcome ~= "refused"
			or result.shover ~= player.UserId
			or result.target ~= player.UserId
			or result.position ~= nil
		then
			return "FAIL", "a shove at myself answered " .. refused.text
		end
		if shovedAfter ~= shovedBefore then
			return "FAIL", "ShovedAt changed on my character after a refused shove"
		end
		if answers > 2 then
			return "FAIL",
				string.format("%d ShoveResult back from 10 Bump calls in one frame", answers)
		end
		if not selfToast then
			return "CHECK", 'refused, but no "You can\'t shove yourself" toast'
		end
		return "PASS",
			string.format(
				"bad and unknown targets: silent; myself: refused with its toast; flood: %d of 10 answered. A real shove needs two players (section 4.3 item 2)",
				answers
			)
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

-- The dropped stray I own the first try on, within `radius` studs of me.
local function myDrop(radius: number): Model?
	local root = rootPart()
	if root == nil then
		return nil
	end
	for _, instance in Workspace:GetDescendants() do
		if
			instance:IsA("Model")
			and instance:GetAttribute("Dropped") == true
			and instance:GetAttribute("DropOwner") == player.UserId
			and horizontal(instance:GetPivot().Position, root.Position) <= radius
		then
			return instance :: Model
		end
	end
	return nil
end

case(
	"drop",
	Enum.KeyCode.Home,
	"Drop: not carrying, junk arguments, CheckIn and 10 DropCat in one frame at my door, then a drop in the alley",
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
		-- 3. In the alley: the cat hops down at my feet as a dropped stray whose first try is mine.
		why = catchOne()
		if why ~= "" then
			table.insert(notes, "alley drop skipped: " .. why)
			return verdict, table.concat(notes, "; ")
		end
		task.wait(1.05)
		local alleyAt = os.clock()
		fire("DropCat")
		waitFor(alleyAt, "ProfileSync", 3, function()
			return state ~= nil and state.carrying == nil
		end)
		task.wait(0.5)
		local dropped = myDrop(30)
		local until_ = if dropped ~= nil then dropped:GetAttribute("DropOwnerUntil") else nil
		if not toasted(alleyAt, " go.") then
			verdict = "FAIL"
			table.insert(notes, 'alley drop: no "You let <Cat> go." toast')
		elseif dropped == nil then
			verdict = "FAIL"
			table.insert(
				notes,
				"alley drop: no stray with Dropped and my DropOwner within 30 studs"
			)
		elseif type(until_) ~= "number" or until_ <= serverNow() then
			verdict = "FAIL"
			table.insert(notes, "alley drop: DropOwnerUntil is not in the future")
		else
			table.insert(
				notes,
				string.format("alley drop: mine to catch for %.1f s more", until_ - serverNow())
			)
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
		local SWITCHES = { "screenShake", "lowPerformance", "showOtherCats", "markers" }
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
-- with a toast of its own ("Tip Jar: +1 spin", F49), left out here.
local function tipToasts(startedAt: number): { Event }
	local found = {}
	for _, event in since(startedAt, "Toast") do
		if
			string.find(event.text, "Tip Jar:", 1, true) ~= nil
			and string.find(event.text, "Tip Jar: %+%d+ spin") == nil
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
	local w = freshWallet()
	local lureBefore = if state ~= nil and def.lureId ~= nil
		then state.lures[def.lureId] or 0
		else 0
	local bankedBefore = if state ~= nil and (state :: any).spin ~= nil
		then state.spin.banked
		else nil
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
	if def.kind == "coins" then
		local paid = tonumber(string.match(toasts[1].text, "%+%$(%d+)")) or 0
		local gained = money() - w.money
		if paid < (def.minCoins or 0) then
			return "FAIL",
				string.format(
					"step %d paid $%d, under its floor of $%d",
					ready,
					paid,
					def.minCoins or 0
				)
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
		local lureAfter = if state ~= nil then state.lures[def.lureId :: string] or 0 else 0
		if lureAfter - lureBefore ~= (def.count or 1) then
			return "FAIL",
				string.format(
					"step %d should give %d %s and gave %d",
					ready,
					def.count or 1,
					def.lureId :: string,
					lureAfter - lureBefore
				)
		end
		prize = string.format("%d %s", def.count or 1, def.lureId :: string)
	end
	-- Steps 11 and 12 bank a spin too (F49), unless the bank is full, which the server says in a toast.
	local spins = def.spins
	if spins ~= nil and bankedBefore ~= nil then
		local banked = (if state ~= nil then state.spin.banked else 0) - bankedBefore
		if banked ~= spins and not toasted(claimAt, "Spins full") then
			return "FAIL",
				string.format("step %d should bank %d spin and banked %d", ready, spins, banked)
		end
		prize ..= string.format(" and %d spin", banked)
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

-- Cats of `areaId` in the collection, or the gold collection, counted the way the Index counts them.
local function pageCount(areaId: string, gold: boolean): number
	local s = state
	if s == nil then
		return 0
	end
	local collection = if gold then s.goldCollection else s.collection
	local count = 0
	for _, def in Catalog.cats do
		if def.area == areaId and collection[def.id] ~= nil then
			count += 1
		end
	end
	return count
end

local function rewardClaimed(areaId: string, milestoneId: string): boolean
	local claims = if state ~= nil then state.indexRewards[areaId] else nil
	return claims ~= nil and claims[milestoneId] == true
end

-- Claims, decor owned and foods held, so a case can tell that a refused call marked or paid nothing.
local function indexHoldings(): string
	local claims, decor = 0, 0
	if state ~= nil then
		for _, area in state.indexRewards do
			for _, claimed in area do
				claims += if claimed then 1 else 0
			end
		end
		for _, owned in state.decorOwned do
			decor += if owned then 1 else 0
		end
	end
	return string.format("%d claims, %d decor, %d foods", claims, decor, foods())
end

type IndexMilestone = { areaId: string, id: string, left: number, gold: boolean }

-- The first unclaimed milestone, in area order, that has its cats (`ready` true) or is still short of them.
local function indexMilestone(ready: boolean): IndexMilestone?
	for _, area in Catalog.areas do
		local prizes = Catalog.indexPrizes[area.id]
		if prizes == nil then
			continue
		end
		for _, milestone in Catalog.indexMilestones do
			if prizes[milestone.id] == nil or rewardClaimed(area.id, milestone.id) then
				continue
			end
			local gold = milestone.gold == true
			local left = milestone.need - pageCount(area.id, gold)
			if (left <= 0) == ready then
				return { areaId = area.id, id = milestone.id, left = left, gold = gold }
			end
		end
	end
	return nil
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
		local expected = string.format(
			"Find %d more%s cat%s first",
			locked.left,
			if locked.gold then " gold" else "",
			if locked.left == 1 then "" else "s"
		)
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
					"%s %s paid with %d cat(s) still to find",
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
				'%d bad calls paid nothing%s; no milestone ready for the double claim, so on the server run %s("fillIndex", nil, "alley", 3) (after %s("resetProfile") if the Alleyway is all claimed) and run again',
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
	local lures: { [string]: number } = prize.lures or {}
	local luresBefore: { [string]: number } = {}
	for lureId in lures do
		luresBefore[lureId] = if state ~= nil then state.lures[lureId] or 0 else 0
	end
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
	local coinsOk, coinsText = coinsMovedBy(w, prize.coins or 0)
	if not coinsOk then
		return "FAIL", string.format("%s should pay $%d: %s", name, prize.coins or 0, coinsText)
	end
	for lureId, count in lures do
		local gained = (if state ~= nil then state.lures[lureId] or 0 else 0) - luresBefore[lureId]
		if gained ~= count then
			return "FAIL",
				string.format("%s should give %d %s and gave %d", name, count, lureId, gained)
		end
	end
	local decorId = prize.decorId
	if
		decorId ~= nil
		and (state == nil or not state.decorOwned[decorId] or not state.decorPlaced[decorId])
	then
		return "FAIL", string.format("%s should give %s owned and placed", name, decorId)
	end
	local againNote = ""
	if not toasted(againAt, "Already claimed") then
		verdict = downgrade(verdict, "CHECK")
		againNote = ', but the third claim got no "Already claimed" toast'
	end
	return verdict,
		string.format(
			"%d bad calls paid nothing%s; %s paid once for three claims (%s)%s",
			#bad,
			lockedNote,
			name,
			coinsText,
			againNote
		)
end)

-- Spin Wheel (F49, engineer PR #223, data-model 11c) -------------------------------------------------------------

type Spun = { slice: number, amount: number }

-- The station tagged SpinWheel nearest the character, or nil.
local function spinStation(): Model?
	local root = rootPart()
	local origin = if root ~= nil then root.Position else Vector3.zero
	local best: Model? = nil
	local bestDistance = math.huge
	for _, instance in CollectionService:GetTagged("SpinWheel") do
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

local function lureCounts(): { [string]: number }
	return if state ~= nil then table.clone(state.lures) else {}
end

-- True when one paid spin moved coins or the slice's food by exactly what SpinResult said, and the slice and
-- amount are ones the wheel can pay; the text goes on the RESULT line.
local function spinPaid(spun: Spun, before: Wallet, lures: { [string]: number }): (boolean, string)
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
	local lureId = row.lureId :: string
	local gained = (if state ~= nil then state.lures[lureId] or 0 else 0) - (lures[lureId] or 0)
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
	local f, left = foods(), spinsLeft()
	local farAt = os.clock()
	fire("SpinWheel")
	local farAnswer = waitFor(farAt, "SpinResult", 2)
	task.wait(0.5)
	local farPaid = spinAnswers(farAt)
	if
		#farPaid > 0
		or money() - w.money > incomeSince(w)
		or foods() ~= f
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
	local lures = lureCounts()
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
	local ok, paidText = spinPaid(paid[1], w, lures)
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
		lures = lureCounts()
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
		local nextOk, nextText = spinPaid(later[1], w, lures)
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
	f = foods()
	local noneAt = os.clock()
	fire("SpinWheel")
	local noneAnswer = waitFor(noneAt, "SpinResult", 2)
	task.wait(0.3)
	if #(spinAnswers(noneAt)) > 0 or money() - w.money > incomeSince(w) or foods() ~= f then
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
	-- A case can end with a cat in the arms, and the server answers a carrying player's GrabBegin with a toast only,
	-- so every later catch case saw no answer (laptop run 2026-10-27). Check it in, then come back.
	if state ~= nil and state.carrying ~= nil then
		local root = rootPart()
		local back = if root ~= nil then root.Position else nil
		if not checkInIfCarrying() then
			log("    still carrying after a check-in try; this case may see no GrabResult")
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
