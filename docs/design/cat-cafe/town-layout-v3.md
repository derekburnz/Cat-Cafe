# Town layout v3: a wider street and a central Town Square (2026-10-27)

Derek, 2026-10-27 22:44: "the main town should be wider so that it can have a central middle area for like code cat and spin wheel and more cleaned up".

Feature F76. Owner: game-designer thread. Sketch: [town-layout-v3.svg](town-layout-v3.svg) (north is up). This replaces the street plaza in [areas-and-stations.md](areas-and-stations.md) B2, and it moves the areas around the town, so it goes in before the Neighbourhood kit placement. Studs, y 0 is the floor top, world X runs across the street (west is -X) and Z along it (south is -Z), as in layout v2.

## 1. What changes and why

As built (layout v2), Cafe Street is 24 studs wide and the Spin Wheel, the Golden Fish Market, the Codes Cat and the night dealer's cart are squeezed into its north end with the player spawn, the walk to the Alley Square arch and the Codes circle all in the same strip. v3 does three things:

- **A wider street.** StreetHalfWidth 12 becomes 16, so the road and sidewalks are 32 wide and the cafes sit 4 studs farther out on each side.
- **A Town Square in the middle.** The four rows of cafes split into two pairs of rows with a 96 x 64 square between them, at the middle of the street. Every station moves there, around a fountain, each in its own corner with room to stand.
- **A tidier street.** The street itself keeps only lamps, benches and the cafes' front gardens. The bunting, the big "Cat Cafe" sign and the stations all live in the square.

## 2. The town

