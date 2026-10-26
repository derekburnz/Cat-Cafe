"""Customer NPCs: blocky Roblox proportions, facing -Y, pivot at feet.
A adult (5 studs), B kid (4 studs), C elder (5 studs, grey hair, cane)."""

from mathutils import Matrix

from common import Builder

VARIANTS = {
    "A": dict(skin="skin_light", shirt="shirt_blue", pants="pants_navy", hair="hair_brown", scale=1.0),
    "B": dict(skin="skin_tan", shirt="shirt_red", pants="dark_wood", hair="choco", scale=0.8, cap=True),
    "C": dict(skin="skin_deep", shirt="shirt_green", pants="pants_navy", hair="fur_grey", scale=1.0, cane=True),
}


def build_customer(variant, mat):
    v = VARIANTS[variant]
    b = Builder()
    for x in (-0.5, 0.5):
        b.box_base((x, 0, 0), (0.98, 0.98, 2.0), v["pants"])
        b.box_base((x, 0, 0), (1.0, 1.02, 0.4), "fur_black")
    b.box_base((0, 0, 2.0), (2.0, 1.0, 2.0), v["shirt"])
    for x in (-1.5, 1.5):
        b.box_base((x, 0, 2.0), (0.98, 0.98, 1.0), v["skin"])
        b.box_base((x, 0, 3.0), (1.0, 1.0, 1.0), v["shirt"])
    b.box_base((0, 0, 4.0), (1.2, 1.2, 1.0), v["skin"])
    if v.get("cap"):
        b.box_base((0, 0, 4.85), (1.3, 1.3, 0.25), "mint")
        b.box((0, -0.85, 4.9), (1.3, 0.5, 0.08), "mint", bevel=False)            # cap peak
    else:
        b.box_base((0, 0, 4.75), (1.28, 1.28, 0.3), v["hair"])
        b.box((0, -0.62, 4.6), (1.28, 0.08, 0.3), v["hair"], bevel=False)
    for x in (-0.25, 0.25):
        b.box((x, -0.62, 4.45), (0.14, 0.06, 0.2), "fur_black", bevel=False)
    if v.get("cane"):
        b.box((0, -0.62, 4.0), (0.6, 0.06, 0.2), "fur_grey", bevel=False)         # moustache
        b.cyl_base((2.1, -0.3, 0), 0.08, 2.4, "dark_wood", segments=8)
        b.box((2.1, -0.3, 2.45), (0.5, 0.18, 0.18), "dark_wood")
    else:
        b.box((0, -0.62, 4.18), (0.4, 0.06, 0.08), "fur_black", bevel=False)
    ob = b.finalize(f"CatCafe_NPC_Customer_{variant}", mat)
    if v["scale"] != 1.0:
        ob.data.transform(Matrix.Scale(v["scale"], 4))
    return [ob]


ASSETS = {f"CatCafe_NPC_Customer_{k}": (lambda mat, k=k: build_customer(k, mat), 1000) for k in VARIANTS}
