# Carry pose check, 2026-11-07 (Desktop-Tester)

Build: main at 451d98dc (#1978 cradle arms, #1980 sleeping hold). Scripts loaded into the real place (119569792798199) in Studio
through the Studio MCP, edit mode, nothing saved or published. Rigs are default R15 and R6 bodies made with
`Players:CreateHumanoidModelFromDescription`, posed with the game's own `Avatar.carryArms` and holding cats placed with the
game's own `HeldCat.attach` (Tabby as the Common cat, King Croissant, the Void). Sheet:
`evidence/2026-11-07/carry-pose-sheet-2026-11-07-main.png`.

Numbers are in studs, measured from the parts (the same for all three cats unless noted).

| Check | R15 | R6 |
| --- | --- | --- |
| Arm parts overlapping the cat (GetPartsInPart) | none | none |
| Cat floor vs torso middle | 0.19 below | 0.40 above |
| Hand (R6: arm) centre vs cat floor | 0.45 to 0.57 below | 0.24 below |
| Hand (R6: arm) top vs cat floor | 0.05 to 0.20 above | 0.75 above |
| Hands forward of torso | 0.9 to 1.1 | arm tips at 1.34 |
| Cat centre forward of torso | 1.34 (Tabby, Void), 1.58 (King) | same |

Findings

1. No clipping: no forearm or hand part intersects the cat on any rig.
2. Hands under the cat: on R15 the hands sit just under the cat's floor, but only under its near half; the cat's
   middle is about 0.3 to 0.6 studs further out than the hands, so the far half (most of King Croissant) has nothing
   under it. On R6 the arms end at the cat's near edge and their tops are 0.75 above its floor, so from the side the
   cat floats in front of the arm ends: hands under the cat fails on R6.
3. Sleeping sideways: Tabby and the Void read as a curled loaf lying across the arms, head to the character's left.
   The head block stays tilted up and sits against the character's chin and cheek (clearest on R6 and on King
   Croissant, whose crown and plate rise to face height), which reads more awake than asleep.

Suggested follow-ups for Animation-Engineer and Gameplay-Engineer: bring the cat 0.3 to 0.5 studs closer to the chest
(or reach the hands further out) so the hands are under its middle; on R6 lower the hold or the arm reach so the arm
ends pass under the floor; tuck the sleeping head down and in so it clears the face.

Limits: static edit-mode rigs with default blocky bodies; real avatars, the walk and the blend-in were not checked here.
## Third check, R6 only, after #1991 (main at a49f7107)

Tabby and the Void. Sheet: `evidence/2026-11-07/carry-r6-check-2026-11-07.png`. Same numbers for both cats.

| Check | R6 |
| --- | --- |
| Arm ends forward of torso | 0.98 (cat spans 0.50 to 1.67, middle 1.08) |
| Arm ends across | 0.18 either side of the middle (cat spans 1.04 either side) |
| Top of the arm-end faces vs cat floor | 0.05 above (level with it) |
| Highest point of each arm vs cat floor | 0.86 above |
| Cat surface straight above the arm ends | 0.96 (left), 0.65 (right) |
| Arm parts overlapping the cat | yes: left arm into the body, head and an eye; right arm into the body and both near legs |

Findings

1. The arm ends now meet under the cat's middle, and from the front the arms read as a cradle under it.
2. The arms clip the cat: each arm rises 0.86 studs past the cat's floor on its way in, so its upper part runs
   through the cat's body (and the head on the left, the legs on the right). Raising the R6 hold by about 0.3 to 0.4
   studs, or tilting the arms flatter, should keep the cradle and clear the clipping.

## Fourth check, R6 only, after #1994 (main at 75a811ca, R6 hold raised)

Tabby and the Void. Sheet: `evidence/2026-11-07/carry-r6-recheck-2026-11-07.png`. Same numbers for both cats.

| Check | R6 |
| --- | --- |
| Cat floor vs torso middle | 0.56 above (was 0.16) |
| Arm ends forward of torso | 0.98 (cat middle 1.08) |
| Arm ends across | 0.18 either side of the middle |
| Top of the arm-end faces vs cat floor | 0.35 below |
| Highest point of each arm vs cat floor | 0.46 above (beside the cat, not in it) |
| Arm parts overlapping the cat | none |
| Cat vs character head | the cat's head and left ear (the Void's prop too) overlap the R6 Head part's box |

Findings

1. Arms pass: the arm ends sit under the cat's middle, 0.35 studs below its underside, and no arm part touches the cat.
2. New issue from the raise: the cat's head now sits at face height. Its head and left ear overlap the character's
   Head part. The R6 Head part is a 2 by 1 by 1 box, wider than the visible head, so on screen this reads as the cat's
   head pressed against the side of the face rather than through it. A smaller raise (r6.up about 0.18 instead of 0.28) or moving the cat 0.2 to 0.3 studs further forward on R6 would clear it.

## Fifth check, R6 only, after #1996 (main at cc251d73, r6.up 0.18, r6.gap 0.1)

Tabby and the Void. Sheet: `evidence/2026-11-07/carry-r6-final-2026-11-07.png`. Same numbers for both cats unless noted.

| Check | R6 |
| --- | --- |
| Cat floor vs torso middle | 0.36 above |
| Cat spans forward of torso | 0.60 to 1.77, middle 1.18 |
| Arm ends forward of torso, across | 0.98, 0.18 either side of the middle |
| Top of the arm-end faces vs cat floor | 0.15 below |
| Highest point of each arm vs cat floor | 0.66 above |
| Arm parts overlapping the cat | left arm into the cat's head by about 0.04 studs; right arm into the body and near legs by about 0.10 |
| Cat vs the character's Head part | Tabby clear (0.02 gap); the Void's prop overlaps the Head box by 0.04 |

Findings

1. Arm ends: under the cat, 0.15 studs below its underside, 0.2 studs short of its middle (the cat moved 0.1 further out).
2. Face: clear. The Void's prop only touches the Head part's box, which is wider than the visible head; nothing shows on
   screen.
3. Arms: a shallow overlap of 0.04 to 0.10 studs is back, too small to see in the shots. A further 0.1 studs of r6.gap,
   or 0.05 to 0.1 more on r6.up, would clear it.
