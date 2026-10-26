--!strict
--[[
	AbuseClient: QA's hostile client for the abuse pass (docs/playtests/test-plan.md section 4.3).

	It only exists in a build made from tests.project.json (StarterPlayer.StarterPlayerScripts.TestsAbuse) and
	only runs inside Studio. It fires remotes the way an exploiter would and prints what the server did about it,
	so a tester, or Claude Code over Studio MCP (get_console_output), can read the verdicts in the output window.

	In a Play Solo or Clients and Servers session:
	  press ` (backquote) to arm it, the menu prints, then one key per case:
	  1 fake stray      2 far grab        3 end without begin   4 instant end   5 late end    6 no end
	  7 perfect farming 8 client ring arg 9 bad ids             0 shop gates    - ownership   = double spend
	  Backspace flood   ] run everything
	Or from a client-context command bar: _G.PurrPotAbuse.run("fakeStray"), _G.PurrPotAbuse.runAll().

	Every line starts with [Abuse]. RESULT lines say PASS, FAIL, SKIP or CHECK. After a run, read the SERVER
	output too: any "[Net] <remote> handler failed" line means the server errored on bad input, a major ticket
	on its own. Anything the server accepted that the table in section 4.3 says it must refuse is a blocker.

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

type Event = { at: number, name: string, text: string }

local events: { Event } = {}
local state: Types.PlayerState? = nil
local running: string? = nil
local lastSyncAt = 0 -- os.clock() of the newest ProfileSync

local function log(text: string)
	print("[Abuse] " .. text)
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

local function record(name: string, text: string)
	table.insert(events, { at = os.clock(), name = name, text = text })
	if #events > 300 then
		table.remove(events, 1)
	end
	if running ~= nil then
		log(string.format("    <- %s %s", name, text))
	end
end

local function fire(name: string, ...: any)
	log(string.format("    -> %s(%s)", name, describe(...)))
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

-- Nearest stray nobody holds or reserved. The server marks every stray model with these attributes.
local function nearestStray(): StrayInfo?
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
			best = {
				id = id,
				model = instance :: Model,
				rarity = (if type(rarity) == "string" then rarity else "Common") :: Types.Rarity,
			}
			bestDistance = distance
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

-- The catch chance upgrade: "gloves" until design v0.2 renames it "net".
local CATCH_UPGRADE = if Catalog.getUpgrade("net") ~= nil then "net" else "gloves"

local function catchUpgradeLevel(): number
	return if state ~= nil then (state.upgradeLevels[CATCH_UPGRADE] or 0) else 0
end

-- One grab with a chosen release time. Returns the GrabResult event (or nil), how long after GrabBegin it came
-- and the os.clock() of the GrabBegin.
local function grabWithRelease(
	stray: StrayInfo,
	releaseAfter: number?,
	extraArg: any?
): (Event?, number, number)
	standNextTo(stray)
	local startedAt = os.clock()
	fire("GrabBegin", stray.id)
	if releaseAfter ~= nil then
		task.wait(releaseAfter)
		if extraArg ~= nil then
			fire("GrabEnd", stray.id, extraArg)
		else
			fire("GrabEnd", stray.id)
		end
	end
	local result = waitFor(startedAt, "GrabResult", 3.5, function(event)
		return string.find(event.text, stray.id, 1, true) ~= nil
	end)
	local after = if result ~= nil then result.at - startedAt else -1
	return result, after, startedAt
end

local function resolvedByTimeout(after: number): boolean
	local expected = Config.GrabHoldSeconds + Config.RingLatencyGraceSeconds
	return after >= expected - 0.15 and after <= expected + 0.45
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

case("fakeStray", Enum.KeyCode.One, "Fake stray: GrabBegin on an id that does not exist", function()
	local startedAt = os.clock()
	fire("GrabBegin", "not_a_stray")
	task.wait(1)
	local reactions = #since(startedAt, "GrabResult") + #since(startedAt, "Toast")
	if reactions == 0 then
		return "PASS", "ignored, no GrabResult and no toast"
	end
	return "FAIL", string.format("%d reaction(s) to a fake id", reactions)
end)

case("farGrab", Enum.KeyCode.Two, "Far grab: GrabBegin and GrabEnd from 200 studs away", function()
	local stray = nearestStray()
	if stray == nil then
		return "SKIP", NO_STRAY
	end
	local root = rootPart()
	if root == nil then
		return "SKIP", "no character"
	end
	local home = root.Position
	teleportTo(stray.model:GetPivot().Position + Vector3.new(200, 0, 0))
	local startedAt = os.clock()
	fire("GrabBegin", stray.id)
	task.wait(1.35)
	fire("GrabEnd", stray.id)
	task.wait(1)
	teleportTo(home)
	local results = since(startedAt, "GrabResult")
	local caught = false
	local refused = false
	for _, event in results do
		if string.find(event.text, "caught", 1, true) then
			caught = true
		elseif string.find(event.text, "Too far", 1, true) then
			refused = true
		end
	end
	if caught then
		return "FAIL", "the server let a grab through from 200 studs away"
	end
	if refused then
		return "PASS", "refused with Too far away, nothing caught"
	end
	return "CHECK", "nothing caught but no Too far away result either; read the server output"
end)

case(
	"endWithoutBegin",
	Enum.KeyCode.Three,
	"End without begin: GrabEnd on a stray nobody locked",
	function()
		local stray = nearestStray()
		if stray == nil then
			return "SKIP", NO_STRAY
		end
		standNextTo(stray)
		local startedAt = os.clock()
		fire("GrabEnd", stray.id)
		task.wait(1)
		local reactions = #since(startedAt, "GrabResult")
		if reactions == 0 then
			return "PASS", "ignored"
		end
		return "FAIL", "the server scored a GrabEnd that had no GrabBegin"
	end
)

case("instantEnd", Enum.KeyCode.Four, "Instant end: GrabEnd 0.05 s after GrabBegin", function()
	local stray = nearestStray()
	if stray == nil then
		return "SKIP", NO_STRAY
	end
	local result, after = grabWithRelease(stray, 0.05)
	checkInIfCarrying()
	if result == nil then
		return "FAIL", "no GrabResult at all; the lock should have resolved itself at 1.75 s"
	end
	if resolvedByTimeout(after) then
		return "PASS",
			string.format(
				"dropped; the hold resolved itself as a ring miss after %.2f s (%s)",
				after,
				result.text
			)
	end
	return "FAIL", string.format("GrabResult after %.2f s, so the 0.05 s release was scored", after)
end)

case("lateEnd", Enum.KeyCode.Five, "Late end: GrabEnd 2.0 s after GrabBegin", function()
	local stray = nearestStray()
	if stray == nil then
		return "SKIP", NO_STRAY
	end
	local result, after, startedAt = grabWithRelease(stray, 2.0)
	task.wait(1)
	local total = 0
	for _, event in since(startedAt, "GrabResult") do
		if string.find(event.text, stray.id, 1, true) ~= nil then
			total += 1
		end
	end
	checkInIfCarrying()
	if result == nil then
		return "FAIL", "no GrabResult; the server should resolve the hold at 1.75 s"
	end
	if resolvedByTimeout(after) and total == 1 then
		return "PASS",
			string.format("resolved at %.2f s by the server, the late GrabEnd was ignored", after)
	end
	return "FAIL", string.format("%d result(s), first after %.2f s", total, after)
end)

case("noEnd", Enum.KeyCode.Six, "No end: GrabBegin and never release", function()
	local stray = nearestStray()
	if stray == nil then
		return "SKIP", NO_STRAY
	end
	local result, after = grabWithRelease(stray, nil)
	checkInIfCarrying()
	if result == nil then
		return "FAIL", "no GrabResult; a hold with no GrabEnd must resolve at 1.75 s"
	end
	if resolvedByTimeout(after) then
		return "PASS",
			string.format("resolved as a ring miss after %.2f s (%s)", after, result.text)
	end
	return "FAIL", string.format("GrabResult after %.2f s", after)
end)

case("perfectFarm", Enum.KeyCode.Seven, "Perfect farming: 10 scripted releases at 1.6 s", function()
	local attempts, caught, expectedWithPerfect, expectedHonest = 0, 0, 0, 0
	for _ = 1, 10 do
		if not checkInIfCarrying() then
			break
		end
		local stray = nearestStray()
		if stray == nil then
			break
		end
		attempts += 1
		expectedWithPerfect += Catching.chance(stray.rarity, catchUpgradeLevel(), false, "perfect")
		expectedHonest += Catching.chance(stray.rarity, catchUpgradeLevel(), false, "miss")
		local result = grabWithRelease(stray, 1.6)
		if result ~= nil and string.find(result.text, "caught", 1, true) then
			caught += 1
		end
		task.wait(Config.GrabCooldownSeconds + 0.3)
	end
	checkInIfCarrying()
	if attempts == 0 then
		return "SKIP", NO_STRAY
	end
	return "CHECK",
		string.format(
			"%d of %d caught; expected about %.1f with every ring perfect, %.1f with no ring. Accepted by design: the bonus is capped at %.2f",
			caught,
			attempts,
			expectedWithPerfect,
			expectedHonest,
			Config.RingBonusPerfect
		)
end)

case(
	"clientRingValue",
	Enum.KeyCode.Eight,
	'Client ring value: GrabEnd(id, "perfect") at 0.5 s',
	function()
		local stray = nearestStray()
		if stray == nil then
			return "SKIP", NO_STRAY
		end
		local result, after = grabWithRelease(stray, 0.5, "perfect")
		checkInIfCarrying()
		if result == nil then
			return "FAIL", "no GrabResult"
		end
		-- GrabResult carries no ring, so a server that honoured "perfect" would answer at the same moment. The client
		-- cannot tell the two apart; the proof is CatService.onGrabEnd taking only the stray id (code review 2026-10-26).
		return "CHECK",
			string.format(
				"GrabResult after %.2f s (%s). The ring is not visible from here: confirm onGrabEnd ignores extra arguments",
				after,
				result.text
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
	:Connect(function(strayId: string, ok: boolean, reason: string, retry: boolean)
		record(
			"GrabResult",
			string.format(
				"%s ok=%s reason=%q retry=%s",
				strayId,
				tostring(ok),
				reason,
				tostring(retry)
			)
		)
	end)
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
