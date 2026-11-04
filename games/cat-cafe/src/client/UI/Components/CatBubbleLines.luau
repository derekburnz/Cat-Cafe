--!strict
-- The speech bubbles' lines (#1079, docs/design/cat-cafe/cat-bubbles.md section 1): one short line per key cat,
-- found by its station's CollectionService tag. The game-designer owns the words; a new station gets a row here
-- (under 36 characters) so the voice stays the same. Pure, so the cloud spec runner checks the lengths.
--
-- `when` says when the line may show (section 3):
--   always             whenever the station is in the world
--   unclaimedBellhop   only while this player's ProfileSync says starterCatClaimed is false
--   dealerHere         only while the night dealer's cart is in town (DealerService parks it at dusk, tagged
--                      DealerCart with Open = true, and destroys it at dawn)
--   collectorVisiting  only while the Cat Collector visits this player's cafe (CustomerController builds him on
--                      the plot, tagged CatCollector, while the plot's visit lasts)
--
-- `anchor` is the attachment the bubble floats over (the station's prompt point), and `lift` the studs the prompt's
-- action pill sits above it (ActionPill LIFT), so the bubble clears the pill. With no anchor the bubble sits 1.5
-- studs over the model's top.

export type When = "always" | "unclaimedBellhop" | "dealerHere" | "collectorVisiting"

export type Line = {
	tag: string,
	text: string,
	when: When,
	anchor: string?,
	lift: number?,
}

local CatBubbleLines = {}

CatBubbleLines.MAX_CHARS = 36

CatBubbleLines.LINES = {
	{
		tag = "SpinWheel",
		text = "Got a spin? Give the wheel a whirl!",
		when = "always",
		anchor = "PromptAnchor",
	},
	{
		tag = "FishMarket",
		text = "Crates, treats and fresh potions!",
		when = "always",
		anchor = "PromptAnchor",
	},
	-- the Codes Cat has a circle on the ground and no prompt: the bubble goes over the model
	{ tag = "CodesCat", text = "Got a code? Tell me here!", when = "always" },
	{
		tag = "BellhopStand",
		text = "A free cat for your cafe!",
		when = "unclaimedBellhop",
		anchor = "PromptAnchor",
	},
	{
		tag = "DealerCart",
		text = "Rare foods here every night!",
		when = "dealerHere",
		anchor = "PromptPoint",
		lift = 3,
	},
	-- the spec names him CatCafe_NPC_Collector (his asset); the visiting model carries the CatCollector tag
	{ tag = "CatCollector", text = "Got a cat I'm looking for?", when = "collectorVisiting" },
	{
		tag = "CornerShop",
		text = "Snacks, bubbles and fireworks!",
		when = "always",
		anchor = "PromptAnchor",
	},
} :: { Line }

return CatBubbleLines
