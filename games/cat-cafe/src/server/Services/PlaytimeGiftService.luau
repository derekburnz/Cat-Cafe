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
-- (the returnGift switch shipped and is gone, #4654).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CafeService = require(script.Parent.CafeService)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)
local DailyGifts = require(ReplicatedStorage.Shared.DailyGifts)
local DataService = require(script.Parent.DataService)
local DaysPlayed = require(ReplicatedStorage.Shared.DaysPlayed)
local Economy = require(ReplicatedStorage.Shared.Economy)
local LiveFlagService = require(script.Parent.LiveFlagService)
local Net = require(script.Parent.Net)
local Payout = require(script.Parent.Payout)
local PlayTime = require(script.Parent.Parent.Util.PlayTime)
local PlaytimeGifts = require(ReplicatedStorage.Shared.PlaytimeGifts)
local ReturnGift = require(ReplicatedStorage.Shared.ReturnGift)
local Telemetry = require(script.Parent.Telemetry)
local Traits = require(ReplicatedStorage.Shared.Traits)
local UpdateGift = require(ReplicatedStorage.Shared.UpdateGift)

local PlaytimeGiftService = {}

local CHECK_SECONDS = 1

local lastPaidAt: { [Player]: number } = {} -- os.clock() of this session's last gift
local dailyAt: { [Player]: number } = {} -- #5506: os.clock() of this player's last daily gift tick
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

-- Config.Giveaways (Derek 2026-11-13, the 15:30 UTC update): each once per account while it is live, marked in
-- codesRedeemed under its id like the update gift before it pays. Golden fish and spins through Payout with the update
-- gift's banner; Trait Tokens banked with a toast. True when one was paid this tick.
local function giveaways(player: Player): boolean
	local profile = DataService.get(player)
	if profile == nil then
		return false
	end
	local now = os.time()
	for _, gift in Config.Giveaways do
		if not UpdateGift.due(profile.codesRedeemed, gift, now) then
			continue
		end
		profile.codesRedeemed[UpdateGift.key(gift.id)] = now
		local tokens = gift.traitTokens or 0
		if tokens > 0 then
			local added = Traits.give(profile.traits, tokens)
			Telemetry.custom(player, "trait_token", added, { "giveaway" })
			Net.toast(
				player,
				string.format("Giveaway! +%d Trait Tokens for the Mystic Pool", added),
				"good"
			)
		end
		if gift.fish > 0 or gift.spins > 0 then
			Payout.pay(player, profile, UpdateGift.prize(gift, Economy.tier(profile)), "giveaway")
			Net.fire(player, "UpdateGiftNotice", "paid", gift.fish, gift.spins, 0, 0)
		end
		Telemetry.custom(player, "update_gift", 1, { gift.id })
		CafeService.sync(player)
		return true -- one a tick, so two never land in the same second
	end
	return false
end

-- #3772: the welcome back gift, on the first second a returning player is loaded on a later UTC day than their
-- first; marked in codesRedeemed before paying, so it never pays twice, on this server or another. True when paid.
local function returnGift(player: Player): boolean
	local profile = DataService.get(player)
	local now = os.time()
	if profile == nil or not ReturnGift.due(profile, now) then
		return false
	end
	profile.codesRedeemed[ReturnGift.KEY] = now
	local paid = Payout.pay(player, profile, ReturnGift.prize(), ReturnGift.REASON)
	Telemetry.custom(player, "return_gift_paid", ReturnGift.daysSince(profile, now))
	CafeService.sync(player)
	Net.toast(player, ReturnGift.TOAST .. table.concat(paid, ", "), "good")
	return true
end

-- #5506 (shared/DailyGifts, switch dailyGifts): counts today's play and pays today's next gift once its minutes are
-- played, marked before paying. Only the seconds since this player's last tick count (at most a few, so a stalled
-- loop never pays a burst), and only while they are loaded on this server. True when a gift was paid this tick.
local DAILY_MAX_STEP = 5

local function dailyGift(player: Player): boolean
	local profile = DataService.get(player)
	local clock = os.clock()
	local last = dailyAt[player]
	dailyAt[player] = clock
	if profile == nil or not LiveFlagService.on(DailyGifts.FLAG, player) then
		return false
	end
	local now = os.time()
	local day = DailyGifts.day(now)
	local step = if last ~= nil then math.clamp(clock - last, 0, DAILY_MAX_STEP) else 0
	local state = DailyGifts.add(DailyGifts.fresh(profile.dailyGifts, day), day, step)
	profile.dailyGifts = state
	local index = DailyGifts.due(state)
	if index == nil then
		return false
	end
	local def = DailyGifts.STEPS[index]
	state.claimed = index
	local paid = Payout.pay(player, profile, table.clone(def.prize), "daily_gift")
	Telemetry.custom(player, "daily_gift", math.floor(state.seconds / 60), {
		def.id,
		Telemetry.device(player) or "unknown",
		if day == profile.telemetry.firstDay then "first_day" else "later_day",
	})
	CafeService.sync(player)
	Net.toast(player, "Daily gift! " .. table.concat(paid, ", "), "good")
	return true
end

-- #5505 part 1 (shared/DaysPlayed, switch awayPromise): counts each UTC day the player is loaded on, once, and pays
-- the next milestone reached, marked before paying. A cat milestone gives the rule's pick into the cafe. True when one
-- was paid this tick.
local function daysPlayed(player: Player): boolean
	local profile = DataService.get(player)
	if profile == nil or not LiveFlagService.on(DaysPlayed.FLAG, player) then
		return false
	end
	local state = DaysPlayed.note(profile.daysPlayed, DaysPlayed.day(os.time()))
	profile.daysPlayed = state
	local milestone = DaysPlayed.due(state)
	if milestone == nil then
		return false
	end
	state.paid = milestone.days
	local words: { string } = {}
	if milestone.cat ~= nil then
		local catId = DaysPlayed.pickCat(milestone.cat, Economy.tier(profile), profile.collection)
		local def = if catId ~= nil then Catalog.getCat(catId) else nil
		if def ~= nil then
			CafeService.addCaughtCat(player, def, true, profile, 50, "starter")
			table.insert(words, "a " .. milestone.cat .. " cat, " .. def.name)
		end
	end
	if milestone.prize ~= nil then
		for _, line in Payout.pay(player, profile, table.clone(milestone.prize), "days_played") do
			table.insert(words, line)
		end
	end
	Telemetry.custom(player, "days_played", milestone.days, {
		if milestone.cat ~= nil then "cat" else "prize",
		Telemetry.device(player) or "unknown",
	})
	CafeService.sync(player)
	Net.toast(
		player,
		string.format("Day %d played! %s", milestone.days, table.concat(words, ", ")),
		"good"
	)
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
	-- #5506: with the daily ladder on, the once-per-account small steps stop paying; the like and favourite stay
	local due: PlaytimeGifts.Step? =
		PlaytimeGifts.due(profile, played, LiveFlagService.on(DailyGifts.FLAG, player))
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
		dailyAt[player] = nil
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
				local awayOk, awayErr = pcall(giveaways, player)
				if not awayOk then
					warn("[PlaytimeGiftService] giveaway: " .. tostring(awayErr))
				end
				local dailyOk, dailyErr = pcall(dailyGift, player)
				if not dailyOk then
					warn("[PlaytimeGiftService] daily gift: " .. tostring(dailyErr))
				end
				local daysOk, daysErr = pcall(daysPlayed, player)
				if not daysOk then
					warn("[PlaytimeGiftService] days played: " .. tostring(daysErr))
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
