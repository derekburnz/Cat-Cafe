# src/client -> StarterPlayer.StarterPlayerScripts.Client

Owner: luau-engineer for Main, Net and Controllers; ui-designer for `UI/` (see docs/design/cat-cafe/ui-contract.md).

```
Main.client.luau                 waits for Shared and Remotes, starts the controllers
Net.luau                         fire(name, ...) and on(name, handler) over ReplicatedStorage.Remotes
Controllers/
  UIController.luau              UI.init with the catalog, ProfileSync -> UI.update, intents -> remotes,
                                 coin prediction between syncs, catch prompt wiring, carry marker, tutorial hints
  WorldController.luau           park gate collision by tier, auto CheckIn at the own door, tutorial step 1
  DoorController.luau            the cafe back doors: the leaf swings for players, the flap for cats, the night sign
  CustomerController.luau        cosmetic customers for the own cafe (one per free chair), coin float text
UI/                              ui-designer's module (init.luau is the public API)
```
