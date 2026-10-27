--!strict
-- Game moments on this client, one Signal each, for the sound and effects modules to react to (sound list
-- section 6, docs/audio/cat-cafe/sound-list.md). The controllers fire them from the server's events; Audio and
-- Effects only listen. A listener never changes game state and never fires a remote.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Signal"))

local Moments = {
	CatchStart = Signal.new() :: Signal.Signal<string>, -- (strayId) the circles arrived
	CircleGrade = Signal.new() :: Signal.Signal<number, string>, -- (index, "perfect" | "good" | "miss")
	CatchSuccess = Signal.new() :: Signal.Signal<string, string?>, -- (strayId, rarity)
	CatchFail = Signal.new() :: Signal.Signal<string>, -- (strayId) a Miss ended the catch
	PawLost = Signal.new() :: Signal.Signal<number>, -- (pawsLeft) after a Miss, when this player can run out
	Purrfect = Signal.new() :: Signal.Signal<number>, -- (charmGain) every circle Perfect
	CatFound = Signal.new() :: Signal.Signal<string, boolean>, -- (catId, isNew) checked in at the cafe
	CheckIn = Signal.new() :: Signal.Signal<()>, -- the carried cat went into the cafe
	RankUp = Signal.new() :: Signal.Signal<number>, -- (tier) this player's cafe ranked up
	AreaUnlock = Signal.new() :: Signal.Signal<string, Vector3>, -- (areaId, gate position) a gate opened for you
	Announce = Signal.new() :: Signal.Signal<string, string?>, -- (text, rarity) a server shout-out
}

return Moments
