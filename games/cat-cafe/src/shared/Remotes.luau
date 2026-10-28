--!strict
-- The one list of RemoteEvents (data-model section 15). The server creates them in ReplicatedStorage.Remotes;
-- the client waits for them. Every client -> server call is validated and rate limited in server/Services/Net.luau.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

Remotes.FolderName = "Remotes"

-- Client -> server: (args) and what the server checks.
Remotes.ClientToServer = {
	"GrabBegin", -- (strayId: string)  locks the stray and answers with CatchSchedule
	"CatchPress", -- (strayId: string, index: number)  no time is sent: the server stamps the press on arrival
	"RescueBegin", -- (rescueSpotId: string)  trap holds a stuck cat, unlocked, past its retry waits, in range, not carrying
	"RescuePress", -- (rescueSpotId: string)  no time is sent: the server stamps the press and judges the marker
	"RescueCancel", -- (rescueSpotId: string)  Give up: ends the attempt as a fail
	"CheckIn", -- ()  carrying and within CheckInRangeStuds of own plot Door
	"DropCat", -- ()  carrying: lets the cat go, at the feet in a catching area, else back to its own area
	"PickUpCat", -- (strayId: string)  v0.8 F56: a Dropped stray, area unlocked, 10 studs, not carrying, no lock held,
	-- GrabCooldownSeconds; the first valid call wins and starts the carry (data-model section 10c)
	"PlaceCat", -- (uid: string, spotId: string)
	"UnplaceCat", -- (uid: string)
	"EquipBest", -- ()  places owned cats on open spots for the highest rate (shared/EquipBest.plan)
	"UnequipAll", -- ()  rests every working cat in the cat room (shared/EquipBest.restAll)
	"SellCat", -- (uid: string)
	"BuyUpgrade", -- (upgradeId: string)
	"BuyDecor", -- (decorId: string)
	"RankUp", -- ()  next tier's cost, different cats and rarity (Economy.rankUpBlocker); spends and raises the tier
	"ToggleDecor", -- (decorId: string, placed: boolean)
	"BuyLure", -- (lureId: string)
	"UseLure", -- (lureId: string)  bowl bought and empty, food in stock; from anywhere (2026-10-28)
	"ResolveBait", -- (choice: "tame" | "letgo")  the bowl's cat has arrived, within 20 studs of own BaitBowl
	"ClaimOffline", -- ()
	"TutorialAdvance", -- (step: number)
	"RequestSync", -- ()  asks for a full ProfileSync (client UI just loaded)
	"Travel", -- (destination: string)  "home" or an AreaId the player's tier opens; not while carrying or mid catch
	"BuyDealerFood", -- (slot: number, lureId: string)  night, near the cart, the slot still holds lureId (S42)
	"Tackle", -- ()  v0.11 F74 (data-model section 10c, shared/Shove): in an unlocked catching area, areas open, not
	-- carrying, no lock, off TackleCooldownSeconds; lunges and hits the first player in reach who could be shoved
	"ClaimRichTip", -- ()  own plot has an unexpired rich tip, within RichTipRangeStuds of its RichTipAnchor
	"RenameCat", -- (uid: string, name: string)  owns uid; CatName.validate; RenameCooldownSeconds; the filter passes
	"TelemetryReport", -- (name: string, value: string)  analytics only, allowlisted: device once, ui_opened (F16)
	"SetSetting", -- (key: string, value: boolean | number)  a key of shared/Settings: a switch takes a boolean, a
	-- volume a number clamped to 0 to 1; saved in profile.settings, answered by ProfileSync
	"ClaimTipJar", -- (step: number)  integer 1 to #Catalog.tipJar, unclaimed this session, its minutes reached (F47)
	"ClaimIndexReward", -- (areaId: string, milestoneId: string)  known prize, unclaimed, the area's count met (F48)
	"SpinWheel", -- ()  within SpinStationRange of a SpinWheel station, a free or banked spin, SpinCooldownSeconds (F49)
	"OpenCrate", -- (crateId: string)  within FishMarketRange of a FishMarket, the crate's zone unlocked, a banked
	-- crate (used first) or its price in golden fish, CrateOpenCooldownSeconds between opens (F53, shared/Crates)
	"BuyFishItem", -- (itemId: string)  within FishMarketRange of a FishMarket, a lure or perk row of Catalog.fishShop,
	-- below its max level, its cost in golden fish (F53); answered with a toast and a ProfileSync
	"RedeemCode", -- (text: string)  within CodesCatRange of a CodesCat, at most 40 bytes, trimmed and lowercased to 1
	-- to CodeMaxLength letters and digits, a known active code not yet redeemed (F65, shared/Codes); 1 per 2 s, locked
	-- CodeLockSeconds after CodeWrongLimit wrong codes; answered with CodeResult
	"IntroDone", -- (shot: number, replay: boolean)  integer 0 to 9: 0 when the intro cutscene played to the end, else
	-- the shot showing at Skip (F72, shared/Intro); 1 a second. The first non-replay call sets introSeen
	"ReportBug", -- (text: string, kind: string?, clientErrors: { string }?)  shared/BugReport: 3 to 500 bytes of
	-- UTF-8 text; kind "bug", "stuck" or "idea"; up to 3 error lines; 1 per 20 s, 10 a player and 200 a server
}

