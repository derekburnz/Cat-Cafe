--!strict
-- #4544 (Derek 2026-11-15: look into Roblox Journeys for the non-linear stats): the names of our Journeys and their
-- nodes, and how the events we already check map onto them. A Journey is Roblox's path chart (Creator Hub, Analytics,
-- Journeys): stages of nodes, logged on the server with AnalyticsService:LogJourneyEvent(player, journey, node,
-- sessionId, customFields). The names here must match the published config letter for letter, so the config is
-- published first (Growth-Agent) and every call takes its names from this module. A node that is not in the config
-- does not advance the journey. Analytics only, behind the `journeys` switch, and no user ids, names or free text in
-- any field: tiers, tabs, skus and item kinds only. Pure, so the specs load it.
--   storeNode(step, values) -> node?, fields    a store_v1 funnel step as a StoreVisit node
--   askNode(kind) -> node?                      an event_rsvp kind as an EventAsk node
--   tradeMix(cats, decor, crates, fish) -> string   what moved in a trade, as one word list ("cats+decor")

local Journeys = {}

Journeys.FLAG = "journeys" -- the live switch (LiveFlags.OFF_BY_DEFAULT): on once the configs are published

-- One Store visit (the session id is the visit's own, as the store_v1 funnel's).
Journeys.STORE = "StoreVisit"
Journeys.StoreNodes = table.freeze({
	-- stage 1: the Store opened, by where from (StoreFunnel.SOURCES); field 1 the Tier
	hud_tile = "OpenedFromHud",
	new_dot = "OpenedFromNewDot",
	nudge = "OpenedFromNudge",
	other = "OpenedOther",
	-- stage 2: looked past the first tab; field 1 the tab
	tab = "ViewedTab",
	-- stage 3: pressed a buy button; field 2 the sku
	buy = "PressedBuy",
	-- stage 4: how Roblox's prompt closed; field 2 the sku
	bought = "Bought",
	cancelled = "Cancelled",
})

-- One trade, for each of its two players (the session id is the trade's id).
Journeys.TRADE = "Trade"
Journeys.TradeNodes = table.freeze({
	opened = "OpenedTrade", -- stage 1: the trade window opened for both
	cat = "AddedCat", -- stage 2: this player put something on their side; field 1 the kind
	decor = "AddedDecor",
	other = "AddedOther", -- crates and golden fish
	accepted = "BothAccepted", -- stage 3: both confirmed
	done = "TradeDone", -- stage 4: field 1 what moved (tradeMix), field 2 the best rarity received
	cancelled = "TradeCancelled",
})

-- The update Event's Notify Me ask (the session id is one per play session).
Journeys.EVENT = "EventAsk"
Journeys.AskNodes = table.freeze({
	shown = "SawAsk", -- stage 1
	remind = "PressedInterested", -- stage 2
	later = "PressedLater",
	going = "RobloxGoing", -- stage 3: what Roblox's own prompt answered
	not_going = "RobloxNotGoing",
	none = "NoAnswer",
	failed = "Failed",
})

Journeys.NONE = "na" -- a field with nothing to say (fields are positional, so field 2 needs a field 1)

-- A store_v1 funnel step (`step` one of StoreFunnel.STEPS, `values` its fields) as a StoreVisit node and its fields,
-- or nil for a step with no node ("completed": Bought already said it).
function Journeys.storeNode(step: string, values: { string }): (string?, { string })
	local nodes = Journeys.StoreNodes :: { [string]: string }
	if step == "opened" then
		return nodes[values[1] or "other"] or nodes.other, { values[2] or Journeys.NONE }
	elseif step == "tab_viewed" then
		return nodes.tab, { values[1] or Journeys.NONE }
	elseif step == "buy_pressed" then
		return nodes.buy, { Journeys.NONE, values[1] or Journeys.NONE }
	elseif step == "prompt_closed" then
		local node = if values[2] == "bought" then nodes.bought else nodes.cancelled
		return node, { Journeys.NONE, values[1] or Journeys.NONE }
	end
	return nil, {}
end

-- An event_rsvp kind (Telemetry's RSVP_KINDS) as an EventAsk node, nil for an unknown kind.
function Journeys.askNode(kind: string): string?
	return (Journeys.AskNodes :: { [string]: string })[kind]
end

-- What moved in a trade, both sides together: "cats", "decor", "crates" and "fish" joined by "+", in that order;
-- "nothing" when all four are 0.
function Journeys.tradeMix(cats: number, decor: number, crates: number, fish: number): string
	local parts: { string } = {}
	if cats > 0 then
		table.insert(parts, "cats")
	end
	if decor > 0 then
		table.insert(parts, "decor")
	end
	if crates > 0 then
		table.insert(parts, "crates")
	end
	if fish > 0 then
		table.insert(parts, "fish")
	end
	return if #parts > 0 then table.concat(parts, "+") else "nothing"
end

-- Every journey with its stages of node names, as the published config must hold them (the spec checks the name
-- rules; Growth-Agent publishes from this list).
Journeys.CONFIG = table.freeze({
	[Journeys.STORE] = {
		{ "OpenedFromHud", "OpenedFromNewDot", "OpenedFromNudge", "OpenedOther" },
		{ "ViewedTab" },
		{ "PressedBuy" },
		{ "Bought", "Cancelled" },
	},
	[Journeys.TRADE] = {
		{ "OpenedTrade" },
		{ "AddedCat", "AddedDecor", "AddedOther" },
		{ "BothAccepted" },
		{ "TradeDone", "TradeCancelled" },
	},
	[Journeys.EVENT] = {
		{ "SawAsk" },
		{ "PressedInterested", "PressedLater" },
		{ "RobloxGoing", "RobloxNotGoing", "NoAnswer", "Failed" },
	},
})

return Journeys
