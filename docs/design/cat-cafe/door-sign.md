# The front-door Open/Closed sign (#1140)

Decided by Coordinator for the friend, overnight 11-05, from Derek's 11-04 note that the night Closed sign "looks like it's hovering". Written up by Design-Agent. Owner: game-designer. Readers: Model-Agent, VFX-Agent, Gameplay-Engineer, QA. This replaces the night-only `CatCafe_Plot_ClosedSign` (F44).

## 1. Where it hangs

- **On the front door's glass**, centred left to right. It hangs from a small brass hook at the top of the glass panel on a short twine string, and its back touches the glass, so there's no gap at any angle.
- **Height:** the sign's middle is about 4.5 studs above the floor, at a standing character's eye line, so it reads from the street and the sidewalk.
- **It never covers the door prompt.** The prompt stays on the handle side, and the sign sits in the glass above the handle's height.
- **Every tier and size:** each cafe tier's door model (including the 44 x 34 cafes) carries an Attachment called `SignHook` at the hook's point. The sign is placed on that attachment, never at the plot pivot, which is what made the old sign float.

## 2. The look (Cozy Cream)

- **Board:** a rounded wooden board, about 2.2 x 1.1 studs and 0.1 thick, with a thin darker wood rim. It's two-sided.
- **OPEN side (day):** a cream face with "OPEN" in bold cocoa lettering (the HUD's rounded font, as a texture), and a little pink paw print after the word.
- **CLOSED side (night):** a dusky blue face with "CLOSED" in cream lettering and a small crescent moon. The moon is the `_Moon_Bulb`, which glows with the street's night parts as the old sign did.
- **String and hook:** natural twine in a shallow V to a brass hook. It's tiny, but it's what makes the sign read as hanging.
- **Budget:** one small model per owned cafe, about 200 triangles. Model-Agent passes the blender-asset-qa gate (no z-fighting on the glass: the board sits 0.02 studs in front of it).

## 3. The flip at dusk and dawn

- **When:** the client watches `Clock.Phase` (as #1327 does) and flips each cafe's sign when the phase changes. Day shows OPEN, and Night (and dusk, if the clock has one) shows CLOSED. Every client reads the same `Clock`, so every player sees the same side.
- **The flip (VFX-Agent):** the board turns 180 degrees around its hanging string over 0.6 s, eases out with one small back-and-forth swing (about 8 degrees, settling in 0.4 s), and the string stays put. The moon bulb fades in or out over the same 0.6 s.
- **Reduce Motion:** it swaps sides instantly, and the bulb switches without a fade.
- **Joining mid-phase:** the sign just shows the right side, with no flip.
- **Low performance mode:** the same flip, which is one tween on one part.

## 4. Contracts

- **Model-Agent:**
  - `CatCafe_Plot_OpenClosedSign`, with its pivot at the hook point, both faces, and the `_Moon_Bulb` on the CLOSED face;
  - a `SignHook` Attachment on the front door of every cafe tier model.
- **Gameplay-Engineer:**
  - `WorldBuilder` places the sign **once** on an owned plot's `SignHook` (in place of `setClosedSign`'s create-and-destroy), and removes it when the plot is freed;
  - `PlotService` stops calling `setClosedSign` on phase changes.
  - There's no new remote or attribute: the client reads `Clock.Phase`.
- **VFX-Agent:** the client flip in `Effects/` (a `DoorSign` effect that tags the signs and listens to `Clock.Phase`), with the Reduce Motion path.

## 5. QA checks

1. On every cafe tier, including the 44 x 34 cafes, the sign touches the door glass with no gap from the street, the side or close up, and doesn't cover the door prompt.
2. At dusk it flips to CLOSED with the moon glowing; at dawn it flips to OPEN. With Reduce Motion it swaps instantly.
3. A second player in the server sees the same side at the same time, and a player who joins at night sees CLOSED without a flip.
4. No sign shows on an unowned plot, and releasing a plot removes its sign.
