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
## Second check, after #1985 and #1986 (main at 9b998570)

Same method. Cats: Tabby (Common), Calico (Rare), the Void; King Croissant left out (Derek 2026-11-07: too big as the
carry placeholder). Sheet: `evidence/2026-11-07/carry-pose-sheet-v2-2026-11-07.png`. Same numbers for all three cats.

| Check | R15 | R6 |
| --- | --- | --- |
| Arm parts overlapping the cat | none | none |
| Cat floor vs torso middle | 0.39 below (was 0.19) | 0.16 above (was 0.40) |
| Cat spans forward of torso | 0.50 to 1.67, middle 1.09 (was 1.34) | same |
| Hands (R6: arm ends) forward of torso | 0.95 to 1.01 | 1.19 |
| Cat surface straight above the hand centre | 0.32 (right), 0.59 (left) | 0.98 above the left arm end; nothing above the right |
| Cat touches the head | no; about 0.8 studs clear | no; about 0.5 studs clear |

Findings

1. R15 passes: the hands now sit under the cat's middle (0.95 to 1.01 forward against a middle of 1.09), with a small gap
   to its underside, and nothing clips.
2. The tucked head clears the face on both rigs and the cats read as asleep, curled in the crook of the arms.
3. R6 is better but not there: the arms rise on either side of the cat rather than under it, their tops a full stud
   above its floor, and only the left arm's end has the cat above it. Lowering the R6 arms (`arms6`) or raising the hold
   on R6 would put the arm ends under the cat.
