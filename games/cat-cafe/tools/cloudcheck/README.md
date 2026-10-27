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
node run-tests.mjs --shared   # every spec in one Luau state (the old way; see below)
node analyze.mjs --tests       # also check tests/ (specs, TestKit, the abuse client)
CLOUDCHECK_DUMP_DIR=/tmp/dump node analyze.mjs   # writes each module as the checker sees it, for debugging the rewrites
```

| File | What |
|---|---|
| `run-tests.mjs` | Builds a fake instance tree from `tests.project.json`, loads every ModuleScript with its own `script` and `require`, then calls `StudioRunner` exactly like Studio would, once per spec file in a fresh Luau state. Exit code 1 on any failure. |
| `analyze.mjs` | The Luau type checker (same engine luau-lsp wraps) in strict mode with lint, using the Roblox API definitions luau-lsp uses. Rewrites `require(script.Parent.X)` to module names first because there is no sourcemap here. Exit code 1 on type errors. |
| `rojo-tree.mjs` | Rojo project file to instance tree. Handles `$path`, `init.luau`, `.server`/`.client` suffixes, `.json` modules, optional paths and `globIgnorePaths`. |
| `roblox-shim.luau` | Instance proxies plus `game`, `workspace`, `task`, `warn`, `Enum`, `Color3`, `Vector3`, `UDim2`, `Random`... Enough for pure modules. `Instance.new`, events, DataStores and `RunService:IsServer()` are not there on purpose: a module that needs them is Studio-only and its spec says so. |
| `enum-keep.txt` | Enums kept in the type definitions (the full list is too big for the WebAssembly checker). Add a name here if you see `Unknown type 'Enum.X'`. |

Runtime: `@luau-rs/luau` (Luau 0.739 compiled to WebAssembly). The real gate is still `./check.sh` on a PC
with the Rokit toolchain: it has the sourcemap, the full enum list and selene. Treat a green run here as
"very likely fine" and a red run here as "definitely look".

## One Luau state per spec file

`run-tests.mjs` gives every spec file its own fresh Luau state, module cache and shim, and adds up the results.
On 2026-10-27 the suite in one shared state hit a fault in the WebAssembly Luau build: with 14 spec files and
the check 4 walk grid in `Layout.spec`, 24 `ProfileSchema.migrate` tests failed with "attempt to call a nil
value" at `ProfileSchema.luau:141`. Each of them passed when its spec ran alone, when any other spec file was
left out, or when a debug line was added to `ProfileSchema.luau`. Stopping the Luau garbage collector did not
help, and the cached `Catalog` module still held `getUpgrade`. It looks like a fault in the VM build that depends
on how much code is loaded, not a bug in the game. Real Roblox does not run this build. `--shared` brings back
the single state to reproduce it. If a spec fails here but passes with `--filter` and in Studio, suspect this
first and say so in the PR.

## Differences from luau-lsp you may notice
- `Enum.X` for enums not in `enum-keep.txt` type checks as `any`.
- `script.Parent.Foo` outside of `require()` is typed as `Instance` (luau-lsp knows the tree), so those lines
  are reported as info, not errors. Pass `--all-lints` to see them.
- `Instance.new("X")` and `game:GetService("X")` are cast to `X` by text rewrite before checking.
