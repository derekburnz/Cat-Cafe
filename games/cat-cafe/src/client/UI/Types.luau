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
export type SpotDef = SharedTypes.SpotDef
export type TierDef = SharedTypes.TierDef -- data-model section 5b
export type AreaDef = SharedTypes.AreaDef

export type Catalog = {
	cats: { CatDef },
	upgrades: { UpgradeDef },
	decor: { DecorDef },
	lures: { LureDef },
	spots: { SpotDef }?, -- role slots; needed for the cat room's Assign picker
	tiers: { TierDef }?, -- v0.3: tier names, gates and the rank up card
	areas: { AreaDef }?, -- v0.3: which areas a tier opens (bait odds pool every unlocked area)
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
	equippedLure: string?,
	-- optional extras the engineer's ProfileSync also sends
	cats: { [string]: CatInstance }?, -- uid -> instance; enables the cat room tab
	collection: { [string]: number }?, -- catId -> firstCaughtAt; drives silhouettes
	shinyCollection: { [string]: number }?, -- catId -> first shiny caught at
	carrying: string?, -- catId while carrying a stray home (HUD banner)
	tutorialStep: number?,
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
	equippedLure: string?,
	cats: { [string]: CatInstance }?,
	collection: { [string]: number }?,
	shinyCollection: { [string]: number }?,
	carrying: string?,
	tutorialStep: number?,
}

export type ScreenName = "Upgrades" | "Decor" | "Collection" | "RankUp" | "Areas" | "Bait" | "Dealer"

export type ToastKind = "info" | "good" | "warn" | "announce"

export type CatchInfo = {
	catName: string?,
	catId: string?,
	strayId: string?,
	rarity: Rarity?,
	holdDuration: number?, -- the prompt's HoldDuration: 0 for a press, the rescue hold's length otherwise
	actionText: string?, -- default "Catch", "Rescue" or "Hold to rescue"
	keyCode: Enum.KeyCode?, -- default E
	stars: number?, -- 1 to 5 from the stray's Stars attribute
	charm: number?, -- 0 to 100 from the stray's Charm attribute
	kind: PromptKind?, -- default "swing" (the net); "rescue" is a stuck cat (F21)
	rescueSpotId: string?, -- RescueSpotId attribute; what RescueBegin and RescueEnd take
	press: boolean?, -- v0.3: the prompt has HoldDuration 0, so one press starts the catch or rescue
	shiny: boolean?, -- v0.3: the stray's Shiny attribute (rescued cats hide it until freed)
	patience: number?, -- v0.4: the stray's Patience attribute, its full paw count; nil on a v0.3 server
	paws: number?, -- v0.4: paws this player has left on it (Paws_<UserId>, else Patience)
}

-- Net circles (F26, data-model section 10), from shared Types. Times are server time
-- (Workspace:GetServerTimeNow()): a circle starts at its widest at startsAt and meets its ring at
-- startsAt + shrinkSeconds. x and y are 0 to 1 and map into the middle of the screen, clear of the HUD.
-- Windows are half-widths in seconds either side of each target, from the player's net level.
export type CatchCircle = SharedTypes.CatchCircle
export type CatchWindows = SharedTypes.CatchWindows
export type CircleGrade = SharedTypes.CircleGrade

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
	keybinds: boolean?, -- default true: U upgrades, B decor, C collection, F lure
	parent: Instance?, -- default LocalPlayer.PlayerGui
	-- Plays a cue by id (pass Audio.play). The UI calls uiClick, uiError, uiOpen, uiClose, uiToast, uiTab,
	-- uiHint and uiRankReady; nil keeps the UI silent.
	playSound: ((cueId: string) -> ...any)?,
	-- v0.3 bait bowl (F28): the HUD lure slot becomes the bowl chip and F opens the Bait bowl screen. Leave it
	-- off while the server still runs the v0.2 lure spots (equipLure).
	baitBowl: boolean?,
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
	variant: string?, -- "shiny" shows the sparkle
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