-- Server -> client.
Remotes.ServerToClient = {
	"ProfileSync", -- (state: Types.PlayerState)  full state; the client merges
	"CatCaught", -- (catId: string, isNew: boolean)
	"OfflineEarnings", -- (amount: number, seconds: number)
	"Toast", -- (text: string, kind: "info" | "good" | "warn")
	"Announce", -- (text: string, rarity: Types.Rarity?)  fired to everyone; rarity on a rare catch
	"GrabResult", -- (id: string, ok: boolean, reason: string, retry: boolean)  id is a strayId or a rescueSpotId;
	-- retry keeps the prompt open. For a stray it only refuses GrabBegin; the catch outcome is CatchResult.
	"CatchSchedule", -- (strayId: string, circles: { Types.CatchCircle }, windows: Types.CatchWindows)
	"CatchResult", -- (strayId: string, grades: { Types.CircleGrade }, success: boolean, charmGain: number)  grades
	-- up to and including the first Miss; after a miss the stray sprints off and anyone may try again (v0.5)
	"RescueChallenge", -- (rescueSpotId: string, challenge: Types.RescueChallenge)  the bar, or a tree's falling cat
	"RescueResult", -- (rescueSpotId: string, hits: number, pawsLeft: number, done: boolean, success: boolean)
	-- after every judged press and when the attempt ends; refusals of RescueBegin come as GrabResult
	"TravelResult", -- (destination: string, ok: boolean, reason: string?)  answers every Travel the limiter lets through
	"PlotOpened", -- (position: Vector3, plotIndex: number)  fired to everyone when a For Rent plot gets an owner
	"DealerStock", -- (stock: Types.DealerStock?)  this player's three slots at night, nil by day; after every buy
	"TipJarState", -- (state: Types.TipJarState)  when the profile loads and after every claim (F47)
	"SpinResult", -- (slice: number, amount: number)  the slice a SpinWheel landed on and its coins or foods; 0, 0
	-- when refused (F49)
	"CrateResult", -- (crateId: string, decorId: string, duplicate: boolean, refund: number)  the piece an OpenCrate
	-- gave (its rarity and kind are on its DecorDef) and the golden fish a duplicate paid back; decorId "" when refused
	"CodeResult", -- (ok: boolean, message: string, prize: Types.IndexPrize?)  the answer to RedeemCode: the code box's
	-- answer line and, when ok, the prize pictures (F65)
	"ShoveResult", -- (outcome: "shove" | "loose" | "held" | "miss" | "refused", shoverUserId: number,
	-- targetUserId: number, position: Vector3?, direction: Vector3?)  a tackle that hits goes to everyone; the target's
	-- client pushes its own character ShoveKnockbackStuds along direction. "miss" (v0.11 F74: the window ended with no
	-- hit, targetUserId 0, position the tackler's, direction the lunge's) and "refused" (no position) go to the
	-- tackler alone
	"CatchBurst", -- (direction: Vector3)  the getaway (v0.8 F55): a player beside a catch or rescue that just
	-- succeeded; their client pushes its own character CatchBurstStuds along direction (flat, unit). Not a shove
	"CatLevelUp", -- (uid: string, level: number)  one of this player's cats reached `level` (v0.12 F75): the toast,
	-- the level up chime and, from the model's Level attribute, the sparkle; once per settle that raises it
}

function Remotes.folder(): Folder
	local existing = ReplicatedStorage:FindFirstChild(Remotes.FolderName)
	if existing ~= nil then
		return existing :: Folder
	end
	return ReplicatedStorage:WaitForChild(Remotes.FolderName) :: Folder
end

function Remotes.event(name: string): RemoteEvent
	return Remotes.folder():WaitForChild(name) :: RemoteEvent
end

return Remotes
