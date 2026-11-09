--!strict
-- Mystery Visitor gift tiers on the UI (#2614): the wrap a waiting gift wears (the plot's MysteryGiftTier attribute)
-- and the tier MysteryGiftResult names. Pure (no Theme), so the cloud spec runner checks it.
--   tier(raw) -> Tier          "common", "rare" or "super" from the server's "Common", "Rare", "Super" (any case);
--                              anything else (an older server) is "common"
--   title(raw) -> string       the gift card's heading: "Mystery gift!", "Rare gift!" or "Super gift!"
--   chip(raw) -> string        the HUD's quiet line while a gift waits on your plot (info only, no press):
--                              "A gift waits at your cafe", "A rare gift waits at your cafe" ...
--   waiting(giftAt) -> boolean the plot's MysteryGiftAt says a gift sits on the table

local GiftLogic = {}

export type Tier = "common" | "rare" | "super"

local TITLE: { [string]: string } = {
	common = "Mystery gift!",
	rare = "Rare gift!",
	super = "Super gift!",
}

local CHIP: { [string]: string } = {
	common = "A gift waits at your cafe",
	rare = "A rare gift waits at your cafe",
	super = "A super gift waits at your cafe!",
}

function GiftLogic.tier(raw: any): Tier
	local word = if type(raw) == "string" then string.lower(raw) else ""
	if word == "rare" then
		return "rare"
	elseif word == "super" then
		return "super"
	end
	return "common"
end

function GiftLogic.title(raw: any): string
	return TITLE[GiftLogic.tier(raw)]
end

function GiftLogic.chip(raw: any): string
	return CHIP[GiftLogic.tier(raw)]
end

function GiftLogic.waiting(giftAt: any): boolean
	return type(giftAt) == "number" and giftAt > 0
end

return GiftLogic
