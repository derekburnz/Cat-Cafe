--!strict
-- Draws a glyph's picture from the uploaded icon sheet (Theme.iconSheet, assets/cat-cafe/ui/icons) over the
-- TextLabel that shows that glyph, so the menus get drawn icons in place of emoji (Derek 2026-10-27: "a lot of the
-- symbols like index upgrades and cats could use a tiny bit more quality also").
--
-- The emoji stays the fallback: it shows until the picture has loaded (a new upload draws blank until Roblox
-- moderation approves it), for glyphs the sheet has no picture of, and with no sheet id at all.
--
--   IconArt.set(label, glyph, scale?)        the label's glyph changed (or was just made); scale shrinks the picture
--   IconArt.setTransparency(label, value)    fade or grey the icon, picture or emoji, whichever shows
--
-- Roblox terms: ImageRectOffset and ImageRectSize cut one cell out of a bigger picture; IsLoaded turns true once
-- the picture has downloaded.

local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Parent.Theme)

local IconArt = {}

local ART = "IconArt"
local BASE = "IconTransparency" -- the transparency the caller asked for, whichever of the two shows

-- The sheet cell for a glyph, or nil when the sheet has no picture of it or is not uploaded.
function IconArt.cell(glyph: string?): Vector2?
	local sheet = Theme.iconSheet
	if glyph == nil or sheet.image == "" then
		return nil
	end
	return sheet.cells[glyph]
end

local function apply(label: TextLabel)
	local art = label:FindFirstChild(ART) :: ImageLabel?
	local value = label:GetAttribute(BASE)
	local transparency = if type(value) == "number" then value else 0
	if art and art.Visible and art.IsLoaded then
		label.TextTransparency = 1
		art.ImageTransparency = transparency
	else
		label.TextTransparency = transparency
		if art then
			art.ImageTransparency = 1
		end
	end
end

function IconArt.set(label: TextLabel, glyph: string?, scale: number?)
	if label:GetAttribute(BASE) == nil then
		label:SetAttribute(BASE, label.TextTransparency)
	end
	local cell = IconArt.cell(glyph)
	local art = label:FindFirstChild(ART) :: ImageLabel?
	if cell == nil then
		if art then
			art.Visible = false
		end
		apply(label)
		return
	end
	assert(cell, "cell")
	if art == nil then
		local made: ImageLabel = Create("ImageLabel", {
			Name = ART,
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Image = Theme.iconSheet.image,
			ImageRectSize = Vector2.new(Theme.iconSheet.cell, Theme.iconSheet.cell),
			ImageTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = label.ZIndex,
			Parent = label,
		})
		made:GetPropertyChangedSignal("IsLoaded"):Connect(function()
			apply(label)
		end)
		art = made
	end
	local picture = art :: ImageLabel
	local size = scale or 1
	picture.Size = UDim2.fromScale(size, size)
	picture.ImageRectOffset = cell * Theme.iconSheet.cell
	picture.Visible = true
	apply(label)
end

function IconArt.setTransparency(label: TextLabel, transparency: number)
	if label:GetAttribute(BASE) == transparency then
		return -- already shown; markers fade every frame, so skip the attribute write (reviewer N215)
	end
	label:SetAttribute(BASE, transparency)
	apply(label)
end

return IconArt
