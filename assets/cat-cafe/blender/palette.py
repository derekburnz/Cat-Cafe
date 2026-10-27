"""Cat Cafe palette: the single source of color truth for every mesh.

Mirrors docs/art/style-guide.md section 2. Index = row * 8 + col, rows counted
from the top of the PNG. Edit the style guide first, then this list. The texture is 8 swatches wide and 16 tall
(256 x 512 px); rows 0 to 7 are the original 64, rows 8 and up were added on 2026-10-27 for per-cat coats, and new
swatches only ever go at the end so every existing index keeps its place.
"""

import bpy

GRID = 8          # swatches per row
ROWS = 16         # rows in the texture (room for more coats); unused cells are black
SWATCH_PX = 32    # 256 x 512 texture
TEXTURE_NAME = "CatCafe_Palette"

# Gold cats (features.md F42, formerly "shiny"; Derek, 2026-10-27: gold, gold-modeled, and called gold): each
# cat's coat colours map onto these three golds (gold.py), dark coats onto the deepest so nothing turns brown,
# and the golds are metal (METAL_SWATCHES).
GOLD_TONES = ("#FBE49A", "#F2C14E", "#C98F2A")
GOLD_DEEP = "gold_dark"           # what a near-black coat colour becomes
# Swatches that are metal: Material Metal on the Roblox Part models, metallic in the palette material (a mask
# texture, CatCafe_Palette_Metal.png). Only the golds, so only gold cats shine.
METAL_SWATCHES = ("gold_light", "gold_mid", "gold_dark")

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
    # row 7: v0.3 and v0.4 additions, then the gold coat tones (v0.5, renamed from shiny)
    ("rarity_mythic", "#FF5E7E"), ("fur_blue", "#9AA9C2"), ("aurora_violet", "#8E7CF0"), ("pastel_butter", "#F6DFA0"),
    ("pastel_lilac", "#C9B8E8"), ("gold_light", GOLD_TONES[0]), ("gold_mid", GOLD_TONES[1]),
    ("gold_dark", GOLD_TONES[2]),
    # row 8: coats, so every cat has its own colors (2026-10-27)
    ("fur_ginger", "#D9662E"), ("fur_charcoal", "#4A4F58"), ("fur_silver", "#CDD2DA"), ("fur_latte", "#C79F7A"),
    ("fur_sand", "#DDB46A"), ("fur_rose", "#F2BFCB"), ("fur_peach", "#EDBBA1"), ("fur_lavender", "#B9A3DE"),
    # row 9: eyes and noses for the coats
    ("eye_copper", "#E0782F"), ("eye_chartreuse", "#B9D84A"), ("eye_violet", "#9C7CF2"), ("nose_dark", "#4A4450"),
    ("nose_brick", "#C4675B"), ("fur_seal", "#3E2A22"), ("fur_apricot", "#F2B88A"), ("fur_smoke_light", "#8A8F99"),
]
assert len(SWATCHES) % GRID == 0 and len(SWATCHES) <= GRID * ROWS

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


def lstar(name):
    """CIE L* (0 black to 100 white) of a swatch: how light it reads, for picking gold tones and line colours."""
    r, g, b = (srgb_to_linear(c) for c in hex_to_rgb(SWATCHES[idx(name)][1]))
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    return 116 * y ** (1 / 3) - 16 if y > 0.008856 else 903.3 * y


def uv_center(i):
    """UV of the center of swatch i. Row 0 is the TOP of the image."""
    col, row = i % GRID, i // GRID
    return ((col + 0.5) / GRID, 1.0 - (row + 0.5) / ROWS)


def _write_grid_png(path, name, value, colorspace):
    """A GRID x ROWS swatch texture where swatch i is value(i, hex) (an RGB tuple). Returns the bpy image."""
    w, h = GRID * SWATCH_PX, ROWS * SWATCH_PX
    img = bpy.data.images.get(name)
    if img is None:
        img = bpy.data.images.new(name, w, h, alpha=False)
    px = [0.0] * (w * h * 4)
    for o in range(3, len(px), 4):
        px[o] = 1.0
    for i, (sw, hx) in enumerate(SWATCHES):
        col, row = i % GRID, i // GRID
        r, g, b = value(sw, hx)
        y0 = (ROWS - 1 - row) * SWATCH_PX   # bpy pixel rows start at the bottom
        for y in range(y0, y0 + SWATCH_PX):
            base = (y * w + col * SWATCH_PX) * 4
            for x in range(SWATCH_PX):
                o = base + x * 4
                px[o], px[o + 1], px[o + 2] = r, g, b
    img.pixels.foreach_set(px)
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    # Reload from disk so exporters see a real file path (and the right color space).
    img = bpy.data.images.load(path, check_existing=False)
    img.name = name
    img.colorspace_settings.name = colorspace
    return img


def write_palette_png(path):
    """Generate the palette texture and save it as PNG. Returns the bpy image."""
    return _write_grid_png(path, TEXTURE_NAME, lambda sw, hx: hex_to_rgb(hx), "sRGB")


def write_metal_png(path):
    """White where a swatch is metal (METAL_SWATCHES), black elsewhere; a Non-Color mask for Metallic."""
    return _write_grid_png(path, TEXTURE_NAME + "_Metal", lambda sw, hx: (1.0,) * 3 if sw in METAL_SWATCHES else (0.0,) * 3,
                           "Non-Color")
