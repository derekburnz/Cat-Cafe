--!strict
-- Chat tags (#1624): the "[VIP]" a VIP pass owner shows before their name in chat. The server sets the player's
-- CHAT_TAG_ATTRIBUTE to a tag id from TAGS (PassService); each client's ChatTagController reads it on an incoming
-- message and puts the tag's rich text in front of the name. Only ids in TAGS are shown, so a stray value shows
-- nothing. #1626: Cafe Pass season tags (cafe-pass.md section 3) are tag items on a paid track, kept forever in
-- profile.pass.items. The player picks one tag (PassSetTag, saved as profile.pass.tag) or OFF; with no pick they show
-- VIP if they own it, else their first season tag in ORDER.
--   prefixFor(tagId) -> rich text prefix or nil
--   choices(ownsVip, items) -> the tag ids the player may show, in ORDER
--   shown(pick, ownsVip, items) -> the tag id to show, or nil
--   validPick(pick) -> whether a saved pick is a known tag id or OFF
--   textFor(tagId, text) -> the message text in the tag's colour, or nil
--   addAchievementTitles(items, achievements) -> items with the claimed big achievements' titles (#3694)

local Config = require(script.Parent.Config)

local ChatTags = {}

ChatTags.CHAT_TAG_ATTRIBUTE = "ChatTag"

export type Tag = { text: string, color: string }

local TAGS: { [string]: Tag } = {
	vip = { text = "[VIP]", color = "#F2C14E" },
	supporter = { text = "[Thank You]", color = "#FFC94D" }, -- #1168 row 4: the Thank You Badge (ChatTags.withSupporter)
	tag_maple = { text = "[Maple]", color = "#D9822B" }, -- #1626: Season 1's paid track, level 1
	tag_grand_opener = { text = "[Grand Opener]", color = "#F5A65B" }, -- #1893: the Grand Opening's last milestone
	-- #3324 (Derek2 11-11: "add title beside owner in chat"): only the game owner's account shows it (PassService,
	-- Config.OwnerUserIds); it is never a choice or a saved pick, so nobody else can show it
	owner = { text = "[Owner]", color = "#FF7A6B" },
	-- #3333 (Derek2 11-11: "add rank 1/2/3 titles"): held while the player is 1st, 2nd or 3rd on an all-time board
	-- (LeaderboardService.place); they come off at the next refresh after the place is lost
	rank_1 = { text = "[#1]", color = "#FFD54A" },
	rank_2 = { text = "[#2]", color = "#D9DEE6" },
	rank_3 = { text = "[#3]", color = "#E3A36B" },
	-- #3694 (achievements-v2.md, titles): the big achievements' own titles, held for good once claimed
	-- (ChatTags.ACHIEVEMENT_TITLES)
	title_cat_legend = { text = "[Cat Legend]", color = "#E9A23B" },
	title_steady_hands = { text = "[Steady Hands]", color = "#7FC8A9" },
	title_devoted = { text = "[Devoted]", color = "#C79BE8" },
	title_week_champion = { text = "[Week Champion]", color = "#6FB3E8" },
	title_gold_rush = { text = "[Gold Rush]", color = "#E8C547" },
	-- #4061: the Ticket Booth's title, held for good from 10,000 tickets spent (TicketBooth.REGULAR_SPENT)
	title_park_regular = { text = "[Park Regular]", color = "#4FC3D9" },
	-- #4709 (Derek 2026-11-16: "I got the 100 cat index title but can't equipped it in bag"): the Index milestones'
	-- titles, held for good once the milestone is claimed (ChatTags.INDEX_TITLES). all/totalAll gives title_cat_legend
	title_cat_master = { text = "[Cat Master]", color = "#F0B95A" },
	title_golden_paw = { text = "[Golden Paw]", color = "#F2C94C" },
	title_golden_legend = { text = "[Golden Legend]", color = "#FFD86B" },
	title_rainbow_finder = { text = "[Rainbow Finder]", color = "#F59AC8" },
	title_rainbow_master = { text = "[Rainbow Master]", color = "#C38BF2" },
	title_rainbow_star = { text = "[Rainbow Star]", color = "#7FB8F5" },
	title_rainbow_legend = { text = "[Rainbow Legend]", color = "#FF8FA3" },
	title_gold_alley = { text = "[Alleyway Gold Master]", color = "#C9A15B" },
	title_gold_park = { text = "[Park Gold Master]", color = "#8CC46B" },
	title_gold_neighbourhood = { text = "[Neighbourhood Gold Master]", color = "#E8A0B4" },
	title_gold_woods = { text = "[Woods Gold Master]", color = "#6FA36B" },
	title_gold_sewer = { text = "[Sewer Gold Master]", color = "#7FB5A8" },
	title_gold_desert = { text = "[Desert Gold Master]", color = "#E3B062" },
	title_gold_ruins = { text = "[Ruins Gold Master]", color = "#B89C7A" },
	title_gold_snowy = { text = "[Snowy Mountain Gold Master]", color = "#A8D8F0" },
	title_gold_waterpark = { text = "[Water Park Gold Master]", color = "#5CC8E8" },
	title_gold_castle = { text = "[Medieval Castle Gold Master]", color = "#B8A0E0" },
}
for _, tag in TAGS do
	table.freeze(tag)
