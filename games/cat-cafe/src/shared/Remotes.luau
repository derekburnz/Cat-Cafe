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
	"UseLure", -- (lureId: string)  bowl bought and empty, food in stock, within BaitBowlRangeStuds of own BaitBowl
	"ResolveBait", -- (choice: "tame" | "letgo")  the bowl's cat has arrived, within 20 studs of own BaitBowl
	"ClaimOffline", -- ()
	"TutorialAdvance", -- (step: number)
	"RequestSync", -- ()  asks for a full ProfileSync (client UI just loaded)
	"Travel", -- (destination: string)  "home" or an AreaId the player's tier opens; not while carrying or mid catch
	"BuyDealerFood", -- (slot: number, lureId: string)  night, near the cart, the slot still holds lureId (S42)
	"Bump", -- (targetUserId: number)  Shove: both in one unlocked catching area, range, locks, safe zone, cooldowns
	-- and target immunity (data-model section 10c, shared/Shove)
	"ClaimRichTip", -- ()  own plot has an unexpired rich tip, within RichTipRangeStuds of its RichTipAnchor
	"RenameCat", -- (uid: string, name: string)  owns uid; CatName.validate; RenameCooldownSeconds; the filter passes
	"TelemetryReport", -- (name: string, value: string)  analytics only, allowlisted: device once, ui_opened (F16)
	"SetSetting", -- (key: string, value: boolean)  "music" or "sfx"; saved in profile.settings, answered by ProfileSync
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
	"ShoveResult", -- (outcome: "shove" | "loose" | "held" | "refused", shoverUserId: number, targetUserId: number,
	-- position: Vector3?, direction: Vector3?)  a landed shove goes to everyone; the target's client pushes its own
	-- character ShoveKnockbackStuds along direction. "refused" goes to the shover alone, with no position
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
