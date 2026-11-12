"""Pack the Mouse Dash pictures (arcade_icons.py, #3296) into one 1024 px sheet, so the game needs one upload:
exports/icons/CatCafe_Sheet_Arcade_MouseDash.png, a 4 x 4 grid of 256 px cells, and the cell of each picture in
CatCafe_Sheet_Arcade_MouseDash.json (ImageRectOffset x, y and ImageRectSize 256). The Backdrop stays its own picture.

Run after icons.py with the system Python (needs Pillow): python3 pack_arcade_sheet.py
"""

import json
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ICONS = os.path.join(HERE, "..", "exports", "icons")
CELL, COLS = 256, 4
ORDER = ["Mouse", "MouseHit", "GoldMouse", "GoldMouseHit", "Kitten", "KittenAwake", "Hole", "HoleFront",
         "Dust", "Paw", "PawBop", "Heart", "HeartEmpty", "Cheese", "MouseDash"]


def main():
    sheet = Image.new("RGBA", (CELL * COLS, CELL * COLS), (0, 0, 0, 0))
    cells = {}
    for i, name in enumerate(ORDER):
        pic = Image.open(os.path.join(ICONS, f"CatCafe_Icon_Arcade_{name}.png")).convert("RGBA")
        x, y = (i % COLS) * CELL, (i // COLS) * CELL
        sheet.paste(pic.resize((CELL, CELL), Image.LANCZOS), (x, y))
        cells[name] = {"x": x, "y": y, "size": CELL}
    sheet.save(os.path.join(ICONS, "CatCafe_Sheet_Arcade_MouseDash.png"), optimize=True)
    with open(os.path.join(ICONS, "CatCafe_Sheet_Arcade_MouseDash.json"), "w") as f:
        json.dump({"image": "CatCafe_Sheet_Arcade_MouseDash.png", "cell": CELL, "cells": cells}, f, indent=2)
        f.write("\n")
    print("sheet", len(cells), "pictures")


if __name__ == "__main__":
    main()
