--!strict
-- The like and favourite gifts (#1947, like-prompts.md section 2): once a second, a loaded player whose account has
-- played long enough for a gift not yet paid (shared/PlaytimeGifts) has it marked and paid at once (Payout), then
-- hears ProfileSync and PlaytimeGift(kind, paid) for the card. The gift is for playing: nothing the client sends pays
-- it, and the card's buttons (like, favourite, close) only reach analytics (Telemetry playtime_gift). A second gift
-- in one session waits PlaytimeGifts.GAP_SECONDS after the first.
-- #2997: the same loop pays the Saturday update gift (shared/UpdateGift) once per account per id.
-- #2791: the gift ladder's small steps (2, 4, 6, 15 and 20 minutes) pay the same way, with a "Gift! ..." toast in place
-- of the card; each paid step logs playtime_gift {step, "paid"}.
-- #3772: and the welcome back gift (shared/ReturnGift), a golden crate once per account on its first later-day join,
-- behind the returnGift switch.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CafeService = require(script.Parent.CafeService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local LiveFlagService = require(script.Parent.LiveFlagService)
local Net = require(script.Parent.Net)
local Payout = require(script.Parent.Payout)
local PlayTime = require(script.Parent.Parent.Util.PlayTime)
local PlaytimeGifts = require(ReplicatedStorage.Shared.PlaytimeGifts)
local ReturnGift = require(ReplicatedStorage.Shared.ReturnGift)
local Telemetry = require(script.Parent.Telemetry)
local UpdateGift = require(ReplicatedStorage.Shared.UpdateGift)

local PlaytimeGiftService = {}

local CHECK_SECONDS = 1

local lastPaidAt: { [Player]: number } = {} -- os.clock() of this session's last gift
local noticed: { [Player]: string } = {} -- #3420: the gift id whose "a gift is coming" banner this player was sent

-- #2997: the Saturday update gift (shared/UpdateGift), once per account per id, on the first second the player is
-- loaded while it is live; marked in codesRedeemed before paying, so it never pays twice.
-- true when the update gift was paid this tick
local function updateGift(player: Player): boolean
	local profile = DataService.get(player)
	if profile == nil then
		return false
	end
	local now = os.time()
	-- #3535: the gift that pays now, and the one whose notice may show (the next one, in the minutes before it)
	local gift, coming = UpdateGift.pick(Config.UpdateGift, Config.UpdateGiftNext, now)
	-- #3420: in the minutes before it, one "a gift is coming" banner per player per gift (on join, or at the first
	-- tick for players already in). It promises only what the gift pays, and nothing is lost by leaving.
	local left = UpdateGift.soon(profile.codesRedeemed, coming, now)
	if coming ~= nil and left ~= nil and noticed[player] ~= coming.id then
		noticed[player] = coming.id
		Net.fire(
			player,
			"UpdateGiftNotice",
			"soon",
			coming.fish,
			coming.spins,
			left,
			UpdateGift.crateCount(coming)
		)
		return false
	end
	if gift == nil or not UpdateGift.due(profile.codesRedeemed, gift, now) then
		return false
	end
	profile.codesRedeemed[UpdateGift.key(gift.id)] = now
	Payout.pay(player, profile, UpdateGift.prize(gift, Economy.tier(profile)), "update_gift")
	Telemetry.custom(player, "update_gift", 1, { gift.id })
	CafeService.sync(player)
	-- the banner in place of the toast (#3420); the client falls back to the toast's words when no banner can show
	Net.fire(
		player,
		"UpdateGiftNotice",
		"paid",
		gift.fish,
		gift.spins,
		0,
		UpdateGift.crateCount(gift)
	)
	return true
end

-- #3772: the welcome back gift, on the first second a returning player is loaded on a later UTC day than their
-- first; marked in codesRedeemed before paying, so it never pays twice, on this server or another.
local function returnGift(player: Player)
	local profile = DataService.get(player)
	local now = os.time()
	if
		profile == nil
		or not LiveFlagService.on(ReturnGift.FLAG)
		or not ReturnGift.due(profile, now)
	then
		return
	end
	profile.codesRedeemed[ReturnGift.KEY] = now
	local paid = Payout.pay(player, profile, ReturnGift.prize(), ReturnGift.REASON)
	Telemetry.custom(player, "return_gift_paid", ReturnGift.daysSince(profile, now))
	CafeService.sync(player)
	Net.toast(player, ReturnGift.TOAST .. table.concat(paid, ", "), "good")
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
		noticed[player] = nil
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
				local returnOk, returnErr = pcall(returnGift, player)
				if not returnOk then
					warn("[PlaytimeGiftService] return gift: " .. tostring(returnErr))
				end
			end
		end
	end)
end

return PlaytimeGiftService
