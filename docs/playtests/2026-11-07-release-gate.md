# Release gate: soft launch, device matrix, load check (#1935)

Author: QA-Planner, 2026-11-07. Release is planned for about 2026-11-10 to 2026-11-12 (Derek2, 2026-11-07). Derek decides the date and the final go or no-go. Nothing here changes game code or Config.

## 0. Schedule (Design-Agent, release.md section 2, PR #1939)
Freeze Mon 2026-11-09 18:00 UTC. Private check on 11-08 and 11-09 across the device matrix. Soft launch Tue 11-10. Go wide Thu 11-12 if the gate passes, otherwise Sat 11-14. The run report goes in `docs/playtests/2026-11-10-release-gate.md`.
Design-Agent's performance marks (Tools-Agent captures them): phone load to first move 20 s or less, client memory under 1.2 GB, server 55 Hz or more with 8 players. Also from Design: median first session 10 minutes or more with 25% reaching 30 minutes, no error signature in more than 1% of sessions, owner tests on every pass passing.

## 1. Stages
| Stage | Who sees it | How long | Moves on when |
|---|---|---|---|
| 0. Build gate | nobody | until green | `./check.sh` passes, CI green on main, a fresh-account run on the live build with no new console errors (checklist in `docs/playtests/`), device matrix (section 2) has no open blocker |
| 1. Soft launch | friends, group members, a small ad test | 48 hours, or until 100 new players, whichever is later | the numbers in section 3 are read and meet the "go" column |
| 2. Wide | public, ads on | after Derek's go | weekly ritual in `docs/growth/analytics-plan.md` |

Soft launch means the experience is public but quiet: no ads, no store push, the group and friends only. If the Roblox limited-access setting is available for the experience, use it for stage 1 (Derek checks in Creator Hub).

## 2. Numbers to read (stage 1)
Read only after about 100 new players; below that, a number is noise and the stage just continues.
| Number | Where | Go | Hold (fix first) |
|---|---|---|---|
| Tutorial completion (`onboarding_v4` reached the last intro step) | analytics funnel `onboarding_v4` | 80% or more | below 65% |
| D1 retention | Creator Hub Retention page | Design-Agent proposes 25% or more; our own bar in analytics-plan section 6 is 12%. Derek picks (see note below) | below 8% |
| `session_10m` share of new players | custom events `session_*` | 50% or more | below 35% |
| Average session | Creator Hub | 10 minutes or more | below 7 |
| Errors | `ClientErrors`, BugReportService, DataStore failures | no error seen in more than 2% of sessions; zero save-loss reports | any save loss |
| Store timing | `first_store_open`, purchases | no pass or Store prompt before about 30 minutes of play | a prompt in the first 10 minutes |

Note for Derek: the outside launch guide's "D1 30% or more" is far above the 2026 GameAnalytics Roblox figures in `analytics-plan.md` (median D1 10.3%, 90th percentile about 15.9%). A 30% gate would hold the game back almost no matter what, so this page uses 12%. Design-Agent's 25% is also well above the median; Derek decides which bar the go uses. The 25% is the stricter option, so a pass on it is a clear go, and a result between 12% and 25% is Derek's call.

## 3. Device matrix
Run on the live build with a fresh account, 10 minutes each: load to first move, intro, catch a cat, open the Store, visit the busiest cafe area. Record load time, frame rate, memory (F9 / MicroProfiler or the Developer Console memory tab), and console errors. Report to `docs/playtests/2026-11-xx-devices.md`; every problem becomes an issue.
| Device | Why | Pass |
|---|---|---|
| Low-end phone (older Android, 2 to 3 GB RAM) | most failures happen here | first move under 30 s on Wi-Fi, no crash, UI fits, memory under the client limit, no black screen |
| Recent iPhone or iPad | tablet layout, safe areas | UI not covered by notch or corners, touch targets work |
| Desktop (mid laptop) | main player | steady frame rate, graphics setting lowers load |
| Console or gamepad (or the closest emulation: Studio gamepad emulator) | shop and tutorial must work without mouse | every button reachable with a gamepad, no dead end in the tutorial |
| Phone with Reduce Motion / lighter graphics on | #1139, #1572 settings | effects still readable, no stuck state |
Who: Laptop-Tester and Device-Tester run what they have. What only Derek or a friend can do: the real low-end phone, an iPhone or iPad, a console. If those are missing, the Studio device emulator is the fallback, and the report must say it was emulated.

## 4. Load and memory check for a busy server
Caps (Gameplay-Engineer, 2026-11-07): 8 players a server, one per cafe plot (`Config.World.PlotCount`; Creator Hub's max players should match). No hard cap on owned cats in a save; the check uses 500 cats a save plus every Index cat (65) in all three coats and all 103 decor pieces, at Tier 5 with every job slot filled. Live strays: at most `Config.StrayLiveMax` (16) in each of 5 areas, so 80 a server.

Cloud-runner stress spec (PR #1953, runs in the normal test gate), results:
- Heaviest save is about 99 KB as JSON, against DataStore's 4 MB a key.
- One second of server work for 8 such players takes about 8 ms on average and 17 ms at worst.
- No save grows over a simulated half hour.
- The heap change is reported but not asserted, because Roblox's Luau cannot force a garbage collect.

Still to do in Studio (needs a Studio session, not the cloud runner): 8 test clients (Test tab, Local Server) catching and decorating for 10 minutes, reading server memory and heartbeat in the Developer Console. Tools-Agent captures the performance marks.
Not possible without real players: network lag, real DataStore throttling, and mixed devices. Soft launch is where those get seen, so watch `ClientErrors` and DataStore failures through stage 1.

## 5. What Derek has to do himself
1. Pick the date and make the final go or no-go call after stage 1 (and approve this page, or change the numbers in section 2).
2. Create the badges in Creator Hub for #1934 (icons, names, ids) once Design-Agent's list exists, and give the ids to the Gameplay-Engineer.
3. Run or lend the real devices for section 3 (a low-end Android phone, an iPhone or iPad, a console), or say the emulator is enough.
4. Check in Creator Hub whether limited access is available for stage 1, and switch on ads only after the go.

## 6. Open items
- Stress spec merged or pending in #1953; paste the final numbers if they change.
- Monetization-Agent: confirm the thresholds in section 2.
- The soft-launch minimum (100 new players) may take longer than two days without ads; if so, Derek decides whether to run a small ad test.