end
table.freeze(TAGS)
ChatTags.TAGS = TAGS

-- The order tags are offered in and the default falls through: VIP, then the season tags oldest first.
local ORDER: { string } = {
	"vip",
	"supporter",
	"tag_maple",
	"tag_grand_opener",
	"title_cat_legend",
	"title_steady_hands",
	"title_devoted",
	"title_week_champion",
	"title_gold_rush",
	"title_park_regular",
	"title_cat_master",
	"title_golden_paw",
	"title_golden_legend",
	"title_rainbow_finder",
	"title_rainbow_master",
	"title_rainbow_star",
	"title_rainbow_legend",
	"title_gold_alley",
	"title_gold_park",
	"title_gold_neighbourhood",
	"title_gold_woods",
	"title_gold_sewer",
	"title_gold_desert",
	"title_gold_ruins",
	"title_gold_snowy",
	"title_gold_waterpark",
	"title_gold_castle",
	"rank_1",
	"rank_2",
	"rank_3",
}
table.freeze(ORDER)
ChatTags.ORDER = ORDER

-- #3694: achievement id -> the title its claim gives. Read from the save's claimed achievements each time, so a
-- player who claimed one before the titles shipped has it on the next join.
ChatTags.ACHIEVEMENT_TITLES = table.freeze({
	a_catch10k = "title_cat_legend",
	a_perfect5k = "title_steady_hands",
	a_hours100 = "title_devoted",
	a_week10 = "title_week_champion",
	a_gold50 = "title_gold_rush",
}) :: { [string]: string }

-- #4709: Index page -> milestone -> the title its claim gives (the Catalog prize's `tag`). Read from the save's
-- claimed Index rewards each time, so a milestone claimed before the titles shipped gives it on the next join.
ChatTags.INDEX_TITLES = table.freeze({
	all = table.freeze({
		total50 = "title_cat_master",
		totalAll = "title_cat_legend",
		goldtotal50 = "title_golden_paw",
		goldtotalAll = "title_golden_legend",
	}),
	rainbow = table.freeze({
		rainbow1 = "title_rainbow_finder",
		rainbow25 = "title_rainbow_master",
		rainbow50 = "title_rainbow_star",
		rainbowAll = "title_rainbow_legend",
	}),
	alley = table.freeze({ gold10 = "title_gold_alley" }),
	park = table.freeze({ gold10 = "title_gold_park" }),
	neighbourhood = table.freeze({ gold10 = "title_gold_neighbourhood" }),
	woods = table.freeze({ gold10 = "title_gold_woods" }),
	sewer = table.freeze({ gold10 = "title_gold_sewer" }),
	desert = table.freeze({ gold10 = "title_gold_desert" }),
	ruins = table.freeze({ gold10 = "title_gold_ruins" }),
	snowy = table.freeze({ gold10 = "title_gold_snowy" }),
	waterpark = table.freeze({ gold10 = "title_gold_waterpark" }),
	castle = table.freeze({ gold10 = "title_gold_castle" }),
}) :: { [string]: { [string]: string } }

ChatTags.OFF = "off" -- the pick that shows no tag
ChatTags.OWNER = "owner" -- #3324: the owner's tag, set by the server from the user id alone

