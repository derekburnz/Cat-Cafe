"""The cafe at its bigger room sizes (#4543, Derek 2026-11-15: the cafe grows with rank ups).

Design-Agent's ladder (issue #4543): Tier 1 and 2 keep the 44 x 34 room, then 48 x 37 (Tier 3 and 4), 52 x 40 (5 and 6),
56 x 43 (7 and 8) and 60 x 46 (9 and 10). plot.py lays the shell, the interior, the For Rent dressing and the tier
dressing out from one room size (its IW, ID), and yardfence.py lays the yard's picket fence out from plot's lines, so
this module loads a second copy of both for each bigger size and offers their assets under the base name plus
"_<W>x<D>": CatCafe_Plot_Cafe_Mint_48x37, CatCafe_Plot_Interior_48x37, CatCafe_Plot_Tier3_48x37,
CatCafe_Plot_YardFence_48x37. The Store themes' fronts and the Grand chandelier (themes.py) follow the windows and the
beams, so they get the same copies: CatCafe_Plot_ThemeGarden_48x37, ThemeGrand_48x37, ThemeGrandChandelier_48x37. The game loads <base>_<W>x<D> from Config.CafeRoomByTier and falls back to the base.

Pivot: each sized model is centred on its own room's floor, front -Z, exactly as the base. The room keeps its front
wall when it grows (Design-Agent), so the game places a sized model (D - 34) / 2 studs behind the plot's pivot (+Z).
"""
import importlib.util
import os
import re
import sys

import common
import plot
import themes
import yardfence

BASE = (44, 34)
SIZES = ((48, 37), (52, 40), (56, 43), (60, 46))


def suffix(w, d):
    return f"_{w}x{d}"


def _load(module, name, env=None, swap=None):
    """A second copy of `module` under `name`, imported with CAFE_SIZE `env` and with sys.modules entries `swap`."""
    spec = importlib.util.spec_from_file_location(name, module.__file__)
    copy = importlib.util.module_from_spec(spec)
    old_env, old_mods = os.environ.get("CAFE_SIZE"), {k: sys.modules.get(k) for k in (swap or {})}
    try:
        if env is not None:
            os.environ["CAFE_SIZE"] = env
        sys.modules.update(swap or {})
        spec.loader.exec_module(copy)
    finally:
        if old_env is None:
            os.environ.pop("CAFE_SIZE", None)
        else:
            os.environ["CAFE_SIZE"] = old_env
        for k, v in old_mods.items():
            if v is None:
                sys.modules.pop(k, None)
            else:
                sys.modules[k] = v
    return copy


def _renamed(fn, base, name):
    """fn's objects, each renamed from <base><part> to <name><part> (Blender adds .001 when the base is in the scene)."""
    def build(mat):
        objs = fn(mat)
        for o in objs:
            part = re.sub(r"\.\d+$", "", o.name)
            assert part.startswith(base), (o.name, base)
            o.name = name + part[len(base):]
            if getattr(o, "data", None) is not None:      # the part list is kept by mesh name (common.PRIMS)
                prims = common.PRIMS.pop(o.data.name, None)
                o.data.name = o.name
                if prims is not None:
                    common.PRIMS[o.data.name] = prims
        return objs
    return build


PLOTS = {}        # (w, d) -> the plot module laid out for that room
BASE_OF = {}      # sized asset name -> its base asset name
ASSETS = {}
for _w, _d in SIZES:
    _sfx = suffix(_w, _d)
    _plot = _load(plot, f"plot{_sfx}", env=f"{_w},{_d}")
    _fence = _load(yardfence, f"yardfence{_sfx}", swap={"plot": _plot})
    _themes = _load(themes, f"themes{_sfx}", swap={"plot": _plot})
    PLOTS[(_w, _d)] = _plot
    for _m in (_plot, _fence, _themes):
        for _base, (_fn, _budget) in _m.ASSETS.items():
            if _m is _themes and "_Plot_" not in _base:      # the themes' props (garland, pot, cushion) have no room
                continue
            ASSETS[_base + _sfx] = (_renamed(_fn, _base, _base + _sfx), _budget)
            BASE_OF[_base + _sfx] = _base


def plot_of(name):
    """The plot module an asset was laid out by: the sized copy for a sized name, plot itself otherwise."""
    m = re.search(r"_(\d+)x(\d+)$", name)
    return PLOTS.get((int(m.group(1)), int(m.group(2))), plot) if m else plot


def set_back(name):
    """How far behind the plot's pivot (+Z, studs) a sized model stands so that the front wall stays where it is."""
    return (plot_of(name).ID - BASE[1]) / 2
