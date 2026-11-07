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
