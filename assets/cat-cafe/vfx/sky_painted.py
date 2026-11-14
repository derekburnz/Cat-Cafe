"""CatCafe_Sky, painted (#4291; Derek 2026-11-14: "the sky still needs to be changed off the boring cloudy view").

A deeper blue overhead falling to a warm cream horizon, with soft cartoon cumulus clouds painted in a band above the
horizon. The clouds are laid out on the sphere (azimuth and elevation) and none crosses from one cube face to the next,
so the box has no seam. Below the horizon it is the same haze as blender/sky.py, so the Dn face is that script's.

  python3 sky_painted.py            sky/CatCafe_Sky2_{Ft,Rt,Bk,Lf,Up}.png (1024 px)
  python3 sky_painted.py --preview  also sky/preview-before-after.png, a mock-up of the view from the street

Roblox draws the sun, moon and stars itself and dims the box at night. Upload each face once with the upload-image
workflow and put the ids in ../rbx/CatCafe_Sky.model.json.
"""

import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "sky")
SIZE = 1024
SEED = 20261114

# (elevation in degrees, colour). At and below the horizon these are blender/sky.py's stops.
STOPS = (
    (-90, "#D8CBB6"),
    (-8, "#E4D5BE"),
    (0, "#EFDDC1"),
    (3, "#F6E6CC"),
    (9, "#CFE8F5"),
    (22, "#8CCBF4"),
    (45, "#5FB0EE"),
    (90, "#3F97E6"),
)
OLD_STOPS = ((-90, "#D8CBB6"), (-8, "#E4D5BE"), (0, "#EFDDC1"), (4, "#ECE2D0"), (12, "#D3E3EA"), (32, "#AACFEA"),
             (90, "#88BDE6"))
CLOUD_TOP = np.array([255, 253, 247]) / 255      # sunlit cream white
CLOUD_SHADE = np.array([186, 208, 236]) / 255    # soft blue underside
CLOUD_FAR = np.array([246, 236, 222]) / 255      # the far ones take the horizon's warmth


def _rgb(h):
    return [int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)]


def gradient(elev, stops=STOPS):
    e = [s for s, _ in stops]
    c = np.array([_rgb(h) for _, h in stops])
    # smooth the joins: sample the piecewise ramp at three nearby elevations
    acc = 0
    for d, w in ((-2.5, 0.25), (0, 0.5), (2.5, 0.25)):
        acc = acc + w * np.stack([np.interp(elev + d, e, c[:, k]) for k in range(3)], axis=-1)
    return acc


