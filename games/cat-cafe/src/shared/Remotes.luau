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
	"RescueBegin", -- (rescueSpotId: string)  spot holds a stuck cat, not locked by another player, in range, not carrying
	"RescueEnd", -- (rescueSpotId: string)  sent after the full hold; the server checks RescueHoldSeconds on its own clock
	"CheckIn", -- ()  carrying and within CheckInRangeStuds of own plot Door
	"PlaceCat", -- (uid: string, spotId: string)
	"UnplaceCat", -- (uid: string)
	"EquipBest", -- ()  places owned cats on open spots for the highest rate (shared/EquipBest.plan)
	"SellCat", -- (uid: string)
	"BuyUpgrade", -- (upgradeId: string)
	"BuyDecor", -- (decorId: string)
	"ToggleDecor", -- (decorId: string, placed: boolean)
	"BuyLure", -- (lureId: string)
	"EquipLure", -- (lureId: string?)
	"UseLure", -- (lureSpotId: string)
	"ClaimOffline", -- ()
	"TutorialAdvance", -- (step: number)
	"RequestSync", -- ()  asks for a full ProfileSync (client UI just loaded)
}

-- Server -> client.
Remotes.ServerToClient = {
	"ProfileSync", -- (state: Types.PlayerState)  full state; the client merges
	"CatCaught", -- (catId: string, isNew: boolean)
	"OfflineEarnings", -- (amount: number, seconds: number)
	"Toast", -- (text: string, kind: "info" | "good" | "warn")
	"Announce", -- (text: string)  fired to everyone
	"GrabResult", -- (id: string, ok: boolean, reason: string, retry: boolean)  id is a strayId or a rescueSpotId;
	-- retry keeps the prompt open. For a stray it only refuses GrabBegin; the catch outcome is CatchResult.
	"CatchSchedule", -- (strayId: string, circles: { Types.CatchCircle }, windows: Types.CatchWindows)
	"CatchResult", -- (strayId: string, scores: { number }, chance: number, success: boolean, stayed: boolean)
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
