--!strict
-- Game moments on this client, one Signal each, for the sound and effects modules to react to (sound list
-- section 6, docs/audio/cat-cafe/sound-list.md). The controllers fire them from the server's events; Audio and
-- Effects only listen. A listener never changes game state and never fires a remote.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Signal"))

local Moments = {
	CatchStart = Signal.new() :: Signal.Signal<string>, -- (strayId) the circles arrived
	CircleAppear = Signal.new() :: Signal.Signal<number, number>, -- (index, shrinkSeconds) a circle starts closing,
	-- at its startsAt in server time; none after CatchResult
	NetSwing = Signal.new() :: Signal.Signal<number>, -- (index) a press on a circle, the instant it lands
	CircleGrade = Signal.new() :: Signal.Signal<number, string>, -- (index, "perfect" | "good" | "miss") this
	-- device's estimate at press time; the server's grades come with CatchSuccess or CatchFail
	CatchSuccess = Signal.new() :: Signal.Signal<string, string?>, -- (strayId, rarity)
	CatchFail = Signal.new() :: Signal.Signal<string>, -- (strayId) a Miss ended the catch
	Purrfect = Signal.new() :: Signal.Signal<number>, -- (charmGain) every circle Perfect
	CatFound = Signal.new() :: Signal.Signal<string, boolean>, -- (catId, isNew) checked in at the cafe
	CheckIn = Signal.new() :: Signal.Signal<()>, -- the carried cat went into the cafe
	CatDrop = Signal.new() :: Signal.Signal<Vector3>, -- (position) this player pressed Drop or G while carrying, at
	-- the press (like NetSwing); position is the character's root
	Travel = Signal.new() :: Signal.Signal<string>, -- (destination) the server allowed a Travel: "home", an area id
	-- or the manhole's area
	CatPlaced = Signal.new() :: Signal.Signal<string, string>, -- (uid, role) a sync shows a cat newly in a role, or
	-- moved to another one
	UnplaceCat = Signal.new() :: Signal.Signal<string>, -- (uid) a sync shows a cat off its role; Unequip all fires
	-- one per cat in the same frame
	TipJarClaim = Signal.new() :: Signal.Signal<number>, -- (step) a TipJarState shows this step newly claimed (F47)
	RankUp = Signal.new() :: Signal.Signal<number>, -- (tier) this player's cafe ranked up
	AreaUnlock = Signal.new() :: Signal.Signal<string, Vector3>, -- (areaId, gate position) a gate opened for you
	Announce = Signal.new() :: Signal.Signal<string, string?>, -- (text, rarity) a server shout-out
	PlotOpened = Signal.new() :: Signal.Signal<Vector3, number>, -- (door position, plotIndex) a For Rent plot opened
	CoinPop = Signal.new() :: Signal.Signal<Vector3>, -- (position) a customer's tip floated up over your cafe
	Purchase = Signal.new() :: Signal.Signal<()>, -- a sync shows an upgrade, decor or lure you bought
	RichArrive = Signal.new() :: Signal.Signal<()>, -- a rich customer came to your cafe and left a tip (F31)
	RichTipClaim = Signal.new() :: Signal.Signal<()>, -- the rich tip went into your till, collected or at expiry
	DealerArrive = Signal.new() :: Signal.Signal<()>, -- the night dealer's cart parked on the street
	DealerLeave = Signal.new() :: Signal.Signal<()>, -- the cart left at dawn
	-- Rescue minigames (F27), from RescueChallenge and RescueResult: the server's count, not this device's guess
	RescueStart = Signal.new() :: Signal.Signal<string>, -- (rescueSpotId) the bar came up
	RescueHit = Signal.new() :: Signal.Signal<number, number, number, string?>, -- (hits, needed, pawsLeft, trapType)
	RescueMiss = Signal.new() :: Signal.Signal<number>, -- (pawsLeft)
	RescueDrop = Signal.new() :: Signal.Signal<string>, -- (rescueSpotId) a tree's cat fell after the last shake
	RescueDone = Signal.new() :: Signal.Signal<string, string?>, -- (rescueSpotId, rarity) the cat is free
	RescueFail = Signal.new() :: Signal.Signal<string>, -- (rescueSpotId) out of paws or time, or walked away
	RescueCancel = Signal.new() :: Signal.Signal<string>, -- (rescueSpotId) Give up
	-- Shove (F41, section 10c), from ShoveResult on every client. role is "shover", "target" or "bystander";
	-- position is the target's. Shove fires for every landed shove, then BumpLoose or BumpHeld when the target
	-- carried a cat that could be knocked loose.
	Shove = Signal.new() :: Signal.Signal<string, Vector3>,
	BumpLoose = Signal.new() :: Signal.Signal<string, Vector3>, -- the cat fell out of the target's arms
	BumpHeld = Signal.new() :: Signal.Signal<string, Vector3>, -- "It held on tight!"
}

return Moments
