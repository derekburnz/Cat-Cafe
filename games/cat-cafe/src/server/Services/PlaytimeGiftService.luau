--!strict
-- The like and favourite gifts (#1947, like-prompts.md section 2): once a second, a loaded player whose account has
-- played long enough for a gift not yet paid (shared/PlaytimeGifts) has it marked and paid at once (Payout), then
-- hears ProfileSync and PlaytimeGift(kind, paid) for the card. The gift is for playing: nothing the client sends pays
-- it, and the card's buttons (like, favourite, close) only reach analytics (Telemetry playtime_gift). A second gift
-- in one session waits PlaytimeGifts.GAP_SECONDS after the first.
-- #2997: the same loop pays the Saturday update gift (shared/UpdateGift) once per account per id.
-- #2791: the gift ladder's small steps (2, 4, 6, 15 and 20 minutes) pay the same way, with a "Gift! ..." toast in place
-- of the card; each paid step logs playtime_gift {step, "paid"}.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CafeService = require(script.Parent.CafeService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Net = require(script.Parent.Net)
local Payout = require(script.Parent.Payout)
local PlayTime = require(script.Parent.Parent.Util.PlayTime)
local PlaytimeGifts = require(ReplicatedStorage.Shared.PlaytimeGifts)
local Telemetry = require(script.Parent.Telemetry)
local UpdateGift = require(ReplicatedStorage.Shared.UpdateGift)

local PlaytimeGiftService = {}

local CHECK_SECONDS = 1

local lastPaidAt: { [Player]: number } = {} -- os.clock() of this session's last gift

-- #2997: the Saturday update gift (shared/UpdateGift), once per account per id, on the first second the player is
-- loaded while it is live; marked in codesRedeemed before paying, so it never pays twice.
-- true when the update gift was paid this tick
local function updateGift(player: Player): boolean
	local profile = DataService.get(player)
	local gift = Config.UpdateGift
	if
		profile == nil
		or gift == nil
		or not UpdateGift.due(profile.codesRedeemed, gift, os.time())
	then
		return false
	end
	profile.codesRedeemed[UpdateGift.key(gift.id)] = os.time()
	Payout.pay(player, profile, UpdateGift.prize(gift), "update_gift")
	Telemetry.custom(player, "update_gift", 1, { gift.id })
	CafeService.sync(player)
	Net.toast(player, UpdateGift.words(gift), "good")
	return true
end

-- true when a gift was paid this tick
local function check(player: Player): boolean
	local profile = DataService.get(player)
	if profile == nil then
		return false
	end
	local last = lastPaidAt[player]
	if last ~= nil and os.clock() - last < PlaytimeGifts.GAP_SECONDS then
		return false
	end
	local played = PlayTime.seconds(player, profile)
	local due: PlaytimeGifts.Step? = PlaytimeGifts.due(profile, played)
	if due == nil then
		return false
	end
	local step: PlaytimeGifts.Step = due
	-- marked before paying, so a failure inside the payout never pays it twice
	PlaytimeGifts.mark(profile, step)
	lastPaidAt[player] = os.clock()
	local card = PlaytimeGifts.isCard(step)
	local paid = Payout.pay(
		player,
		profile,
		PlaytimeGifts.prize(step),
		if card then step .. "_gift" else "ladder_gift"
	)
	Telemetry.custom(player, "playtime_gift", math.floor(played / 60), { step, "paid" })
	CafeService.sync(player)
	if card then
		Net.fire(player, "PlaytimeGift", step, paid)
	else
		Net.toast(player, "Gift! " .. table.concat(paid, ", "), "good")
	end
	return true
end

function PlaytimeGiftService.start()
	Players.PlayerRemoving:Connect(function(player: Player)
		lastPaidAt[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			for _, player in DataService.loadedPlayers() do
				local ok, err = pcall(check, player)
				if not ok then
					warn("[PlaytimeGiftService] " .. tostring(err))
				end
				local giftOk, giftErr = pcall(updateGift, player)
				if not giftOk then
					warn("[PlaytimeGiftService] update gift: " .. tostring(giftErr))
				end
			end
		end
	end)
end

return PlaytimeGiftService
