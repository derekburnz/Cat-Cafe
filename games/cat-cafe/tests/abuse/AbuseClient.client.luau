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
	  Backspace flood   ] run everything
	Or from a client-context command bar: _G.CatCafeAbuse.run("fakeStray"), _G.CatCafeAbuse.runAll().

	Every line starts with [Abuse]. RESULT lines say PASS, FAIL, SKIP or CHECK. After a run, read the SERVER
	output too: any "[Net] <remote> handler failed" line means the server errored on bad input, a major ticket
	on its own, and the "[Catch]" lines show how the server graded each circle. Anything the server accepted
	that the tables in test plan section 4.4 say it must refuse is a blocker.

	Owner: qa-playtester. Never ships: it is not in default.project.json.
]]

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

-- GrabBegin next to the stray. Returns the schedule the server sent (or nil and why not) and when it fired.
local function beginCatch(stray: StrayInfo): (Schedule?, string, number)
	grabReady()
	standNextTo(stray)
	local startedAt = os.clock()
	fire("GrabBegin", stray.id)
	local answer = answerTo(startedAt, stray.id, 2)
	if answer == nil then
		return nil, "no CatchSchedule or GrabResult within 2 s of GrabBegin", startedAt
	end
	if answer.name == "GrabResult" then
		return nil, "GrabBegin refused: " .. answer.text, startedAt
	end
	return answer.data :: Schedule, answer.text, startedAt
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
		-- A working cat if there is one, so its DisplayName over the model can be checked by eye too.
		local uid: string? = nil
		for candidate, view in state.cats do
			if uid == nil or (view.spotId ~= nil and state.cats[uid :: string].spotId == nil) then
				uid = candidate
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
