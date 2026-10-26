---
name: asset-pipeline
description: How Purr Pot 3D assets go from Blender (via Blender MCP) to Roblox Studio: scale calibration, triangle budgets, naming, pivots, UV and texture rules, FBX export settings, Roblox Blender plugin upload, Studio import checks, saving .rbxm files for Rojo and replacing PH_ placeholders. Use for any model, prop or environment task.
---

# Asset pipeline (Blender -> Studio -> Rojo)

Roblox measures the world in **studs**. A default R15 avatar is about 5 studs tall, a door about 7 studs, a cafe table about 3. Roblox's **MeshPart** is a single mesh with one material or one texture; a model is a `Model` of MeshParts and Parts with a `PrimaryPart`.

## 1. Scale calibration (do once per Blender file)
1. In Studio insert a Part sized 4 x 4 x 4 studs.
2. In Blender make a cube and export it with the settings in section 5; import to Studio.
3. Adjust Blender's Scene > Units > Unit Scale (or the exporter's scale) until the imported cube matches the 4-stud Part. Write the working value at the top of `docs/art/style-guide.md` and reuse it for every asset. The Roblox Blender plugin applies its own scale setting; calibrate the same way through the plugin.

## 2. Budgets (per asset, triangles after export)
| Asset type | Triangles | Texture |
|---|---|---|
| Cat (hero, 6 to 10 breeds) | 1,500 to 3,000 | 512 px, one atlas per breed or vertex colours |
| Furniture (counter, table, chair, shelf) | 300 to 1,200 | 512 px or plain Roblox materials |
| Small prop (bowl, cup, plant, bin) | 50 to 400 | vertex colours or 256 px |
| Alley set piece (fence, lamp, crate stack) | 200 to 1,500 | 512 px |
| Whole visible scene | under 150,000 triangles, under 1,500 parts | |
Keep every single mesh under 10,000 triangles (well under Studio's import limit and kind to phones). Low-poly, chunky, readable at a distance: this is a game played on phones in a bright cafe.

## 3. Naming and structure
- Pattern: `Set_Category_NameVariant`: `Cafe_Furniture_CounterA`, `Cafe_Decor_PlantFern`, `Alley_Prop_BinBlue`, `Cat_Tabby_Base`, `Cat_Siamese_Base`, `Prop_FoodBowl`.
- Blender object name = Roblox MeshPart name. Group one asset per Collection named the same.
- Pivot (origin) at the base centre for furniture and props, at the floor between the paws for cats, so placing at a floor position needs no offset.
- Apply all transforms before export (Ctrl+A > All Transforms). Front faces -Y in Blender so it faces -Z in Roblox.
- Cats: one mesh for the body, separate `Eyes` and `Collar` meshes so breeds can share animation and swap colours. Use a Model with `PrimaryPart = Root` (an invisible 1 x 1 x 1 Part at the pivot).

## 4. UVs, materials, colours
- Prefer flat colours via Roblox `Color3` and `Material` on the MeshPart over textures where possible: zero texture memory and easy to recolour per breed.
- When texturing, one UV set, non-overlapping islands, 8 px padding, power-of-two sizes.
- No transparency on hero meshes (sorting issues); glass and liquids as separate Parts with `Transparency`.
- Vertex colours export via FBX and can be used in Roblox with `SurfaceAppearance` disabled; test early.

## 5. Export (FBX)
Blender File > Export > FBX: Selected Objects; Object Types: Mesh (and Armature if rigged); Scale per section 1; Apply Transform on; Forward -Z, Up Y; Mesh: Apply Modifiers, Triangulate on; no Leaf Bones. Save to `assets/cat-cafe/exports/<Name>.fbx`. Keep the `.blend` in `assets/cat-cafe/blender/`.

With the **Roblox Blender plugin** instead: log in once, select the objects, press Upload; it lands in the open Studio session's Workspace. Same naming and pivot rules apply.

## 6. Studio import checks
1. 3D Importer (Avatar > Import 3D or File > Import 3D): Scene unit per calibration, Insert using scene position off, Anchored on, uncheck "Rig" for static props.
2. Check `MeshPart.Size` against the budget sizes in the style guide (a cat 1.5 to 2 studs tall at the shoulder, counter 3 studs high).
3. `CollisionFidelity`: Box for small props, Hull for furniture, PreciseConvexDecomposition only for things players walk on or through. `RenderFidelity`: Automatic.
4. `Anchored = true` for everything static; `CanCollide = false` for decorations players should walk past (plants on shelves).
5. Materials: `Material = SmoothPlastic` with `Color3` from the style guide palette unless a texture is intended.
6. Creator Store assets: before use, search the inserted model for `Script`, `LocalScript` and `ModuleScript` (Studio MCP `search_game_tree`) and delete any; check for unexpected `Decal`s and `Sound`s. Prefer our own or Roblox-made assets.

## 7. Save for Rojo and hand off
- Right-click the finished Model in Studio > Save to File > `assets/cat-cafe/rbx/<Name>.rbxm`. Rojo syncs that folder into `ReplicatedStorage.Assets`, so the engineer can `Assets:FindFirstChild("Cat_Tabby_Base"):Clone()`.
- Replacing a placeholder: the engineer names temporary parts `PH_<Thing>`. Match the `PH_` part's size and pivot, keep the same name in a `Placeholder` attribute, then tell the engineer so spawn code switches to the asset name.
- Screenshots: 2 to 4 per asset or scene (`screen_capture`) to `docs/concepts/cat-cafe/<date>-<name>-<n>.png`, caption in `docs/concepts/cat-cafe/README.md`.

## 8. Handoff note format
Asset name, triangle count, path (.blend, .fbx, .rbxm), Studio size in studs, collision fidelity, which PH_ it replaces, screenshot paths, anything the style guide should record.
