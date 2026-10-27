--!strict
-- Type definitions for the cat cafe UI.
-- Catalog types (Rarity, Role, CatDef, UpgradeDef, DecorDef, LureDef, SpotDef, TierDef, AreaDef) are re-exported from
-- src/shared/Types.luau (engineer) so the client controller can hand the shared Catalog to UI.init with
-- no cast. State, event and screen types below are the UI's own; field names follow
-- docs/design/cat-cafe/ui-contract.md. The UI only reads these; it never writes player data.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SharedTypes = require(Shared:WaitForChild("Types"))

export type Rarity = SharedTypes.Rarity
export type Area = SharedTypes.Area
export type SpotType = SharedTypes.SpotType -- v0.3: the same as Role; a role slot is still a spot in code
export type Role = SharedTypes.Role
export type CatchMethod = SharedTypes.CatchMethod
export type ClockPhase = "day" | "night" -- Clock folder attribute Phase (data-model section 9)
export type PromptKind = "swing" | "rescue" -- the net (closing circles), or a stuck cat (the rescue hold)
export type CatDef = SharedTypes.CatDef
export type UpgradeDef = SharedTypes.UpgradeDef
export type DecorDef = SharedTypes.DecorDef
export type LureOdds = SharedTypes.LureOdds -- percentages that sum to 100, shown before purchase
export type LureDef = SharedTypes.LureDef
export type RarityDef = SharedTypes.RarityDef
export type SpotDef = SharedTypes.SpotDef
export type TierDef = SharedTypes.TierDef -- data-model section 5b
export type AreaDef = SharedTypes.AreaDef

export type Catalog = {
	cats: { CatDef },
	upgrades: { UpgradeDef },
	decor: { DecorDef },
	lures: { LureDef },
	spots: { SpotDef }?, -- role slots; needed for the cat room's crew strip and Upgrades > Staff
	tiers: { TierDef }?, -- v0.3: tier names, gates and the rank up card
	areas: { AreaDef }?, -- v0.3: which areas a tier opens (bait odds pool every unlocked area)
	tipJar: { TipJarRow }?, -- F47: the twelve playtime gifts (data-model section 11b)
	indexMilestones: { IndexMilestone }?, -- F48: the Index's milestones, the same on every area page
	indexPrizes: { [string]: { [string]: IndexPrize } }?, -- F48: area id -> milestone id -> prize (S61: not indexRewards)
	rarities: { [string]: RarityDef }?, -- the cat room's sell prices (reviewer N103)
	spinWheel: { SpinRow }?, -- F49: the Spin Wheel's six slices, clockwise from the top (data-model section 11c)
	crates: { [string]: CrateDef }?, -- F53: Catalog.crates, the Cafe Crates by id (golden-fish.md section 4)
}

-- A Cafe Crate (F53): ten cosmetics of one pool (a zone id or "classic"); golden ones are Epic or better.
export type CrateDef = SharedTypes.CrateDef

-- One Spin Wheel slice (F49): the Tip Jar row's prize plus a weight; the weights add up to 100.
export type SpinRow = {
	slice: number,
	kind: string, -- "coins", "lure", F54 "fish" (golden fish) or "crate"
	seconds: number?,
	minCoins: number?,
	lureId: string?,
	count: number?, -- foods, golden fish or crates
	crate: string?, -- F54: the crate id, or "highest" for the crate of the player's highest open area
	weight: number,
}

-- state.spin (F49): lastFreeDay is the UTC day number (floor(serverTime / 86400)) of the last free spin.
export type SpinState = {
	lastFreeDay: number,
	banked: number,
}

-- One Tip Jar gift (F47): unlocks `minutes` into the session; coins pay max(minCoins, dayRate * seconds).
export type TipJarRow = {
	step: number,
	minutes: number,
	kind: string, -- "coins" or "lure"
	seconds: number?,
	minCoins: number?,
	lureId: string?,
	count: number?,
	spins: number?, -- F49: Spin Wheel spins it also banks (steps 11 and 12), up to SpinBankCap
	fish: number?, -- F52: golden fish it also gives (step 12)
}

-- An Index milestone (F48, data-model section 11b): `need` of the area's cats found, or as gold cats. F54
-- (golden-fish.md section 8) renames `need` to `needs` and `gold` to `track = "gold"`; read both through
-- Components/IndexRewards.need and .isGold.
export type IndexMilestone = {
	id: string, -- cats3, cats6, cats10, gold1 to gold10; total5 to total50 on the "all" page
	need: number?,
	needs: number?,
	gold: boolean?,
	track: string?, -- "normal" or "gold"
}

-- What an Index milestone pays, any of these (F54 adds all but coins, lures and decorId; decorId goes away).
export type IndexPrize = {
	coins: number?, -- the coins, or the least they pay when coinSeconds is set
	coinSeconds: number?, -- pays max(coins, floor(dayRate * coinSeconds)), like a Tip Jar gift
	lures: { [string]: number }?,
	fish: number?, -- golden fish
	spins: number?, -- banked Spin Wheel spins, up to SpinBankCap
	crates: { [string]: number }?, -- crate id -> count
	bonus: number?, -- tips forever, as a fraction (0.02)
	tag: string?, -- a name tag ("Cat Master")
	decorId: string?,
}

