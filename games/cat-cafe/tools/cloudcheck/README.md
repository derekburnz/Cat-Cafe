# tools/cloudcheck: run Purr Pot tests without Roblox Studio

Owner: qa-playtester. Node 20+ only, no Rokit tools needed. Works in the cloud (where GitHub release
downloads are blocked, so Lune, luau-lsp and friends cannot be installed) and on any PC.

```
cd games/cat-cafe/tools/cloudcheck
npm install --no-bin-links     # once; --no-bin-links only matters on network drives
npm test                       # tests/specs/*.spec.luau through tests/StudioRunner.luau
npm run test:verbose           # one line per test
npm run analyze                # strict type check + lint of src/, Roblox API types included
npm run check                  # both
node run-tests.mjs --filter Economy --json report.json
node analyze.mjs --tests       # also check tests/
```

| File | What |
|---|---|
| `run-tests.mjs` | Builds a fake instance tree from `tests.project.json`, loads every ModuleScript with its own `script` and `require`, then calls `StudioRunner` exactly like Studio would. Exit code 1 on any failure. |
| `analyze.mjs` | The Luau type checker (same engine luau-lsp wraps) in strict mode with lint, using the Roblox API definitions luau-lsp uses. Rewrites `require(script.Parent.X)` to module names first because there is no sourcemap here. Exit code 1 on type errors. |
| `rojo-tree.mjs` | Rojo project file to instance tree. Handles `$path`, `init.luau`, `.server`/`.client` suffixes, `.json` modules, optional paths and `globIgnorePaths`. |
| `roblox-shim.luau` | Instance proxies plus `game`, `workspace`, `task`, `warn`, `Enum`, `Color3`, `Vector3`, `UDim2`, `Random`... Enough for pure modules. `Instance.new`, events, DataStores and `RunService:IsServer()` are not there on purpose: a module that needs them is Studio-only and its spec says so. |
| `enum-keep.txt` | Enums kept in the type definitions (the full list is too big for the WebAssembly checker). Add a name here if you see `Unknown type 'Enum.X'`. |

Runtime: `@luau-rs/luau` (Luau 0.739 compiled to WebAssembly). The real gate is still `./check.sh` on a PC
with the Rokit toolchain: it has the sourcemap, the full enum list and selene. Treat a green run here as
"very likely fine" and a red run here as "definitely look".

## Differences from luau-lsp you may notice
- `Enum.X` for enums not in `enum-keep.txt` type checks as `any`.
- `script.Parent.Foo` outside of `require()` is typed as `Instance` (luau-lsp knows the tree), so those lines
  are reported as info, not errors. Pass `--all-lints` to see them.
- `Instance.new("X")` and `game:GetService("X")` are cast to `X` by text rewrite before checking.
