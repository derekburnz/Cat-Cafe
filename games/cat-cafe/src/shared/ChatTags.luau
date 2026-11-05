--!strict
-- Chat tags (#1624): the "[VIP]" a VIP pass owner shows before their name in chat. The server sets the player's
-- CHAT_TAG_ATTRIBUTE to a tag id from TAGS (PassService); each client's ChatTagController reads it on an incoming
-- message and puts the tag's rich text in front of the name. Only ids in TAGS are shown, so a stray value shows nothing.
-- Later tags (the Cafe Pass season tag, cafe-pass.md section 3) join TAGS.
--   prefixFor(tagId) -> rich text prefix or nil

local ChatTags = {}

ChatTags.CHAT_TAG_ATTRIBUTE = "ChatTag"

export type Tag = { text: string, color: string }

ChatTags.TAGS = table.freeze({
	vip = table.freeze({ text = "[VIP]", color = "#F2C14E" }),
}) :: { [string]: Tag }

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

return ChatTags
