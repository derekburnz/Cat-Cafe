# src/shared -> ReplicatedStorage.Shared

Owner: luau-engineer. Pure modules first (no Roblox services at load time) so QA's cloud runner can require them.

```
Config.luau         tuning constants (data-model section 17) and world layout numbers
Types.luau          shared types: catalog defs, CatInstance, PlayerProfile v1, PlayerState (ProfileSync payload)
Catalog.luau        rarities, cats, spots, upgrades, decor, lures, areas (data-model sections 2 to 9)
Economy.luau        income per second, cafe multiplier, lazy settle(), offline gain, purchase gates
Catching.luau       catch chance, ring result, rarity and cat picks from odds tables
ProfileSchema.luau  template(now) and migrate(raw, now)
Signal.luau         tiny typed signal (no Wally dependency)
Remotes.luau        the remote list; touches ReplicatedStorage only when folder()/event() are called
```
