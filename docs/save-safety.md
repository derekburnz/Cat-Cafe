# Save safety: migrations, DataStore outages and restoring one player

Owner: Gameplay-Engineer. Reviewed by: QA-Planner. Written for #2116 (Derek2's pre-release list, 2026-11-07).

A **save** (also called a profile) is one player's progress: coins, cats, decor, settings and so on. Roblox keeps it in a
**DataStore**, a key-value store hosted by Roblox. Our server code reads it when the player joins and writes it while
they play. The library that does the reading and writing is ProfileStore (`src/server/Vendor/ProfileStore.luau`), and
our wrapper around it is `src/server/Services/DataService.luau`.

| What | Value |
|---|---|
| DataStore name (live) | `CatCafeProfiles` (`Config.ProfileStoreName`) |
| DataStore name (Studio playtests) | `CatCafeProfiles_dev`, so Studio never touches live saves |
| Key for a player | `p_<UserId>`, for example `p_123456789` (`Config.ProfileKeyPrefix`) |
| What the key holds | ProfileStore's wrapper: `Data` (our save), `MetaData` (the session lock and counters), `GlobalUpdates`, `UserIds`, `RobloxMetaData` |
| Save format version | `Data.version`, currently `ProfileSchema.VERSION` (42 when this was written) |

## 1. Old saves still load (tested)

Every time the save format changes, `ProfileSchema.VERSION` goes up by one and `ProfileSchema.migrate` learns how to
read the older shape. Three sets of specs cover it, and all of them run in the check gate on every pull request:

- `tests/specs/SaveDrill.spec.luau` (#2116) takes one full save (cats, a gold cat, decor owned and placed, coins,
  golden fish, the Index, an achievement, the stats behind badges, a changed setting, store receipts and the
  Thank You board choice) and labels it with each version from 3 to the current one. Each copy must migrate with
  nothing lost. Migrating twice must change nothing more, and a partly damaged save keeps its good parts.
- `tests/specs/ProfileSchema.spec.luau` covers versions 1 and 2, where version 3 repriced upgrades and refunded the
  difference on purpose, along with each later version's own changes.
