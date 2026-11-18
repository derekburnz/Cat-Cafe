--!strict
-- Gold cats from their base model (Model-Agent #4133, the first half of dropping the gold copies): each base cat's
-- parts say how its gold twin differs, and GoldTone.apply turns a clone of the base into the gold cat. Per BasePart:
--   GoldTone 1, 2 or 3   the light, mid or deep gold below, in GoldTone.MATERIAL with a little Reflectance
--   GoldColor (Color3)   that colour, material unchanged (eyes, nose and the like keep their look)
--   GoldSolid true       fully opaque, and casting a shadow when its longest side is at least 0.5 studs
-- A part with none of these is left as it is. Every gold cat is the toned base (#4656: the `goldTone` switch is
-- retired and the _Gold twin models are gone).
-- Shared by the server (AssetRegistry.cloneCat) and the client (portraits and walks).

local GoldTone = {}

GoldTone.TONES = table.freeze({
	-- #5199: mid and deep a step brighter than the Blender swatches (#F2C14E, #C98F2A, which goldtone.py matches the
	-- twins by) at the same or more saturation, so a gold cat reads gold in the cafe's warm light and stays orange gold
	-- in the sun (a paler lift went khaki outdoors, a darker deep went amber in the cafe). The light tone is the swatch.
	Color3.new(0.9843, 0.8941, 0.6039), -- 1 light #FBE49A
	Color3.new(1, 0.7593, 0.24), -- 2 mid #FFC23D
	Color3.new(0.93, 0.7022, 0.279), -- 3 deep #EDB347
})
GoldTone.SHADOW_SIZE = 0.5
-- #5199: Metal turned the gold amber in the cafe's dim warm light and khaki in bright sun (Sync, three rounds of
-- colour tuning), because Metal takes its look from the surroundings. SmoothPlastic shows the tone's own colour
-- everywhere, and a little Reflectance keeps a sheen.
GoldTone.MATERIAL = Enum.Material.SmoothPlastic
GoldTone.REFLECTANCE = 0.12

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
		part.Material = GoldTone.MATERIAL
		part.Reflectance = GoldTone.REFLECTANCE
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
