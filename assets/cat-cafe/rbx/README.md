# Roblox models (Rojo syncs this folder into ReplicatedStorage.Assets)

`<Name>.model.json` files are Part-built versions of every asset, written by
`assets/cat-cafe/blender/build_all.py` (see `rbx_export.py` and style guide section 14). Do not edit them by hand;
change the generator and rebuild. AssetRegistry clones a model from here before it builds a code placeholder of the
same name, so a file here swaps the art in with no code change.

For a higher-detail MeshPart version, import the FBX from `../exports/` in Studio (3D Importer, Scale Unit Studs),
check it against style guide section 10, save it here as `<Name>.rbxm` and delete `<Name>.model.json`.

`CatCafe_Sky.model.json` is the one exception: a Sky (no parts) written by `assets/cat-cafe/blender/sky.py` from
images already uploaded to Roblox; WorldController puts it in Lighting.
