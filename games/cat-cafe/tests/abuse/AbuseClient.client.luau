--!strict
--[[
	AbuseClient: QA's hostile client for the abuse pass (docs/playtests/test-plan.md section 4.3).

	It only exists in a build made from tests.project.json (StarterPlayer.StarterPlayerScripts.TestsAbuse) and
	only runs inside Studio. It fires remotes the way an exploiter would and prints what the server did about it,
	so a tester, or Claude Code over Studio MCP (get_console_output), can read the verdicts in the output window.

	In a Play Solo or Clients and Servers session:
	  press ` (backquote) to arm it, the menu prints, then one key per case:
	  1 fake stray      2 far grab          3 press without begin  4 bad presses   5 press with a time
	  6 no press        7 scripted perfect  8 far press            [ second grab   ; retry after a fail
	  ' press spam      9 bad ids           0 shop gates           - ownership     = double spend
	  Backspace flood   ] run everything
	Or from a client-context command bar: _G.PurrPotAbuse.run("fakeStray"), _G.PurrPotAbuse.runAll().

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
local Catching = require(Shared:WaitForChild("Catching"))
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))

local player = Players.LocalPlayer

-- What the server sent back, newest last --------------------------------------------------------------------

-- `at` is os.clock(), `server` the synced server clock (Workspace:GetServerTimeNow) the circle times use. `id` is
-- the stray or spot the event is about; `data` keeps a CatchSchedule or CatchResult for the cases to read.
type Event = { at: number, server: number, name: string, text: string, id: string?, data: any }

-- What CatchSchedule and CatchResult carry.
type Schedule = { circles: { Types.CatchCircle }, windows: Types.CatchWindows }
type Outcome = { scores: { number }, chance: number, success: boolean, stayed: boolean }

local events: { Event } = {}
local state: Types.PlayerState? = nil
local running: string? = nil
local lastSyncAt = 0 -- os.clock() of the newest ProfileSync
local lastGrabAt = -math.huge -- os.clock() of the newest GrabBegin this script fired

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
		local reservedFor = instance:GetAttribute("ReservedFor")
		if
			(lockedBy ~= nil and lockedBy ~= 0)
			or (reservedFor ~= nil and reservedFor ~= 0 and reservedFor ~= player.UserId)
		then
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

-- From design v0.2 the alley is empty by day apart from the tutorial Common, so a run wants night first.
local NO_STRAY = 'no free stray nearby; on the server run Debug.spawnStray("tabby") '
	.. '(ServerScriptService.Server.Services.Debug), or from v0.2 Debug.setPhase("night")'

local cases: { Case } = {}

local function case(name: string, key: Enum.KeyCode, title: string, run: () -> (Verdict, string))
	table.insert(cases, { name = name, key = key, title = title, run = run })
end

-- Catching (design v0.3 closing circles) ---------------------------------------------------------------------

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
	local event = waitFor(startedAt, "CatchResult", math.max(0, endsAt(schedule) - serverNow()) + 1.5, about(id))
	return if event ~= nil then event.data :: Outcome else nil, event
end

-- A press the moment the circle reaches its target on the synced clock, which is what a player watching it sees.
-- The server takes half the ping off the arrival, so this grades Perfect.
local function pressOnTarget(id: string, index: number, circle: Types.CatchCircle)
	waitUntilServer(targetOf(circle))
	fire("CatchPress", id, index)
end

local function scoresText(scores: { number }): string
	local parts = {}
	for _, score in scores do
		table.insert(parts, string.format("%.1f", score))
	end
	return "{" .. table.concat(parts, ", ") .. "}"
end

-- Commons have one circle; a catch that outlasts the 2 s GrabBegin limit wants a Rare or rarer stray.
local function longCatch(info: StrayInfo): boolean
	return circlesOf(info.rarity) >= 2
end

local NO_LONG_STRAY = 'spawn a Rare next to you with Debug.spawnStray("calico") and rerun'

case("fakeStray", Enum.KeyCode.One, "Fake stray: GrabBegin and CatchPress on an id that does not exist", function()
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
end)

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
	"Bad presses: bad indexes, out of order, early and repeated; the on-target presses must still grade",
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
		-- Out of order (circle 2 before circle 1 is judged), then circle 1 before it starts: both ignored.
		local first = schedule.circles[1]
		if serverNow() < first.startsAt - 0.1 then
			fire("CatchPress", stray.id, 2)
			fire("CatchPress", stray.id, 1)
		else
			table.insert(notes, "early presses skipped: circle 1 had already started")
		end
		-- Every circle pressed on target. Before each later one, the previous index again once this circle is open:
		-- had the server counted that repeat here, this circle would score 0.
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
		if #outcome.scores ~= #schedule.circles then
			return "FAIL",
				string.format("%d scores for %d circles", #outcome.scores, #schedule.circles)
		end
		for index, score in outcome.scores do
			if score <= 0 then
				return "FAIL",
					string.format(
						"circle %d scored 0 %s: a bad, early or repeated press was counted, or the on-target press missed (read the [Catch] lines)",
						index,
						scoresText(outcome.scores)
					)
			end
		end
		local text = string.format(
			"every on-target press graded %s, chance %.2f; the bad, early and repeated presses counted for nothing",
			scoresText(outcome.scores),
			outcome.chance
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
		if (outcome.scores[1] or 0) > 0 then
			return "FAIL",
				string.format(
					"circle 1 scored %.1f from a press %.2f s early: the server used the time or grade the client sent",
					outcome.scores[1],
					early
				)
		end
		return "PASS",
			string.format(
				"circle 1 scored 0 on the server's clock (%.2f s early); the time and grade sent with it were ignored",
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
	local outcome, event = outcomeOf(startedAt, stray.id, schedule)
	if outcome == nil or event == nil then
		return "FAIL", "no CatchResult: unpressed circles must score 0 and the catch resolve by itself"
	end
	local offBy = event.server - endsAt(schedule)
	task.wait(0.3)
	local gone = stray.model.Parent == nil
	local lockedBy = stray.model:GetAttribute("LockedBy")
	-- A lured stray stays whatever its rarity; the others flee unless Common (Catching.fleesOnFail).
	local lured = stray.model:GetAttribute("ReservedFor") == player.UserId
	local shouldStay = lured or not Catching.fleesOnFail(stray.rarity)
	for _, score in outcome.scores do
		if score ~= 0 then
			return "FAIL", "an unpressed circle scored " .. scoresText(outcome.scores)
		end
	end
	if #outcome.scores ~= #schedule.circles or outcome.success then
		return "FAIL",
			string.format(
				"%d scores for %d circles, success=%s",
				#outcome.scores,
				#schedule.circles,
				tostring(outcome.success)
			)
	end
	if outcome.stayed ~= shouldStay then
		return "FAIL",
			string.format(
				"stayed=%s for a failed %s%s catch, expected %s",
				tostring(outcome.stayed),
				if lured then "lured " else "",
				stray.rarity,
				tostring(shouldStay)
			)
	end
	if not gone and lockedBy ~= 0 then
		return "FAIL", string.format("the stray is still locked by %s after the result", tostring(lockedBy))
	end
	local text = string.format(
		"%d circle(s) scored 0, resolved %+.2f s from the last target + good + %.2f s, %s %s",
		#outcome.scores,
		offBy,
		Config.CatchLatencyCapSeconds,
		stray.rarity,
		if outcome.stayed then "stayed and unlocked" else "fled"
	)
	if offBy < -0.1 or offBy > 0.5 then
		return "CHECK", text .. "; expected within -0.10 to +0.50 s"
	end
	return "PASS", text
end)

local scriptedCircles = 0 -- circles perfectFarm pressed this session; the server's autoPress flag needs 50

case(
	"perfectFarm",
	Enum.KeyCode.Seven,
	"Scripted perfect: 10 catches that press every circle on its target",
	function()
		local catches, caught, circles, perfect, chanceTotal = 0, 0, 0, 0, 0
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
			for index, circle in schedule.circles do
				pressOnTarget(stray.id, index, circle)
			end
			local outcome = outcomeOf(startedAt, stray.id, schedule)
			if outcome == nil then
				return "FAIL", "no CatchResult after every circle was pressed on target"
			end
			chanceTotal += outcome.chance
			circles += #outcome.scores
			for _, score in outcome.scores do
				if score >= Config.CircleScorePerfect then
					perfect += 1
				end
			end
			if outcome.success then
				caught += 1
			end
		end
		checkInIfCarrying()
		if catches == 0 then
			return "SKIP", stop or NO_STRAY
		end
		scriptedCircles += circles
		return "CHECK",
			string.format(
				"%d of %d caught, mean chance %.2f, %d of %d circles Perfect%s. Accepted by design: one roll at the mean score. "
					.. "%d scripted circles this session; once the last 50 judged circles are over 95%% Perfect the server warns "
					.. '"[CatService] <userId> flagged autoPress"%s',
				caught,
				catches,
				chanceTotal / catches,
				perfect,
				circles,
				if stop ~= nil then " (stopped early: " .. stop .. ")" else "",
				scriptedCircles,
				if scriptedCircles >= 50
					then "; look for it in the server output now"
					else "; run this case again until the count passes 50"
			)
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
			return "FAIL",
				string.format("caught from 200 studs away (chance %.2f)", outcome.chance)
		end
		local text = string.format(
			"not caught at chance %.2f %s, %s",
			outcome.chance,
			scoresText(outcome.scores),
			if outcome.stayed then "the stray stayed" else "the stray fled"
		)
		if not tooFar then
			return "CHECK", text .. ", but no Too far away toast; read the server output"
		end
		return "PASS", "forfeit with no roll: " .. text .. ", toast Too far away"
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
		local function worse(level: Verdict)
			if level == "FAIL" or (level == "CHECK" and verdict == "PASS") then
				verdict = level
			end
		end

		-- Catch 1: a GrabBegin on another stray within 2 s is dropped by the rate limit; the same stray again
		-- after 2 s, while its circles run, is refused and never restarts them.
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
		if other ~= nil then
			local otherAt = os.clock()
			fire("GrabBegin", other.id)
			task.wait(1)
			local answer = answerTo(otherAt, other.id, 0.1)
			if answer ~= nil and answer.name == "CatchSchedule" then
				worse("FAIL")
				table.insert(notes, "a second catch started at once on another stray")
			elseif answer ~= nil then
				worse("CHECK")
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
			worse("CHECK")
			table.insert(notes, "same-stray check skipped: the catch ended inside 2 s; " .. NO_LONG_STRAY)
		else
			local againAt = os.clock()
			fire("GrabBegin", stray.id)
			local answer = waitFor(againAt, "GrabResult", 1.5, about(stray.id))
			if countAbout(againAt, "CatchSchedule", stray.id) > 0 then
				worse("FAIL")
				table.insert(notes, "a second GrabBegin on the same stray restarted the circles")
			elseif answer ~= nil and string.find(answer.text, "Keep going", 1, true) ~= nil then
				table.insert(notes, "same stray after 2 s: Keep going, no new schedule")
			else
				worse("CHECK")
				table.insert(
					notes,
					"same stray after 2 s: "
						.. (if answer ~= nil then answer.text else "no answer")
				)
			end
		end
		outcomeOf(startedAt, stray.id, schedule)
		task.wait(0.3)
		local results = countAbout(startedAt, "CatchResult", stray.id)
		if results ~= 1 then
			worse("FAIL")
			table.insert(notes, string.format("%d CatchResults for catch 1", results))
		end
		checkInIfCarrying()

		-- Catch 2: one catch at a time. After 2 s, stand by another stray and GrabBegin it while catch 2 runs.
		task.wait(Config.GrabRetrySeconds + 0.2) -- a Common from catch 1 that stayed is out of its retry wait too
		local second = nearestStray(longCatch) or nearestStray()
		if second == nil then
			worse("CHECK")
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
			worse("CHECK")
			table.insert(notes, "catch 2 did not start: " .. why2)
		elseif third == nil then
			worse("CHECK")
			table.insert(notes, "one-at-a-time check skipped: no other stray")
		else
			task.wait(math.max(0, startedAt2 + Config.GrabRateLimitSeconds - 0.3 - os.clock()))
			standNextTo(third)
			task.wait(math.max(0, startedAt2 + Config.GrabRateLimitSeconds + 0.15 - os.clock()))
			if serverNow() > endsAt(schedule2) - 0.3 then
				worse("CHECK")
				table.insert(
					notes,
					"one-at-a-time check skipped: catch 2 ended inside 2 s; " .. NO_LONG_STRAY
				)
			else
				local thirdAt = os.clock()
				fire("GrabBegin", third.id)
				local answer = answerTo(thirdAt, third.id, 1.5)
				if answer ~= nil and answer.name == "CatchSchedule" then
					worse("FAIL")
					table.insert(notes, "a second catch started while catch 2 was running")
				elseif answer ~= nil and string.find(answer.text, "Finish this catch", 1, true) ~= nil then
					table.insert(notes, "another stray during catch 2: Finish this catch first")
				else
					worse("CHECK")
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
	"Retry: GrabBegin 2 s after a failed Common catch, then again once the wait is over",
	function()
		if not checkInIfCarrying() then
			return "SKIP", "carrying a cat that could not be checked in"
		end
		local stray = nearestStray(function(info)
			return info.rarity == "Common"
		end)
		if stray == nil then
			return "SKIP", 'no free Common nearby; Debug.spawnStray("tabby") and rerun'
		end
		local schedule, why, startedAt = beginCatch(stray)
		if schedule == nil then
			return "CHECK", why
		end
		-- Fail it on purpose: a press just after circle 1 starts is most of a shrink early.
		waitUntilServer(schedule.circles[1].startsAt + 0.15)
		fire("CatchPress", stray.id, 1)
		local outcome = outcomeOf(startedAt, stray.id, schedule)
		if outcome == nil then
			return "FAIL", "no CatchResult"
		end
		if outcome.success then
			checkInIfCarrying()
			return "FAIL", "an early press on the only circle still caught the cat"
		end
		if not outcome.stayed then
			return "FAIL", "a failed Common catch reported stayed=false"
		end
		local failedAt = os.clock()
		local notes = {}
		local verdict: Verdict = "PASS"
		-- The GrabBegin limit and the catch cooldown both count 2 s from the first GrabBegin; the retry wait counts
		-- GrabRetrySeconds from the fail, which comes later.
		task.wait(math.max(0, startedAt + Config.GrabRateLimitSeconds + 0.15 - os.clock()))
		if os.clock() > failedAt + Config.GrabRetrySeconds - 0.2 then
			verdict = "CHECK"
			table.insert(notes, "retry-wait check skipped: the fail came too early to test inside the wait")
		else
			local againAt = os.clock()
			fire("GrabBegin", stray.id)
			local answer = answerTo(againAt, stray.id, 1.5)
			if answer ~= nil and answer.name == "CatchSchedule" then
				return "FAIL",
					string.format(
						"a new catch started %.2f s after the fail, inside the %d s retry wait",
						againAt - failedAt,
						Config.GrabRetrySeconds
					)
			elseif answer ~= nil and string.find(answer.text, "Give it a moment", 1, true) ~= nil then
				table.insert(
					notes,
					string.format("%.2f s after the fail: Give it a moment", againAt - failedAt)
				)
			else
				verdict = "CHECK"
				table.insert(
					notes,
					"inside the retry wait: " .. (if answer ~= nil then answer.text else "no answer")
				)
			end
		end
		-- After the wait the same player may try the same stray again.
		task.wait(math.max(0, failedAt + Config.GrabRetrySeconds + 0.2 - os.clock()))
		local schedule2, why2, startedAt2 = beginCatch(stray)
		if schedule2 == nil then
			return "FAIL", table.concat(notes, "; ") .. "; after the wait: " .. why2
		end
		table.insert(notes, "after the wait: a new schedule")
		outcomeOf(startedAt2, stray.id, schedule2)
		checkInIfCarrying()
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
		-- Quiet on purpose: one log line for the burst, not one per call.
		while index <= #schedule.circles and serverNow() < stopAt do
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
		for _, score in outcome.scores do
			if score > 0 then
				return "FAIL",
					string.format(
						"a mashed press scored %s, chance %.2f",
						scoresText(outcome.scores),
						outcome.chance
					)
			end
		end
		return "PASS",
			string.format(
				"%d presses; each circle graded from the first press after it started, so all %d missed (chance %.2f)",
				sent,
				#outcome.scores,
				outcome.chance
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
		fire("EquipLure", 7)
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
		fire("BuyUpgrade", "jetpack")
		fire("BuyDecor", "jetpack")
		task.wait(1.5)
		local unknownToasts = {}
		local bought = state.upgradeLevels["jetpack"] ~= nil or state.decorOwned["jetpack"] ~= nil
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
					"gates skipped: tier is %d, not 1; run Debug.setTier(player, 1) and rerun",
					state.tier
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
				"unaffordable skipped: tables is affordable; on the server run Debug.setCoins(player, 0) and rerun"
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
Remotes.event("CatchSchedule").OnClientEvent:Connect(
	function(strayId: string, circles: { Types.CatchCircle }, windows: Types.CatchWindows)
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
	end
)
Remotes.event("CatchResult").OnClientEvent:Connect(
	function(strayId: string, scores: { number }, chance: number, success: boolean, stayed: boolean)
		local outcome: Outcome = { scores = scores, chance = chance, success = success, stayed = stayed }
		record(
			"CatchResult",
			string.format(
				"%s scores=%s chance=%.2f success=%s stayed=%s",
				strayId,
				scoresText(scores),
				chance,
				tostring(success),
				tostring(stayed)
			),
			strayId,
			outcome
		)
	end
)
Remotes.event("CatCaught").OnClientEvent:Connect(function(catId: string, isNew: boolean)
	record("CatCaught", string.format("%s new=%s", catId, tostring(isNew)))
end)
Remotes.event("OfflineEarnings").OnClientEvent:Connect(function(amount: number, seconds: number)
	record("OfflineEarnings", string.format("$%d for %d s", amount, seconds))
end)

local names = {}
for _, entry in cases do
	table.insert(names, entry.name)
end
_G.PurrPotAbuse = { run = run, runAll = runAll, cases = names }

Remotes.event("RequestSync"):FireServer()
log(
	"loaded (Studio only). Press ` to arm, or use _G.PurrPotAbuse.run(name) from a client command bar."
)
