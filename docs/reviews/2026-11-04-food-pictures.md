# Review: food pictures are the clean 2D picture everywhere (#1242, PR #1261), 2026-11-04

Reviewer: luau-reviewer. Change: commits 02397a28, 22371994 and d3f318b4 on `ui/food-pictures-everywhere` (`git diff origin/main...HEAD`): `Components/ItemIcon.luau`, `Components/ShopIcons.luau`, `Components/IconArt.luau`, `Components/PrizeChips.luau`, `Screens/SpinWheel.luau`, `tests/specs/ShopIcons.spec.luau`, the contract, the icons README and a preview. d3f318b4 (IconArt's shared `loaded`/`waiting` tables, `ShopIcons.prize`) is reviewed in findings 6 to 9 and its own section below.
Not run: `check.sh` and StyLua/selene (no rokit toolchain in this container), the UI gate, the cloud specs. StyLua was checked by hand against `games/cat-cafe/stylua.toml` (tabs, column width **100**, not 120).

This is a client-only view change: no remotes, saves or server code. Checklist items 1 to 3 (client trust, rate limits, data safety) don't apply. On leaks, the removed `_artWatch` connection was tied to the ImageLabel and is not replaced by anything, so nothing is left connected.

## Findings

1. **should-fix**, `games/cat-cafe/src/client/UI/Components/ItemIcon.luau:208-211` (the `wanted` rule) against `docs/design/cat-cafe/ui-contract.md:524`. `ItemIcon.set` is shared by every picture tile, not only foods, so the change also drops the 3D model for every non-food caller that passes both a model and a picture:
   - crates: `Screens/YardSale.luau:199-204`, `Screens/FishMarket.luau:1085-1090` and `Screens/SpinWheel.luau:616-621`;
   - decor: `Screens/DecorShop.luau:630-635` and `Screens/DecorIndex.luau:468-473`;
   - prize chips: `Components/PrizeChips.luau:544`, crates through `partImage`;
   - Big Pull: `Screens/BigPull.luau:380`.

   That model fallback was added on purpose (the removed comment quoted Derek 2026-10-28: "make different visuals for the area crates and models"; every crate looked the same while its picture waited for moderation). Now any crate, decor or food picture that hasn't loaded yet (new upload pending moderation, slow fetch, or rejected) shows the shared emoji (📦 for every crate) and never the model. No tile goes blank: the glyph's text shows until IconArt sees `IsLoaded`. The contract mentions this only in the food card paragraph. Either keep the change (it also fixes the same "model left under the picture" fault for crates and decor) and say so in the contract's crate and decor sections, which reverses the 10-28 rule and needs Derek's OK; or limit it to foods by having `setFood` pass `nil` for `asset` when it has a picture and keeping the old cover logic in `set`. The first option is simpler and probably right, but the contract should say which.

2. **nit**, `games/cat-cafe/src/client/UI/Screens/SpinWheel.luau:615`. The comment "the clean crate symbol (#966: "too small"), the crate's model until it loads" no longer holds. With `ShopIcons.clean("Crate")` always set, the crate model is never drawn, so `crate.asset` on line 617 is dead. Change the comment to "the crate glyph until it loads", or pass `nil`.

3. **nit**, `games/cat-cafe/src/client/UI/Components/ShopIcons.luau:8-10` and `:13`. The header still says `crateModel` is "the 3D crate under its picture until the picture loads (ItemIcon)" and that `food("moon_milk")` gives `MoonMilk`. It now gives `Icon_Clean_MoonMilk`, and no model is drawn under a picture any more.

4. **nit**, `games/cat-cafe/src/client/UI/Components/ShopIcons.luau:45-51` and `:157-167`. The old 3D-render food uploads (`Kibble` ... `StarTreat`) and the seven food entries in `CLEAN_FOR` can now be reached only through `ShopIcons.image("<Food>")`. Since d3f318b4 nothing under `src` calls `ShopIcons.image` at all; only the spec does. They are harmless, but they leave a way back to the old renders. Drop them, or comment them as kept for history.

5. **nit**, `games/cat-cafe/tests/specs/ShopIcons.spec.luau:57-61`. The new loop checks that each Catalog food resolves to some `rbxassetid://<digits>`. It would still pass if `ShopIcons.food` went back to `preferClean` with its fallback to the old render, or to any other id, so it does not guard what #1242 cares about. Pin each food to its clean id instead, e.g. `expect(ShopIcons.food(lure.id)).to.equal(ShopIcons.clean(<Pascal of lure.id>))`. The spec can't reach the module's `pascal`, so either build the name in the spec with the same gsub, or keep a seven-row table.

6. **should-fix (verify in Studio)**, `games/cat-cafe/src/client/UI/Components/IconArt.luau:54` with `:112-116`. `apply` now treats a picture as drawn when `loaded[art.Image]` is set, even if this ImageLabel's own `IsLoaded` is false, and `loaded` is set from the `PreloadAsync` status alone. IconArt's header (lines 6-7) and ShopIcons' (line 21) say a new upload "draws blank until Roblox moderation approves it", and that is why the emoji stays under the picture. If `PreloadAsync` reports `Enum.AssetFetchStatus.Success` for an upload still in moderation (Roblox serves a blank placeholder for it), every label showing that id hides its emoji and draws nothing: a blank tile, the case the emoji fallback exists to prevent. I couldn't confirm what status Roblox reports for a pending image from here. `Icon_Clean_Kibble` (uploaded 11-04) or a fresh test upload would show it. If it does report Success, keep the per-label `IsLoaded` as the only "drawn" test and use the shared fetch only to redraw every waiting label (the second half of this change, which fixes the reported fault by itself).

7. **nit**, `IconArt.luau:100-107` with `:118-119`. If a fetch fails (or `PreloadAsync` throws), `loaded[id]` never turns true and `fetched[id]` stays true, so the id is never fetched again. Every later label showing it is still added to a new `waiting[id]` set that no fetch will ever drain. The keys are weak, so this is bounded by live labels and not a real leak, but the set is dead weight. Only add to `waiting` while a fetch is in flight, e.g. keep `waiting[id]` for the fetch's lifetime and skip the insert once `fetched[id]` is true and `waiting[id]` is nil. Such labels still update through their own `IsLoaded` connection (line 89-91), as before.

8. **nit**, `IconArt.luau:101-106`. The statement starting with `(labels :: ...)` is legal, because the previous token is `end`. But a line starting with `(` turns into a call of the line above if someone later adds a statement in front of it. Write it as `local labels = waiting[id] or newWaitingSet(id)` (or `labels = labels or ...`) and then `labels[label] = true`.

9. **nit**, `games/cat-cafe/tests/specs/ShopIcons.spec.luau:70`. `ShopIcons.prize("fish")` is pinned to a literal id with the comment "Theme.textures.fishCoin". The id is also `Icon_Clean_Fish` (ShopIcons.luau:83). Use `.to.equal(ShopIcons.clean("Fish"))` so the spec checks the lookup and not a copy of an id (Theme can't be required in the cloud runner). `Theme.textures.fishCoin` (Theme.luau:139) and `Icon_Clean_Fish` are now two copies of one id; a comment on either would keep them together.

## d3f318b4 (IconArt, ShopIcons.prize, PrizeChips)

- **PreloadAsync callback.** `ContentProvider:PreloadAsync(contentIdList, callback)` calls `callback(contentId: string, status: Enum.AssetFetchStatus)` once per id, so `function(_, status: Enum.AssetFetchStatus)` is the right signature and type. `Enum.AssetFetchStatus.Success` is a real member, and the comparison is correct. The call is still inside `pcall` inside `task.spawn`, so a throw can't break the caller. The redraw loop runs after the pcall, so it runs on success, failure and throw alike.
- **A label whose Image changes while it waits.** The label sits in both `waiting[A]` and `waiting[B]`. When A's fetch ends, `apply` reads the label's current `art.Image` (B) and `loaded[B]`, so it draws B's real state and never shows A's result for B. If the label went back to a glyph in the meantime (`art.Visible = false`), `apply` shows the emoji. Labels added for B after B was already loaded skip `waiting`, and `artFor`'s callers run `apply` at once. Correct.
- **Failed fetch.** Waiting labels are redrawn and keep their emoji. The id is never retried (as before), and later labels rely on their own `IsLoaded` (finding 7).
- **Leaks.** `waiting[id]` is cleared when its fetch ends, and its keys are weak. `each.Parent` skips destroyed labels. `loaded` and `fetched` grow by one entry per distinct id, which is bounded by the id table. No connections were added.
- **ShopIcons.prize / PrizeChips.partImage.** The ids are the same as before: coins `Icon_Clean_Bag` (the old `or ShopIcons.image("Coins")` could never be reached, since Bag is in IDS), spins `Icon_Clean_Spin` (what `image("Spin")` already returned through `CLEAN_FOR`), and fish `rbxassetid://111395416488950` (= `Theme.textures.fishCoin` = `Icon_Clean_Fish`). Other kinds still get nil. `Theme` is still used throughout PrizeChips, so there's no unused require. StyLua: every changed code line fits in 100 columns; only comments and the spec's code-plus-trailing-comment lines are longer, as on main.

## Asked-about checks

- **Every `ItemIcon` caller with `image` nil, empty or never loading.** In `set`:
  - `image == nil` keeps the old path, with the model or else the glyph.
  - `image == ""` is truthy in Luau, so `wanted` is nil. `IconArt.setImage` then treats `""` as no picture (`artFor`, IconArt.luau:66) and hides the art, leaving the emoji showing. No caller passes `""` today: every image comes from a `ShopIcons` lookup that returns an id or nil.
  - An image that never loads keeps the emoji at `TextTransparency` = base, with the art at `WAITING` 0.99.

  So no caller can end up with a blank tile. The only visible change is the emoji in place of a model while waiting (finding 1). Foods not in the catalog (`setFood(nil, id)` from PrizeChips and SpinWheel) get `ShopIcons.food(id)`, which is nil for an unknown id. With asset nil too, they show the glyph, as before.
- **Reused icons (set again with a different item).**
  - Model to picture: `wanted = nil ~= _asset`, so `_setModel(nil)` destroys the old model.
  - Picture to model: `wanted = B ~= nil`, so B loads.
  - Picture to no picture: `IconArt.set` calls `artFor(nil)`, which hides the art.

  `_glyph.Text` and `.Visible` are recomputed on every call. `_viewport.Visible` used to be toggled by `_coverModel`, but nothing sets it now, so it stays at its default `true` and can't be stuck hidden. Callers that set repeatedly (SpinWheel crate tiles, `_paint`, DecorShop slots, DecorIndex cells, LawnTab slots, BigPull) are all fine. The grade badge is still hidden by `set` and shown again by `setFood`.
- **Removed members.** `rg "_watchPicture|_coverModel|_artWatch|self\._image"` over `games/cat-cafe/src`, `tests` and `tools` finds nothing.
- **`ShopIcons.food` and its callers.**
  - All seven `Catalog.lures` ids resolve: kibble, tuna, salmon, sardines, caviar, moon_milk and star_treat map to `Icon_Clean_Kibble/Tuna/Salmon/Sardines/Caviar/MoonMilk/StarTreat` (ShopIcons.luau:78, 102-108).
  - The dealer's foods are the `source = "dealer"` rows of `Catalog.lures`, so they are covered.
  - Direct callers are `ItemIcon.setFood` and `FishMarket.luau:1243`, and neither needs the old fallback.
  - No caller asks for `ShopIcons.image("<Food>")`.
  - `Icon_Clean_Kibble` was uploaded 11-04 (run 41851955780). If its moderation is still pending live, kibble shows 🥣 until it passes, not a model. That's expected.
- **SpinWheel.** Removing `CleanGlyphs` is safe: it was used only on the removed lines. `Theme.luau:5`/`:410` still require it for `Theme.cleanGlyphs`, and the spec still covers it. Kibble on the wheel now shows `Icon_Clean_Kibble` in place of the clean `Bowl` symbol, which matches the bowl and the Market. Caviar is unchanged (`Icon_Clean_Caviar` both ways, pinned by the new spec line 53).
- **Style.** `--!strict` is kept and `git diff --check` is clean. Every changed code line fits in 100 columns. The over-100 lines are comments (StyLua doesn't wrap comments) or code with a trailing comment (spec lines 53 and 54, the same as main's lines 25 and 70, which already pass CI). Requires are still sorted. `ShopIcons` is still used in ItemIcon (`setFood`). The `wanted` local type-checks as `string?`.
- **API hygiene.** No new Roblox APIs.

## Verdict

**merge after should-fixes.** The code is correct: no blank tiles, no stale models or glyphs on reuse, and no dangling references. Finding 1 needs one contract line (or Derek's call) because the change also covers crates and decor. Finding 6 needs a Studio check that a picture still in moderation doesn't leave a blank tile now that a shared fetch counts as loaded. Findings 2 to 5 and 7 to 9 are comment, spec and tidy-up nits.

QA test plan: on live, open the Bait bowl (card and food rows), the Market's treats, the night dealer, a Tip Jar, Daily Treat and quest prize row and the Spin Wheel. Check that every food is its flat clean picture with no 3D model around its edges. Check a Tip Jar with several gifts: every money bag, fish and wheel is a picture, not an emoji. Then check that a crate in the Yard Sale, Market and Spin Wheel and a decor piece in the Decor Shop and Index still show their pictures, at 1280 x 720 and on a phone. With a freshly uploaded, not yet approved picture, its tile must keep the emoji and never go blank.
