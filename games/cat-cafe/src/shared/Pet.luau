--!strict
-- Pet a cat (#3651, a player's idea from the Feedback board). Derek 2026-11-12: "add the petting cat in shop to
-- increase how much money they make by 2x and display a heart beside their money while it lasts make it 1 hour
-- long", then "make the petting 1 cat only at a time and petting a new one changes it" and "online pay only".
-- Behind the `petCats` switch (Pet.FLAG, off by default).
--   One happy cat a player: petting a working cat in your own cafe makes it the happy cat for Config.PetSeconds by
--   the clock (the hour runs while away) and takes the heart off the cat that had it. Petting the happy cat again
--   starts a fresh hour.
--   The happy cat's own pay is times Config.PetMoneyBoost, in online cafe pay only (Economy.settle); offline pay,
--   tips and everything else that reads the day rate are unchanged. Passes and potions multiply as always. With
--   the event money slot (events, parties, the rest in your cafe) it does not multiply: the cat is never above
--   Config.EventMoneyMax from the pet and that slot together (Pet.gain).
--   The heart ends when the hour does, or when the cat is sold, traded or taken off its job (Pet.prune).
--   The save is one field on the profile, { uid, untilAt } (os.time); an older server drops it, which loses at most
--   the rest of one hour's small boost, so it needs no save version step.
-- Nothing here is sold, random or sped up, and there is no timer on screen but the cat's own prompt. Pure.

local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local Pet = {}

Pet.FLAG = "petCats" -- LiveFlags, off by default
Pet.PROMPT = "PetPrompt" -- the client's prompt on each of the player's own working cats
Pet.ACTION = "Pet"
Pet.ATTRIBUTE = "HappyUntil" -- on the happy cat's model: the heart's end (server time), for the money tag
Pet.EVENT = "cat_pet" -- Telemetry.custom (value 1; fields: moved, same or first)
Pet.HEART = "💗"

export type Save = Types.PetSave

-- A saved pet made safe, or nil: a cat id and an end still ahead, no further off than one full pet.
function Pet.sanitize(raw: unknown, now: number): Save?
	if type(raw) ~= "table" then
		return nil
	end
	local uid, untilAt = (raw :: any).uid, (raw :: any).untilAt
	if type(uid) ~= "string" or uid == "" or #uid > 64 then
		return nil
	end
	if type(untilAt) ~= "number" or untilAt ~= untilAt or untilAt <= now then
		return nil
	end
	return { uid = uid, untilAt = math.min(math.floor(untilAt), now + Config.PetSeconds) }
end

-- The happy cat's uid at `now`, or nil: the hour still runs and the cat is still owned and on a job.
function Pet.active(save: Save?, cats: { [string]: Types.CatInstance }, now: number): string?
	if save == nil or now >= save.untilAt then
		return nil
	end
	local cat = cats[save.uid]
	if cat == nil or cat.spotId == nil then
		return nil
	end
	return save.uid
end

-- Drops a heart that has ended: the hour is over, or its cat was sold, traded or taken off its job. Returns true
-- when it dropped one. Called before every pay window, so a cat put back to work later has no heart.
function Pet.prune(profile: Types.PlayerProfile, now: number): boolean
	if profile.pet ~= nil and Pet.active(profile.pet, profile.cats, now) == nil then
		profile.pet = nil
		return true
	end
	return false
end

-- Why `uid` cannot be petted, or nil: it must be one of the player's cats, on a job in the cafe.
function Pet.blocker(cats: { [string]: Types.CatInstance }, uid: string): string?
	local cat = cats[uid]
	if cat == nil then
		return "That cat isn't yours"
	end
	if cat.spotId == nil then
		return "Only a cat on a job can be petted"
	end
	return nil
end

-- Pets `uid` at `now`: it is the happy cat for a full fresh hour. Returns how the heart came ("first": no heart
-- was running, "same": this cat had it, "moved": another cat had it) and the uid that had it before, if another.
function Pet.pet(profile: Types.PlayerProfile, uid: string, now: number): (string, string?)
	local had = Pet.active(profile.pet, profile.cats, now)
	profile.pet = { uid = uid, untilAt = now + Config.PetSeconds }
	if had == nil then
		return "first", nil
	elseif had == uid then
		return "same", nil
	end
	return "moved", had
end

-- What the pet adds to the happy cat's own pay, as a share of that cat's pay at money 1, while the event money
-- slot pays `money` (1 with no event): the cat earns the larger of the slot and the pet, never both multiplied and
-- never above Config.EventMoneyMax from the two. 1 with no event (2x in all), 0 during a 2x event.
function Pet.gain(money: number): number
	local slot = math.max(1, money)
	local most = math.max(slot, Config.EventMoneyMax)
	return math.max(0, math.min(Config.PetMoneyBoost * slot, most) - slot)
end

-- The seconds of the pay window that starts at `from` and lasts `elapsed` during which the heart still runs.
function Pet.seconds(save: Save?, from: number, elapsed: number): number
	if save == nil or elapsed <= 0 then
		return 0
	end
	return math.clamp(save.untilAt - from, 0, elapsed)
end

-- The happy cat's prompt line: "Happy for 42 m", "Happy for 1 h", or nil when no heart runs. Whole minutes, never
-- under 1 m.
function Pet.label(untilAt: unknown, now: number): string?
	if type(untilAt) ~= "number" or untilAt ~= untilAt or untilAt <= now then
		return nil
	end
	local minutes = math.max(1, math.ceil((untilAt - now) / 60))
	if minutes >= 60 then
		return string.format("Happy for %d h", minutes // 60)
	end
	return string.format("Happy for %d m", minutes)
end

-- The money tag's number for a cat whose model says `rate` and `untilAt` (Pet.ATTRIBUTE): times the boost while
-- the heart runs, with true for the heart.
function Pet.shown(rate: number, untilAt: unknown, now: number): (number, boolean)
	if type(untilAt) == "number" and untilAt == untilAt and now < untilAt then
		return rate * Config.PetMoneyBoost, true
	end
	return rate, false
end

return Pet
