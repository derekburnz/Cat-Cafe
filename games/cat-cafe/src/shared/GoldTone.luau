--!strict
-- Gold cats from their base model (Model-Agent #4133, the first half of dropping the gold copies): each base cat's
-- parts say how its gold twin differs, and GoldTone.apply turns a clone of the base into the gold cat. Per BasePart:
--   GoldTone 1, 2 or 3   the light, mid or deep gold below, in Metal
--   GoldColor (Color3)   that colour, material unchanged (eyes, nose and the like keep their look)
--   GoldSolid true       fully opaque, and casting a shadow when its longest side is at least 0.5 studs
-- A part with none of these is left as it is. Every gold cat is the toned base (#4656: the `goldTone` switch is
-- retired and the _Gold twin models are gone).
-- Shared by the server (AssetRegistry.cloneCat) and the client (portraits and walks).

local GoldTone = {}

GoldTone.TONES = table.freeze({
	-- #5199: brighter than the Blender swatches (#FBE49A, #F2C14E, #C98F2A, which goldtone.py matches the twins by),
	-- so a gold cat in the cafe's warm indoor light still reads gold, not bronze
	Color3.new(0.9922, 0.9216, 0.6902), -- 1 light #FDEBB0
	Color3.new(0.9804, 0.8157, 0.3922), -- 2 mid #FAD064
	Color3.new(0.8784, 0.6627, 0.251), -- 3 deep #E0A940
})
GoldTone.SHADOW_SIZE = 0.5

local override: boolean? = nil

-- Specs: false looks up the _Gold models again, as before #4133 (nil goes back to the toned base).
function GoldTone.setOpen(open: boolean?)
	override = open
end

-- Whether gold cats are toned from the base: always, but for a spec's override.
function GoldTone.open(): boolean
	return override ~= false
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

-- The names to look up for a gold cat's model, in order, and whether what is found must be toned: the base `baseName`
-- only (toned), or with a spec's setOpen(false) `goldName` then `baseName` (as found).
function GoldTone.names(goldName: string, baseName: string): ({ string }, boolean)
	if GoldTone.open() then
		return { baseName }, true
	end
	return { goldName, baseName }, false
end

return GoldTone
