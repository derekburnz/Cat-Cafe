# Area sets: how the world places them

Built by `assets/cat-cafe/blender/{areakit,neighbourhood,woods,sewer}.py` from the approved drafts in
`/mnt/project-files/Model-Agent/area-drafts/`, sized for town layout v3.1 (town-layout-v3.md section 7).

| Set | Footprint (studs) | Tris | Parts | Area in v3.1 |
|---|---|---|---|---|
| `CatCafe_Neighbourhood_Set` | 139 x 139.5 | 43,892 | 2,182 | 140 x 140, centre (0, 196), gate z 125 |
| `CatCafe_Woods_Set` | 119 x 119 | 20,126 | 880 | 120 x 120, centre (-155, 0), gate x -94 |
| `CatCafe_Sewer_Set` | 93.2 x 93.3 | 36,400 | 1,249 | 90 x 90 walkable, centre (140, 0), gate x 94 |

## Placing a set

- One Model per area in `ReplicatedStorage.Assets`. Its pivot is the area centre on the floor's top (Layout
  `floorY`), and its gate side is local **-Z**. Place it with
  `set:PivotTo(CFrame.new(cx, floorY, cz) * CFrame.Angles(0, turn, 0))`, where `turn` makes -Z face the Town
  Square: 0 for the Neighbourhood, a half turn for the Park, a quarter turn each way for the Woods and the Sewer.
- The set brings its own ground dressing (roads, paths, stream, canal), houses, trees and borders. Drop the
  graybox paths and stand-in props for that area once the set is in.
- WorldBuilder keeps the area floor and walls. The wall facing the town should be invisible (Transparency 1, still
  colliding): each set puts a see-through border on that side (low hedge blocks with gaps for the Neighbourhood,
  low bushes for the Woods, a low brick wall with a railing for the Sewer). The other three walls can stay; the
  sets' hedges, thicket and brick walls stand just inside them and cover them.
- The Sewer's own brick walls are 16 high and wrap WorldBuilder's 1 stud walls at 44.5 to 45.5; its tiled floor
  slab is 0.4 thick, so its spots sit at y 0.4.
- Collision (PR #452): parts at least 0.35 thick collide, and so do thin ones down to 0.12 thick when at least
  0.9 long (planks, decks, rungs, rails). Round parts collide with a block 75% of their size. `_Decor`, `_Water`,
  `_Glow`, `_Bulb`, `_Tube` and `_Flowers` parts never collide. `_Bulb` and `_Pane` parts light at night through
  WorldController.
- Ladders have an invisible TrussPart (`..._Climb`) behind their rungs, so players climb them: the Great Oak's
  inside ladder, the tree house, the lookout tower and the Neighbourhood slide.

## Spots for cats

`manifest.json` lists each set's spots under `points_roblox` as `{label: [[x, y, z], ...]}` relative to the pivot,
in the set's own (unturned) space. Turn them with the set (the same CFrame as `PivotTo`). Each spot is a clear
floor or seat for one cat: none is inside a colliding part.

- Neighbourhood: porch 9, flowerbed 9, hub 3 (tyre, under the slide, sandpit), garden 2, shed 1, driveway 4,
  bins 1, van 1.
- Woods: oak_nook 3, nook_great_oak 3 (inside the Great Oak's top, y 18: the rare-biased nook), bridge 1, tent 2,
  mushroom_ring 1, treehouse 1 (on the cabin cushion, y 10.3), tower 1, fern 2, berry_bush 1, rock 2, stump 1,
  leaf_pile 1, log 1.
- Sewer: catwalk 1, throne 1, toy_pile 1, valve 1, cart 1, pipe_end 1, stall 3, house 4, sofa 1, deck 2, boat 1,
  raft 1, trolley 1, hammock 1.

Labels starting with `trap_` are rescue trap spots, where a stuck cat sits inside its prop:
Woods `trap_hollow_log` (-14, 0, 22), `trap_bramble_bush` (14, 0, 22) and `trap_treehouse_branch`
(-36.44, 15.45, 17.36: up the tree house's trunk); Sewer `trap_grate` (-31, 0.4, 2) and
`trap_drain_pipe` (-40, 0.4, -35). The Neighbourhood's shed (59.2, 0, 40) has a jammed door for the shed rescue.

## Checks

All three pass the build gate (budget 80,000, transforms, one material, swatch UVs, naming), the toolkit QA with 0
visible overlaps (`toolkit_qa.md`; the floating parts listed there stand on the world floor), and a part-overlap
check between pieces (0 pairs sinking more than 0.15 studs into each other) plus a spot check (0 spots inside a
colliding part).
