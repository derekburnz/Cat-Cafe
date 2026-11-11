--!strict
-- #2910 (Derek2 2026-11-10: "check if anyone is still using the one click buttons for areas with walk up circle areas
-- that auto open"): how each walk-up station's window was opened, "ring" (walked into its circle, WalkUpController)
-- or "prompt" (pressed its ProximityPrompt), counted per station and rolled up into station_open events
-- (Telemetry.stationOpen). Counts only, never who. Pure, so the specs and the server read the same lists.

local StationOpens = {}

-- The windows a walk-up station opens (WalkUpController's KINDS, plus the own bait bowl). "BugReport" is the Feedback
-- window, opened by the feedback stand (#3066). The Yard Sale, the Oasis Spa, the Relic Museum and the Index Boards
-- ("Collection") count their ring opens too since #3113; their prompts are not in PROMPTS, so only rings are counted.
StationOpens.WINDOWS = table.freeze({
	"Cannon",
	"Spin",
	"Market",
	"CornerShop",
	"MysteryMarket",
	"Dealer",
	"Bait",
	"BugReport",
	-- #3113: the camp stations' rings and the Index Boards'
	"YardSale",
	"OasisSpa",
	"RelicMuseum",
	"Collection",
	"Arcade", -- #3378: the Cat Arcade's ring and prompt (arcade_v1 step 2 hears it)
})
StationOpens.HOWS = table.freeze({ "ring", "prompt" })

-- The prompt name of each station's ProximityPrompt, by its window (WalkUpController's KINDS; the bowl's is
-- UIController's BaitBowlPrompt).
StationOpens.PROMPTS = table.freeze({
	CannonPrompt = "Cannon",
	SpinPrompt = "Spin",
	MarketPrompt = "Market",
	CornerShopPrompt = "CornerShop",
	MysteryPrompt = "MysteryMarket",
	DealerPrompt = "Dealer",
	BaitPrompt = "Bait",
	FeedbackPrompt = "BugReport",
	ArcadePrompt = "Arcade",
} :: { [string]: string })

-- Whether (window, how) from a client names a known station and way; anything else is dropped.
function StationOpens.valid(window: unknown, how: unknown): boolean
	return type(window) == "string"
		and type(how) == "string"
		and table.find(StationOpens.WINDOWS, window) ~= nil
		and table.find(StationOpens.HOWS, how) ~= nil
end

-- The window a pressed prompt called `name` opens, or nil for any other prompt.
function StationOpens.windowOfPrompt(name: string): string?
	return StationOpens.PROMPTS[name]
end

return StationOpens