def make_clouds():
    """Each cloud: (azimuth, base elevation, [(d_az, d_el, radius)...]) in degrees, flat along its base."""
    rng = np.random.default_rng(SEED)
    clouds = []

    def cloud(az, base, width, height):
        blobs = []
        n = max(4, int(width / (height * 0.55)))
        for i in range(n):
            x = (i / (n - 1) - 0.5) * width
            hump = 1 - (2 * x / width) ** 2                      # tall in the middle
            r = height * (0.38 + 0.42 * hump) * rng.uniform(0.85, 1.15)
            blobs.append((x, r * 0.55, r))
        for _ in range(n // 2):                                   # a few extra puffs on top
            x = rng.uniform(-0.3, 0.3) * width
            r = height * rng.uniform(0.3, 0.45)
            blobs.append((x, height * rng.uniform(0.55, 0.8), r))
        # no cloud crosses the line between two side faces (azimuth 45, 135, 225, 315) or reaches the Up face, so the
        # box has no seam however Roblox turns each face
        reach = max(abs(b[0]) + b[2] for b in blobs) + 1.5
        mid = round((az % 360) / 90) * 90
        az = mid + max(-(45 - reach), min(45 - reach, ((az - mid + 180) % 360 - 180)))
        clouds.append((az % 360, base, blobs))

    # big friendly ones, evenly round with a jitter so no gap and no pile
    for i in range(7):
        cloud(i * 360 / 7 + rng.uniform(-12, 12), rng.uniform(9, 17), rng.uniform(26, 38), rng.uniform(8, 11))
    # middle ones higher up
    for i in range(6):
        cloud(i * 60 + 25 + rng.uniform(-14, 14), rng.uniform(19, 25), rng.uniform(14, 20), rng.uniform(4.5, 6))
    # small far ones sitting near the horizon
    for i in range(11):
        cloud(i * 360 / 11 + rng.uniform(-10, 10), rng.uniform(3.5, 6.5), rng.uniform(9, 15), rng.uniform(2.2, 3.4))
    return clouds


CLOUDS = make_clouds()


def paint(az, el, sky):
    """Clouds over `sky` (h, w, 3 floats) for pixel directions az, el (degrees)."""
    out = sky.copy()
    for caz, base, blobs in sorted(CLOUDS, key=lambda c: c[1]):          # far (low) first
        daz = (az - caz + 180) % 360 - 180
        reach = max(abs(b[0]) + b[2] for b in blobs) + 1
        top = max(b[1] + b[2] for b in blobs)
        near = (np.abs(daz) < reach) & (el > base - 1) & (el < base + top + 1)
        if not near.any():
            continue
        x = daz[near] * np.cos(np.radians(el[near]))
        y = el[near] - base
        body = np.full(x.shape, -1.0)       # > 0 inside, in degrees from the edge
        for bx, by, r in blobs:
            body = np.maximum(body, r - np.hypot(x - bx, y - by))
        body = np.minimum(body, y + 0.15)   # the flat base
        edge = 0.12 + top * 0.012
        alpha = np.clip(body / edge, 0, 1)
        alpha = alpha * alpha * (3 - 2 * alpha)
        height = np.clip(y / top, 0, 1)
        lit = np.clip(0.25 + 0.95 * height + 0.25 * np.clip(body / (top * 0.35), 0, 1), 0, 1)
        col = CLOUD_SHADE + (CLOUD_TOP - CLOUD_SHADE) * lit[:, None]
        far = np.clip((9 - base) / 6, 0, 1) * 0.55                       # low ones melt into the horizon
        col = col + (CLOUD_FAR - col) * far
        alpha = alpha * (1 - 0.35 * far)
        out[near] = out[near] + (col - out[near]) * alpha[:, None]
    return out


def directions(face, size):
    c = (np.arange(size) + 0.5) / size * 2 - 1
    u, v = np.meshgrid(c, -c)
    one = np.ones_like(u)
    # Roblox: Ft looks along -Z, Bk +Z, Rt +X, Lf -X; image right is to the viewer's right
    x, y, z = {"Ft": (u, v, -one), "Bk": (-u, v, one), "Rt": (one, v, u), "Lf": (-one, v, -u),
               "Up": (u, one, v), "Dn": (u, -one, -v)}[face]
    az = np.degrees(np.arctan2(x, -z)) % 360
    el = np.degrees(np.arctan2(y, np.hypot(x, z)))
    return az, el


def face(name, size=SIZE):
    az, el = directions(name, size)
    return to8(paint(az, el, gradient(el)))


def to8(rgb):
    noise = (np.random.default_rng(7).random(rgb.shape[:2]) - 0.5)[..., None]    # breaks up banding
    return np.clip(np.floor(rgb * 255 + 0.5 + noise), 0, 255).astype(np.uint8)


def view(sky_fn, width=1280, height=720, fov=70, pitch=14, yaw=20):
    """What a player on the street sees: a pinhole camera looking a little up."""
    f = 0.5 * width / math.tan(math.radians(fov) / 2)
    px, py = np.meshgrid(np.arange(width) - width / 2 + 0.5, height / 2 - np.arange(height) - 0.5)
    d = np.stack([px, py, np.full_like(px, -f)], axis=-1)
    d /= np.linalg.norm(d, axis=-1, keepdims=True)
    p, yw = math.radians(pitch), math.radians(yaw)
    y = d[..., 1] * math.cos(p) - d[..., 2] * math.sin(p)
    z = d[..., 1] * math.sin(p) + d[..., 2] * math.cos(p)
    x = d[..., 0] * math.cos(yw) - z * math.sin(yw)
    z = d[..., 0] * math.sin(yw) + z * math.cos(yw)
    az = np.degrees(np.arctan2(x, -z)) % 360
    el = np.degrees(np.arctan2(y, np.hypot(x, z)))
    return sky_fn(az, el), el


def haze_clouds(az, el, cover):
    """A stand-in for Roblox's own cloud layer: soft white patches over about `cover` of the sky."""
    rng = np.random.default_rng(3)
    n = np.zeros_like(az)
    for k, amp in ((1, 1.0), (2, 0.5), (4, 0.25), (8, 0.12)):
        ph = rng.uniform(0, 6.28, 4)
        n += amp * np.sin(np.radians(az) * 2 * k + ph[0] + 2 * np.sin(np.radians(el) * 5 * k + ph[1])) \
            * np.sin(np.radians(el) * 7 * k + ph[2] + np.sin(np.radians(az) * 3 * k + ph[3]))
    n = (n - n.min()) / (n.max() - n.min())
    a = np.clip((n - (1 - cover)) / 0.18, 0, 1) * np.clip((el - 6) / 18, 0, 1)
    return a * a * (3 - 2 * a)


def street(img, el):
    """A plain street in front: grass, a row of cafe shapes and a lamp, so the sky has a place to sit over."""
    h, w, _ = img.shape
    im = Image.fromarray(img)
    d = ImageDraw.Draw(im)
    horizon = int(np.argmax(el[:, w // 2] < 0))
    d.rectangle([0, horizon, w, h], fill=(142, 201, 116))
    d.rectangle([0, horizon + int(h * 0.09), w, h], fill=(214, 196, 170))
    roofs = [(236, 142, 150), (140, 196, 214), (244, 196, 120), (176, 160, 220), (150, 206, 160)]
    for i, col in enumerate(roofs):
        x0 = int(w * (0.03 + i * 0.2))
        bw, bh = int(w * 0.15), int(h * 0.2)
        d.rectangle([x0, horizon - bh, x0 + bw, horizon + 6], fill=(250, 236, 212), outline=(92, 66, 48), width=3)
        d.polygon([(x0 - 12, horizon - bh), (x0 + bw + 12, horizon - bh), (x0 + bw // 2, horizon - bh - int(h * 0.11))],
                  fill=col, outline=(92, 66, 48))
        d.rectangle([x0 + bw // 2 - 16, horizon - 52, x0 + bw // 2 + 16, horizon + 6], fill=(146, 104, 76))
    return np.array(im)


def preview(path):
    def before(az, el):
        sky = gradient(el, OLD_STOPS)
        a = haze_clouds(az, el, 0.5)
        return sky + (np.array([1.0, 0.99, 0.97]) - sky) * (a * 0.9)[..., None]

    def after(az, el):
        sky = paint(az, el, gradient(el))
        a = haze_clouds(az + 40, el, 0.22)
        return sky + (np.array([1.0, 0.99, 0.97]) - sky) * (a * 0.55)[..., None]

    panels = []
    for fn in (before, after):
        rgb, el = view(fn)
        panels.append(street(to8(rgb), el))
    gap, bar = 24, 64
    h, w, _ = panels[0].shape
    sheet = Image.new("RGB", (w * 2 + gap * 3, h + bar + gap * 2), (46, 30, 20))
    d = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 34)
    except OSError:
        font = ImageFont.load_default()
    for i, (p, label) in enumerate(zip(panels, ("Before: pale sky, half covered in flat cloud",
                                                "After: deeper blue, painted puffy clouds"))):
        x = gap + i * (w + gap)
        sheet.paste(Image.fromarray(p), (x, bar + gap))
        d.text((x + 4, gap), label, fill=(255, 210, 74), font=font)
    sheet.save(path)
    return path


def main():
    os.makedirs(OUT, exist_ok=True)
    if "--preview" in sys.argv:
        print(preview(os.path.join(OUT, "preview-before-after.png")))
        if "--only" in sys.argv:
            return
    for name in ("Ft", "Rt", "Bk", "Lf", "Up"):
        p = os.path.join(OUT, f"CatCafe_Sky2_{name}.png")
        Image.fromarray(face(name)).save(p, optimize=True)
        print(p, os.path.getsize(p))


if __name__ == "__main__":
    main()