-- #3333: the rank title for a leaderboard place 1 to 3, or nil.
function ChatTags.rankTag(place: number?): string?
	if place == 1 or place == 2 or place == 3 then
		return "rank_" .. tostring(place)
	end
	return nil
end

-- #3324: whether `userId` is the game owner's account (Config.OwnerUserIds).
function ChatTags.isOwner(userId: number): boolean
	return table.find(Config.OwnerUserIds, userId) ~= nil
end

-- The rich text in front of a name for `tagId`, or nil for no tag or one we don't know.
function ChatTags.prefixFor(tagId: unknown): string?
	if type(tagId) ~= "string" then
		return nil
	end
	local tag = ChatTags.TAGS[tagId]
	if tag == nil then
		return nil
	end
	return string.format('<font color="%s">%s</font> ', tag.color, tag.text)
end

-- The tag ids the player may show: VIP when they own the pass, and each season tag in `items` (profile.pass.items).
function ChatTags.choices(ownsVip: boolean, items: { [string]: boolean }): { string }
	local out: { string } = {}
	for _, id in ORDER do
		if (id == "vip" and ownsVip) or (id ~= "vip" and items[id] == true) then
			table.insert(out, id)
		end
	end
	return out
end

-- The tag to show for a saved `pick`: none for OFF, the pick while the player still may show it, and otherwise the
-- first of their choices (VIP, then season tags), or none.
function ChatTags.shown(pick: string?, ownsVip: boolean, items: { [string]: boolean }): string?
	if pick == ChatTags.OFF then
		return nil
	end
	local choices = ChatTags.choices(ownsVip, items)
	if pick ~= nil and table.find(choices, pick) ~= nil then
		return pick
	end
	return choices[1]
end

-- #1168 row 4: the items `choices` and `shown` read, with the supporter tag added for a Thank You Badge buyer. A
-- copy; `items` is never changed.
function ChatTags.withSupporter(
	items: { [string]: boolean },
	supporter: boolean
): { [string]: boolean }
	local out: { [string]: boolean } = {}
	for id, has in items do
		if id ~= "supporter" then
			out[id] = has
		end
	end
	if supporter then
		out.supporter = true
	end
	return out
end

-- #3694: `items` with the title of each claimed achievement in ACHIEVEMENT_TITLES set (`achievements` the save's
-- achievementId -> claimed). Changes and returns `items`.
function ChatTags.addAchievementTitles(
	items: { [string]: boolean },
	achievements: { [string]: boolean }
): { [string]: boolean }
	for achievementId, tagId in ChatTags.ACHIEVEMENT_TITLES do
		if achievements[achievementId] == true then
			items[tagId] = true
		end
	end
	return items
end

-- #4709: `items` with the title of each claimed Index milestone in INDEX_TITLES set (`indexRewards` the save's
-- page -> milestone -> claimed). Changes and returns `items`.
function ChatTags.addIndexTitles(
	items: { [string]: boolean },
	indexRewards: { [string]: { [string]: boolean } }?
): { [string]: boolean }
	if indexRewards == nil then
		return items
	end
	for page, milestones in ChatTags.INDEX_TITLES do
		local claims = indexRewards[page]
		if claims ~= nil then
			for milestoneId, tagId in milestones do
				if claims[milestoneId] == true then
					items[tagId] = true
				end
			end
		end
	end
	return items
end

-- Derek2 11-11 ("make the title change text color in chat also"): the message text drawn in the
-- speaker's tag colour, or nil for no tag or one we don't know. `text` is TextChatMessage.Text, which TextChatService
-- has already escaped for rich text, so a typed "<b>" stays plain text inside the font tag.
function ChatTags.textFor(tagId: unknown, text: string): string?
	if type(tagId) ~= "string" then
		return nil
	end
	local tag = ChatTags.TAGS[tagId]
	if tag == nil then
		return nil
	end
	return string.format('<font color="%s">%s</font>', tag.color, text)
end

-- Whether `pick` may be saved: a known tag id or OFF (whether the player may show it is checked when shown).
function ChatTags.validPick(pick: unknown): boolean
	return type(pick) == "string"
		and pick ~= ChatTags.OWNER
		and (pick == ChatTags.OFF or TAGS[pick] ~= nil)
end

return ChatTags
