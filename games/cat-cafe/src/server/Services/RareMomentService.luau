--!strict
-- Rare moments (F89, luck-and-rare-moments.md section 2; shared/RareMoments). CatService (a check-in, at the cafe or a
-- camp, rescues included) and BaitService (a tame) call `secured`; FishMarketService calls `foundDecor`.
--   SecuredRare(userId, catId, rarity, gold, variant) goes to every client for a big pull (the owner's card, the hop
--   and spin, the shockwave and stings everyone sees) and to the owner alone for the first Epic's small card.
--   rare_secured (value 1; rarity, gold yes or no, catch, bait or rescue) is logged for a big pull.
--   The server-wide toast for a cat is the check-in shout-out (Announce, Catching.shoutOut); `shoutOut` holds a
--   Legendary or Mythical one back within TOAST_SECONDS of the player's last toast. One that goes out is also a chat
--   line here and in every other server (#2203, GlobalCatchService). A Mythical crate piece sends
--   FoundRareDecor(userId, decorId) to everyone, on the same once-a-minute rule. #2429: a Legendary or Mythical crate
--   piece is also a chat line here and in every other server (GlobalCatch.crateLine): a Mythical always, a Legendary
--   at most once a minute per player, so an Open all of many crates cannot flood the chat.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GlobalCatch = require(ReplicatedStorage.Shared.GlobalCatch)
local GlobalCatchService = require(script.Parent.GlobalCatchService)
local Net = require(script.Parent.Net)
local QuietStartService = require(script.Parent.QuietStartService)
local RareMoments = require(ReplicatedStorage.Shared.RareMoments)
local Telemetry = require(script.Parent.Telemetry)
local Types = require(ReplicatedStorage.Shared.Types)

local RareMomentService = {}

local lastToastAt: { [Player]: number } = {} -- os.clock() of each player's last cat or crate toast
local lastChatAt: { [Player]: number } = {} -- os.clock() of each player's last Legendary crate chat line (#2429)

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

-- The check-in shout-out `text` (nil when the cat is not worth one) to everyone's chat, and as a toast unless it is a
-- Legendary or Mythical one within a minute of this player's last toast. Epic and gold shout-outs go out as before. `here` keeps
-- the chat line in this server (#2567: a pity or shower cat, which every server had out).
function RareMomentService.shoutOut(
	player: Player,
	rarity: Types.Rarity,
	text: string?,
	here: boolean?
)
	if text == nil then
		return
	end
	-- #2902: the chat line goes out even when the toast is held back, so every rare catch is in the chat window
	GlobalCatchService.share(text, rarity, here) -- #2203: the chat line here and in every other server
	if RareMoments.toasts(rarity) and not takeToast(player) then
		return
	end
	QuietStartService.fireAll(player, "Announce", text, rarity) -- #4005
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
	QuietStartService.fireAll(player, "SecuredRare", player.UserId, def.id, def.rarity, gold, coat) -- #4005
	local fields: { string } = { def.rarity, if gold then "yes" else "no", RareMoments.how(method) }
	Telemetry.custom(player, "rare_secured", 1, fields)
end

-- `player` opened `decor` from a crate: a Mythical piece toasts the server, at most once a minute.
function RareMomentService.foundDecor(player: Player, decor: Types.DecorDef)
	local rarity = decor.rarity or "Common"
	if RareMoments.decorToasts(rarity) and takeToast(player) then
		QuietStartService.fireAll(player, "FoundRareDecor", player.UserId, decor.id) -- #4005
	end
	local text = GlobalCatch.crateLine(player.DisplayName, rarity, decor.name)
	if text == nil then
		return
	end
	local now = os.clock()
	local last = lastChatAt[player]
	if rarity ~= "Mythical" and last ~= nil and now - last < RareMoments.TOAST_SECONDS then
		return
	end
	lastChatAt[player] = now
	GlobalCatchService.share(text, rarity) -- #2429: the chat line here and in every other server
end

function RareMomentService.start()
	Players.PlayerRemoving:Connect(function(player)
		lastToastAt[player] = nil
		lastChatAt[player] = nil
	end)
end

return RareMomentService