-- TipJarState from the server (F47): sessionStartedAt in Workspace:GetServerTimeNow() time, claimed steps.
export type TipJarState = {
	sessionStartedAt: number,
	claimed: { [any]: boolean }?,
}

export type OwnedCat = {
	count: number,
}

-- One cat the player owns (data-model section 4).
export type CatInstance = {
	uid: string,
	catId: string,
	variant: string?,
	caughtAt: number?,
	spotId: string?, -- the role slot it works ("barista_1"), nil when resting in the cat room
	rescued: boolean?,
	name: string?, -- the player's name for it, filtered by the server; nil shows the catalog name
	method: CatchMethod?, -- how it was found
	-- per-cat stats (cat stats thread); all optional, shown when present
	level: number?, -- 1 to 10
	xp: number?,
	xpToNext: number?,
	charm: number?, -- 0 to 100
	stars: number?, -- 1 to 5, derived from charm
	rating: number?, -- this cat's coins per second before spot and cafe multipliers
}

export type PlayerState = {
	money: number,
	incomePerSecond: number,
	tier: number, -- v0.3: 1 to 5, replaces cafeLevel (data-model section 5b)
	cafeProgress: number?, -- 0..1 toward the next level, nil hides the bar
	cafeProgressText: string?, -- "3 / 6 upgrades", nil hides the caption
	tables: number?,
	customers: number?,
	catsOwned: { [string]: OwnedCat }, -- catId -> count (derived from cats when cats is given)
	upgradeLevels: { [string]: number },
	decorOwned: { [string]: boolean },
	decorPlaced: { [string]: boolean },
	lures: { [string]: number },
	-- optional extras the engineer's ProfileSync also sends
	cats: { [string]: CatInstance }?, -- uid -> instance; enables the cat room tab
	collection: { [string]: number }?, -- catId -> firstCaughtAt; drives silhouettes
	goldCollection: { [string]: number }?, -- catId -> first gold cat caught at (was shinyCollection)
	carrying: string?, -- catId while carrying a stray home (HUD banner)
	tutorialStep: number?,
	settings: { [string]: boolean | number }?, -- profile.settings (shared/Settings): switches and 0 to 1 volumes
	indexRewards: { [string]: { [string]: boolean } }?, -- F48: area id -> milestone id -> true once claimed
	spin: SpinState?, -- F49: the free spin and the banked ones
	goldenFish: number?, -- F52: the rare currency; nil hides its HUD counter
	crates: { [string]: number }?, -- F53: crate id -> unopened count
	crateLuck: { [string]: number }?, -- F53: crate pool -> opens since its last Epic or better (0 to 19)
	fishPerks: { [string]: number }?, -- F53: Golden Fish Market perk id -> level
}

-- Partial update accepted by UI.update. Every field optional. Tables replace, not deep-merge,
-- except the top level (so pass the whole catsOwned map when a cat is added).
export type PartialState = {
	money: number?,
	incomePerSecond: number?,
	tier: number?,
	cafeProgress: number?,
	cafeProgressText: string?,
	tables: number?,
	customers: number?,
	catsOwned: { [string]: OwnedCat }?,
	upgradeLevels: { [string]: number }?,
	decorOwned: { [string]: boolean }?,
	decorPlaced: { [string]: boolean }?,
	lures: { [string]: number }?,
	cats: { [string]: CatInstance }?,
	collection: { [string]: number }?,
	goldCollection: { [string]: number }?,
	carrying: string?,
	tutorialStep: number?,
	settings: { [string]: boolean | number }?,
	indexRewards: { [string]: { [string]: boolean } }?,
	spin: SpinState?,
	goldenFish: number?,
	crates: { [string]: number }?,
	crateLuck: { [string]: number }?,
	fishPerks: { [string]: number }?,
}

export type ScreenName =
	"Upgrades"
	| "Decor"
	| "Collection"
	| "RankUp"
	| "Areas"
	| "Bait"
	| "Dealer"
	| "Settings"
	| "TipJar"
	| "Spin"
	| "BugReport"

export type ToastKind = "info" | "good" | "warn" | "announce"

