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
}
for _, tag in TAGS do
	table.freeze(tag)
end
table.freeze(TAGS)
ChatTags.TAGS = TAGS

-- The order tags are offered in and the default falls through: VIP, then the season tags oldest first.
local ORDER: { string } =
	{ "vip", "supporter", "tag_maple", "tag_grand_opener", "rank_1", "rank_2", "rank_3" }
table.freeze(ORDER)
ChatTags.ORDER = ORDER

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
