--!strict
-- The cat lock's rules as the cat room shows them (F62, data-model section 4): a locked cat cannot be sold (or
-- traded to the Cat Collector), the lock on its card sets it with LockCat, and gold, Legendary and Mythical cats
-- arrive locked. Pure, so the cloud spec runner checks it.
--
-- A tap shows at once and fires events.lockCat; the card then follows the saved `locked` from ProfileSync. While
-- the server has not caught up (HOLD_SECONDS) the tap wins. The lock shows only once the server sends `locked` as
-- a boolean on its cats, so a server without LockCat never gets a lock that does nothing.

local Types = require(script.Parent.Parent.Types)

export type Tap = { value: boolean, at: number }

local CatLock = {}

CatLock.HOLD_SECONDS = 5

-- data-model section 4: these arrive locked, so one quick tap never sells a player's best cat
local LOCKED_RARITIES: { [string]: boolean } = { Legendary = true, Mythical = true }

-- True once the server sends `locked` on any cat (a boolean, false when unlocked).
function CatLock.live(cats: { [string]: Types.CatInstance }?): boolean
	if cats == nil then
		return false
	end
	for _, instance in cats do
		if type(instance.locked) == "boolean" then
			return true
		end
	end
	return false
end

-- What the lock shows: a fresh tap until the server agrees or HOLD_SECONDS pass, else the saved value.
function CatLock.shown(locked: boolean?, tap: Tap?, now: number): boolean
	local saved = locked == true
	if tap and tap.value ~= saved and now - tap.at < CatLock.HOLD_SECONDS then
		return tap.value
	end
	return saved
end

-- Whether a new cat of this rarity and variant arrives locked (the Studio demo's stand-in server uses it).
function CatLock.arrivesLocked(rarity: string?, gold: boolean): boolean
	return gold or (rarity ~= nil and LOCKED_RARITIES[rarity] == true)
end

return CatLock