export type CatchInfo = {
	catName: string?,
	catId: string?,
	strayId: string?,
	rarity: Rarity?,
	holdDuration: number?, -- the prompt's HoldDuration: the card fills over it (0.5 s on cat prompts), 0 for a press
	actionText: string?, -- default "Catch", "Rescue" or "Hold to rescue"
	keyCode: Enum.KeyCode?, -- default E
	stars: number?, -- 1 to 5 from the stray's Stars attribute
	charm: number?, -- 0 to 100 from the stray's Charm attribute
	kind: PromptKind?, -- default "swing" (the net); "rescue" is a stuck cat (F21)
	rescueSpotId: string?, -- RescueSpotId attribute; what RescueBegin and RescueEnd take
	press: boolean?, -- v0.3: the prompt has HoldDuration 0, so one press starts the catch or rescue
	shiny: boolean?, -- v0.3: the stray's Gold attribute (rescued cats hide it until freed)
	-- v0.5: the stray's FleeingUntil (server time). Until then it is sprinting off after a miss and nobody can
	-- grab it; the card reads "It's running!".
	fleeingUntil: number?,
	-- v0.5.1: server time this player may try again after their own miss (StraySelfRetrySeconds after the cat
	-- stops); init.luau fills it from this player's CatchResult, the card reads "Catch your breath..." until then.
	retryAt: number?,
	-- v0.5 F41: server time until which only the old carrier may catch a cat knocked loose by a shove (the
	-- stray's DropOwnerUntil while its DropOwner is someone else); nil when that is you or the cat was not dropped.
	-- The card reads "Owner's turn" until then (reviewer N90).
	ownerTurnUntil: number?,
}

-- Net circles (F26, data-model section 10), from shared Types. Times are server time
-- (Workspace:GetServerTimeNow()): a circle starts at its widest at startsAt and meets its ring at
-- startsAt + shrinkSeconds. x and y are 0 to 1 and map into the middle of the screen, clear of the HUD.
-- Windows are half-widths in seconds either side of each target, from the player's net level.
export type CatchCircle = SharedTypes.CatchCircle
export type CatchWindows = SharedTypes.CatchWindows
export type CircleGrade = SharedTypes.CircleGrade

-- Rescue minigame (F27, data-model section 10b), as RescueChallenge sends it. Times are server time
-- (Workspace:GetServerTimeNow()). "bar": the marker slides along a bar (shared/RescueMarker) and each press
-- in the zone is a hit; zones holds the zone centre (0 to 1) for each hit in order. "shake_catch": the same bar,
-- where each hit shakes the branch; the server then sends a second challenge of kind "circle", one catch
-- circle with its windows.
export type RescueKind = "bar" | "shake_catch" | "circle"

export type RescueChallenge = {
	kind: RescueKind,
	startsAt: number,
	phase: number?, -- 0 to 2, where on the back-and-forth the marker starts
	speed: number?, -- bar lengths per second (RescueBarSpeed)
	zoneWidth: number?, -- fraction of the bar (RescueZoneWidth)
	zones: { number }?,
	hitsNeeded: number?,
	paws: number?, -- misses allowed (RescuePatience); nil hides the paw row
	endsAt: number?, -- the attempt's deadline; else startsAt + RescueAttemptMaxSeconds
	circle: CatchCircle?, -- kind "circle"
	windows: CatchWindows?, -- kind "circle"
}

-- Day and night clock (data-model section 9). phaseEndsAt is server os.time() seconds, as the Clock
-- folder's PhaseEndsAt attribute; the HUD counts down against Workspace:GetServerTimeNow().
export type ClockState = {
	phase: ClockPhase,
	phaseEndsAt: number,
}

export type CarryInfo = {
	catId: string?,
	catName: string?,
	rarity: Rarity?,
	door: BasePart?, -- own cafe door; shows a world marker with distance
}

-- Optional extras for UI.showCatFound, all from the catch: the cat's charm stars (CatView.stars), whether it is
-- shiny, and the charm the Purrfect bonus added (CatchResult charmGain, v0.4).
export type CatFoundExtra = {
	stars: number?,
	shiny: boolean?,
	charmGain: number?,
}

export type InitConfig = {
	catalog: Catalog,
	keybinds: boolean?, -- default true: U upgrades, B decor, C collection, F bait bowl
	parent: Instance?, -- default LocalPlayer.PlayerGui
	-- Plays a cue by id (pass Audio.play). The UI calls uiClick, uiError, uiOpen, uiClose, uiToast, uiTab,
	-- uiHint and uiRankReady; nil keeps the UI silent.
	playSound: ((cueId: string) -> ...any)?,
}

-- What is in the bait bowl (data-model section 8), as UI.bait.set takes it. readyAt is server os.time(); the
-- rolled cat is never sent before it arrives (N30), so the countdown cannot spoil it.
export type BaitView = {
	lureId: string,
	readyAt: number,
}

-- The cat that came to the bowl, from BaitReady (a CatView or anything with these fields).
export type BaitCat = {
	catId: string,
	variant: string?, -- "gold" shows the sparkle
	charm: number?,
	stars: number?, -- 1 to 5
	name: string?, -- a custom name, else the catalog name
}

export type BaitChoice = "tame" | "letgo"

-- The night dealer's stock for this player (data-model section 8b), as the DealerStock remote sends it: three
-- slots in the order the server rolled them (the slot number Buy sends is the index here), and restocksAt in
-- server os.time() when the next dealer window starts.
export type DealerSlot = {
	lureId: string,
	cost: number,
	bought: boolean,
}

export type DealerStock = {
	slots: { DealerSlot },
	restocksAt: number,
}

-- ModuleScripts must return a non-nil value.
return {}