- **Newer save guard:** a server still running old code never loads a save written by newer code (it would drop what
  it doesn't know). It sends the player to a new server with "The game just updated, please rejoin."

## 2. When Roblox's DataStores are down

| When | What happens | What the player sees |
|---|---|---|
| Join, store down | ProfileStore keeps retrying the read for up to 120 s. A read error is never mistaken for "no save yet", so no fresh save is written over a real one. | The normal loading wait. After 120 s with no answer they are kicked with "Your save couldn't load just now. Nothing is lost. Please rejoin in a minute." |
| Join, another server still holds the save | The other server is asked to let go. The save is taken over after about 40 s, or sooner if that server crashed. | The loading wait, then they play normally. If it takes over 120 s they get the same kick message. |
| While playing | Autosave every `Config.AutosaveSeconds` (60 s). A failed save stays in memory and is retried on the next round. After 5 failures within 2 minutes the server log says "DataStores are failing: saves are queued and retried", and "DataStores are back" once they recover. | Nothing changes for the player. Progress since the last good save is held in memory. |
| Leave | The leave hooks run (a carried cat is checked in, for example), then the final save is written, with retries. | Nothing. |
| Server shutdown (an update or a restart) | `BindToClose` runs the same leave save for everyone. ProfileStore holds the shutdown until those saves finish, up to Roblox's 30 s limit. | Nothing. |
| A save that can't be read as a profile | ProfileStore replaces it with a fresh one and the server log says "a damaged save was replaced (CatCafeProfiles / p_…)". The old value is still in the key's version history. | A fresh start. Restore them with section 3. |

What the code can't protect against: a whole Roblox outage that lasts longer than a session. Anything earned after the
last good autosave is lost if the server also dies before the store comes back. That window is at most about 60
seconds of play in the normal case.

## 3. Restore one player from version history (runbook)

Roblox keeps every write to a DataStore key as a **revision** for 30 days. To undo a bad save, copy an older revision
back on top. Do this for one player at a time, and only with the player out of the game.

### Before you start

- You need the player's **UserId**, the number in their profile URL (`roblox.com/users/<UserId>/profile`). The
  key is `p_<UserId>`.
- You need an Open Cloud API key with `universe-datastores.objects:list`, `:read` and `:update` on the Cat Cafe
  experience. The existing `ROBLOX_PUBLISH_KEY` has these (docs/setup-guide.md step 24). Keep it in an environment
  variable, never in a file, a commit or chat.
- `curl` and `jq` (Git Bash on Windows works).
- Ask the player to **leave the game** and stay out until you're done. While they're in a server, that server holds
  the save and will write over anything you restore.

```bash
export ROBLOX_PUBLISH_KEY=...          # paste it in your own terminal only
UNIVERSE_ID=10773193456
STORE=CatCafeProfiles                  # never CatCafeProfiles_dev for a live player
KEY=p_123456789                        # p_<UserId>
base=https://apis.roblox.com/cloud/v2/universes/$UNIVERSE_ID/data-stores/$STORE/entries
```

### Step 1: list the revisions

```bash
curl -sS -H "x-api-key: $ROBLOX_PUBLISH_KEY" "$base/$KEY:listRevisions?maxPageSize=50" \
  | jq -r '.dataStoreEntries[] | "\(.revisionCreateTime)  \(.revisionId)"'
```

The newest is at the top. Pick the last revision **before** the problem (the player's report says roughly when).

### Step 2: download that revision and check it

```bash
REV=<revisionId from step 1>
curl -sS -H "x-api-key: $ROBLOX_PUBLISH_KEY" "$base/$KEY@$REV" > restore.json
jq '.value.Data | {version, coins, tier, cats: (.cats | length), lastSeen}' restore.json
```

Check that the coins, tier and number of cats look like what the player had. If they don't, try an older revision.
Keep `restore.json` on your own machine, and delete it when you're done, because it's the player's data.

### Step 3: clear the old session lock

A revision saved while the player was in a game still names that game's server in `MetaData.ActiveSession`.
Clear it, so the next join doesn't wait for a server that is long gone:

```bash
jq 'del(.value.MetaData.ActiveSession, .value.MetaData.ForceLoadSession)' restore.json > restore-clean.json
```

Delete the two fields, don't set them to `null`: Open Cloud refuses any `null` inside the value with
`400 "Value cannot be null"`.

Don't change anything else in the file: not `Data`, not `version`, not `GlobalUpdates`.

### Step 4: write it back as the newest revision

```bash
jq '{value: .value}' restore-clean.json \
  | curl -sS -X PATCH -H "x-api-key: $ROBLOX_PUBLISH_KEY" -H "Content-Type: application/json" \
      --data-binary @- "$base/$KEY" | jq '{revisionId, revisionCreateTime}'
```

Send only `value`: these entries have no `users` list, and a body with `"users": null` is refused with
`400 "Object reference not set"`. The write itself becomes a new revision, so a restore can also be undone with the
same steps. Two writes a few seconds apart merge into one revision, so wait a minute between a test write and the
real one.

### Step 5: check it in game

Ask the player to join. The save loads, `ProfileSchema.migrate` brings an older version up to date, and the welcome
back card shows their offline earnings from the restored `lastSeen`. Then delete `restore.json` and
`restore-clean.json`.

### Don't

- Don't restore while the player is in a server: their server overwrites it within a minute.
- Don't edit `Data` by hand to "fix" one value. Restore a whole revision, or ask Gameplay-Engineer for a migration.
- Don't touch any other live key, or other DataStores (`IdeaCredits_v1`, `BugReports_v1` and so on).
- Don't paste the API key, the UserId together with the save contents, or the JSON into chat or an issue. The repo is
  public.

Tested so far (Tools-Agent, 2026-11-07, on a throwaway key `p_0` in `CatCafeProfiles_dev`, deleted afterwards; the
live store untouched): the key can list, read, create, update and delete; the path needs no scope segment; step 1's
list returns `dataStoreEntries` with `revisionId` and `revisionCreateTime` (and no value), and step 2's `@<revisionId>`
fetch returns `value.Data` and `value.MetaData`. Not yet done: step 4's write with the `{value}` body is still being
confirmed. Until it is, don't use this on a real player.
