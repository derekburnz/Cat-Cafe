--!strict
-- Shared types. Field names follow docs/design/cat-cafe/ui-contract.md and data-model.md.
-- Pure: no Roblox globals, so tests can require it.

export type Rarity = "Common" | "Rare" | "Epic" | "Legendary" | "Secret"
export type Area = "alley" | "park" | "both"
export type SpotType = "counter" | "window" | "cushion" | "shelf" | "cattree" | "patio"
export type RingResult = "perfect" | "good" | "miss"
export type ToastKind = "info" | "good" | "warn"

export type RarityDef = {
	incomePerSecond: number,
	baseCatchChance: number,
	fleesOnMiss: boolean,
	sellValue: number,
	firstCatchReward: number,
	color: string, -- hex like "#8E97B2"
}

export type CatDef = {
	id: string,
	name: string,
	rarity: Rarity,
	incomePerSecond: number,
	area: Area,
	favoriteSpot: SpotType,
	description: string,
	pattern: string,
	color: { number }, -- {r, g, b} 0..255 for the placeholder body
}

export type UpgradeDef = {
	id: string,
	name: string,
	description: string,
	maxLevel: number,
	costs: { number }, -- costs[n] = cost of level n
	startLevel: number, -- 0 for most, 1 for cafe_level and espresso
	requiresCafeLevel: number?,
	requiresCafeLevelAtLevel: { [number]: number }?, -- e.g. espresso level 3 needs cafe 3
}

export type DecorDef = {
	id: string,
	name: string,
	cost: number,
	category: string,
	effect: string,
	description: string,
	requiresCafeLevel: number?,
	bonus: number, -- added to the cafe multiplier while placed
	asset: string, -- model name in ReplicatedStorage.Assets
}

export type LureOdds = { Common: number, Rare: number, Epic: number, Legendary: number }

export type LureDef = {
	id: string,
	name: string,
	cost: number,
	attracts: Rarity,
	description: string,
	odds: LureOdds, -- percentages summing to 100, shown before purchase
	asset: string, -- food model shown in the bowl while the lure is active
}

export type AreaDef = {
	id: string,
	name: string,
	unlock: string?, -- upgrade id that must be level 1+, nil when free
	spawnPoints: number,
	maxStrays: number,
	spawnInterval: number,
	despawnAfter: number,
	odds: LureOdds,
}

export type SpotDef = {
	id: string, -- "counter_1"
	spotType: SpotType,
	cafeLevel: number, -- opens at this cafe level
}

export type CatInstance = {
	uid: string,
	catId: string,
	variant: string, -- "base" in the slice
	caughtAt: number,
	spotId: string?, -- nil when resting in the cat room
}

export type Stats = {
	catsCaught: number,
	catsSold: number,
	grabsAttempted: number,
	grabsSucceeded: number,
	luresUsed: number,
	playtimeSeconds: number,
	sessions: number,
}

-- Saved per player (data-model section 14). JSON-safe values only.
export type PlayerProfile = {
	version: number,
	coins: number,
	lifetimeCoins: number,
	lastTick: number,
	lastSeen: number,
	rateAtLogout: number,
	upgradeLevels: { [string]: number },
	decorOwned: { [string]: boolean },
	decorPlaced: { [string]: boolean },
	lures: { [string]: number },
	equippedLure: string?,
	cats: { [string]: CatInstance },
	collection: { [string]: number },
	stats: Stats,
	tutorialStep: number,
	settings: { music: boolean, sfx: boolean },
}

-- What ProfileSync sends. Matches ui-contract PlayerState plus a few extras the controller uses.
export type PlayerState = {
	money: number,
	incomePerSecond: number,
	cafeLevel: number,
	cafeProgress: number?,
	cafeProgressText: string?,
	tables: number,
	customers: number?, -- not sent; customers are simulated on the client
	catsOwned: { [string]: { count: number } },
	upgradeLevels: { [string]: number },
	decorOwned: { [string]: boolean },
	decorPlaced: { [string]: boolean },
	lures: { [string]: number },
	equippedLure: string?,
	-- extras (not in the UI contract, used by the client controller)
	cats: { [string]: CatInstance },
	collection: { [string]: number },
	plotIndex: number,
	carrying: string?, -- catId while carrying a caught stray home
	dataSaves: boolean,
	tutorialStep: number,
	serverTime: number,
}

return {}
