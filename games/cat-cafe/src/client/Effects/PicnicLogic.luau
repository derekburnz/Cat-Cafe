--!strict
-- The Picnic Party's pure timelines and words (#5572; Effects/PicnicParty draws them). Numbers in
-- Presets.picnicParty. Pure: no instances, no services.

local Presets = require(script.Parent.Presets)

local PicnicLogic = {}

export type Phase = "off" | "ready" | "party" | "waiting"

-- Which look the basket has: off (switch off), the party (Picnic Time running, `endsAt` past `now`), ready, or
-- waiting for the next one.
function PicnicLogic.phase(on: boolean, ready: boolean, endsAt: number?, now: number): Phase
	if not on then
		return "off"
	end
	if endsAt ~= nil and endsAt > now then
		return "party"
	end
	return if ready then "ready" else "waiting"
end

-- "12 m", "1 h 5 m", "30 s" for the seconds until the next picnic.
function PicnicLogic.wait(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	if s < 60 then
		return string.format("%d s", s)
	end
	local m = math.ceil(s / 60)
	if m < 60 then
		return string.format("%d m", m)
	end
	local h = m // 60
	local rest = m % 60
	return if rest == 0 then string.format("%d h", h) else string.format("%d h %d m", h, rest)
end

-- The sign's words: "PICNIC READY", or "Next picnic 12 m" (nil `nextAt`: just "Next picnic").
function PicnicLogic.sign(phase: Phase, nextAt: number?, now: number): string?
	local w = Presets.picnicParty.words
	if phase == "ready" then
		return w.ready
	elseif phase == "waiting" then
		if nextAt == nil then
			return (string.gsub(string.format(w.waiting, ""), "%s+$", ""))
		end
		if nextAt - now <= 0 then
			return nil -- Sync Nov 20: due but not yet ready read "Next picnic 0 s"; hide until the server says ready
		end
		return string.format(w.waiting, PicnicLogic.wait(nextAt - now))
	end
	return nil
end

-- The wobble's tilt in degrees `t` seconds into the ready look: `wiggles` swings that ease out over `seconds`,
-- once every `every` seconds, still between.
function PicnicLogic.wobble(
	t: number,
	every: number,
	seconds: number,
	degrees: number,
	wiggles: number
): number
	local k = t % every
	if k >= seconds then
		return 0
	end
	local u = k / seconds
	return degrees * math.sin(u * wiggles * 2 * math.pi) * (1 - u)
end

-- Where the pop is `t` seconds in: the lid 0 (shut) to 1 (open), the blanket 0 (rolled) to 1 (out), and each
-- treat's flight 0 (in the basket) to 1 (on the blanket), nil before it leaves. `still` (Reduce Motion): all at 1.
function PicnicLogic.pop(t: number, still: boolean): (number, number, { number? })
	local p = Presets.picnicParty.pop
	local count = #Presets.picnicParty.treats
	local treats: { number? } = {}
	if still then
		for i = 1, count do
			treats[i] = 1
		end
		return 1, 1, treats
	end
	local lid = math.clamp(t / p.lidSeconds, 0, 1)
	local roll = math.clamp((t - p.rollAt) / p.rollSeconds, 0, 1)
	for i = 1, count do
		local from = p.treatAt + (i - 1) * p.treatGap
		treats[i] = if t < from then nil else math.clamp((t - from) / p.treatSeconds, 0, 1)
	end
	return lid, roll, treats
end

-- The pop's length: the last treat landing, at least `seconds`.
function PicnicLogic.popLength(): number
	local p = Presets.picnicParty.pop
	local last = p.treatAt + (#Presets.picnicParty.treats - 1) * p.treatGap + p.treatSeconds
	return math.max(p.seconds, last)
end

-- The pack away `t` seconds in: the treats and cats fade 0 to 1 over the first half, the blanket rolls up 1 to 0
-- over the whole, the lid closes 1 to 0 over the last `lidSeconds`.
function PicnicLogic.pack(t: number): (number, number, number)
	local p = Presets.picnicParty.pack
	local fade = math.clamp(t / (p.seconds / 2), 0, 1)
	local blanket = 1 - math.clamp(t / p.seconds, 0, 1)
	local lid = 1 - math.clamp((t - (p.seconds - p.lidSeconds)) / p.lidSeconds, 0, 1)
	return fade, blanket, lid
end

-- A treat's bounce: height over its straight path for flight `k` 0 to 1 (an arc with one small hop at the end).
function PicnicLogic.arc(k: number, height: number): number
	if k < 0.8 then
		local u = k / 0.8
		return height * 4 * u * (1 - u)
	end
	local u = (k - 0.8) / 0.2
	return height * 0.15 * 4 * u * (1 - u)
end

-- Ease out (a quick start, a soft stop).
function PicnicLogic.easeOut(k: number): number
	local u = math.clamp(k, 0, 1)
	return 1 - (1 - u) * (1 - u)
end

return PicnicLogic
