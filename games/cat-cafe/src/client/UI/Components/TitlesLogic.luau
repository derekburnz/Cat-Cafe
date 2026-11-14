--!strict
-- The Bag's Titles tab (Derek2 11-11: "add a title area maybe inside bag with all titles unlocked instead of having it
-- inside pass"). Titles are the chat tags (shared/ChatTags). The tab lists every one: Off first, then the titles the
-- player has, then the rest greyed out with where they come from. Equip sends PassSetTag, which the server checks
-- against ChatTags.choices, so this only draws. Kept pure so the cloud tests can load it.
--
--   rows(view)        the tab's rows, in order: { id, text, color, how, owned, equipped }; owned and locked each
--                     rarest first (RAREST)
--   HOW               title id -> where it comes from, for the greyed rows

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChatTags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ChatTags"))
local Types = require(script.Parent.Parent.Types)

local TitlesLogic = {}

export type Row = {
	id: string, -- a ChatTags id, or ChatTags.OFF
	text: string, -- "[VIP]", or "No title"
	color: string?, -- the title's "#RRGGBB", nil for Off
	how: string, -- where it comes from, or "Show no title in chat" for Off
	owned: boolean,
	equipped: boolean,
}

local HOW: { [string]: string } = {
	vip = "From the VIP pass",
	supporter = "From the Thank You Badge",
	tag_maple = "Cafe Pass Season 1 reward",
	tag_grand_opener = "Grand Opening reward",
	rank_1 = "Hold 1st place on an all-time leaderboard", -- #3333: kept only while the place is held
	rank_2 = "Hold 2nd place on an all-time leaderboard",
	rank_3 = "Hold 3rd place on an all-time leaderboard",
	-- #3694: the big achievements (ChatTags.ACHIEVEMENT_TITLES)
	title_cat_legend = "Achievement: Cat Legend",
	title_steady_hands = "Achievement: Steady Hands",
	title_devoted = "Achievement: Devoted",
	title_week_champion = "Achievement: Week Champion",
	title_gold_rush = "Achievement: Gold Rush",
}
table.freeze(HOW)
TitlesLogic.HOW = HOW

-- Derek 2026-11-13 ("sort titles in backpack section to sort rarest first so that leaderboards players can see
-- their good titles first"): the tab's order, rarest first. The leaderboard places (three players each), then the
-- big achievements hardest first, then the event and season rewards, then the bought ones. A title missing here
-- (a new ChatTags id) goes after these, in ChatTags.ORDER.
TitlesLogic.RAREST = table.freeze({
	"rank_1",
	"rank_2",
	"rank_3",
	"title_cat_legend",
	"title_devoted",
	"title_steady_hands",
	"title_week_champion",
	"title_gold_rush",
	"tag_grand_opener",
	"tag_maple",
	"supporter",
	"vip",
}) :: { string }

local function rarestOrder(): { string }
	local order: { string } = table.clone(TitlesLogic.RAREST)
	for _, id in ChatTags.ORDER do
		if not table.find(order, id) then
			table.insert(order, id)
		end
	end
	return order
end

-- The rows for the last CafePassState (`tags` the ones the player may show, `tagShown` the one their name shows).
function TitlesLogic.rows(view: Types.CafePassView?): { Row }
	local have: { [string]: boolean } = {}
	if view ~= nil and type(view.tags) == "table" then
		for _, id in view.tags do
			if ChatTags.TAGS[id] ~= nil then
				have[id] = true
			end
		end
	end
	local shown: string? = if view ~= nil then view.tagShown else nil
	if shown ~= nil and not have[shown] then
		shown = nil
	end
	local out: { Row } = {
		{
			id = ChatTags.OFF,
			text = "No title",
			color = nil,
			how = "Show no title in chat",
			owned = true,
			equipped = shown == nil,
		},
	}
	local locked: { Row } = {}
	for _, id in rarestOrder() do
		local tag = ChatTags.TAGS[id]
		if tag ~= nil then
			local row: Row = {
				id = id,
				text = tag.text,
				color = tag.color,
				how = HOW[id] or "",
				owned = have[id] == true,
				equipped = shown == id,
			}
			table.insert(if row.owned then out else locked, row)
		end
	end
	for _, row in locked do
		table.insert(out, row)
	end
	return out
end

return TitlesLogic
