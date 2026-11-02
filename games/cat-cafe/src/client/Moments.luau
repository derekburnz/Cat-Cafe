--!strict
-- Game moments on this client, one Signal each, for the sound and effects modules to react to (sound list
-- section 6, docs/audio/cat-cafe/sound-list.md). The controllers fire them from the server's events; Audio and
-- Effects only listen. A listener never changes game state and never fires a remote.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Signal"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local Moments = {
	CatchStart = Signal.new() :: Signal.Signal<string>, -- (strayId) the circles arrived
	CircleAppear = Signal.new() :: Signal.Signal<number, number>, -- (index, shrinkSeconds) a circle starts closing,
	-- at its startsAt in server time; none after CatchResult
	NetSwing = Signal.new() :: Signal.Signal<number>, -- (index) a press on a circle, the instant it lands
	-- The net swing (F93, catch-rework.md section 1), from Controllers/NetSwingController: NetSmackPress on this
	-- player's own screen at the press, before the server hears of it; NetSwung (userId, hit) on every nearby client
	-- when the server judged a swing, hit true when it started a catch or a pick up; NetInReach (stray model or nil)
	-- whenever the stray this player's swing would land on right now changes, for the glow
	NetSmackPress = Signal.new() :: Signal.Signal<()>,
	NetSwung = Signal.new() :: Signal.Signal<number, boolean>,
	NetInReach = Signal.new() :: Signal.Signal<Model?>,
	CircleGrade = Signal.new() :: Signal.Signal<number, string>, -- (index, "perfect" | "good" | "miss") this
	-- device's estimate at press time; the server's grades come with CatchSuccess or CatchFail
	CatchSuccess = Signal.new() :: Signal.Signal<string, string?>, -- (strayId, rarity)
	CatchFail = Signal.new() :: Signal.Signal<string>, -- (strayId) a Miss ended the catch
	Purrfect = Signal.new() :: Signal.Signal<number>, -- (charmGain) every circle Perfect
	CatFound = Signal.new() :: Signal.Signal<string, boolean>, -- (catId, isNew) checked in at the cafe
	CheckIn = Signal.new() :: Signal.Signal<()>, -- the carried cat went into the cafe
	CatDrop = Signal.new() :: Signal.Signal<Vector3>, -- (position) this player pressed Drop or G while carrying, at
	-- the press (like NetSwing); position is the character's root
	Travel = Signal.new() :: Signal.Signal<string>, -- (destination) the server allowed a Travel: "home" or "cannon"
	-- (F84; an area id before it)
	CampCheckIn = Signal.new() :: Signal.Signal<number, string>, -- (userId, campId) F84: a carrier walked into a
	-- camp and their cat is being checked in there, fired before the cat leaves their arms; CheckIn follows for your own
	CatPlaced = Signal.new() :: Signal.Signal<string, string>, -- (uid, role) a sync shows a cat newly in a role, or
	-- moved to another one
	UnplaceCat = Signal.new() :: Signal.Signal<string>, -- (uid) a sync shows a cat off its role; Unequip all fires
	-- one per cat in the same frame
	TipJarClaim = Signal.new() :: Signal.Signal<number>, -- (step) a TipJarState shows this step newly claimed (F47)
	IndexReward = Signal.new() :: Signal.Signal<string, string>, -- (areaId, milestoneId) a sync shows this Index
	-- reward newly claimed (F48)
	RankUp = Signal.new() :: Signal.Signal<number>, -- (tier) this player's cafe ranked up
	CatLevelUp = Signal.new() :: Signal.Signal<string, number>, -- (uid, level) one of this player's cats levelled
	-- up (v0.12 F75), once per CatLevelUp from the server
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
	-- The Tackle (v0.11 F74) on the tackler's own screen, so the dive starts on the press and not a round trip later
	-- (other screens read the character's TackleAt): position is the root at the press, as the lunge starts.
	TacklePress = Signal.new() :: Signal.Signal<Vector3>,
	TackleRefused = Signal.new() :: Signal.Signal<()>, -- a "refused" ShoveResult ended this player's lunge
	-- The intro cutscene (F72) on this screen: started (replay), each shot as it starts (1 to 10, shot 6 once), and
	-- ended, played out or skipped, once everything is back. IntroCatSeated is shot 5's job (v3, F84): the demo cat
	-- appears seated at the waiter spot (the position) as the model, for a small puff.
	IntroStart = Signal.new() :: Signal.Signal<boolean>,
	IntroShot = Signal.new() :: Signal.Signal<number>,
	IntroCatSeated = Signal.new() :: Signal.Signal<Vector3, Model>,
	IntroEnd = Signal.new() :: Signal.Signal<()>,
	-- Rare moments (F89, luck-and-rare-moments.md 2a and 2b) from SecuredRare and FoundRareDecor on every client that
	-- gets them: (userId, catId, rarity, gold, variant) a big pull, or this player's first Epic (rarity Epic, not
	-- gold, userId this player's); (userId, decorId) a Mythical crate piece
	SecuredRare = Signal.new() :: Signal.Signal<number, string, string, boolean, string>,
	FoundRareDecor = Signal.new() :: Signal.Signal<number, string>,
	-- Team Rescue (F92, playing-together.md section 3): a rescue this player helped or was helped on freed its cat, to
	-- both: (rescueSpotId, rescuerUserId, helperUserId, position) for the "Team Rescue!" pop and its two-note chime
	TeamRescue = Signal.new() :: Signal.Signal<string, number, number, Vector3>,
	-- F92 (section 5): a player who joined through a pal's invite or by following them stands at that pal's front door,
	-- on every client: (joinerUserId, palUserId) for the wave from both characters
	PalArrived = Signal.new() :: Signal.Signal<number, number>,
	-- Cats make the orders (F90, cats-make-orders.md section 2), from Controllers/CafeOrders, in any cafe this client
	-- shows the making in (your own, and others nearby unless phone or Low performance):
	-- OrderMaking (plot, station, at, seconds) a Barista starts on an order: station "espresso" (steam), "oven" (flour
	-- puff and door glow) or "counter"; at is the plot's Espresso model, its Oven model or, for the counter, the
	-- Barista. The Barista's local Making (menu id) and MakeSeconds attributes are set until it is done, for its bob
	-- and the bubble's ring.
	-- OrderReady (plot, station, at, item) the "ding!", with the same plot, station and at: item is the dish (the
	-- CatCafe_Menu_<Model> clone, with a GoldPlate child and Rich true for the rich customer) where it appeared in
	-- the Workspace (the counter's pass, a tray, the customer's hands or the table), nil without its art or while it
	-- waits out of sight for its customer to sit.
	-- OrderServed (customer, itemId, position) the dish is set on the customer's table, as the heart pops.
	OrderMaking = Signal.new() :: Signal.Signal<Model, string, Instance, number>,
	OrderReady = Signal.new() :: Signal.Signal<Model, string, Instance, Model?>,
	OrderServed = Signal.new() :: Signal.Signal<Model, string, Vector3>,
	-- Your own cafe only (F90 section 2.5): (cat, position) a Waiter or Greeter swept a tip pile into its coin bag at
	-- position; (cat, position) it dropped the bag in the till at position. Cosmetic: the pile was paid as it appeared.
	TipSwept = Signal.new() :: Signal.Signal<Model, Vector3>,
	TipBanked = Signal.new() :: Signal.Signal<Model, Vector3>,
	-- F99 (rainbow-coat.md section 2): a rainbow stray spawned, on every client: (areaId, catId, strayId) for the beam
	-- over it (the stray is the model named strayId in the Strays folder, Variant "rainbow") and a nearby shimmer
	RainbowSpawned = Signal.new() :: Signal.Signal<string, string, string>,
	-- The crate reel (F103, crate-reel.md section 3), fired by the UI's reel in the Market window: CrateReelTick at each
	-- tile line crossing the marker (Sound's ticks, at most one every 0.06 s), CrateReelLanded at the stop or on a tap
	-- skip (the thunk, and VFX's lid pop on the counter crate).
	CrateReelTick = Signal.new() :: Signal.Signal<()>,
	CrateReelLanded = Signal.new() :: Signal.Signal<()>,
	-- The camp extras (F100, camp-extras.md section 3), from Controllers/CampExtrasController: CampExtraCollect
	-- (extraId, position) on this client when the server confirms a collect or a Yard Sale buy ("picnic", "pond": the
	-- rod lands the fish, "lostFound": the lid lets the prize out, or "yardSale"), at the extra's PromptAnchor;
	-- CampExtrasState (state) on every CampExtrasState from the server, the Lost and Found's prizes waiting at
	-- state.lostFound.held (its lid rattles while above 0).
	CampExtraCollect = Signal.new() :: Signal.Signal<string, Vector3>,
	CampExtrasState = Signal.new() :: Signal.Signal<Types.CampExtrasState>,
}

return Moments
