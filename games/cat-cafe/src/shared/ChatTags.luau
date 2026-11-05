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

local ChatTags = {}

ChatTags.CHAT_TAG_ATTRIBUTE = "ChatTag"

export type Tag = { text: string, color: string }

local TAGS: { [string]: Tag } = {
	vip = { text = "[VIP]", color = "#F2C14E" },
	tag_maple = { text = "[Maple]", color = "#D9822B" }, -- #1626: Season 1's paid track, level 1
}
for _, tag in TAGS do
	table.freeze(tag)
end
table.freeze(TAGS)
ChatTags.TAGS = TAGS

-- The order tags are offered in and the default falls through: VIP, then the season tags oldest first.
local ORDER: { string } = { "vip", "tag_maple" }
table.freeze(ORDER)
ChatTags.ORDER = ORDER

ChatTags.OFF = "off" -- the pick that shows no tag

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

-- Whether `pick` may be saved: a known tag id or OFF (whether the player may show it is checked when shown).
function ChatTags.validPick(pick: unknown): boolean
	return type(pick) == "string" and (pick == ChatTags.OFF or TAGS[pick] ~= nil)
end

return ChatTags
