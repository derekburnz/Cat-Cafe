"""Cat Cafe palette: the single source of color truth for every mesh.

Mirrors docs/art/style-guide.md section 2. Index = row * 8 + col, rows counted
from the top of the PNG. Edit the style guide first, then this list.
"""

import bpy

GRID = 8          # 8 x 8 swatches
SWATCH_PX = 32    # 256 x 256 texture
TEXTURE_NAME = "CatCafe_Palette"

# (name, hex) in index order. Row comments match the style guide tables.
SWATCHES = [
    # row 0: cafe interior
    ("cream", "#F6EBDD"), ("caramel_wood", "#C98A4B"), ("dark_wood", "#5E4634"), ("mint", "#8FD3C1"),
    ("blush", "#E8A0A0"), ("offwhite", "#FFF9F2"), ("lamp_warm", "#FFD9A8"), ("floor_tile", "#E9D9C4"),
    # row 1: cat fur
    ("fur_orange", "#E9A24B"), ("fur_orange_dark", "#B8732B"), ("fur_black", "#2B2B35"), ("fur_white", "#F7F1E6"),
    ("fur_grey", "#8E96A3"), ("fur_cream", "#EFD9B4"), ("fur_brown", "#7A4F2E"), ("fur_golden", "#F2C14E"),
    # row 2: cat details and rarity
    ("eye_green", "#6FCF97"), ("eye_amber", "#F2B134"), ("eye_blue", "#5FA8FF"), ("nose_pink", "#E07A8C"),
    ("rarity_common", "#8E97B2"), ("rarity_rare", "#5FA8FF"), ("rarity_epic", "#C07CFF"), ("rarity_legend", "#FFC94D"),
    # row 3: alley
    ("brick", "#9C5F4F"), ("concrete", "#8B8F99"), ("concrete_dark", "#5B5F6B"), ("dumpster_green", "#3F6F5E"),
    ("metal", "#A9AFB8"), ("rust", "#7A4A2A"), ("cardboard", "#C9A273"), ("puddle", "#6E8FB3"),
    # row 4: customers
    ("skin_light", "#F3C9A2"), ("skin_tan", "#C98E6A"), ("skin_deep", "#7A4B32"), ("shirt_blue", "#3C7DD9"),
    ("shirt_red", "#D9483B"), ("shirt_green", "#4E9A3C"), ("pants_navy", "#2F3E5C"), ("hair_brown", "#5A3A22"),
    # row 5: items and food
    ("bowl_red", "#D94C3B"), ("kibble", "#B07B4F"), ("fish_blue", "#6EC1FF"), ("fish_belly", "#DDF2FF"),
    ("treat_tan", "#E3B77A"), ("choco", "#4A2E1F"), ("milk", "#FFFFFF"), ("leaf_green", "#5FB85A"),
    # row 6: extra plants and glass
    ("leaf_dark", "#3E7F4E"), ("terracotta", "#C47A58"), ("glass", "#CFE9E3"), ("sign_teal", "#1FA58F"),
    ("night_sky", "#1F2A44"), ("neon_pink", "#FF6B81"), ("sparkle", "#FFF4B0"), ("galaxy_blue", "#3B4C8C"),
    # row 7: v0.3 additions, then spare
    ("rarity_mythic", "#FF5E7E"), ("fur_blue", "#9AA9C2"), ("aurora_violet", "#8E7CF0"), ("spare_59", "#FF00FF"),
    ("spare_60", "#FF00FF"), ("spare_61", "#FF00FF"), ("spare_62", "#FF00FF"), ("spare_63", "#FF00FF"),
]
assert len(SWATCHES) == GRID * GRID

INDEX = {name: i for i, (name, _) in enumerate(SWATCHES)}


def idx(name):
    """Swatch index by name. Raises KeyError with a helpful message."""
    try:
        return INDEX[name]
    except KeyError:
        raise KeyError(f"unknown swatch {name!r}; add it to palette.py and the style guide") from None


def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def rgb_linear(name):
    """Linear RGB tuple for Blender material colors (Blender wants linear)."""
    return tuple(srgb_to_linear(c) for c in hex_to_rgb(SWATCHES[idx(name)][1]))


def uv_center(i):
    """UV of the center of swatch i. Row 0 is the TOP of the image."""
    col, row = i % GRID, i // GRID
    return ((col + 0.5) / GRID, 1.0 - (row + 0.5) / GRID)


def write_palette_png(path):
    """Generate the palette texture and save it as PNG. Returns the bpy image."""
    size = GRID * SWATCH_PX
    img = bpy.data.images.get(TEXTURE_NAME)
    if img is None:
        img = bpy.data.images.new(TEXTURE_NAME, size, size, alpha=False)
    px = [0.0] * (size * size * 4)
    for i, (_, h) in enumerate(SWATCHES):
        col, row = i % GRID, i // GRID
        r, g, b = hex_to_rgb(h)
        y0 = (GRID - 1 - row) * SWATCH_PX   # bpy pixel rows start at the bottom
        for y in range(y0, y0 + SWATCH_PX):
            base = (y * size + col * SWATCH_PX) * 4
            for x in range(SWATCH_PX):
                o = base + x * 4
                px[o], px[o + 1], px[o + 2], px[o + 3] = r, g, b, 1.0
    img.pixels.foreach_set(px)
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    # Reload from disk so exporters see a real file path (and sRGB color space).
    img = bpy.data.images.load(path, check_existing=False)
    img.name = TEXTURE_NAME
    img.colorspace_settings.name = "sRGB"
    return img
