--!strict
-- Rare moments (F89, luck-and-rare-moments.md section 2; shared/RareMoments). CatService (a check-in, at the cafe or a
-- camp, rescues included) and BaitService (a tame) call `secured`; FishMarketService calls `foundDecor`.
--   SecuredRare(userId, catId, rarity, gold, variant) goes to every client for a big pull (the owner's card, the hop
--   and spin, the shockwave and stings everyone sees) and to the owner alone for the first Epic's small card.
--   rare_secured (value 1; rarity, gold yes or no, catch, bait or rescue) is logged for a big pull.
--   The server-wide toast for a cat is the check-in shout-out (Announce, Catching.shoutOut); `shoutOut` holds a
--   Legendary or Mythical one back within TOAST_SECONDS of the player's last toast. A Mythical crate piece sends
--   FoundRareDecor(userId, decorId) to everyone, on the same once-a-minute rule.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(script.Parent.Net)
local RareMoments = require(ReplicatedStorage.Shared.RareMoments)
local Telemetry = require(script.Parent.Telemetry)
local Types = require(ReplicatedStorage.Shared.Types)

local RareMomentService = {}

local lastToastAt: { [Player]: number } = {} -- os.clock() of each player's last cat or crate toast

-- Whether a toast from `player` may go out now; one that may is counted.
local function takeToast(player: Player): boolean
	local last = lastToastAt[player]
	local now = os.clock()
	if last ~= nil and now - last < RareMoments.TOAST_SECONDS then
		return false
	end
	lastToastAt[player] = now
	return true
end

-- The check-in shout-out `text` (nil when the cat is not worth one) to everyone, unless it is a Legendary or
-- Mythical one within a minute of this player's last toast. Epic and gold shout-outs go out as before.
function RareMomentService.shoutOut(player: Player, rarity: Types.Rarity, text: string?)
	if text == nil then
		return
	end
	if RareMoments.toasts(rarity) and not takeToast(player) then
		return
	end
	Net.fireAll("Announce", text, rarity)
end

-- `player` secured `def` (variant "base", "gold" or later "rainbow") by `method`; `hadEpicOrBetter` is whether their
-- collection held an Epic or better before this cat went in.
function RareMomentService.secured(
	player: Player,
	def: Types.CatDef,
	variant: string?,
	method: Types.CatchMethod,
	hadEpicOrBetter: boolean
)
	local card = RareMoments.card(def.rarity, variant, hadEpicOrBetter)
	if card == nil then
		return
	end
	local coat = variant or "base"
	local gold = coat == "gold"
	if card == "first_epic" then
		Net.fire(player, "SecuredRare", player.UserId, def.id, def.rarity, gold, coat)
		return
	end
	Net.fireAll("SecuredRare", player.UserId, def.id, def.rarity, gold, coat)
	local fields: { string } = { def.rarity, if gold then "yes" else "no", RareMoments.how(method) }
	Telemetry.custom(player, "rare_secured", 1, fields)
end

-- `player` opened `decor` from a crate: a Mythical piece toasts the server, at most once a minute.
function RareMomentService.foundDecor(player: Player, decor: Types.DecorDef)
	if RareMoments.decorToasts(decor.rarity or "Common") and takeToast(player) then
		Net.fireAll("FoundRareDecor", player.UserId, decor.id)
	end
end

function RareMomentService.start()
	Players.PlayerRemoving:Connect(function(player)
		lastToastAt[player] = nil
	end)
end

return RareMomentService
