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
	"PlaceCat", -- (uid: string, spotId: string)
	"UnplaceCat", -- (uid: string)
	"EquipBest", -- ()  places owned cats on open spots for the highest rate (shared/EquipBest.plan)
	"SellCat", -- (uid: string)
	"BuyUpgrade", -- (upgradeId: string)
	"BuyDecor", -- (decorId: string)
	"RankUp", -- ()  next tier's cost, different cats and rarity (Economy.rankUpBlocker); spends and raises the tier
	"ToggleDecor", -- (decorId: string, placed: boolean)
	"BuyLure", -- (lureId: string)
	"EquipLure", -- (lureId: string?)  v0.2, retired with the lure spots; kept until the abuse client drops it
	"UseLure", -- (lureId: string)  bowl bought and empty, food in stock, within BaitBowlRangeStuds of own BaitBowl
	"ResolveBait", -- (choice: "tame" | "letgo")  the bowl's cat has arrived, within 20 studs of own BaitBowl
	"ClaimOffline", -- ()
	"TutorialAdvance", -- (step: number)
	"RequestSync", -- ()  asks for a full ProfileSync (client UI just loaded)
	"Travel", -- (destination: string)  "home" or an AreaId the player's tier opens; not while carrying or mid catch
	"BuyDealerFood", -- (slot: number, lureId: string)  night, near the cart, the slot still holds lureId (S42)
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
	"CatchSchedule", -- (strayId: string, circles: { Types.CatchCircle }, windows: Types.CatchWindows, pawsLeft: number?)
	-- pawsLeft is nil when this player cannot run out of paws on the stray (data-model section 10 step 5)
	"CatchResult", -- (strayId: string, grades: { Types.CircleGrade }, success: boolean, pawsLeft: number?,
	-- charmGain: number)  grades up to and including the first Miss; the stray stays after a miss (v0.4)
	"RescueChallenge", -- (rescueSpotId: string, challenge: Types.RescueChallenge)  the bar, or a tree's falling cat
	"RescueResult", -- (rescueSpotId: string, hits: number, pawsLeft: number, done: boolean, success: boolean)
	-- after every judged press and when the attempt ends; refusals of RescueBegin come as GrabResult
	"TravelResult", -- (destination: string, ok: boolean, reason: string?)  answers every Travel the limiter lets through
	"PlotOpened", -- (position: Vector3, plotIndex: number)  fired to everyone when a For Rent plot gets an owner
	"DealerStock", -- (stock: Types.DealerStock?)  this player's three slots at night, nil by day; after every buy
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
