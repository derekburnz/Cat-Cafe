# src/server -> ServerScriptService.Server

Owner: luau-engineer. One system per ModuleScript, one bootstrap script.

```
Main.server.luau          builds assets and world, then starts Net, PlotService, CafeService, CatService, DataService
World/
  Placeholders.luau       Part models for every asset name (cats, customers, furniture, decor, alley, park, items)
  AssetRegistry.luau      ReplicatedStorage.Assets access: ensurePlaceholders(), clone(name)
  Layout.luau             pure numbers: plot placement, spots, anchors, tables, area spawn and lure points
  WorldBuilder.luau       builds workspace.World (ground, street, 8 plots, alley, park, gate, spawn)
Services/
  Net.luau                creates RemoteEvents, rate limits client calls, fire/toast helpers
  DataService.luau        ProfileStore sessions, migration, settle on leave, offline gain, PolicyService cache
  PlotService.luau        plot assignment and release
  CafeService.luau        income sync, placement, sell, upgrades, decor, lures inventory, offline claim
  CatService.luau         stray spawning, GrabBegin/GrabEnd, carry and check-in, lures at lure spots
Util/
  Guard.luau              remote argument validators
  RateLimiter.luau        token bucket per key
Vendor/
  ProfileStore.luau       MadStudioRoblox/ProfileStore (MIT), header changed to --!nonstrict only
```
