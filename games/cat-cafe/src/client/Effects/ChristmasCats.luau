--!strict
-- The Christmas cats' signature beats (snowglobe-village-spec section 4; Model-Agent's #5294 models), drawn on top of
-- every cat's own motion by Cats.luau (ChristmasCats.layer on each moving cat whose CatId is one of these):
--   jingle       the gold bell on its collar (the `_Bell` piece Pose turns as "bell") gives a little jiggle every
--                `every` seconds while it is awake (Logic.jingleBell)
--   star_topper  the floating star (`_Star_Glow`) and the tree lights on its back (`_Bulbs_Glow`) glow: dim by day,
--                full and twinkling at night (Logic.christmasGlow)
--   sugar_plum   the tiara gem (`_Gem_Glow`) and wing edges (`_Wings_Glow`) twinkle the same way
-- Numbers in Presets.christmasCats. Client only: no remotes; the glow parts only get LocalTransparencyModifier, so the
-- server's parts are never changed. Reduce Motion keeps the glow steady and the bell still.

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Presets = require(script.Parent.Presets)

local ChristmasCats = {}

type State = {
	lastAt: number,
	ringAt: number?,
	nextRing: number,
	glows: { BasePart },
	phase: number,
}

local states: { [Model]: State } = setmetatable({}, { __mode = "k" }) :: any
local rng = Random.new()

-- Whether `model` is one of the cats with a beat here.
function ChristmasCats.is(model: Model): boolean
	local id = model:GetAttribute("CatId")
	return type(id) == "string" and Presets.christmasCats.cats[id] ~= nil
end

local function glowsOf(model: Model, suffixes: { string }): { BasePart }
	local out: { BasePart } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			for _, suffix in suffixes do
				if string.sub(descendant.Name, -#suffix) == suffix then
					table.insert(out, descendant :: BasePart)
					break
				end
			end
		end
	end
	return out
end

local function stateOf(model: Model, now: number): State
	local state = states[model]
	if state == nil then
		local id = model:GetAttribute("CatId") :: string
		local look = Presets.christmasCats.cats[id]
		local c = Presets.christmasCats
		local fresh: State = {
			lastAt = now,
			ringAt = nil,
			nextRing = now + rng:NextNumber(c.jingle.firstMin, c.jingle.every[2]),
			glows = if look ~= nil then glowsOf(model, look.glows) else {},
			phase = rng:NextNumber(0, 2 * math.pi),
		}
		states[model] = fresh
		return fresh
	end
	return state
end

-- One frame of model's beat into `o` (the offsets Pose draws next) and its glow parts.
function ChristmasCats.layer(model: Model, o: Logic.Offsets, style: Logic.Style, now: number)
	local c = Presets.christmasCats
	local id = model:GetAttribute("CatId")
	if type(id) ~= "string" then
		return
	end
	local look = c.cats[id]
	if look == nil then
		return
	end
	local state = stateOf(model, now)
	state.lastAt = now
	local reduced = Context.reducedMotion()
	if look.bell and not reduced then
		if state.ringAt == nil and now >= state.nextRing and not Logic.asleep(style) then
			state.ringAt = now
			state.nextRing = now + rng:NextNumber(c.jingle.every[1], c.jingle.every[2])
		end
		local at = state.ringAt
		if at ~= nil then
			local alpha = (now - at) / c.jingle.seconds
			if alpha >= 1 then
				state.ringAt = nil
			else
				Logic.jingleBell(o, alpha)
			end
		end
	end
	if #state.glows > 0 then
		local modifier = Logic.christmasGlow(now, Context.isNight(), state.phase, reduced)
		for _, part in state.glows do
			if part.Parent ~= nil then
				part.LocalTransparencyModifier = modifier
			end
		end
	end
end

return ChristmasCats
