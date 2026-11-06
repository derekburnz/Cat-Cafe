--!strict
-- The rules Effects follows with no Roblox services in them, so they can be unit tested: the device tier, which
-- cats and sources get the budget, catch grades, what a plot change means, and the motion curves for cats,
-- confetti and butterflies. Angles are radians, distances studs, times seconds.

local Presets = require(script.Parent.Presets)

local Logic = {}

export type Style =
	"nap"
	| "loaf"
	| "doze"
	| "stuck"
	| "stray"
	| "barista"
	| "waiter"
	| "greeter"
	| "entertainer"
	| "sit"
	| "lick"
	| "stuckButt"
	| "stuckFlip"
	| "held"

-- Which body a cat has (Pose finds it): "walk", "sit" and "work" are the bodies with hinged pieces (PR #259: walking
-- A, sitting B; #826: S, a working cat standing at its station on its back legs, its front legs arms holding the
-- role's thing), "parts" the placeholder and older Part cats, which lie down by folding their legs themselves.
export type Body = "parts" | "walk" | "sit" | "work"

-- Turns and lifts for one cat at one moment. Pitch lifts the nose (or the front of the body), yaw turns left
-- and right, roll tilts sideways. tailPitch lifts the tail, a paw value swings that leg forward from the hip.
export type Offsets = {
	bodyY: number,
	belly: number, -- studs the top of the body rises as the belly fills with a breath (Pose swells the body parts)
	bodyPitch: number,
	bodyRoll: number,
	headPitch: number,
	headYaw: number,
	headRoll: number,
	tailPitch: number,
	tailYaw: number,
	pawFL: number,
	pawFR: number,
	pawBL: number,
	pawBR: number,
	-- On the work body (S) the front legs are arms: radians each swings out to its own side about the shoulder, the
	-- way a raised paw waves (`waveL` the cat's left, `waveR` its right), and radians the held thing tips about the
	-- paw that holds it, its top towards the cat's front (`held`). 0 on every other body.
	waveL: number,
	waveR: number,
	held: number,
	sink: number, -- 0 standing, 1 lying on its belly (Pose turns it into studs from the cat's leg length)
	-- The entertainer's pom-pom wand (Logic.toy places it): radians it leans off its rest to the cat's right
	-- (`yarn`) and away from the cat (`yarnOut`).
	yarn: number,
	yarnOut: number,
	-- How far into each of Model-Agent's piece poses (Presets.catPoses) the cat is, 0 to 1, on the bodies with
	-- hinged pieces. The idle's own turns ride on top.
	sleep: number,
	loaf: number,
	lick: number,
	blink: number, -- 0 eyes open, 1 shut
	earL: number, -- how far each ear is flicked back, radians
	earR: number,
	-- The Bellhop Cat's cap and bell (F96; Pose turns the head's `_Prop` and `_Bell` pieces about their own pivots):
	-- radians the cap tips up at the front, how far it is pulled down over the eyes to sleep (0 to 1), and radians
	-- the bell swings side to side. 0 leaves them riding the head as before, on every cat.
	capTip: number,
	capDown: number,
	bell: number,
}

export type Candidate<K> = { key: K, distance: number }

export type PlotChange = "claim" | "release" | "rankUp"
export type AreasTurn = "dusk" | "sunrise"
export type PrizeTier = "small" | "good" | "jackpot"

-- A phone or tablet (touch with no keyboard) gets the low budget.
function Logic.tier(touch: boolean, keyboard: boolean): Presets.Tier
	if touch and not keyboard then
		return "low"
	end
	return "high"
end

-- The player's Settings switches that effects follow, from ProfileSync `settings`: screen shake is on and Low
-- performance off until the player flips them, so a missing key or no settings at all keeps those.
function Logic.readSettings(settings: { [string]: unknown }?): (boolean, boolean)
	if settings == nil then
		return true, false
	end
	return settings.screenShake ~= false, settings.lowPerformance == true
end

-- The tier and budget effects run at: the device's own, or the Low performance budget on any device while that
-- setting is on. The tier reads "low" then, so what else scales by Effects.tier() (the street's customers)
-- comes down too.
function Logic.budgetFor(
	device: Presets.Tier,
	lowPerformance: boolean
): (Presets.Tier, Presets.Budget)
	if lowPerformance then
		return "low", Presets.budget.lowPerformance
	end
	return device, Presets.budget[device]
end

-- One circle from CatchResult: "perfect", "good" or "miss" (catching v0.4), or the v0.3 score 1, 0.5 or 0.
export type Grade = string | number

-- CatchResult's success flag. v0.4 sends (strayId, grades, success, pawsLeft, charmGain); v0.3 sent (strayId,
-- scores, chance, success, stayed). Both are read until catching v0.4 (engineer PR #71) is on main.
function Logic.catchSucceeded(third: any, fourth: any): boolean
	if type(third) == "boolean" then
		return third
	end
	return fourth == true
end

-- A Purrfect: every circle Perfect.
function Logic.isPurrfect(grades: { Grade }): boolean
	if #grades == 0 then
		return false
	end
	for _, grade in grades do
		if grade ~= "perfect" and grade ~= 1 then
			return false
		end
	end
	return true
end

-- The keys of the nearest `limit` candidates within `radius`, nearest first.
function Logic.nearest<K>(candidates: { Candidate<K> }, radius: number, limit: number): { K }
	local inRange: { Candidate<K> } = {}
	for _, candidate in candidates do
		if candidate.distance <= radius then
			table.insert(inRange, candidate)
		end
	end
	table.sort(inRange, function(a: Candidate<K>, b: Candidate<K>): boolean
		return a.distance < b.distance
	end)
	local keys: { K } = {}
	for i = 1, math.min(limit, #inRange) do
		keys[i] = inRange[i].key
	end
	return keys
end

-- Logic.nearest over `first`, then the nearest of `rest` in whatever is left of `limit`, so a crowd of `rest` never
-- takes a slot one of `first` needs (Rare and better strays ahead of Commons for the rarity gem).
function Logic.nearestFirst<K>(
	first: { Candidate<K> },
	rest: { Candidate<K> },
	radius: number,
	limit: number
): { K }
	local keys = Logic.nearest(first, radius, limit)
	for _, key in Logic.nearest(rest, radius, limit - #keys) do
		table.insert(keys, key)
	end
	return keys
end

-- What a change of a plot's OwnerUserId or Tier means. `sinceOwnerChange` is how long ago the owner last
-- changed: a claim sets OwnerUserId and Tier in the same server step but they can replicate a frame apart, so a
-- Tier rise right after a claim is the new owner's saved tier, not a rank up.
function Logic.plotChange(
	prevOwner: number,
	prevTier: number,
	owner: number,
	tier: number,
	sinceOwnerChange: number
): PlotChange?
	if owner ~= prevOwner then
		if owner == 0 then
			return "release"
		end
		return "claim"
	end
	if
		owner ~= 0
		and prevTier >= 1
		and tier > prevTier
		and sinceOwnerChange >= Presets.rankUp.claimGrace
	then
		return "rankUp"
	end
	return nil
end

-- The gates that open when this player's cafe goes from prevTier to tier.
function Logic.newlyOpen<K>(requires: { [K]: number }, prevTier: number, tier: number): { K }
	local opened: { K } = {}
	for key, needed in requires do
		if prevTier < needed and tier >= needed then
			table.insert(opened, key)
		end
	end
	return opened
end

-- A timed state on a character, such as F55's `RushUntil` or F57's `StartledUntil` (the server time it ends), read
-- at server time `now` just after it changed from `previous`: the seconds it has left, never more than `longest`,
-- and whether it is a new one, so its start (the getaway ring, the startled bump) plays once. A change that only
-- moves the end of one still running is not new; anything but a number ahead of `now` has nothing left.
function Logic.timedState(
	ends: unknown,
	previous: unknown,
	now: number,
	longest: number
): (number, boolean)
	if type(ends) ~= "number" or ends <= now then
		return 0, false
	end
	local running = type(previous) == "number" and previous > now
	return math.min(ends - now, longest), not running
end

-- What a change of the Clock's `AreasOpen` (F66) means: "dusk" when the areas close, "sunrise" when they open,
-- nil when it is the first value this client sees or not a real true or false.
function Logic.areasTurn(previous: unknown, open: unknown): AreasTurn?
	if type(previous) ~= "boolean" or type(open) ~= "boolean" or previous == open then
		return nil
	end
	if open then
		return "sunrise"
	end
	return "dusk"
end

-- How a catch of `rarity` pops (Presets.catchPop): the ring's width in studs, the share of the budget's confetti
-- (0 for none) and whether a beam shoots up. An unknown rarity pops like a Common.
function Logic.catchPop(rarity: string): (number, number, boolean)
	local c = Presets.catchPop
	local ring = c.ring[rarity]
	if ring == nil then
		return c.ring.Common, 0, false
	end
	return ring, c.confetti[rarity] or 0, c.beams[rarity] == true
end

-- How a spin prize is celebrated, from its slice's chance among `weights` (slice number to weight, as in
-- Catalog.spinWheel): "jackpot" at or under Presets.wheel.jackpot, "good" at or under .good, else "small". An
-- unknown slice is "small".
function Logic.prizeTier(weights: { [number]: number }, slice: number?): PrizeTier
	local total = 0
	for _, weight in weights do
		total += weight
	end
	local weight = if slice ~= nil then weights[slice] else nil
	if weight == nil or total <= 0 then
		return "small"
	end
	local chance = weight / total
	if chance <= Presets.wheel.jackpot then
		return "jackpot"
	elseif chance <= Presets.wheel.good then
		return "good"
	end
	return "small"
end

-- The colours of a signature cat's effect (Presets.signature): its gold ones on a gold cat (round 4 Q8), else its
-- own. A cat with no signature has none.
function Logic.signatureColors(catId: unknown, gold: boolean): { Color3 }?
	local spec = if type(catId) == "string" then Presets.signature[catId] else nil
	if spec == nil then
		return nil
	end
	return if gold then spec.gold else spec.colors
end

-- Whether a stuck cat's "!" can show (Presets.stuckMark): nobody is rescuing it (`LockedBy` is 0 or not set) and you
-- are within maxDistance studs but not close: one `shown` hides at hideWithin or nearer, one hidden comes back only
-- past hideWithin + showAfter, so standing at the edge never pops it in and out.
function Logic.stuckMarkShows(lockedBy: unknown, distance: number, shown: boolean): boolean
	local m = Presets.stuckMark
	local locked = type(lockedBy) == "number" and lockedBy ~= 0
	local near = if shown then m.hideWithin else m.hideWithin + m.showAfter
	return not locked and distance > near and distance <= m.maxDistance
end

export type CloudPlan = {
	coverFrom: number,
	coverTo: number,
	partFrom: number,
	partTo: number,
	tintFrom: number,
	tintTo: number,
}

local function smoothstep(x: number): number
	local k = math.clamp(x, 0, 1)
	return k * k * (3 - 2 * k)
end

-- How much of the screen the clouds of a cannon flight or a cloud hop cover `t` seconds into their plan
-- (Presets.clouds): 0 clear, 1 fully covered, so the server's move is never seen.
function Logic.cloudCover(t: number, plan: CloudPlan): number
	if t < plan.coverFrom or t >= plan.partTo then
		return 0
	end
	if t < plan.coverTo then
		return smoothstep((t - plan.coverFrom) / (plan.coverTo - plan.coverFrom))
	end
	if t < plan.partFrom then
		return 1
	end
	return 1 - smoothstep((t - plan.partFrom) / (plan.partTo - plan.partFrom))
end

-- How far the clouds have turned toward the destination's colour `t` seconds into their plan, 0 to 1.
function Logic.cloudTint(t: number, plan: CloudPlan): number
	if plan.tintTo <= plan.tintFrom then
		return if t >= plan.tintTo then 1 else 0
	end
	return math.clamp((t - plan.tintFrom) / (plan.tintTo - plan.tintFrom), 0, 1)
end

-- The intro's cloud dip over a jump between places (#958, Presets.introCut), for a shot of `before` seconds left at
-- the jump and one of `after` seconds after it (nil: long enough). A shot shorter than `full` gets its side of the dip
-- shortened in proportion, so even the camp tour's quick cuts show clear for over half their time.
function Logic.introDip(
	p: { cut: number, full: number, plan: CloudPlan },
	before: number?,
	after: number?
): CloudPlan
	local into = math.clamp((before or p.full) / p.full, 0, 1)
	local out = math.clamp((after or p.full) / p.full, 0, 1)
	local base, cut = p.plan, p.cut
	return {
		coverFrom = cut - (cut - base.coverFrom) * into,
		coverTo = cut - (cut - base.coverTo) * into,
		partFrom = cut + (base.partFrom - cut) * out,
		partTo = cut + (base.partTo - cut) * out,
		tintFrom = base.tintFrom,
		tintTo = base.tintTo,
	}
end

-- Where the middle of the cloud tunnel has drifted `t` seconds in, as shares of the screen's shorter side: a slow,
-- uneven loop, so the flight feels like it banks.
function Logic.cloudBank(t: number, bank: { share: number, hz: number }): Vector2
	local turn = 2 * math.pi * bank.hz * t
	return Vector2.new(math.sin(turn) * bank.share, math.cos(turn * 0.7) * bank.share * 0.5)
end

-- The beats of a timeline (name to seconds) due by `t` and not yet in `fired`, earliest first; marks them fired, so
-- a step that lands late still plays each one once and in order.
function Logic.beatsDue(
	t: number,
	beats: { [string]: number },
	fired: { [string]: boolean }
): { string }
	local due: { string } = {}
	for name, at in beats do
		if fired[name] ~= true and t >= at then
			table.insert(due, name)
		end
	end
	table.sort(due, function(a: string, b: string): boolean
		if beats[a] ~= beats[b] then
			return beats[a] < beats[b]
		end
		return a < b
	end)
	for _, name in due do
		fired[name] = true
	end
	return due
end

-- Whether a flying player's sparkle trail is on `t` seconds into a cannon flight (Presets.cannon): out of the
-- barrel until the cloud puff, and again on the drop to the landing pad.
function Logic.cannonTrail(
	t: number,
	c: { boomAt: number, puffAt: number, dropAt: number, landAt: number }
): boolean
	return (t >= c.boomAt and t < c.puffAt) or (t >= c.dropAt and t < c.landAt)
end

-- A hop from `from` to `to`, `k` of the way (0 to 1), peaking `height` studs over the straight line at its middle:
-- a checked-in cat jumping into the camp's carrier basket.
function Logic.hopPoint(from: Vector3, to: Vector3, height: number, k: number): Vector3
	local s = math.clamp(k, 0, 1)
	return from:Lerp(to, s) + Vector3.new(0, 4 * height * s * (1 - s), 0)
end

-- Whether something last seen at `seenAt` (os.clock(), nil if never) still counts as in view at `now`: for `grace`
-- seconds after it goes out of sight, so a post or a passing player does not make a mark pop again and again.
function Logic.stillInView(seenAt: number?, now: number, grace: number): boolean
	return seenAt ~= nil and now - seenAt <= grace
end

-- Whether you stand in a walk-in circle (the Codes Cat's, F65) at `distance` flat studs from its centre: in at
-- `radius` or less, out only past `radius + leaveAfter`, and between the two as you were, so the edge never
-- flickers.
function Logic.insideCircle(
	wasInside: boolean,
	distance: number,
	radius: number,
	leaveAfter: number
): boolean
	if distance <= radius then
		return true
	elseif distance > radius + leaveAfter then
		return false
	end
	return wasInside
end

-- Half a box's size along the axes `frame` is measured in (the world's, or a plot's), however the box is turned.
function Logic.halfExtents(frame: CFrame, size: Vector3): Vector3
	local r, u, l = frame.RightVector, frame.UpVector, frame.LookVector
	return Vector3.new(
		math.abs(r.X) * size.X + math.abs(u.X) * size.Y + math.abs(l.X) * size.Z,
		math.abs(r.Y) * size.X + math.abs(u.Y) * size.Y + math.abs(l.Y) * size.Z,
		math.abs(r.Z) * size.X + math.abs(u.Z) * size.Y + math.abs(l.Z) * size.Z
	) / 2
end

-- The golden fish a ProfileSync added since the last count: none for the first count, a missing one or spending.
function Logic.fishGain(previous: unknown, current: unknown): number
	if type(previous) ~= "number" or type(current) ~= "number" then
		return 0
	end
	return math.max(0, current - previous)
end

-- The gold sparkles and ring diameter for a golden fish gain: the biggest Presets.fishPickup step it reaches, or
-- 0 and 0 for no gain.
function Logic.fishPickup(gain: number): (number, number)
	local sparkles, ring = 0, 0
	for _, step in Presets.fishPickup.steps do
		if gain >= step.from then
			sparkles, ring = step.sparkles, step.ring
		end
	end
	return sparkles, ring
end

-- The decor ids a ProfileSync's `decorPlaced` (`current`) has in use that the last one (`previous`) did not, sorted:
-- none for the first one seen, or when either is not a table, so joining flashes nothing.
function Logic.newlyPlaced(previous: unknown, current: unknown): { string }
	local ids: { string } = {}
	if type(previous) ~= "table" or type(current) ~= "table" then
		return ids
	end
	local before = previous :: { [unknown]: unknown }
	for id, inUse in current :: { [unknown]: unknown } do
		if type(id) == "string" and inUse == true and before[id] ~= true then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	return ids
end

-- What flashes when a decor piece of `kind` (Types.DecorKind, nil for a shop piece) goes into use: "piece" for its
-- models (shop pieces, crate furniture and decorations, a door set's doors and a cat flap), "floor" for a floor
-- style, nil for wallpaper and paint, which already repaint whole walls.
function Logic.equipTarget(kind: string?): string?
	if kind == "floor" then
		return "floor"
	elseif kind == "wallpaper" or kind == "paint" then
		return nil
	end
	return "piece"
end

-- Whether a cat's `Level` going from `previous` to `current` is a level up: both whole numbers and the new one
-- higher. The first value a client sees (nil before it) is not one.
function Logic.levelledUp(previous: unknown, current: unknown): boolean
	return type(previous) == "number" and type(current) == "number" and current > previous
end

-- The potion whose glow a drinker shows: the newest (last) id in their `ActivePotions` ("tip_potion,swift_potion",
-- oldest drink first), or nil for none or an unknown kind.
function Logic.newestPotion(value: unknown): string?
	if type(value) ~= "string" then
		return nil
	end
	local newest: string? = nil
	for id in string.gmatch(value, "[^,%s]+") do
		newest = id
	end
	if newest ~= nil and Presets.potions[newest] ~= nil then
		return newest
	end
	return nil
end

-- The potion you just drank, from your own ProfileSync `buffs` (potion id to endsAt) before and after: the one whose
-- end moved furthest later, or nil for the first sync, a buff running out or nothing new.
function Logic.potionDrunk(previous: unknown, current: unknown): string?
	if type(previous) ~= "table" or type(current) ~= "table" then
		return nil
	end
	local before = previous :: { [unknown]: unknown }
	local best: string? = nil
	local most = 0
	for id, ends in current :: { [unknown]: unknown } do
		if type(id) == "string" and type(ends) == "number" then
			local was = before[id]
			local moved = ends - (if type(was) == "number" then was else 0)
			if moved > most then
				best, most = id, moved
			end
		end
	end
	return best
end

-- The colour of what a Mystery Visitor gift held (MysteryGiftResult kind and id): a potion in its own colour, the
-- rest by kind, and the ribbon pink for anything else.
function Logic.giftColour(kind: unknown, id: unknown): Color3
	if kind == "potion" and type(id) == "string" then
		local spec = Presets.potions[id]
		if spec ~= nil then
			return spec.colour
		end
	end
	local byKind = if type(kind) == "string" then Presets.mystery.kinds[kind] else nil
	return byKind or Presets.palette.neonPink
end

local function wave(t: number, seconds: number): number
	return math.sin(t * 2 * math.pi / seconds)
end

-- One breath every `seconds`, 0 (out) to 1 (in): a slow fill, a longer let-out, then a short rest before the next
-- (motion.breath), the way a sleeping cat's belly rises and falls rather than a plain sine.
function Logic.breath(t: number, seconds: number): number
	local b = Presets.motion.breath
	local into = (t / seconds) % 1
	if into < b.inhale then
		local k = into / b.inhale
		return k * k * (3 - 2 * k)
	elseif into < b.inhale + b.exhale then
		local k = (into - b.inhale) / b.exhale
		return 1 - k * k * (3 - 2 * k)
	end
	return 0
end

-- 0 most of the time; once every `every` seconds it rises to 1 and back over `length` seconds.
function Logic.pulse(t: number, every: number, length: number): number
	local into = t % every
	if into >= length then
		return 0
	end
	return math.sin(into / length * math.pi)
end

-- How far up the entertainer's batting paw is, 0 to 1 of motion.entertainer.reach, `c` seconds after it meets the
-- pom-pom (before that, negative): it comes up over `windup`, faster and faster so it strikes, holds the pom-pom
-- for `hold`, then goes down smoothly over `back`.
function Logic.bat(c: number): number
	local e = Presets.motion.entertainer
	if c < -e.windup or c >= e.hold + e.back then
		return 0
	elseif c < 0 then
		local u = (c + e.windup) / e.windup
		return u * u
	elseif c < e.hold then
		return 1
	end
	return 1 - smoothstep((c - e.hold) / e.back)
end

-- How the pom-pom wand leans `since` seconds after a bat sent it toward `toward` (1 the cat's right, -1 its left):
-- radians away from the cat, then radians to its right. It springs away and wobbles back, dying away, and is still
-- again by the next bat (it settles over the next paw's windup), so the next paw always meets it at rest.
function Logic.toySway(since: number, toward: number): (number, number)
	local e = Presets.motion.entertainer
	if since < 0 or since >= e.every then
		return 0, 0
	end
	local settle = 1 - smoothstep((since - (e.every - e.windup)) / e.windup)
	local out = math.rad(e.tilt)
		* math.exp(-e.decay * since)
		* math.sin(since * e.hz * 2 * math.pi)
		* settle
	return out, out * e.side * toward
end

-- Where the entertainer's pom-pom rests, up and ahead (negative) of the cat's floor point in studs, for front paws
-- hinged `hingeY` up and `hingeZ` ahead at the cat's `scale`: against the pad of a paw raised `reach` degrees.
-- The pad sits at the bottom of the leg, PAD_AHEAD of the hinge; raised, it faces forward and a little down.
local PAD_AHEAD = 0.05
function Logic.toyRest(hingeY: number, hingeZ: number, scale: number): (number, number)
	local e = Presets.motion.entertainer
	local a = math.rad(e.reach)
	local ahead = PAD_AHEAD * scale
	local r = e.pom * scale / 2
	-- the pad's centre with the leg swung forward `a` about the hinge, then out along the leg by the pom-pom's radius
	local y = hingeY - hingeY * math.cos(a) + ahead * math.sin(a) - r * math.cos(a)
	local z = hingeZ - hingeY * math.sin(a) - ahead * math.cos(a) - r * math.sin(a)
	return y, z
end

-- The pom-pom and its wand in the cat's floor space for offsets `o` (`yarn`, `yarnOut`), resting at
-- (0, restY, restZ) for a cat at `scale`: the pom-pom's centre, the wand's foot (`wandBase` ahead, on the perch)
-- and its tip under the pom-pom. The wand leans about its foot, away from the cat by `yarnOut`, then to its right
-- by `yarn`, so the pom-pom swings on an arc and never leaves it.
function Logic.toy(
	o: Offsets,
	restY: number,
	restZ: number,
	scale: number
): (Vector3, Vector3, Vector3)
	local e = Presets.motion.entertainer
	local foot = Vector3.new(0, 0, -e.wandBase * scale)
	local y, z = restY, restZ - foot.Z
	-- to the right about the wand's forward axis, then away about its sideways one
	local x = y * math.sin(o.yarn)
	y *= math.cos(o.yarn)
	local away = -o.yarnOut
	y, z = y * math.cos(away) - z * math.sin(away), y * math.sin(away) + z * math.cos(away)
	local arm = Vector3.new(x, y, z)
	local length = math.max(arm.Magnitude - e.pom * scale / 2, 0.05)
	return foot + arm, foot, foot + arm.Unit * length
end

function Logic.blank(): Offsets
	return {
		bodyY = 0,
		belly = 0,
		bodyPitch = 0,
		bodyRoll = 0,
		headPitch = 0,
		headYaw = 0,
		headRoll = 0,
		tailPitch = 0,
		tailYaw = 0,
		pawFL = 0,
		pawFR = 0,
		pawBL = 0,
		pawBR = 0,
		waveL = 0,
		waveR = 0,
		held = 0,
		sink = 0,
		yarn = 0,
		yarnOut = 0,
		sleep = 0,
		loaf = 0,
		lick = 0,
		blink = 0,
		earL = 0,
		earR = 0,
		capTip = 0,
		capDown = 0,
		bell = 0,
	}
end

-- Blends two sets of offsets, k = 0 giving a and 1 giving b: a cat settling from one style into the next.
function Logic.mix(a: Offsets, b: Offsets, k: number): Offsets
	local out = Logic.blank()
	for key, value in a :: any do
		(out :: any)[key] = value + ((b :: any)[key] - value) * k
	end
	return out
end

-- Eyes and ears for a style at time t: blinks now and then, eyes shut asleep, and an ear flick now and then.
local function face(o: Offsets, style: Style, t: number)
	local m = Presets.motion
	local b = m.blink
	local asleep = style == "nap" or style == "doze"
	if asleep then
		o.blink = 1
	elseif style == "loaf" then
		-- half shut and content, with a slow blink
		o.blink = b.sleepy + (1 - b.sleepy) * Logic.pulse(t, b.every * 2, b.slowSeconds)
	elseif style == "lick" then
		o.blink = m.lick.eyes
	else
		o.blink = Logic.pulse(t, b.every, b.seconds)
	end
	local e = m.ears
	local pace = if asleep then 0.5 else 1
	o.earL = math.rad(e.twitch) * Logic.pulse(t * pace, e.everyL, e.seconds)
	o.earR = math.rad(e.twitch) * Logic.pulse(t * pace + 2.3, e.everyR, e.seconds)
end

-- A working cat's idle on the work body (S, #826; Derek 2026-11-02 12:02: "S: chibi holding the prop"), on top of
-- what Logic.idle already set (the breath, the tail swish, the blinks and ear flicks). The server has turned the arms
-- into the role's pose (Model-Agent's cat_poses.work_<role>), so these are small turns on top, none past about 15
-- degrees (motion.work), and the back legs it stands on never move. It shifts its weight from foot to foot; the
-- Barista offers its cup now and then, the Waiter watches the room with its tray held steady, the Greeter waves its
-- raised paw in bursts and the Entertainer sings into its mic, nodding on the beat and waving to it. True when the
-- style is a role it has an idle for.
function Logic.workIdle(o: Offsets, style: Style, t: number): boolean
	local w = Presets.motion.work
	if
		style ~= "barista"
		and style ~= "waiter"
		and style ~= "greeter"
		and style ~= "entertainer"
	then
		return false
	end
	o.bodyRoll = math.rad(w.sway) * wave(t, w.swaySeconds)
	o.headRoll = -o.bodyRoll * 0.5 -- the head stays level as the weight shifts
	if style == "barista" then
		local b = w.barista
		local offer = Logic.pulse(t, b.every, b.seconds)
		o.pawFR = math.rad(b.lift) * offer
		o.held = math.rad(b.held) * offer
		o.headPitch = -math.rad(b.look) * offer
	elseif style == "waiter" then
		local a = w.waiter
		o.headYaw = math.rad(a.look) * wave(t, a.lookSeconds)
		o.headRoll += math.rad(a.tilt) * Logic.pulse(t, a.tiltEvery, 1.2)
	elseif style == "greeter" then
		local g = w.greeter
		local burst = Logic.pulse(t, g.every, g.seconds)
		local into = t % g.every
		o.waveL = math.rad(g.wave) * math.sin(into * g.hz * 2 * math.pi) * burst
			+ math.rad(g.rest) * wave(t, g.restSeconds) * (1 - burst)
		o.headRoll += math.rad(g.tilt) * burst
	else
		local e = w.entertainer
		local nod = 0.5 - 0.5 * math.cos(t / e.beat * 2 * math.pi) -- down and back up once a beat
		local sway = wave(t, 2 * e.beat)
		o.bodyRoll = math.rad(e.sway) * sway
		o.headRoll = -o.bodyRoll * 0.5
		o.headPitch = -math.rad(e.nod) * nod
		o.held = math.rad(e.mic) * nod
		o.pawFL = math.rad(e.swing) * sway -- the free paw at its side keeps time
	end
	return true
end

-- The idle for a style at time t on a body (Logic.Body; none means "parts"). Every cat breathes, swishes its tail,
-- blinks and flicks its ears; the style adds the rest. On the bodies with hinged pieces a nap, loaf and paw lick
-- are Model-Agent's piece poses (sleep, loaf, lick) with the idle on top; the "parts" cats fold their own legs.
function Logic.idle(style: Style, t: number, body: Body?): Offsets
	local m = Presets.motion
	local o = Logic.blank()
	local pieces = body == "walk" or body == "sit" or body == "work"
	o.bodyY = (wave(t, m.breathe.seconds) * 0.5 + 0.5) * m.breathe.studs
	o.tailYaw = math.rad(m.tailSwish.degrees) * wave(t, m.tailSwish.seconds)
	face(o, style, t)
	if body == "work" and Logic.workIdle(o, style, t) then
		return o -- standing at its station on the work body, the role's arm pose already on the model
	end
	if style == "nap" and pieces then
		-- Curled up asleep (manifest sleep): the pose lays it down and turns its head and tail; only the belly
		-- rising and falling with each slow breath and the tip of the tail move.
		o.sleep = 1
		o.bodyY = 0
		o.belly = Logic.breath(t, m.nap.seconds) * m.nap.breathe
		o.tailYaw *= 0.1
	elseif style == "loaf" and pieces then
		-- Tucked in and awake (manifest loaf): a slow breath and a slow look to one side and back now and then.
		local l = m.loaf
		o.loaf = 1
		o.bodyY = 0
		o.belly = Logic.breath(t, l.seconds) * l.breathe
		local side = if math.floor(t / l.lookEvery) % 2 == 0 then 1 else -1
		o.headYaw = math.rad(l.look) * side * Logic.pulse(t, l.lookEvery, l.lookSeconds)
		o.tailYaw *= 0.1
	elseif style == "lick" then
		-- Washing a paw (manifest lick; Derek 2026-10-29 19:46: the old rub read as kicking): the paw is held up at the
		-- mouth and the head does the licking, dipping to it quickly and coming up slower, turned a little into it, in
		-- bursts of `strokes` seconds; the paw only lifts a little to meet each lick. Every other pause the cat rubs
		-- its cheek along the paw, the head turned, bowed and tipped into it as the paw rises, the way a cat washes its
		-- face.
		local k = m.lick
		o.lick = 1
		local cycle = k.strokes + k.pause
		local into = t % cycle
		local lap = 0
		if into < k.strokes then
			local f = (t * k.hz) % 1
			local dip = if f < k.down
				then smoothstep(f / k.down)
				else 1 - smoothstep((f - k.down) / (1 - k.down))
			local ease = math.clamp(math.min(into, k.strokes - into) / k.ease, 0, 1) -- no lick cut off mid-dip
			lap = dip * ease
		end
		local wipe = 0
		if into >= k.strokes and math.floor(t / cycle) % 2 == 1 then
			wipe = math.sin((into - k.strokes) / k.pause * math.pi)
		end
		o.headPitch = -math.rad(k.bob) * lap - math.rad(k.wipeBow) * wipe
		o.headYaw = math.rad(k.turn) * lap + math.rad(k.wipeTurn) * wipe
		o.headRoll = math.rad(k.wipeTilt) * wipe
		o.pawFL = math.rad(k.paw) * lap + math.rad(k.wipe) * wipe
		o.tailYaw *= 0.5
	elseif style == "nap" then
		-- Curled up: down on its belly, front paws out in front, back legs folded under, head tucked round to the
		-- left and the tail wrapped along the left side to meet it.
		o.sink = m.nap.sink
		o.bodyY = 0
		o.belly = Logic.breath(t, m.nap.seconds) * m.nap.breathe
		o.headPitch = -math.rad(m.nap.headDroop)
		o.headYaw = math.rad(m.nap.headTuck)
		o.tailYaw = -math.rad(m.nap.tailWrap) + o.tailYaw * 0.1
		o.pawFL = math.rad(90)
		o.pawFR = math.rad(90)
		o.pawBL = math.rad(90)
		o.pawBR = math.rad(90)
	elseif style == "loaf" then
		-- Tucked in and awake (Derek 2026-10-27, from draft E): down on its belly with every leg folded under and the
		-- front paws peeking out, head up and level, the tail laid along the right side. Very still: a slow breath,
		-- a slow look to one side and back every so often, and a quick flick of the head like an ear.
		local l = m.loaf
		o.sink = 1
		o.bodyY = 0
		o.belly = Logic.breath(t, l.seconds) * l.breathe
		local side = if math.floor(t / l.lookEvery) % 2 == 0 then 1 else -1
		o.headYaw = math.rad(l.look) * side * Logic.pulse(t, l.lookEvery, l.lookSeconds)
		o.headPitch = -math.rad(l.headDroop)
		o.headRoll = math.rad(l.flick) * Logic.pulse(t + 2, l.flickEvery, 0.2)
		o.tailYaw = math.rad(l.tailWrap) + o.tailYaw * 0.1
		o.pawFL = math.rad(90)
		o.pawFR = math.rad(90)
		o.pawBL = math.rad(90)
		o.pawBR = math.rad(90)
	elseif style == "doze" then
		-- Asleep where it sits or stands at its station at night (F25, F44, PR #262). The belly fills with each
		-- slow breath and the head lifts a little with it, the body sways a little and the tail hangs; no sink and
		-- no folded legs.
		local breath = Logic.breath(t, m.doze.seconds)
		o.bodyY = 0
		o.belly = breath * m.doze.breathe
		o.bodyRoll = math.rad(m.doze.sway) * wave(t, m.doze.seconds * 2.3)
		o.headPitch = -math.rad(m.doze.headDroop + m.doze.nod * (1 - 2 * breath))
		o.headRoll = -o.bodyRoll * 0.5
		o.tailYaw *= m.doze.tail
	elseif style == "held" then
		-- Awake in a player's arms (Derek 2026-10-28): loafing on the walking body (the loaf's piece pose, or
		-- folded legs on the older Part cats) or just sitting on the sitting body, eyes open, a slow breath, looking
		-- about now and then and the tail swishing slowly.
		local h = m.held
		if body == "walk" then
			o.loaf = 1
		elseif not pieces then
			o.sink = 1
			o.pawFL = math.rad(90)
			o.pawFR = math.rad(90)
			o.pawBL = math.rad(90)
			o.pawBR = math.rad(90)
		end
		if body ~= "sit" then
			o.bodyY = 0
			o.belly = Logic.breath(t, h.seconds) * h.breathe
		end
		o.headYaw = math.rad(h.look) * wave(t, h.lookSeconds)
		o.headPitch = math.rad(h.nod) * wave(t, h.lookSeconds * 0.6)
		o.tailYaw *= h.tail
	elseif style == "stuckButt" then
		-- Head first in the trap with only its back end out: in bursts the hips wiggle, the back legs paddle one
		-- after the other and the raised tail lashes; a little of it keeps going in between.
		local s = m.stuck.butt
		local burst = math.max(Logic.pulse(t, s.every, s.seconds), s.twitch)
		local beat = math.sin(t * s.hz * 2 * math.pi)
		o.bodyRoll = math.rad(s.wiggle) * beat * burst
		o.pawBL = math.rad(s.kick) * beat * burst
		o.pawBR = -math.rad(s.kick) * beat * burst
		o.tailPitch = math.rad(s.tailUp)
		o.tailYaw = math.rad(s.tail) * math.sin(t * s.hz * 1.5 * 2 * math.pi) * burst
	elseif style == "stuckFlip" then
		-- Upside down, hanging under a branch or a gutter or on its back in a bush: in bursts all four legs pedal in
		-- the air and the body rocks, ears back; the tail swings and the head looks about all the while.
		local s = m.stuck.flip
		local burst = math.max(Logic.pulse(t, s.every, s.seconds), s.twitch)
		local w = t * s.hz * 2 * math.pi
		o.pawFL = math.rad(s.legs) * math.sin(w) * burst
		o.pawFR = math.rad(s.legs) * math.sin(w + math.pi) * burst
		o.pawBL = math.rad(s.legs) * math.sin(w + math.pi / 2) * burst
		o.pawBR = math.rad(s.legs) * math.sin(w - math.pi / 2) * burst
		o.bodyRoll = math.rad(s.rock) * math.sin(w * 0.5) * burst
		o.tailYaw = math.rad(s.tail) * wave(t, 1.6)
		o.headYaw = math.rad(s.look) * wave(t, 3.1)
		o.earL = math.max(o.earL, math.rad(s.ears) * burst)
		o.earR = math.max(o.earR, math.rad(s.ears) * burst)
	elseif style == "stuck" then
		local struggle = Logic.pulse(t, m.stuck.every, m.stuck.seconds)
		o.headYaw = math.rad(m.stuck.shake) * math.sin(t * 40) * struggle
		o.bodyRoll = math.rad(m.stuck.shake * 0.4) * math.sin(t * 30) * struggle
		o.tailYaw *= 1.6
	elseif style == "stray" then
		o.headYaw = math.rad(m.headLook.degrees) * wave(t, m.headLook.seconds)
		o.headPitch = math.rad(m.headLook.degrees * 0.3) * wave(t, m.headLook.seconds * 0.7)
	elseif style == "barista" then
		local tap = Logic.pulse(t, m.barista.tapEvery, 0.4)
		o.headPitch = -math.rad(m.barista.headDip) * tap
		o.pawFL = math.rad(m.barista.paw) * tap
	elseif style == "waiter" then
		-- watching the room: the head turns from table to table and tilts now and then, the body still
		local w = m.waiter
		o.headYaw = math.rad(w.look) * wave(t, w.lookSeconds)
		o.headRoll = math.rad(w.tilt) * Logic.pulse(t, w.tiltEvery, 1.2)
	elseif style == "greeter" then
		local greet = Logic.pulse(t, m.greeter.waveEvery, 1.2)
		o.pawFR = math.rad(m.greeter.wave) * greet * (0.75 + 0.25 * math.sin(t * 16))
		o.headRoll = math.rad(m.greeter.tilt) * greet
	elseif style == "entertainer" then
		-- the paws take turns batting the pom-pom: the last one going back down, the next one coming up for its bat
		local e = m.entertainer
		local beat = math.floor(t / e.every)
		local since = t - beat * e.every
		local last = Logic.bat(since)
		local coming = Logic.bat(since - e.every)
		local leftLast = beat % 2 == 0
		o.pawFL = math.rad(e.reach) * (if leftLast then last else coming)
		o.pawFR = math.rad(e.reach) * (if leftLast then coming else last)
		o.yarnOut, o.yarn = Logic.toySway(since, if leftLast then 1 else -1)
		o.headPitch = -math.rad(e.look)
		o.headYaw = -e.follow * o.yarn
		o.bodyPitch = -math.rad(e.lean) * math.max(last, coming)
	else
		o.headYaw = math.rad(m.headLook.degrees * 0.6) * wave(t, m.headLook.seconds)
	end
	return o
end

-- A steady number from 0 to 1 for a text key (a cat's Uid), so every player sees the same cat do the same thing
-- at the same moment without the server saying so.
function Logic.phaseOf(key: string): number
	local h = 0
	for i = 1, #key do
		h = (h * 31 + string.byte(key, i)) % 16777216
	end
	-- times the golden ratio, so keys a letter apart ("cat_1", "cat_2") still land far apart
	local spread = h * 0.6180339887498949
	return spread - math.floor(spread)
end

-- Whether a resting cafe cat is up in a loaf at server time `t`: for `hold` seconds out of every `every`, starting
-- at its own `phase` (0 to 1), so the cats in a cafe take turns rather than all sitting up at once.
function Logic.loafing(t: number, phase: number): boolean
	local l = Presets.motion.loaf
	return (t + phase * l.every) % l.every < l.hold
end

-- Whether a resting cat on the sitting body is washing a paw at server time `t`, the way Logic.loafing takes turns:
-- `hold` seconds out of every `every` (motion.lick), from its own `phase`.
function Logic.licking(t: number, phase: number): boolean
	local k = Presets.motion.lick
	return (t + phase * k.every) % k.every < k.hold
end

-- Bedtime (F79, data-model 12c): the server walks a working cat to a sleep spot at night and back at sunrise,
-- setting `Bedtime` for the whole trip and `Asleep` while it lies on the spot. On the way it moves like a stray (the
-- gait at its real speed, the get-up stretch from StretchAt) and on the spot it naps like one. nil when the cat is
-- not on a bedtime trip, so the station idles and the old station nap (a server that never sets Bedtime) still run.
function Logic.bedtimeStyle(bedtime: unknown, asleep: unknown): Style?
	if bedtime ~= true then
		return nil
	end
	return if asleep == true then "nap" else "stray"
end

-- How long one breath takes in a style: slow asleep, a little slower again dozing or in a loaf.
function Logic.breathSeconds(style: Style): number
	local m = Presets.motion
	if style == "nap" then
		return m.nap.seconds
	elseif style == "doze" then
		return m.doze.seconds
	elseif style == "loaf" then
		return m.loaf.seconds
	end
	return m.breathe.seconds
end

-- One of the floating z's over a sleeping cat at time `t` (the same t as its idle, so the z's keep time with its
-- breath, every `seconds`): z number `index` of `count` takes every `count`th breath. It pops up small as the cat
-- breathes out, rises, grows and drifts to the right with a little sway over nap.life breaths, fades out at the
-- top and waits for its next turn, where it starts again from the bottom. Returns where it is in the z's box (0 to
-- 1 across from the left, 0 to 1 down from the top), its size (1 a full z), how see-through it is (1 hidden) and
-- its tilt in degrees.
function Logic.napZ(
	index: number,
	count: number,
	t: number,
	seconds: number
): (number, number, number, number, number)
	local z = Presets.nap
	local breaths = t / seconds - Presets.motion.breath.inhale -- counted from the first breath out
	local along = ((breaths - (index - 1)) % count) / z.life
	if along >= 1 then
		return z.x, z.y, z.size, 1, 0
	end
	local x = z.x + z.drift * along + z.sway * math.sin(along * 2 * math.pi)
	local y = z.y - z.rise * along
	local size = z.size + (1 - z.size) * along
	local fade = 0
	if along < z.fadeIn then
		fade = 1 - along / z.fadeIn
	elseif along > 1 - z.fadeOut then
		fade = (along - (1 - z.fadeOut)) / z.fadeOut
	end
	local tilt = z.tilt * math.sin(along * 2 * math.pi + 0.6)
	return x, y, size, fade, tilt
end

-- How far round a spin of the world wheel is after `k` (0 to 1) of its time: fast at first, easing to a stop.
function Logic.wheelEase(k: number): number
	local left = 1 - math.clamp(k, 0, 1)
	return 1 - left * left * left
end

-- A flat part's thinnest axis, one of its `right`, `up` and `look` vectors by the smallest of `size`'s X, Y and Z,
-- turned to point the same way as `back`: the Spin Wheel's axle, from its disc, pointing to the back of the station.
function Logic.thinAxis(
	right: Vector3,
	up: Vector3,
	look: Vector3,
	size: Vector3,
	back: Vector3
): Vector3
	local axis = if size.X <= size.Y and size.X <= size.Z
		then right
		elseif size.Y <= size.Z then up
		else look
	return if axis:Dot(back) < 0 then -axis else axis
end

-- The up direction across a wheel's face: world up with its share along the `axle` taken out, or the station's
-- `back` the same way for a wheel lying flat.
function Logic.wheelUp(axle: Vector3, back: Vector3): Vector3
	local up = Vector3.yAxis - axle * axle.Y
	if up.Magnitude < 1e-3 then
		up = back - axle * back:Dot(axle)
	end
	return up.Unit
end

-- The world wheel's slice widths in degrees, in Catalog.spinWheel order, from its Wheel Model's `SliceSpans`
-- attribute ("52,52,52,52,52,52,24,24": the two jackpot slices are narrow, #1411), or `slices` equal ones when it
-- is missing or its widths are not all above 0 and do not add up to a whole turn.
function Logic.wheelSpans(value: unknown, slices: number): { number }
	local spans: { number } = {}
	local total = 0
	if type(value) == "string" then
		for word in string.gmatch(value, "[^,]+") do
			local span = tonumber(word)
			if span == nil or span <= 0 then
				spans = {}
				break
			end
			table.insert(spans, span)
			total += span
		end
	end
	if #spans == 0 or math.abs(total - 360) > 0.5 then
		return table.create(slices, 360 / slices)
	end
	return spans
end

-- How far round, in degrees the way the wheel turns, slice `slice`'s middle is from slice 1's, which sits under
-- the pointer at rest.
function Logic.sliceMiddle(spans: { number }, slice: number): number
	local before = 0
	for i = 1, slice - 1 do
		before += spans[i]
	end
	return before + spans[slice] / 2 - spans[1] / 2
end

-- Where the world wheel comes to rest after a spin at server time `at`, in radians from where the server placed
-- it: on the won slice when the station says which (`slice`, 1 to #`spans`, slice 1 under the pointer at rest and
-- the rest counted round the way the wheel turns, each `spans` degrees wide), somewhere inside it rather than dead
-- centre, never near an edge, so it can never seem to just miss a better prize. With no slice, anywhere. Every
-- client works out the same angle, so everyone sees the wheel stop in the same place.
function Logic.wheelRest(at: number, slice: number?, spans: { number }): number
	local jitter = Logic.phaseOf(string.format("%.3f", at))
	if slice == nil or slice ~= math.floor(slice) or slice < 1 or slice > #spans then
		return jitter * 2 * math.pi
	end
	local inside = (jitter - 0.5) * Presets.wheel.landWithin
	return -math.rad(Logic.sliceMiddle(spans, slice) + inside * spans[slice])
end

-- The angle a spin turns to from `from`: `turns` whole turns, then on to `rest`, always forward.
function Logic.wheelTarget(from: number, rest: number, turns: number): number
	local tau = 2 * math.pi
	return from + turns * tau + (rest - from) % tau
end

-- How far the pointer is knocked aside, in degrees, at a wheel angle (radians, as wheelRest's): `tilt` just as a
-- slice edge passes it, back to nothing `share` of that slice later. Turning forward, the point under the pointer
-- runs back through the slices, so the edge it last passed is the far edge of the slice under it now.
function Logic.pointerTilt(angle: number, spans: { number }, tilt: number, share: number): number
	local at = (spans[1] / 2 - math.deg(angle)) % 360 -- degrees from slice 1's near edge
	local edge = 0
	for _, span in spans do
		edge += span
		if at < edge then
			return tilt * math.max(0, 1 - (edge - at) / span / share)
		end
	end
	return 0
end

-- Whether rim light `index` is on `t` seconds into a spin: every other one, stepping round each `step` seconds.
function Logic.chaseOn(index: number, t: number, step: number): boolean
	return (index + math.floor(t / step)) % 2 == 0
end

-- The leg a part of the body is ("pawFL", "pawFR", "pawBL" or "pawBR"), or nil. `at` is the part's centre in
-- the body part's own axes (the cat faces -Z, +X is its right), so a cat stood upright reads like one on all
-- fours. The exported cats name every body part like the body, legs included, so a leg is told by shape and place:
-- taller than it is wide, its top at or below the underside of the body, off the middle line.
function Logic.legOf(at: Vector3, size: Vector3, bodySize: Vector3): string?
	if size.Y < 1.2 * math.min(size.X, size.Z) then
		return nil
	end
	if at.Y + size.Y / 2 > 0.1 - bodySize.Y / 2 or math.abs(at.X) < 0.05 then
		return nil
	end
	local front = at.Z < 0
	if at.X > 0 then
		return if front then "pawFR" else "pawBR"
	end
	return if front then "pawFL" else "pawBL"
end

-- How far into a run a cat moving at `speed` studs a second is: 0 at a walk or standing, 1 at a full gallop.
function Logic.runFactor(speed: number): number
	local g = Presets.motion.gait
	return math.clamp((speed - g.runFrom) / (g.runFull - g.runFrom), 0, 1)
end

-- Studs a cat covers in one leg cycle at this speed; Pose counts cycles from the distance the server moves it.
function Logic.strideLength(speed: number): number
	local g = Presets.motion.gait
	return g.walkStride + (g.runStride - g.walkStride) * Logic.runFactor(speed)
end

-- Legs, bob and lean for a cat on the move, layered on the idle. `stride` counts leg cycles covered. Slow, it walks
-- the way cats do, one leg at a time (back left, front left, back right, front right, a quarter cycle apart), its
-- body swaying a little side to side, its head nodding with each step and its tail held up and swaying; from
-- gait.trotFrom it blends into a trot (diagonal legs together) and from gait.runFrom into a gallop (front legs
-- together, back legs half a cycle behind) with the body rocking, the head stretched forward and down and the tail
-- out straight behind.
--
-- `level` (0 to 1, none for 0) is how steady it keeps its head for something balanced on it (a cafe tray, F90): at 1
-- the head stops nodding with the steps and the body bobs half as much.
function Logic.gait(o: Offsets, speed: number, stride: number, level: number?)
	local g = Presets.motion.gait
	if speed < g.moveFrom then
		return
	end
	local steadyHead = 1 - math.clamp(level or 0, 0, 1)
	local start = math.clamp((speed - g.moveFrom) / g.moveFrom, 0, 1) -- eases in from a standstill
	local run = Logic.runFactor(speed)
	local trot = math.clamp((speed - g.trotFrom) / (g.trotFull - g.trotFrom), 0, 1)
	local walk = 1 - trot -- the one-leg-at-a-time walk
	trot *= 1 - run
	local phase = stride * 2 * math.pi
	local s = math.sin(phase)
	local quarter = math.pi / 2
	local swing = math.rad(g.walkSwing + (g.runSwing - g.walkSwing) * run) * start
	o.pawFL += swing * (walk * math.sin(phase - quarter) + trot * s + run * s)
	o.pawFR += swing * (walk * math.sin(phase - 3 * quarter) - trot * s + run * math.sin(
		phase + 0.3
	))
	o.pawBL += swing * (walk * s - trot * s + run * math.sin(phase + math.pi))
	o.pawBR += swing * (walk * math.sin(phase - math.pi) + trot * s + run * math.sin(
		phase + math.pi + 0.3
	))
	local stepBob = g.walkBob * (0.5 - 0.5 * math.cos(2 * phase)) -- two steps a cycle
	local gallopBob = g.runBob * (0.5 + 0.5 * math.cos(phase))
	o.bodyY += ((1 - run) * stepBob * (0.5 + 0.5 * steadyHead) + run * gallopBob) * start
	local rock = math.rad(g.runRock) * s * run
	o.bodyPitch += rock
	o.bodyRoll += math.rad(g.walkRoll) * s * walk * start
	local steady = (1 - run) * start
	o.headPitch += -rock * 0.6 - math.rad(g.runHead) * run + math.rad(g.walkNod) * math.sin(
		2 * phase
	) * steady * steadyHead
	o.headRoll -= math.rad(g.walkRoll) * s * walk * start * 0.6 -- the head stays level as the body sways
	o.headYaw *= 1 - g.lookAhead * start -- on the move it mostly looks where it is going
	o.tailPitch += math.rad(8) * run + math.rad(g.walkTail) * steady
	o.tailYaw = o.tailYaw * (1 - 0.8 * run) + math.rad(g.tailSway) * math.sin(phase + 1) * steady
end

-- An action's weight at `alpha` (0 to 1 of the action): 0 until `start`, easing up to 1 by `full`, holding to
-- `hold`, easing back to 0 by `stop`.
function Logic.envelope(
	alpha: number,
	start: number,
	full: number,
	hold: number,
	stop: number
): number
	if alpha <= start or alpha >= stop then
		return 0
	elseif alpha < full then
		local k = (alpha - start) / (full - start)
		return k * k * (3 - 2 * k)
	elseif alpha <= hold then
		return 1
	end
	local k = (stop - alpha) / (stop - hold)
	return k * k * (3 - 2 * k)
end

-- How long a cat takes to settle from one style into the next: lying down is slow, getting up a little quicker,
-- anything else motion.settle.
function Logic.settleSeconds(from: Style?, to: Style): number
	local m = Presets.motion
	local down = to == "nap" or to == "loaf"
	local wasDown = from == "nap" or from == "loaf"
	if down and not wasDown then
		return m.settleDown
	elseif wasDown and not down then
		return m.settleUp
	end
	return m.settle
end

-- A stretch, layered on the idle while `alpha` runs from 0 to 1 (motion.stretch; Cats plays one as a stray gets up
-- from a nap to walk off, and now and then while a stray stands still). On all fours (the walking body and the older
-- Part cats) the cat gets up from wherever it lay, bows with its front legs out ahead, chest low, rear up and tail
-- up, lifting its head in a yawn with its eyes shut, then rocks forward and stretches each back leg out behind in
-- turn, and settles back. A seated cat is not going anywhere, so it does not stretch (Derek 2026-10-27). `weight`
-- (1 if not given) scales it all, so a stray that sets off mid-stretch can let it go smoothly.
function Logic.stretch(o: Offsets, alpha: number, body: Body?, weight: number?)
	if alpha < 0 or alpha >= 1 or body == "sit" or body == "work" then
		return
	end
	local s = Presets.motion.stretch
	local w = math.clamp(weight or 1, 0, 1)
	local up = Logic.envelope(alpha, 0, s.rise, 1 - s.rise, 1) * w
	o.sleep *= 1 - up
	o.loaf *= 1 - up
	o.lick *= 1 - up
	o.sink *= 1 - up
	o.belly *= 1 - up
	local bow = Logic.envelope(alpha, 0.08, 0.3, 0.48, 0.62) * w
	local rearL = Logic.envelope(alpha, 0.5, 0.6, 0.68, 0.78) * w
	local rearR = Logic.envelope(alpha, 0.66, 0.76, 0.84, 0.94) * w
	local rock = math.max(rearL, rearR)
	local pitch = -math.rad(s.bow) * bow + math.rad(s.rock) * rock
	o.bodyPitch += pitch
	o.bodyY -= s.drop * bow -- the body turns about its middle, so drop it to keep the back feet down
	-- front legs reach out ahead in the bow, then stand straight under the chest
	o.pawFL += math.rad(s.reach) * bow - math.rad(s.rock) * rock
	o.pawFR += math.rad(s.reach) * bow - math.rad(s.rock) * rock
	-- back legs stay upright under the raised rear, then each stretches out behind
	o.pawBL += -pitch - math.rad(s.rear) * rearL
	o.pawBR += -pitch - math.rad(s.rear) * rearR
	o.headPitch += -pitch * s.headLevel + math.rad(s.yawn) * bow
	o.tailPitch += math.rad(s.tail) * math.max(bow, rock * 0.5)
	o.tailYaw *= 1 - bow
	o.blink = math.max(o.blink, bow)
	o.earL = math.max(o.earL, math.rad(s.ears) * bow)
	o.earR = math.max(o.earR, math.rad(s.ears) * bow)
end

-- Catching its breath after a sprint: quick shallow breaths, head low, tail down. Replaces the idle's breathing.
function Logic.pant(o: Offsets, t: number)
	local p = Presets.motion.pant
	o.bodyY = (wave(t, p.seconds) * 0.5 + 0.5) * p.studs
	o.headPitch = -math.rad(p.headDown)
	o.headYaw *= 0.3
	o.tailPitch = -math.rad(p.tailDown)
	o.tailYaw *= 0.4
end

-- Which wriggle a cat stuck in a rescue trap of this TrapType gets (motion.stuck.kinds); the plain shake when the
-- trap is not listed.
function Logic.stuckStyle(trapType: unknown): Style
	local kind = if type(trapType) == "string" then Presets.motion.stuck.kinds[trapType] else nil
	if kind == "butt" then
		return "stuckButt"
	elseif kind == "flip" then
		return "stuckFlip"
	end
	return "stuck"
end

function Logic.isStuck(style: Style): boolean
	return style == "stuck" or style == "stuckButt" or style == "stuckFlip"
end

-- How much of the Balloon Cat's float (motion.float) a style gets: all of it awake, `resting` of it asleep or
-- loafing, none stuck in a trap.
function Logic.floatShare(style: Style): number
	if Logic.isStuck(style) then
		return 0
	elseif style == "nap" or style == "loaf" or style == "doze" then
		return Presets.motion.float.resting
	end
	return 1
end

-- The Balloon Cat's bob (F78, motion.float), layered on everything else by `share` (Logic.floatShare, less while it
-- runs): the whole cat lifts off its paws and settles back, every few bobs pulled higher, swaying as it hangs with
-- its legs a little apart (on its feet only) and its tail up.
function Logic.float(o: Offsets, t: number, share: number)
	if share <= 0 then
		return
	end
	local f = Presets.motion.float
	local cycle = t / f.seconds
	local into = cycle % 1
	local up = 0
	if into < f.rise then
		local k = into / f.rise
		up = k * k * (3 - 2 * k)
	elseif into < f.rise + f.fall then
		local k = (into - f.rise) / f.fall
		up = 1 - k * k * (3 - 2 * k)
	end
	local tug = math.floor(cycle) % f.tugEvery == f.tugEvery - 1
	up *= share
	o.bodyY += up * (if tug then f.tugStuds else f.studs)
	o.bodyRoll += math.rad(f.sway) * up * wave(t, f.swaySeconds)
	o.tailPitch += math.rad(f.tail) * up
	local hang = math.rad(f.dangle) * up * (1 - math.max(o.sink, o.sleep, o.loaf))
	o.pawFL += hang
	o.pawFR += hang
	o.pawBL -= hang
	o.pawBR -= hang
end

-- The hiss on a missed catch, layered on the idle while `alpha` runs from 0 to 1: the cat rears and hops back
-- with its head pulled back and its tail straight up.
function Logic.hiss(o: Offsets, alpha: number)
	if alpha < 0 or alpha >= 1 then
		return
	end
	local h = Presets.motion.hiss
	local arc = math.sin(alpha * math.pi)
	o.bodyY += h.hop * arc
	o.bodyPitch += math.rad(12) * arc
	o.headPitch += math.rad(h.headBack) * arc
	o.tailPitch += math.rad(h.tailUp) * arc
	o.tailYaw *= 1 - arc
end

-- The startled spring of a near miss (motion.startle), `alpha` 0 to 1 through it, layered on whatever the cat does:
-- up and back down in one arc, nose up, tail up and ears flat back, all easing out by the landing.
function Logic.startle(o: Offsets, alpha: number)
	if alpha < 0 or alpha >= 1 then
		return
	end
	local s = Presets.motion.startle
	local arc = math.sin(alpha * math.pi)
	o.bodyY += s.hop * arc
	o.bodyPitch += math.rad(s.lean) * arc
	o.tailPitch += math.rad(s.tailUp) * arc
	o.tailYaw *= 1 - arc
	o.earL = math.max(o.earL, math.rad(s.ears) * arc)
	o.earR = math.max(o.earR, math.rad(s.ears) * arc)
end

-- Asleep for the Bellhop Cat's sleepy cap: a nap or a doze.
function Logic.asleep(style: Style): boolean
	return style == "nap" or style == "doze"
end

-- The Bellhop Cat's bell ring (Presets.bellhop.ring), `alpha` 0 to 1 through it: a quick shake of the head and the
-- bell swinging side to side, dying away to rest by the end.
function Logic.bellRing(o: Offsets, alpha: number)
	if alpha < 0 or alpha >= 1 then
		return
	end
	local r = Presets.bellhop.ring
	local fade = (1 - alpha) * (1 - alpha)
	o.bell += math.rad(r.degrees) * math.sin(alpha * r.swings * 2 * math.pi) * fade
	local shaking = r.shakeSeconds / r.seconds
	if alpha < shaking then
		local k = alpha / shaking
		o.headRoll += math.rad(r.shake) * math.sin(k * 3 * math.pi) * (1 - k)
	end
end

-- The Bellhop Cat tipping its cap (Presets.bellhop.tip), `alpha` 0 to 1: the cap lifts at the front with a small nod,
-- holds a moment and settles back.
function Logic.capTip(o: Offsets, alpha: number)
	local t = Presets.bellhop.tip
	local k = Logic.envelope(alpha, 0, 0.3, 0.55, 1)
	o.capTip += math.rad(t.degrees) * k
	o.headPitch -= math.rad(t.nod) * k
end

-- A cat's motion `t` seconds into a card's picture (Portrait.luau, Presets.portrait), for a cat `catId` on a `body`
-- (Pose's rig kind): the stray idle in place, breathing with the belly, and for the Bellhop Cat a bell ring every
-- `every` seconds from `ringFrom` with the cap tip `tipAfter` later. The body itself never moves or rolls, so the
-- picture holds still round it.
function Logic.portrait(catId: string?, t: number, body: Body?): Offsets
	local p = Presets.portrait
	local o = Logic.idle("stray", t, body)
	local held = Presets.motion.held
	o.bodyY = 0 -- breathing with the belly, as a cat in your arms does, instead of floating up and down
	o.belly = Logic.breath(t, held.seconds) * held.breathe
	o.bodyRoll = 0
	if catId == Presets.bellhop.catId and t >= p.ringFrom then
		local b = Presets.bellhop
		local into = (t - p.ringFrom) % p.every
		if into < b.ring.seconds then
			Logic.bellRing(o, into / b.ring.seconds)
		end
		local tip = (into - b.tipAfter) / b.tip.seconds
		if tip >= 0 and tip < 1 then
			Logic.capTip(o, tip)
		end
	end
	return o
end

-- The Bellhop Cat's little bow as it is put in its place (Presets.bellhop.bow), `alpha` 0 to 1: it leans forward,
-- head down and cap tipped, holds and sits back up, the tail still while it bows.
function Logic.bow(o: Offsets, alpha: number)
	local b = Presets.bellhop.bow
	local k = Logic.envelope(alpha, 0, 0.35, 0.6, 1)
	o.bodyPitch -= math.rad(b.lean) * k
	o.headPitch -= math.rad(b.head) * k
	o.capTip += math.rad(b.cap) * k
	o.tailYaw *= 1 - k
end

-- The happy hop as the Bellhop Cat is claimed (Presets.bellhop.hop), `alpha` 0 to 1: a little bounce where it sits,
-- then the leap with its nose and tail up, its front paws reaching ahead and its ears pricked. Where it is comes from
-- Logic.hopArc.
function Logic.happyHop(o: Offsets, alpha: number)
	if alpha < 0 or alpha >= 1 then
		return
	end
	local h = Presets.bellhop.hop
	local arc
	if alpha < h.bounce then
		arc = math.sin(alpha / h.bounce * math.pi)
		o.bodyY += h.bounceHeight * arc
		o.tailPitch += math.rad(h.tailUp) * 0.5 * arc
	else
		arc = math.sin((alpha - h.bounce) / (1 - h.bounce) * math.pi)
		o.bodyPitch += math.rad(h.lean) * arc
		o.headPitch += math.rad(h.lean) * 0.5 * arc
		o.tailPitch += math.rad(h.tailUp) * arc
		o.pawFL += math.rad(h.reach) * arc
		o.pawFR += math.rad(h.reach) * arc
	end
	o.tailYaw *= 1 - arc
	o.earL *= 1 - arc
	o.earR *= 1 - arc
end

-- Where the happy hop's leap is `alpha` of the way from `from` to `to` (0 to 1, clamped): straight across with a
-- parabola `height` studs high on top, so it leaves from one point and lands on the other.
function Logic.hopArc(from: Vector3, to: Vector3, height: number, alpha: number): Vector3
	local k = math.clamp(alpha, 0, 1)
	return from + (to - from) * k + Vector3.new(0, 4 * height * k * (1 - k), 0)
end

-- The Lucky Cat's paw at time t (Presets.luckyPaw), radians about its shoulder's X: a smooth beckon forward and back,
-- one every seconds[level], faster at each level; level 0 (the empty plinth) or an unknown level rests at 0.
function Logic.pawWave(t: number, level: number): number
	local p = Presets.luckyPaw
	local seconds: number? = p.seconds[math.floor(level)]
	if seconds == nil then
		return 0
	end
	return math.rad(p.degrees) * math.sin(t * 2 * math.pi / seconds)
end

-- Where the secured cat's happy hop (Presets.pullHop) has it `alpha` of the way through (0 to 1): studs off the
-- floor and radians it has turned. On the floor until takeoff, a parabola `height` high to the landing while it turns
-- `turns` full turns (easing in and out), then down and turned all the way round, facing where it began.
function Logic.pullHop(alpha: number): (number, number)
	local h = Presets.pullHop
	local full = 2 * math.pi * h.turns
	if alpha <= h.takeoff then
		return 0, 0
	elseif alpha >= h.land then
		return 0, full
	end
	local k = (alpha - h.takeoff) / (h.land - h.takeoff)
	return 4 * h.height * k * (1 - k), full * k * k * (3 - 2 * k)
end

-- The secured cat's body through its happy hop (Presets.pullHop), `alpha` 0 to 1: a crouch to spring, the leap with
-- its tail up, front paws reaching and back paws kicking, nose up then down for the landing, a squash as it lands,
-- then sitting up proud with its ears pricked.
function Logic.pullHopPose(o: Offsets, alpha: number)
	local h = Presets.pullHop
	if alpha < 0 or alpha >= 1 then
		return
	end
	if alpha < h.takeoff then
		local c = math.sin(alpha / h.takeoff * math.pi)
		o.bodyY -= h.crouch * c
		o.bodyPitch -= math.rad(h.lean) * 0.5 * c
	elseif alpha < h.land then
		local k = (alpha - h.takeoff) / (h.land - h.takeoff)
		local s = math.sin(k * math.pi)
		o.tailPitch += math.rad(h.tailUp) * s
		o.tailYaw *= 1 - s
		o.pawFL += math.rad(h.reach) * s
		o.pawFR += math.rad(h.reach) * s
		o.pawBL -= math.rad(h.reach) * s
		o.pawBR -= math.rad(h.reach) * s
		o.bodyPitch += math.rad(h.lean) * math.sin(k * 2 * math.pi)
		o.earL *= 1 - s
		o.earR *= 1 - s
	elseif alpha < h.settle then
		local c = math.sin((alpha - h.land) / (h.settle - h.land) * math.pi)
		o.bodyY -= h.squash * c
	else
		local k = Logic.envelope(alpha, h.settle, h.settle + 0.06, 0.96, 1)
		o.headPitch += math.rad(h.proud) * k
		o.tailPitch += math.rad(h.tailUp) * 0.5 * k
		o.earL *= 1 - k
		o.earR *= 1 - k
	end
end

-- How much of a server jump is still drawn as distance left to travel: 1 at the jump, 0 on landing.
function Logic.landing(alpha: number): number
	local a = math.clamp(alpha, 0, 1)
	return 1 - a * a * (3 - 2 * a)
end

-- Where a confetti piece is `t` seconds after launch, relative to where it started. Linear drag with gravity:
-- it shoots up, slows, then drifts down near its terminal speed (gravity / drag) with a little sway.
function Logic.confettiOffset(velocity: Vector3, t: number, phase: number): Vector3
	local c = Presets.confetti
	local k = c.drag
	local slow = 1 - math.exp(-k * t)
	local terminal = c.gravity / k
	local y = (velocity.Y + terminal) / k * slow - terminal * t
	local sway = math.sin(t * 6 + phase) * c.flutter * math.min(1, t)
	return Vector3.new(velocity.X / k * slow + sway, y, velocity.Z / k * slow)
end

-- Where a butterfly is `k` (0 to 1 of the flight's time) into a flight from one spot to the next: eased, so it
-- sets off and settles gently, and still at either end.
function Logic.butterflyLeg(from: Vector3, to: Vector3, k: number): Vector3
	local x = math.clamp(k, 0, 1)
	return from + (to - from) * (x * x * (3 - 2 * x))
end

-- How far above its straight line a butterfly flying over to another bed is `k` (0 to 1) into the flight: up to
-- `arc` studs halfway, none at either end.
function Logic.hopLift(k: number, arc: number): number
	return arc * math.sin(math.pi * math.clamp(k, 0, 1))
end

-- How much of a butterfly shows `age` seconds into a spell out `length` long: fading in over the first `fade`
-- seconds and out over the last, none before or after it.
function Logic.spell(age: number, length: number, fade: number): number
	if age <= 0 or age >= length then
		return 0
	end
	local edge = math.min(fade, length / 2)
	if edge <= 0 then
		return 1
	end
	return math.min(1, age / edge, (length - age) / edge)
end

-- A butterfly's little loop on top of its flight: its offset at time t and its wing angle.
function Logic.butterfly(t: number, phase: number): (Vector3, number)
	local b = Presets.butterfly
	local roam = b.roam
	local offset = Vector3.new(
		math.sin(t * 0.7 + phase) * roam.X,
		b.height + math.sin(t * 1.3 + phase * 2) * roam.Y,
		math.sin(t * 0.9 + phase * 3) * roam.Z
	)
	local flap = math.rad(b.flapDegrees) * math.sin(t * b.flapHz * 2 * math.pi + phase)
	return offset, flap
end

-- A Jazz Cat music note `age` seconds after it left the saxophone (Presets.notes, F78): its offset from there, quick
-- off the sax and slowing as it rises, swaying to and fro, and how much of it shows, fading in over `fadeIn` and out
-- over the last `fade` seconds.
function Logic.note(age: number, phase: number): (Vector3, number)
	local n = Presets.notes
	local k = math.clamp(age / n.seconds, 0, 1)
	local rise = n.rise * (1 - (1 - k) * (1 - k))
	local sway = n.sway * math.sin(age * n.swayHz * 2 * math.pi + phase)
	local shown = math.clamp(math.min(age / n.fadeIn, (n.seconds - age) / n.fade), 0, 1)
	return Vector3.new(sway, rise, 0), shown
end

-- Whether a stray's rarity gem (Presets.rarityMark) can show: its `Rarity` is one that shows, nobody is catching it
-- (`LockedBy` is 0 or not set) and you are within maxDistance studs. With hideWithin at 0 it stays up close while
-- the cat is free; a larger hideWithin would hide a `shown` gem at that distance or nearer, and a hidden one would
-- come back only past hideWithin + showAfter.
function Logic.rarityMarkShows(
	rarity: unknown,
	lockedBy: unknown,
	distance: number,
	shown: boolean
): boolean
	local r = Presets.rarityMark
	if type(rarity) ~= "string" or r.shows[rarity] ~= true then
		return false
	end
	local locked = type(lockedBy) == "number" and lockedBy ~= 0
	local near = if shown then r.hideWithin else r.hideWithin + r.showAfter
	return not locked and distance > near and distance <= r.maxDistance
end

-- Whether a part is water players can walk through (Effects/Splash): its name ends in "Water" or "Puddle", as the
-- placeholders' Water, every model's ..._Water and the Alley's puddles do; a WaterfallPond's rocks do not.
function Logic.isWaterName(name: string): boolean
	return string.sub(name, -5) == "Water" or string.sub(name, -6) == "Puddle"
end

-- Whether feet stand in a flat piece of water: `height` studs above its top (Presets.splash: up to `above` over it,
-- down to `depth` under it, wading), and `u`, `v` across its face within halfU and halfV of its middle, or within
-- the smaller of the two as a radius on a round one.
function Logic.wading(
	height: number,
	u: number,
	v: number,
	halfU: number,
	halfV: number,
	round: boolean
): boolean
	local s = Presets.splash
	if height > s.above or height < -s.depth then
		return false
	end
	if round then
		local radius = math.min(halfU, halfV)
		return u * u + v * v <= radius * radius
	end
	return math.abs(u) <= halfU and math.abs(v) <= halfV
end

-- A walker's next splash in the water: whether one is due after `moved` more studs, and the studs carried toward the
-- one after (never more than a stride, so a fast walker does not bank splashes).
function Logic.waterStep(carried: number, moved: number, stride: number): (boolean, number)
	local total = carried + moved
	if total >= stride then
		return true, math.min(total - stride, stride)
	end
	return false, total
end

-- The model of a crate from `area` (a zone id or "classic") in ReplicatedStorage.Assets: `CatCafe_Prop_Crate_Alley`,
-- `CatCafe_Prop_Crate_Alley_Gold` for its golden twin (Model-Agent's crates.py). Nil for no area.
function Logic.crateModelName(area: unknown, golden: unknown): string?
	if type(area) ~= "string" or area == "" then
		return nil
	end
	local pool = string.upper(string.sub(area, 1, 1)) .. string.sub(area, 2)
	return "CatCafe_Prop_Crate_" .. pool .. (if golden == true then "_Gold" else "")
end

-- How far open a crate's lid is `elapsed` seconds into its `seconds` swing: quick at first and easing into
-- `degrees`, never past it.
function Logic.lidAngle(elapsed: number, seconds: number, degrees: number): number
	if seconds <= 0 then
		return degrees
	end
	local x = math.clamp(elapsed / seconds, 0, 1)
	return degrees * (1 - (1 - x) * (1 - x))
end

-- The crate reel (F103, crate-reel.md) in the Market window, from Config's CrateReel* numbers: it starts with tile 1
-- under the marker and stops on the centre of tile `landing`, speeding up evenly to `topSpeed` tiles a second over
-- `rampSeconds`, running flat out, then slowing to a stop over `stopSeconds` with an ease-out cubic. That cubic sets
-- off at three times its average pace, so meeting the top speed it covers topSpeed * stopSeconds / 3 tiles (4 with
-- the spec's numbers). How many seconds after CrateResult it stops (about 2.9 with the defaults), and when the slow
-- down starts.
function Logic.crateReelStop(
	landing: number,
	topSpeed: number,
	rampSeconds: number,
	stopSeconds: number
): (number, number)
	local ramp = math.max(rampSeconds, 0)
	local slowTiles = math.max(topSpeed, 0) * math.max(stopSeconds, 0) / 3
	local cruise = 0
	if topSpeed > 0 then
		cruise = math.max(landing - 1 - topSpeed * ramp / 2 - slowTiles, 0) / topSpeed
	end
	local slowFrom = ramp + cruise
	return slowFrom + math.max(stopSeconds, 0), slowFrom
end

-- How fast the reel runs `t` seconds in, from 0 (still) to 1 (flat out): up evenly over `rampSeconds`, flat until
-- `slowFrom`, then the ease-out cubic's slowing over `stopSeconds`, still from the stop on. The counter crate's lid
-- rattles this hard, the same for every prize.
function Logic.crateReelPace(
	t: number,
	rampSeconds: number,
	slowFrom: number,
	stopSeconds: number
): number
	if t <= 0 then
		return 0
	end
	if t < rampSeconds then
		return t / rampSeconds
	end
	if t < slowFrom then
		return 1
	end
	if stopSeconds <= 0 then
		return 0
	end
	local left = 1 - math.clamp((t - slowFrom) / stopSeconds, 0, 1)
	return left * left
end

-- Campfires ---------------------------------------------------------------------------------------------------

-- How one tongue of a campfire's flame moves `t` seconds in, `phase` radians apart from its neighbours: its stretch
-- (1 is the modelled height), its lean at the tip in radians about X and about Z, and a flicker from 0 to 1 for its
-- colour and the light. Three waves at `c.hz` added up, so it never repeats in an obvious beat.
function Logic.flame(
	t: number,
	phase: number,
	c: { stretch: number, lean: number, hz: { number } }
): (number, number, number, number)
	local a = math.sin(2 * math.pi * c.hz[1] * t + phase)
	local b = math.sin(2 * math.pi * c.hz[2] * t + phase * 1.7)
	local d = math.sin(2 * math.pi * c.hz[3] * t + phase * 2.3)
	local lean = math.rad(c.lean)
	return 1 + c.stretch * (0.6 * a + 0.4 * b),
		lean * (0.7 * b + 0.3 * d),
		lean * (0.7 * d + 0.3 * a),
		math.clamp(0.5 + 0.3 * a + 0.2 * d, 0, 1)
end

-- Splits a campfire's flame discs (their centres in `points`) into tongues: discs within `gap` studs of each other
-- across the ground, X and Z, stack into one tongue. Each list holds indexes into `points`, the lowest first.
function Logic.flameTongues(points: { Vector3 }, gap: number): { { number } }
	local tongues: { { number } } = {}
	local anchors: { Vector3 } = {}
	for i, point in points do
		local found: number? = nil
		for k, anchor in anchors do
			if Vector2.new(point.X - anchor.X, point.Z - anchor.Z).Magnitude <= gap then
				found = k
				break
			end
		end
		if found == nil then
			table.insert(anchors, point)
			table.insert(tongues, { i })
		else
			table.insert(tongues[found], i)
		end
	end
	for _, list in tongues do
		table.sort(list, function(x: number, y: number): boolean
			return points[x].Y < points[y].Y
		end)
	end
	return tongues
end

-- Which of a part's own axes points most nearly up, from the Y of its RightVector, UpVector and LookVector: 1 for X,
-- 2 for Y, 3 for Z (a flame disc is a Cylinder, its axis X, turned to stand up).
function Logic.upAxis(rightY: number, upY: number, lookY: number): number
	local x, y, z = math.abs(rightY), math.abs(upY), math.abs(lookY)
	if x >= y and x >= z then
		return 1
	end
	return if y >= z then 2 else 3
end

-- Where one disc of a flame tongue goes, as an offset from the tongue's base: at rest `offset` from it (its centre
-- `offset.Y` studs up a tongue `top` studs tall), stretched by `stretch` and bent by `leanX` and `leanZ` (radians at
-- the top, less lower down). Also the disc's own turn, about X and about Z: CFrame.Angles(ax, 0, az), which turns
-- about Z first and then about X, as this does to the offset.
function Logic.flameLift(
	offset: Vector3,
	top: number,
	stretch: number,
	leanX: number,
	leanZ: number
): (Vector3, number, number)
	local bend = if top > 0 then offset.Y / top else 0
	local ax, az = leanX * bend, leanZ * bend
	local x, y, z = offset.X, offset.Y * stretch, offset.Z
	local cz, sz = math.cos(az), math.sin(az)
	x, y = x * cz - y * sz, x * sz + y * cz
	local cx, sx = math.cos(ax), math.sin(ax)
	y, z = y * cx - z * sx, y * sx + z * cx
	return Vector3.new(x, y, z), ax, az
end

-- How a flame disc's size scales as its tongue stretches: by `stretch` along its upright axis `up` (1 to 3 for X, Y,
-- Z) and thinner across, so the flame keeps its body.
function Logic.flameScale(up: number, stretch: number): Vector3
	local thin = 1 / math.sqrt(stretch)
	return Vector3.new(
		if up == 1 then stretch else thin,
		if up == 2 then stretch else thin,
		if up == 3 then stretch else thin
	)
end

-- Big pulls (F89) ------------------------------------------------------------------------------------------------

-- True when securing something of `rarity` plays the big pull (luck-and-rare-moments.md 2a, 2b): a Legendary, a
-- Mythical, or a gold Epic. Crate pieces are never gold.
function Logic.bigPull(rarity: unknown, gold: boolean, rainbow: boolean?): boolean
	if rainbow == true and type(rarity) == "string" then
		return true -- a rainbow cat of any rarity (F99)
	end
	if rarity == "Legendary" or rarity == "Mythical" then
		return true
	end
	return gold and rarity == "Epic"
end

-- How many confetti pieces a big pull throws from the budget's `most`: half with Reduce Motion, and never fewer than
-- one from each side.
function Logic.pullCount(most: number, reduced: boolean): number
	return math.max(2, if reduced then math.floor(most / 2) else most)
end

-- Where a piece of a big pull's confetti leaves the screen's edge and how fast it goes, in pixels and pixels a
-- second (y down): from the left edge (`side` -1) or the right (1), `u1` to `u3` being its random draws from 0 to 1,
-- up and in toward the middle.
function Logic.pullLaunch(
	side: number,
	u1: number,
	u2: number,
	u3: number,
	view: Vector2,
	c: { height: { number }, speed: { number }, angle: { number } }
): (Vector2, Vector2)
	local y = view.Y * (c.height[1] + (c.height[2] - c.height[1]) * u1)
	local x = if side < 0 then 0 else view.X
	local speed = view.Y * (c.speed[1] + (c.speed[2] - c.speed[1]) * u2)
	local angle = math.rad(c.angle[1] + (c.angle[2] - c.angle[1]) * u3)
	return Vector2.new(x, y), Vector2.new(-side * speed * math.cos(angle), -speed * math.sin(angle))
end

-- Where a confetti piece is `t` seconds after it left `from` at `velocity`, falling at `gravity` pixels a second
-- every second and slowed by `drag` (a share of its speed a second): the closed form, so every frame agrees.
function Logic.confettiAt(
	from: Vector2,
	velocity: Vector2,
	gravity: number,
	drag: number,
	t: number
): Vector2
	if drag <= 0 then
		return from + velocity * t + Vector2.new(0, 0.5 * gravity * t * t)
	end
	local slowed = (1 - math.exp(-drag * t)) / drag
	return from + velocity * slowed + Vector2.new(0, gravity / drag * (t - slowed))
end

-- How see-through a big pull's piece is `t` seconds in: solid, then fading over the last `fade` of `seconds`.
function Logic.pullFade(t: number, seconds: number, fade: number): number
	if t <= seconds - fade then
		return 0
	end
	return math.clamp((t - (seconds - fade)) / fade, 0, 1)
end

-- Gold Leaf trims (F89 2c) ----------------------------------------------------------------------------------------

-- Where Gold Leaf's glint is `t` seconds into its clock, along the cafe front in plot X: at the start of every
-- `every` seconds a band crosses from `width` before `lo` to `width` past `hi` in `seconds`; nil between crossings.
function Logic.trimSweep(
	t: number,
	every: number,
	seconds: number,
	lo: number,
	hi: number,
	width: number
): number?
	if every <= 0 or seconds <= 0 then
		return nil
	end
	local into = t % every
	if into >= seconds then
		return nil
	end
	local from, to = lo - width, hi + width
	return from + (to - from) * into / seconds
end

-- How brightly a trim spanning `x0` to `x1` in plot X catches the glint at `band`: 1 while the band is over it,
-- easing to 0 `width` away. A trim longer than two band widths (the cornice, the awning edge) catches only that
-- share of it, so a long run lifts gently while the short pieces flash in turn.
function Logic.trimGlint(x0: number, x1: number, band: number?, width: number): number
	if band == nil or width <= 0 then
		return 0
	end
	local gap = if band < x0 then x0 - band elseif band > x1 then band - x1 else 0
	if gap >= width then
		return 0
	end
	local k = 1 - gap / width
	local strength = k * k * (3 - 2 * k)
	local length = x1 - x0
	if length > 2 * width then
		strength *= 2 * width / length
	end
	return strength
end

-- True when two colours differ by more than `tolerance` in any channel (a part keeps its Color in 8 bits, so a
-- colour written to it reads back a little off).
function Logic.colourMoved(a: Color3, b: Color3, tolerance: number): boolean
	return math.abs(a.R - b.R) > tolerance
		or math.abs(a.G - b.G) > tolerance
		or math.abs(a.B - b.B) > tolerance
end

-- Rainbow coats (F99) ---------------------------------------------------------------------------------------------

-- The colour `u` of the way round a rainbow's hues (any number; it wraps), each hue blending into the next.
function Logic.rainbowAt(hues: { Color3 }, u: number): Color3
	local n = #hues
	if n == 0 then
		return Color3.new(1, 1, 1)
	end
	local x = (u % 1) * n
	local i = math.floor(x)
	return hues[i % n + 1]:Lerp(hues[(i + 1) % n + 1], x - i)
end

-- Where a coat part sits from the nose (0) to the tail tip (1): `z` back along the cat, the nose at `front` and the
-- tail tip at `back`.
function Logic.rainbowPhase(z: number, front: number, back: number): number
	if back - front <= 1e-6 then
		return 0
	end
	return math.clamp((z - front) / (back - front), 0, 1)
end

-- How far round the hues a part at `phase` is `t` seconds in: the bands flow from nose to tail, one lap every
-- `period` seconds, `spread` laps along the cat. A still coat passes t = 0.
function Logic.rainbowHue(t: number, phase: number, period: number, spread: number): number
	return phase * spread - (if period > 0 then t / period else 0)
end

-- A coat colour's lightness (0 to 1).
function Logic.lightness(colour: Color3): number
	return 0.299 * colour.R + 0.587 * colour.G + 0.114 * colour.B
end

-- How bright a part's band is, from `least` to 1: its own colour's lightness against the lightest coat part's, so
-- stripes and patches still show as darker bands.
function Logic.rainbowShade(light: number, lightest: number, least: number): number
	if lightest <= 1e-6 then
		return 1
	end
	return least + (1 - least) * math.clamp(light / lightest, 0, 1)
end

-- True for a face detail a rainbow coat leaves as it is (the nose, the mouth, the blush): a part whose longest side
-- is under `share` of its piece's biggest part's.
function Logic.rainbowKeeps(longest: number, biggest: number, share: number): boolean
	return longest < biggest * share
end

-- Cafe walks (CafeWalk.luau, Presets.cafeWalk). A waiter's way from its station to a chair's Approach point
-- (CafeService: Aisle is beside the middle aisle at the chair's row lane, Approach on that lane in line with the
-- chair): square onto the lane first, then along it, so it never cuts across a table. The lane point is where the
-- station meets the lane square on, kept between Aisle and Approach; a station already on the lane (or in line with
-- the Approach point) walks straight there. Every point is at the station's height (the cafe floor).
function Logic.strollRoute(station: Vector3, aisle: Vector3, approach: Vector3): { Vector3 }
	local function floor(point: Vector3): Vector3
		return Vector3.new(point.X, station.Y, point.Z)
	end
	local lane = floor(approach) - floor(aisle)
	local length = lane.Magnitude
	local route: { Vector3 } = {}
	if length > 1e-3 then
		local along = lane / length
		local onto = floor(aisle)
			+ along * math.clamp((station - floor(aisle)):Dot(along), 0, length)
		if (onto - station).Magnitude > 0.3 and (onto - floor(approach)).Magnitude > 0.3 then
			table.insert(route, onto)
		end
	end
	table.insert(route, floor(approach))
	return route
end

-- How long a walk through `points` is, in studs.
function Logic.routeLength(points: { Vector3 }): number
	local total = 0
	for i = 2, #points do
		total += (points[i] - points[i - 1]).Magnitude
	end
	return total
end

-- Where a walk through `points` is once it has gone `travelled` studs from the first: the position, the way it is
-- going (a flat unit vector; the last leg's way once it has arrived) and whether it has arrived.
function Logic.along(points: { Vector3 }, travelled: number): (Vector3, Vector3, boolean)
	local left = math.max(travelled, 0)
	local heading = Vector3.new(0, 0, -1)
	for i = 2, #points do
		local leg = points[i] - points[i - 1]
		local flat = Vector3.new(leg.X, 0, leg.Z)
		local length = leg.Magnitude
		if length > 1e-6 then
			if flat.Magnitude > 1e-6 then
				heading = flat.Unit
			end
			if left < length then
				return points[i - 1] + leg * (left / length), heading, false
			end
			left -= length
		end
	end
	return points[#points], heading, true
end

-- The turn about Y (radians) that faces a model, which looks along -Z, along the flat direction `way`.
function Logic.yawOf(way: Vector3): number
	return math.atan2(-way.X, -way.Z)
end

-- `yaw` turned toward `target` by at most `step` radians, the short way round.
function Logic.turnToward(yaw: number, target: number, step: number): number
	local d = (target - yaw + math.pi) % (2 * math.pi) - math.pi
	if math.abs(d) <= step then
		return target
	end
	return yaw + (if d > 0 then step else -step)
end

-- Rescue Rally, bunting and Trade done (F101, F102) -----------------------------------------------------------------

-- How full the Rally bar is, 0 to 1, with `points` of `goal` (empty for a goal of 0).
function Logic.rallyFill(points: number, goal: number): number
	if goal <= 0 then
		return 0
	end
	return math.clamp(points / goal, 0, 1)
end

-- The steps (shares of the bar, 1 the full bar) a Rally state crossed going from `beforeFill` in lap `beforeLap` to
-- `afterFill` in lap `afterLap`, in order. A new lap crossed every step the old one had left, the full bar always;
-- laps skipped in between are not played again. Nothing when the lap goes back (a new weekend or a fresh server).
function Logic.rallySteps(
	beforeFill: number,
	beforeLap: number,
	afterFill: number,
	afterLap: number,
	steps: { number }
): { number }
	local crossed: { number } = {}
	if afterLap < beforeLap then
		return crossed
	end
	local from = beforeFill
	if afterLap > beforeLap then
		for _, step in steps do
			if step >= 1 or step > beforeFill then
				table.insert(crossed, step)
			end
		end
		from = 0
	end
	for _, step in steps do
		if step < 1 and step > from and step <= afterFill then
			table.insert(crossed, step)
		end
	end
	return crossed
end

-- Smooth in and out, 0 to 1.
function Logic.easeInOut(u: number): number
	local k = math.clamp(u, 0, 1)
	return k * k * (3 - 2 * k)
end

-- The bend of a flight from `from` to `to` on the screen (pixels, y down): the middle, pushed sideways by `lift` of
-- the distance (to the left of the way it goes when `lift` is above 0, so a flight to the left arcs up).
function Logic.flyBend(from: Vector2, to: Vector2, lift: number): Vector2
	local d = to - from
	return (from + to) / 2 + Vector2.new(-d.Y, d.X) * lift
end

-- Where a flight is `u` (0 to 1) of the way along the curve from `from` past `bend` to `to`.
function Logic.curve(from: Vector2, bend: Vector2, to: Vector2, u: number): Vector2
	local v = 1 - u
	return from * (v * v) + bend * (2 * v * u) + to * (u * u)
end

-- How big a flying pop is `t` seconds into its `seconds`: it pops in with a small overshoot over `popIn`, then
-- shrinks to `land` as it arrives.
function Logic.popScale(t: number, seconds: number, popIn: number, land: number): number
	if t < popIn then
		local k = t / popIn - 1
		return math.max(0, 1 + 2.70158 * k * k * k + 1.70158 * k * k)
	end
	local u = math.clamp((t - popIn) / math.max(seconds - popIn, 1e-6), 0, 1)
	return 1 + (land - 1) * u * u
end

-- A hanging pennant's hinge from its box's unit axes and size: the thinnest axis is its face's normal and, of the
-- other two, the more upright one hangs it. Returns the axis along its string, its up axis turned toward the sky and
-- half its height along that axis (the top edge is that far above its middle).
function Logic.pennantHinge(
	right: Vector3,
	up: Vector3,
	back: Vector3,
	size: Vector3
): (Vector3, Vector3, number)
	local a, b, ha, hb = up, back, size.Y, size.Z
	if size.Y < size.X and size.Y <= size.Z then
		a, b, ha, hb = right, back, size.X, size.Z
	elseif size.Z < size.X and size.Z < size.Y then
		a, b, ha, hb = right, up, size.X, size.Y
	end
	local hang, along, height = a, b, ha
	if math.abs(b.Y) > math.abs(a.Y) then
		hang, along, height = b, a, hb
	end
	if hang.Y < 0 then
		hang = -hang
	end
	return along, hang, height / 2
end

-- How far along the wind `at` sits, as a phase in radians every `wavelength` studs, so a gust runs across the bunting
-- the way the wind blows (along X when there is no wind to speak of).
function Logic.windPhase(at: Vector3, wind: Vector3, wavelength: number): number
	local flat = Vector3.new(wind.X, 0, wind.Z)
	local way = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(1, 0, 0)
	return 2 * math.pi * at:Dot(way) / wavelength
end

-- How far a pennant swings out of its hanging plane, in degrees, `t` seconds in at `phase`: a lean of `lean` plus two
-- waves of `swing` degrees at `hz1` and `hz2` that never line up.
function Logic.flutter(
	t: number,
	phase: number,
	f: { lean: number, swing: number, hz1: number, hz2: number }
): number
	local w1 = math.sin(2 * math.pi * f.hz1 * t - phase)
	local w2 = math.sin(2 * math.pi * f.hz2 * t - 1.7 * phase + 0.9)
	return f.lean + f.swing * (0.65 * w1 + 0.35 * w2)
end

-- Moving parts of rare decor (F89 2c) ------------------------------------------------------------------------------

-- A moving part's attribute `value` as a number, `default` when it is missing or not a number, held in `least` to
-- `most`.
function Logic.motionNumber(value: unknown, default: number, least: number, most: number): number
	if type(value) ~= "number" or value ~= value then
		return default
	end
	return math.clamp(value, least, most)
end

-- How far a `_Swing` part swings, in degrees, `t` seconds in: side to side up to `angle`, one swing there and back
-- every `seconds`, started `offset` (0 to 1) of the way round so two pieces never swing in step.
function Logic.swingAngle(t: number, seconds: number, angle: number, offset: number): number
	return angle * math.sin(2 * math.pi * (t / seconds + offset))
end

-- How far round a `_Spin` part has turned, in degrees from 0 to 360, `t` seconds in: one turn every `seconds`.
function Logic.spinAngle(t: number, seconds: number, offset: number): number
	return ((t / seconds + offset) % 1) * 360
end

-- How high a `_Bob` part rides, in studs, `t` seconds in: up and down by `rise`, once every `seconds`.
function Logic.bobRise(t: number, seconds: number, rise: number, offset: number): number
	return rise * math.sin(2 * math.pi * (t / seconds + offset))
end

-- The net swing, the catch's result word and rescues (F93, catch-rework.md) ---------------------------------------

-- The word a finished catch's `grades` earn (section 3): "purrfect" when every circle is Perfect, "excellent" when at
-- least half are, "great" when every circle is Good or better; nil with no circles or a Miss ("So close!", no burst).
function Logic.catchWord(grades: { Grade }): string?
	local count = #grades
	if count == 0 then
		return nil
	end
	local perfects = 0
	for _, grade in grades do
		if grade == "perfect" or grade == 1 then
			perfects += 1
		elseif grade == "miss" or grade == 0 then
			return nil
		end
	end
	if perfects == count then
		return "purrfect"
	elseif perfects * 2 >= count then
		return "excellent"
	end
	return "great"
end

-- Where a result word's sparkles start: `n` spots spread evenly across `width` pixels through `centre`.
function Logic.wordSpots(centre: Vector2, width: number, n: number): { Vector2 }
	local spots: { Vector2 } = {}
	for i = 1, n do
		spots[i] = centre + Vector2.new(width * ((i - 0.5) / n - 0.5), 0)
	end
	return spots
end

export type TrapShake = { least: number, most: number, seconds: number, hz: number, hop: number }

-- How a rescue trap shakes `t` seconds after the `hits`-th hit of `needed` (section 4: "a little more each time"): it
-- tips side to side, `o.hz` times a second, up to an angle in degrees that grows from `o.least` on the first hit to
-- `o.most` on the last and dies away over `o.seconds`, hopping up to `o.hop` studs at the biggest. Returns the tip
-- and the hop, both 0 outside the shake.
function Logic.trapShake(t: number, hits: number, needed: number, o: TrapShake): (number, number)
	if t < 0 or t >= o.seconds or o.seconds <= 0 or o.most <= 0 then
		return 0, 0
	end
	local share = if needed > 1 then math.clamp((hits - 1) / (needed - 1), 0, 1) else 1
	local size = o.least + (o.most - o.least) * share
	local fade = 1 - t / o.seconds
	fade *= fade
	local wave = math.sin(2 * math.pi * o.hz * t)
	return size * wave * fade, o.hop * (size / o.most) * math.abs(wave) * fade
end

-- Luck (F88, luck-and-rare-moments.md section 1) ------------------------------------------------------------------

-- Whether the Lucky Day look is on: the Clock's `LuckyDay` is true and its `Phase` is not night (it is for the day).
function Logic.luckyDayOn(luckyDay: unknown, phase: unknown): boolean
	return luckyDay == true and phase ~= "night"
end

-- Whether the gold sky tint is on (luck-and-rare-moments.md 1g, #1572): any of the day's kinds (the Clock's
-- `LuckyDay`, `GoldenDay` and `RainbowDay`) is true and its `Phase` is not night.
function Logic.specialDayOn(
	lucky: unknown,
	golden: unknown,
	rainbow: unknown,
	phase: unknown
): boolean
	return (lucky == true or golden == true or rainbow == true) and phase ~= "night"
end

-- A Lucky Cat statue's level from its model's name (`CatCafe_Plot_LuckyCat_3` is 3), or nil when the name ends in no
-- level from 0 to 5.
function Logic.luckyCatLevel(name: string): number?
	local digits = string.match(name, "_(%d+)$")
	local level = if digits ~= nil then tonumber(digits) else nil
	if level == nil or level < 0 or level > 5 then
		return nil
	end
	return level
end

-- Whether a plot's statue going from `before` (nil when this client had not seen it) to `after` is a level up to
-- sparkle: only a rise this client saw, to a statue (level 1 or more).
function Logic.luckyLevelUp(before: number?, after: number): boolean
	return before ~= nil and after > before and after >= 1
end

-- Cafe walks ------------------------------------------------------------------------------------------------------

-- Half a box's height in the world: how far above its centre the top of a part `size` big reaches, turned so its own
-- axes point along `right`, `up` and `look` (a CFrame's RightVector, UpVector and LookVector).
function Logic.halfHeight(size: Vector3, right: Vector3, up: Vector3, look: Vector3): number
	return 0.5 * (math.abs(right.Y) * size.X + math.abs(up.Y) * size.Y + math.abs(look.Y) * size.Z)
end

-- A walking body part way down into a sit (F90, cats-make-orders.md section 6: "get up and sit down at a station"),
-- `k` 0 standing to 1 down (Presets.cafeWalk.sit): the hindquarters drop with the back legs tucked under, the body
-- tips nose up with the front legs kept upright under it, the head stays near level and the tail lowers. With
-- `standing` it is the way up onto the back legs instead, for a cat that stands at its station on the work body
-- (Presets.cafeWalk.stand, #826): further nose up and lifted rather than dropped.
function Logic.crouch(o: Offsets, k: number, standing: boolean?)
	if k <= 0 then
		return
	end
	local c: { drop: number, tuck: number, pitch: number, tail: number } = if standing
		then Presets.cafeWalk.stand
		else Presets.cafeWalk.sit
	local pitch = math.rad(c.pitch) * k
	o.bodyY -= c.drop * k
	o.bodyPitch += pitch
	o.headPitch -= pitch * 0.7
	o.pawFL -= pitch
	o.pawFR -= pitch
	o.pawBL += math.rad(c.tuck) * k
	o.pawBR += math.rad(c.tuck) * k
	o.tailPitch -= math.rad(c.tail) * k
end

-- A cat with a tray on its head (F90 section 3, "a little tray balanced on its head"), `k` 0 to 1 of the way into
-- carrying it (Presets.cafeWalk.carry): chin up a touch, eyes front with no look about or head tilt, ears pricked and
-- tail held high. Logic.gait's `level` steadies the steps under it.
function Logic.trayCarry(o: Offsets, k: number)
	if k <= 0 then
		return
	end
	local c = Presets.cafeWalk.carry
	o.headPitch += math.rad(c.chin) * k
	o.headYaw *= 1 - k
	o.headRoll *= 1 - k
	o.earL *= 1 - k
	o.earR *= 1 - k
	o.tailPitch += math.rad(c.tail) * k
end

-- The tip sweep (F90 section 5: an idle Waiter or Greeter "sweeps it into a little coin bag"), `alpha` 0 to 1 of
-- Presets.cafeWalk.sweep.seconds: the cat rears up at the table, its left paw on the edge and its body tipped back
-- with the back legs kept under it, and drags its right paw back toward itself `swipes` times; then it drops back
-- onto all fours.
function Logic.sweepPose(o: Offsets, alpha: number)
	if alpha <= 0 or alpha >= 1 then
		return
	end
	local s = Presets.cafeWalk.sweep
	local up = Logic.envelope(alpha, 0, s.up, s.down, 1)
	local rear = math.rad(s.rear) * up
	o.bodyPitch += rear
	o.bodyY += s.lift * up
	o.headPitch -= rear * 0.8 -- looks across the table top, not at the ceiling
	o.pawBL -= rear
	o.pawBR -= rear
	o.pawFL += math.rad(s.reach) * up
	local k = math.clamp((alpha - s.up) / (s.down - s.up), 0, 1)
	local drag = 0.5 - 0.5 * math.cos(2 * math.pi * s.swipes * k) -- 0 reached out, 1 pulled in
	o.pawFR += (math.rad(s.reach) - math.rad(s.drag) * drag) * up
	o.tailPitch += math.rad(s.tail) * up
end

-- Where the tray with the coin bag is through the sweep, `alpha` 0 to 1: the share of the way from the pile on the
-- table to the top of the cat's head (0 until `scoop`, 1 from `land`, eased between) and how far above that straight
-- line it is, in studs, an arc `arc` high at the middle.
function Logic.sweepScoop(alpha: number): (number, number)
	local s = Presets.cafeWalk.sweep
	if alpha <= s.scoop then
		return 0, 0
	elseif alpha >= s.land then
		return 1, 0
	end
	local k = (alpha - s.scoop) / (s.land - s.scoop)
	return k * k * (3 - 2 * k), 4 * s.arc * k * (1 - k)
end

-- The drop at the till (F90 section 5, TipBanked), `alpha` 0 to 1 of Presets.cafeWalk.bank.seconds: a quick bob of
-- the head and shoulders toward the till as the bag tips off, and back up.
function Logic.bankNod(o: Offsets, alpha: number)
	if alpha <= 0 or alpha >= 1 then
		return
	end
	local b = Presets.cafeWalk.bank
	local dip = math.sin(math.pi * alpha)
	o.bodyPitch -= math.rad(b.lean) * dip
	o.headPitch -= math.rad(b.nod) * dip
	o.tailPitch += math.rad(b.tail) * dip
end

-- The Barista's working bob (F90 section 2: "two small hops and a head tilt, on a loop"), `t` seconds into its making
-- (Presets.motion.making): how high its body is lifted off the seat, in studs, and its head's tilt in radians (to its
-- right for plus; the side swaps each loop). Each loop is `hops` hops of `hopSeconds`, a `tiltGap` pause, the tilt
-- over `tiltSeconds` and a rest to `seconds`.
function Logic.makingBob(t: number): (number, number)
	local m = Presets.motion.making
	if t < 0 then
		return 0, 0
	end
	local loop = math.floor(t / m.seconds)
	local into = t - loop * m.seconds
	local lift = 0
	local hopsEnd = m.hops * m.hopSeconds
	if into < hopsEnd then
		local f = (into % m.hopSeconds) / m.hopSeconds
		lift = m.height * math.sin(math.pi * f)
	end
	local tilt = 0
	local from = hopsEnd + m.tiltGap
	if into >= from and into < from + m.tiltSeconds then
		local g = (into - from) / m.tiltSeconds
		tilt = math.rad(m.tilt) * math.sin(math.pi * g) * (if loop % 2 == 0 then 1 else -1)
	end
	return lift, tilt
end

-- The working bob on a seated cat's pose, `weight` 0 to 1 as it eases in and out (Making set or cleared), `t` seconds
-- into its making. The idle's paw tap and head dip give way to it (section 3: "no paw animation"); the front paws
-- only lift a touch at the top of each hop. `still` (Reduce Motion) keeps the head tilt and drops the hops.
function Logic.makingPose(o: Offsets, t: number, weight: number, still: boolean)
	if weight <= 0 then
		return
	end
	local m = Presets.motion.making
	local lift, tilt = Logic.makingBob(t)
	if still then
		lift = 0
	end
	o.pawFL *= 1 - weight
	o.headPitch *= 1 - weight
	local up = lift / m.height
	o.bodyY += lift * weight
	o.headRoll += tilt * weight
	o.pawFL += math.rad(m.paws) * up * weight
	o.pawFR += math.rad(m.paws) * up * weight
	o.tailPitch += math.rad(m.tail) * weight
end

-- Camp extras (F100, camp-extras.md section 3) --------------------------------------------------------------------

-- A keyed turn `t` seconds in, in degrees: `keys` lists { seconds, degrees } in time order; between two keys it eases
-- in and out from one to the next, and before the first or after the last it holds that key's value.
function Logic.keyed(keys: { { number } }, t: number): number
	local first = keys[1]
	if first == nil then
		return 0
	end
	if t <= first[1] then
		return first[2]
	end
	for i = 2, #keys do
		local b = keys[i]
		if t < b[1] then
			local a = keys[i - 1]
			local span = b[1] - a[1]
			return a[2] + (b[2] - a[2]) * Logic.easeInOut(if span > 0 then (t - a[1]) / span else 1)
		end
	end
	return keys[#keys][2]
end

-- How long a keyed turn lasts: its last key's time.
function Logic.keyedSeconds(keys: { { number } }): number
	local last = keys[#keys]
	return if last ~= nil then last[1] else 0
end

-- The Lost and Found lid's rattle `t` seconds in (Presets.campExtras.lid.rattle), radians about its back hinge's X:
-- `knocks` quick lifts of the front edge, each smaller than the last, and 0 outside the rattle. Never below 0, so the
-- lid never dips into the box.
function Logic.lidRattle(t: number): number
	local r = Presets.campExtras.lid.rattle
	local k = t / r.seconds
	if k <= 0 or k >= 1 then
		return 0
	end
	return math.rad(r.degrees) * math.abs(math.sin(math.pi * r.knocks * k)) * (1 - k)
end

-- Where spark `k` of `count` thrown from a bought store card ends (#1823, StoreMotion), in pixels from the card's
-- middle: evenly round a circle `reach` across, the first straight up, every other one a little shorter.
function Logic.sparkOut(k: number, count: number, reach: number): Vector2
	local angle = 2 * math.pi * (k - 1) / math.max(count, 1)
	local length = reach * (if k % 2 == 0 then 0.7 else 1)
	return Vector2.new(math.sin(angle) * length, -math.cos(angle) * length)
end

-- The Lost and Found booth's desk bell ringing `t` seconds in (#1732): its turn about its base in radians, side to side
-- `wobbles` times over `seconds`, dying away to rest; 0 before and after.
function Logic.bellWobble(t: number): number
	local r = Presets.campExtras.bell.ring
	local k = t / r.seconds
	if k <= 0 or k >= 1 then
		return 0
	end
	return math.rad(r.degrees) * math.sin(2 * math.pi * r.wobbles * k) * (1 - k)
end

-- Whether a part of the pond's rod hangs from its tip (the line and the bobber) instead of turning with it: it stands
-- upright in the rod's pivot space (`offset` is its frame there) and sits more than `beyond` studs out from the butt
-- across the ground. A hanging part follows the tip and stays upright.
function Logic.hangs(offset: CFrame, beyond: number): boolean
	local across = Vector2.new(offset.Position.X, offset.Position.Z).Magnitude
	return math.abs(offset.UpVector.Y) > 0.99 and across > beyond
end

-- How many prizes wait in a camp extra, from the server's CampExtrasState: `state[extraId]` as a count, or a table
-- whose `held` is the count. Anything else is 0.
function Logic.campHeld(state: unknown, extraId: string): number
	if type(state) ~= "table" then
		return 0
	end
	local entry = (state :: any)[extraId]
	local held = if type(entry) == "table" then entry.held else entry
	return if type(held) == "number" and held > 0 then held else 0
end

-- Camp extras' water (F100, camp-extras.md section 3) --------------------------------------------------------

-- A drip `t` seconds after it starts forming at a pipe's mouth: how grown it is (0 to 1, eased, full at `swell`
-- seconds) and how far it has fallen since (studs, from rest under `gravity` studs a second squared).
function Logic.dripAt(t: number, swell: number, gravity: number): (number, number)
	if t <= 0 then
		return 0, 0
	elseif t < swell then
		return smoothstep(t / swell), 0
	end
	local falling = t - swell
	return 1, 0.5 * gravity * falling * falling
end

-- Seconds a drip takes to fall `height` studs from rest under `gravity`.
function Logic.dripFall(height: number, gravity: number): number
	if height <= 0 or gravity <= 0 then
		return 0
	end
	return math.sqrt(2 * height / gravity)
end

-- A fish's jump `u` (0 to 1) of the way through, from where it rests `depth` studs under the water to `peak` studs
-- above it and back down `length` studs on: how far forward and up it is from where it started, and its pitch in
-- radians (nose up while it climbs, down as it dives), along the arc.
function Logic.fishArc(
	u: number,
	length: number,
	depth: number,
	peak: number
): (number, number, number)
	local k = math.clamp(u, 0, 1)
	local high = math.max(0, depth) + math.max(0, peak)
	local up = 4 * high * k * (1 - k)
	local pitch = math.atan2(4 * high * (1 - 2 * k), math.max(length, 1e-3))
	return length * k, up, pitch
end

-- Where in its jump (0 to 1) a fish resting `depth` studs under the water leaves it and comes back in.
function Logic.fishSurface(depth: number, peak: number): (number, number)
	local high = math.max(0, depth) + math.max(0, peak)
	if depth <= 0 or high <= 0 then
		return 0, 1
	end
	local out = (1 - math.sqrt(math.max(0, 1 - depth / high))) / 2
	return out, 1 - out
end

-- A fish swimming back under the water to where it rests, `u` (0 to 1) of the way: how far forward of its rest it
-- still is (from `length` down to 0), its turn in radians about its up (half way round over the first `turn` of the
-- swim, so it heads home, and the rest of the way over the last, so it rests as modelled) and its pitch, levelling
-- out from `dive` (the pitch it came into the water at) over that first turn.
function Logic.fishReturn(
	u: number,
	length: number,
	turn: number,
	dive: number
): (number, number, number)
	local k = math.clamp(u, 0, 1)
	local share = math.clamp(turn, 0.01, 0.5)
	local yaw: number
	if k < share then
		yaw = math.pi * smoothstep(k / share)
	elseif k > 1 - share then
		yaw = math.pi + math.pi * smoothstep((k - (1 - share)) / share)
	else
		yaw = math.pi
	end
	local along = smoothstep((k - share / 2) / (1 - share))
	return length * (1 - along), yaw, dive * (1 - smoothstep(k / share))
end

-- The Rally board's marquee (F101, Model-Agent's #759) ----------------------------------------------------------

-- Whether the `index`th bulb round a marquee (from 1) is lit at chase step `phase`: every `gap`th bulb, the lit ones
-- moving one bulb on each step.
function Logic.marqueeLit(index: number, phase: number, gap: number): boolean
	local g = math.max(1, math.floor(gap))
	return (index - 1 - math.floor(phase)) % g == 0
end

-- A marquee's flash `t` seconds in: whether every bulb is lit now (the first half of each of `flashes` flashes at
-- `hz`), or nil before it starts and once it is done.
function Logic.marqueeFlash(t: number, flashes: number, hz: number): boolean?
	if t < 0 or hz <= 0 then
		return nil
	end
	local cycles = t * hz
	if cycles >= flashes then
		return nil
	end
	return cycles % 1 < 0.5
end

-- Cats make the orders (F90, cats-make-orders.md section 4) ------------------------------------------------------

-- Whether an order in a cafe `distance` studs away plays its puff, glow and ding: within `within`, and your own cafe
-- always, another cafe's while fewer than `cap` of theirs play (`others`).
function Logic.orderPlays(
	own: boolean,
	distance: number,
	within: number,
	others: number,
	cap: number
): boolean
	if distance > within then
		return false
	end
	return own or others < cap
end

-- An oven window's glow, 0 to 1, `dt` seconds on from `level`: up to full over `rise` seconds while it bakes (`on`),
-- down to nothing over `fade` seconds once it stops.
function Logic.glowStep(level: number, on: boolean, dt: number, rise: number, fade: number): number
	if on then
		return if rise > 0 then math.min(1, level + dt / rise) else 1
	end
	return if fade > 0 then math.max(0, level - dt / fade) else 0
end

-- How bright a glow at `level` shows `t` seconds in: a soft flicker of `flicker` either way on two waves at `hz`,
-- never below 0.
function Logic.glowFlicker(level: number, t: number, flicker: number, hz: number): number
	local wave = math.sin(t * hz * 2 * math.pi) * 0.6 + math.sin(t * hz * 1.73 * 2 * math.pi) * 0.4
	return math.max(0, level * (1 + flicker * wave))
end

-- Whether a player's leaderboard crown was just earned (F98): their `Crown` going from false to true. `before` nil
-- is the first value seen (they joined, or this client started), which sets no burst.
function Logic.crownEarned(before: boolean?, now: boolean): boolean
	return before == false and now
end

-- A Player's `Crown` attribute as Crown.luau keeps it: the boolean, or nil while the server has not set it yet (it
-- sets it once the save loads, seconds after the player arrives), so a join is never read as off and then on.
function Logic.crownSeen(value: unknown): boolean?
	return if type(value) == "boolean" then value else nil
end

-- Which way a Texture's U runs on a part's `face`, in the part's own space: to the right of someone looking at that
-- face, so the Front's (-Z) is -X and the Back's (+Z) is +X (Effects/ShopCats, Royal Crest, #1366).
function Logic.faceU(face: Enum.NormalId): Vector3
	if face == Enum.NormalId.Front then
		return Vector3.new(-1, 0, 0)
	elseif face == Enum.NormalId.Right then
		return Vector3.new(0, 0, -1)
	elseif face == Enum.NormalId.Left then
		return Vector3.new(0, 0, 1)
	end
	return Vector3.new(1, 0, 0)
end

-- A shine sweeping once across a sign `width` studs wide (the Royal Crest, #1191), `t` seconds into a `sweep`-second
-- sweep: how far along the band's middle is, from a sign's width before its left edge (-width) to a sign's width
-- past it (+width), and how bright it is (0 to 1, brightest halfway). Outside the sweep: at rest and dark.
function Logic.shineSweep(t: number, sweep: number, width: number): (number, number)
	if t < 0 or t >= sweep or sweep <= 0 then
		return 0, 0
	end
	local share = t / sweep
	return -width + share * width * 2, math.sin(math.pi * share)
end

-- Which piece of a customer a part is (Presets.customerWalk, #1143), from its middle `x` and `y` and its `bottom`
-- and `top` heights over the feet, in the model's own frame: "legL"/"legR" below the hip, "armL"/"armR" out at the
-- side up to the shoulder, nil for the body. Left is -X (the models face -Z).
function Logic.customerPiece(x: number, bottom: number, top: number): string?
	local c = Presets.customerWalk
	local side = if x < 0 then "L" else "R"
	if top <= c.legTop and math.abs(x) > 0.05 and math.abs(x) < c.legHalfWidth then
		return "leg" .. side
	end
	if math.abs(x) >= c.armFrom and bottom >= c.armBottom - 0.05 and top <= c.armTop then
		return "arm" .. side
	end
	return nil
end

-- Where a customer's feet are and which way they face on the floor, from its model's pivot now (`at`, `look`) and the
-- `drop` its body was last laid out with (Effects/CustomerWalk, #1143). The pivot follows the body (the models'
-- PrimaryPart is the head), whose origin is the feet's dropped straight down (the roll turns about the feet's own
-- forward line, so it moves neither the origin nor the look), so this gives the same feet frame after frame, and
-- after a whole-model turn (Mover.face) too: it never sinks or tilts.
function Logic.customerFeet(at: Vector3, look: Vector3, drop: number): (Vector3, Vector3)
	local flat = Vector3.new(look.X, 0, look.Z)
	local facing = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
	return at - Vector3.new(0, drop, 0), facing
end

-- A customer's step at `phase` radians through its walk cycle (2 pi per Presets.customerWalk.stride studs) and
-- `weight` 0 to 1 of the way into walking: the left leg's swing about the hip (radians, the right leg's is minus
-- it), the left arm's about the shoulder (opposite the leg), the body's drop (studs, 0 or less: the hip lowers as
-- the legs leave the upright, so the feet stay on the floor) and its side to side roll (radians).
function Logic.customerStep(
	phase: number,
	weight: number,
	reduced: boolean?
): (number, number, number, number)
	local c = Presets.customerWalk
	local scale = math.clamp(weight, 0, 1) * (if reduced then c.reduced else 1)
	local s = math.sin(phase)
	local leg = math.rad(c.legSwing) * scale * s
	local arm = -math.rad(c.armSwing) * scale * s
	local drop = -c.hip * (1 - math.cos(leg))
	local roll = math.rad(c.roll) * scale * s
	return leg, arm, drop, roll
end

-- Door sign flip (#1140, door-sign.md section 3) ---------------------------------------------------------------

-- The door sign's turn `t` seconds into a flip: how far through the half turn it is (0 to 1, eased in and out over
-- `flip` seconds), plus the settle swing after it in radians (one back-and-forth of `swing` radians, fading out over
-- `settle` seconds; 0 before and after). Both are signed by the turn's direction by the caller.
function Logic.signFlip(t: number, flip: number, settle: number, swing: number): (number, number)
	if t <= 0 then
		return 0, 0
	elseif t < flip then
		return smoothstep(t / flip), 0
	end
	local after = t - flip
	if settle <= 0 or after >= settle then
		return 1, 0
	end
	local share = after / settle
	return 1, swing * math.sin(2 * math.pi * share) * (1 - share)
end

-- The context tips' camera cut (#976, easy-start.md section 3, Presets.contextCut): where the camera looks at a
-- place of `extent` studs across, centred on `target`, seen from the side the camera at `from` is on, raised by
-- `rise` of its distance. Straight above or on the target it looks from the south (+Z).
function Logic.cutEye(
	target: Vector3,
	extent: number,
	from: Vector3,
	p: { fit: number, near: number, far: number, rise: number }
): Vector3
	local flat = Vector3.new(from.X - target.X, 0, from.Z - target.Z)
	local dir = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, 1)
	local distance = math.clamp(extent * p.fit, p.near, p.far)
	return target + dir * distance + Vector3.new(0, distance * p.rise, 0)
end

-- How far over to the place the cut's camera is, 0 (the player's view) to 1, `t` seconds into a cut of `seconds`:
-- out over `swingIn`, held, and back over the last `swingOut`. With `reduced` (Reduce Motion) it jumps instead.
function Logic.cutWeight(
	t: number,
	seconds: number,
	p: { swingIn: number, swingOut: number },
	reduced: boolean?
): number
	if t <= 0 or t >= seconds then
		return 0
	end
	if reduced then
		return 1
	end
	local into = smoothstep(t / p.swingIn)
	local out = smoothstep((seconds - t) / p.swingOut)
	return math.min(into, out)
end

-- The carry by what rides on the tray (#1576, Presets.cafeWalk.carry.styles): `style`'s chin and tail on top of
-- Logic.trayCarry, `k` 0 to 1 of the way into carrying.
function Logic.trayStyle(o: Offsets, k: number, style: { chin: number, tail: number })
	if k <= 0 then
		return
	end
	o.headPitch += math.rad(style.chin) * k
	o.tailPitch += math.rad(style.tail) * k
end

-- How the tray rides this frame for `style`: its roll in radians, side to side once a stride, and its lift in studs
-- at each step, `stride` strides into the walk at `speed` studs/s (level while standing), `k` of the way into carrying.
function Logic.traySway(
	stride: number,
	speed: number,
	style: { sway: number, bob: number },
	k: number
): (number, number)
	local moving = math.clamp(speed / Presets.cafeWalk.carry.swayAt, 0, 1) * math.clamp(k, 0, 1)
	local wave = math.sin(2 * math.pi * stride)
	return math.rad(style.sway) * wave * moving, style.bob * math.abs(wave) * moving
end

return Logic
