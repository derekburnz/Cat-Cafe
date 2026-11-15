--!strict
-- Gold cats from their base model (Model-Agent #4133, the first half of dropping the gold copies): each base cat's
-- parts say how its gold twin differs, and GoldTone.apply turns a clone of the base into the gold cat. Per BasePart:
--   GoldTone 1, 2 or 3   the light, mid or deep gold below, in Metal
--   GoldColor (Color3)   that colour, material unchanged (eyes, nose and the like keep their look)
--   GoldSolid true       fully opaque, and casting a shadow when its longest side is at least 0.5 studs
-- A part with none of these is left as it is. Behind the `goldTone` switch (LiveFlags, off by default): on, every gold
-- cat is the toned base, even where a _Gold model is still in Assets, so QA can compare; off, the _Gold models as
-- before. Model-Agent drops the _Gold files only after the switch is on and QA has passed.
-- Shared by the server (AssetRegistry.cloneCat) and the client (portraits and walks).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GoldTone = {}

GoldTone.FLAG = "goldTone"
GoldTone.TONES = table.freeze({
	Color3.new(0.9843, 0.8941, 0.6039), -- 1 light
	Color3.new(0.949, 0.7569, 0.3059), -- 2 mid
	Color3.new(0.7882, 0.5608, 0.1647), -- 3 deep
})
GoldTone.SHADOW_SIZE = 0.5

local override: boolean? = nil

-- Specs: forces the switch (nil goes back to the live one).
function GoldTone.setOpen(open: boolean?)
	override = open
end

-- Whether gold cats are toned from the base (the switch, as LiveFlagService copies it to ReplicatedStorage).
function GoldTone.open(): boolean
	if override ~= nil then
		return override
	end
	return ReplicatedStorage:GetAttribute("LiveFlag_" .. GoldTone.FLAG) == true
end

-- The colour for a GoldTone attribute value, or nil when it is not 1, 2 or 3.
function GoldTone.toneColor(tone: unknown): Color3?
	if type(tone) ~= "number" then
		return nil
	end
	return GoldTone.TONES[tone]
end

local function tonePart(part: BasePart)
	local color = GoldTone.toneColor(part:GetAttribute("GoldTone"))
	if color ~= nil then
		part.Color = color
		part.Material = Enum.Material.Metal
	else
		local own = part:GetAttribute("GoldColor")
		if typeof(own) == "Color3" then
			part.Color = own
		end
	end
	if part:GetAttribute("GoldSolid") == true then
		part.Transparency = 0
		local size = part.Size
		if math.max(size.X, size.Y, size.Z) >= GoldTone.SHADOW_SIZE then
			part.CastShadow = true
		end
	end
end

-- Turns `model` (a clone of a base cat) into its gold twin, in place.
function GoldTone.apply(model: Instance)
	if model:IsA("BasePart") then
		tonePart(model :: BasePart)
	end
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			tonePart(item :: BasePart)
		end
	end
end

-- The names to look up for a gold cat's model, in order, and whether what is found must be toned: with the switch on
-- the base `baseName` only (toned), else `goldName` then `baseName` (as found).
function GoldTone.names(goldName: string, baseName: string): ({ string }, boolean)
	if GoldTone.open() then
		return { baseName }, true
	end
	return { goldName, baseName }, false
end

return GoldTone