| piece | v2 | v3 |
|---|---|---|
| Cafe Street | x -12 to 12, z -100 to 88 | x -16 to 16, z -124 to 124 |
| Town Square | none | x -48 to 48, z -32 to 32, in the safe zone |
| Square gardens | none | x 48 to 63 and -63 to -48, z -32 to 32: trees and flower beds, with a small arch in the middle of each side into the back alley |
| Cafe rows | 4 rows at z -66, -22, 22, 66 | inner rows at z -58 and 58, outer rows at z -102 and 102 |
| Cafe plots | centre x ±34, plot x 20 to 48 | centre x ±38, plot x 24 to 52, back wall 52 to 53, yard 53 to 63 |
| Back alleys (Alleyway) | x 59 to 89, z -101.5 to 88 | x 63 to 93, z -125.5 to 124 |
| Alley Square | x -89 to 89, z 88 to 152 | x -93 to 93, z 124 to 188 |
| Park | centre (0, -130), gate z -101 | centre (0, -154), gate z -125 |
| Woods | centre (-74, -134), gate z -101 | centre (-78, -158), gate z -125 |
| Sewer | centre (74, -134), gate z -101 | centre (78, -158), gate z -125 |
| Neighbourhood | centre (0, 222.5), gate z 151.5 | centre (0, 258.5), gate z 187.5 |
| Ground | 600 | 680 (the Neighbourhood's far wall is at z 328.5) |

The street ends meet the areas as before: the Park gate at the south end, the arch into the Alley Square at the north end, and the Woods and Sewer openings at the south ends of the back alleys. Areas keep their sizes; only their positions move.

**Plot order.** Plots 1 to 4 are the inner rows next to the square (1 and 2 south, 3 and 4 north, west then east), and 5 to 8 the outer rows. So a server with a few players has everyone by the square, and the beginner's cafe (plot 1) is a short walk from the stations.

## 3. The Town Square

The square is paved, with a wide cross of open paving through it: the street's line north to south (x -8 to 8) and a lane east to west (z -6 to 6) to the two side arches. Nothing stands on the cross, so the walk between the cafes, the arches and the gates is never blocked. The four stations stand in the four quarters, each turned to face the fountain.

| what | where (x, z) | faces | notes |
|---|---|---|---|
| Fountain with a cat statue | (0, 0) | | radius 6, the landmark; low rim players can sit on |
| Player spawn | (0, -14) | north | on the street line, looking at the fountain |
| Spin Wheel (F49) | (-28, 16) | the fountain | the spin is still a walk-up prompt within 14 studs |
| Golden Fish Market (F53) | (28, 16) | the fountain | counter toward the fountain |
| Codes Cat stand (F65) | (-28, -16) | the fountain | its CodesCircle 6 studs in front, toward the fountain, radius 4 |
| Night dealer's cart | (28, -16) | the fountain | parks here at dusk; the dealer stands at its town side |
| Side arches into the back alleys | (-63, 0) and (63, 0) | | 10 wide, red SAFE ZONE stripes on the square side as at the other edges |

Dressing for the asset thread: the fountain (`CatCafe_Square_Fountain`), eight benches in a ring 11 studs from the fountain with gaps on the cross, four lamp posts where the cross meets the ring, bunting strung lamp to lamp, a "Cat Cafe" sign arch over the street at each end of the square (z -32 and 32), the two side arches (`CatCafe_Square_ArchAlley`, or the alley kit's small arch), the garden beds and trees, and a paving pattern with a paw print in the middle. Each station keeps its own model.

The square is a safe zone like the street: no tackles, and it shows the Safe zone chip. The place marker the UI shows for the plaza ("Plaza", red dot while a free spin waits) now points at the square and reads "Town Square".

## 4. Walking times (NormalWalkSpeed 20)

| from | to | about |
|---|---|---|
| the farthest cafe door | the fountain | 110 studs, 5.5 s (v2: the plaza was 8 s from the farthest door) |
| an inner row cafe door | the fountain | 65 studs, 3.3 s |
| the spawn | the Park gate | 111 studs, 5.6 s |
| the spawn | the Alley Square arch | 138 studs, 6.9 s |
| any cafe | its own back alley | through the back door, as now |

The Alleyway is still behind every cafe, so the longer street costs nothing for catching. Fast travel lands where it did relative to each area.

## 5. Contract for the engineer

- **Config.World:** StreetHalfWidth 16, StreetSouthZ -124, StreetNorthZ 124, GroundSize 680, AlleyInnerX 63, AlleyOuterX 93, AlleySouthZ -125.5, SquareSouthZ 124, SquareNorthZ 188, ParkCenterZ -154, ParkGateZ -125, WoodsCenterX -78, WoodsCenterZ -158, WoodsGateZ -125, SewerCenterX 78, SewerCenterZ -158, SewerGateZ -125, NeighbourhoodCenterZ 258.5, NeighbourhoodGateZ 187.5. New: TownSquareHalfWidth 48, TownSquareHalfDepth 32, TownSquareLaneHalfWidth 8 (the street line) and 6 (the east to west lane), TownSquareArchWidth 10.
- **Layout.plotPlacement:** inner rows at z ±(TownSquareHalfDepth + PlotRowGap + PlotWidth / 2) = ±58 and outer rows 44 farther out, plot order as in section 2.
- **Layout stations:** `spinWheel`, `fishMarket`, `codesCat`, `dealerCart` and `playerSpawn` as in section 3, each turned to face (0, 0). The manhole stays in the middle of the Alley Square, now at z 160.
- **Alley dressing and anything else written as an absolute number** in Layout or WorldBuilder that belongs to the back alleys moves out by 4 on X; anything south of the street's end moves by -24 on Z and anything north of it by +36. Index Boards, gate fences, travel arrivals and the area gates already follow their area or gate.
- **The safe zone** covers the square and its gardens. The side arches are new edges of the Alleyway, painted like the others.
- **The F72 intro** shots 4 to 9 use absolute positions; [intro-cutscene.md](intro-cutscene.md) section 2b has the v3 numbers.
- **Saves:** nothing in a profile stores a world position, so no save change. Players on a server that updates are simply in the new town after a rejoin.

## 6. QA checks

1. From the spawn, every station is in view and none of them blocks the walk to either arch or the Park gate.
2. Each station's prompt or circle works from its own quarter, and standing in the Codes circle does not cover the Spin Wheel's prompt.
3. The farthest cafe door to the fountain takes under 6 seconds on foot.
4. Tackling is off everywhere in the square, and on in the back alley one step past a side arch.
5. Strays never walk into the square (the side arches keep them in the Alleyway as the street arch does).
