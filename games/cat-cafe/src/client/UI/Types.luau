--!strict
-- Shared type definitions for the cat cafe UI.
-- The engineer's client controller builds tables of these shapes and hands them to UI.init / UI.update.
-- Field names match docs/design/cat-cafe/ui-contract.md and src/shared/Types.luau (engineer).
-- The UI only reads these; it never writes player data.

export type Rarity = "Common" | "Rare" | "Epic" | "Legendary" | "Secret"

export type RingResult = "perfect" | "good" | "miss"

export type CatDef = {
	id: string,
	name: string,
	rarity: Rarity,
	incomePerSecond: number,
	area: string?, -- "alley" | "park" | "both"
	favoriteSpot: string?, -- spot type, e.g. "counter" (1.5x on that spot type)
	description: string?,
	imageId: string?, -- rbxassetid://... when art exists; nil draws a placeholder
	color: { number }?, -- {r, g, b} 0..255 placeholder body colour (engineer's catalog)
}

export type UpgradeDef = {
	id: string,
	name: string,
	description: string,
	maxLevel: number,
	costs: { number }, -- costs[n] is the price of level n
	startLevel: number?, -- 1 for cafe_level and espresso, else 0
	requiresCafeLevel: number?, -- whole upgrade gated behind a cafe level
	requiresCafeLevelAtLevel: { [number]: number }?, -- e.g. { [3] = 3 }: level 3 needs cafe 3
	icon: string?,
}

export type DecorDef = {
	id: string,
	name: string,
	cost: number,
	category: string, -- "Plants", "Floor", "Wall", "Furniture" ... drives the filter chips
	effect: string?, -- one line, e.g. "+5% tips"
	description: string?,
	requiresCafeLevel: number?,
	imageId: string?,
}

-- Percentages that sum to 100. Shown before purchase (paid random items rule).
export type LureOdds = { Common: number, Rare: number, Epic: number, Legendary: number }

export type LureDef = {
	id: string,
	name: string,
	cost: number,
	attracts: Rarity,
	description: string?,
	odds: LureOdds?,
}

export type SpotDef = {
	id: string, -- "counter_1"
	spotType: string, -- "counter"
	cafeLevel: number, -- opens at this cafe level
}

export type Catalog = {
	cats: { CatDef },
	upgrades: { UpgradeDef },
	decor: { DecorDef },
	lures: { LureDef },
	spots: { SpotDef }?, -- needed for the cat room's Place picker
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
	spotId: string?, -- nil when resting in the cat room
}

export type PlayerState = {
	money: number,
	incomePerSecond: number,
	cafeLevel: number,
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
	carrying: string?, -- catId while carrying a stray home (HUD banner)
	tutorialStep: number?,
}

-- Partial update accepted by UI.update. Every field optional. Tables replace, not deep-merge,
-- except the top level (so pass the whole catsOwned map when a cat is added).
export type PartialState = {
	money: number?,
	incomePerSecond: number?,
	cafeLevel: number?,
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
	carrying: string?,
	tutorialStep: number?,
}

export type ScreenName = "Upgrades" | "Decor" | "Collection"

export type ToastKind = "info" | "good" | "warn" | "announce"

export type CatchInfo = {
	catName: string?,
	catId: string?,
	strayId: string?,
	rarity: Rarity?,
	holdDuration: number?, -- seconds the ring takes to shrink (default Config GrabHoldSeconds 1.5)
	actionText: string?, -- default "Hold to grab"
	keyCode: Enum.KeyCode?, -- default E
}

export type RingConfig = {
	duration: number?, -- seconds from full ring to zero
	goodBand: { number }?, -- { min, max } ring scale for "good", default { 0.26, 0.48 }
	perfectBand: { number }?, -- { min, max } ring scale for "perfect", default { 0.33, 0.41 }
}

export type CarryInfo = {
	catId: string?,
	catName: string?,
	rarity: Rarity?,
	door: BasePart?, -- own cafe door; shows a world marker with distance
}

export type InitConfig = {
	catalog: Catalog,
	keybinds: boolean?, -- default true: U upgrades, B decor, C collection, F lure
	parent: Instance?, -- default LocalPlayer.PlayerGui
}

return nil
