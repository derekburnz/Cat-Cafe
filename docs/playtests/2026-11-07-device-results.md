# Release gate: first device and carry results, 2026-11-07

Source: Laptop-Tester over Remote Control (no screen control), on Derek's laptop (Windows 11, the "mid laptop" row). Raw files: `laptop-captures-2026-11-07.md` and `carry-check-2026-11-07.md` in the project files. Gate page: `2026-11-07-release-gate.md`.

| Gate mark | Result | Verdict |
|---|---|---|
| Phone/desktop load to first move, 20 s or less | live "client ready" 10.7 / 7.3 / 6.8 s, median 7.3 s (first run was a cold start). Laptop only, not a phone. | Pass on laptop; phone still to run |
| Client memory under 1.2 GB | only the Windows process total was read (peak 2,728 MB, about 2,510 MB settled), which is not the Developer Console number | Not measured. Needs one F9 > Memory reading by Derek |
| Server 55 Hz or more with 8 players | Studio Play 25 Hz average is not valid (server, client and live Player shared one laptop) | Not measured. Needs a live server (F9 > Server Stats) or the 8-client Local Server test |
| No red errors in the first minutes | live log, 15 minutes: no game errors or warnings | Pass |

Carry check #1139 (build before the carry rework #1968/#1969): 74 of 75 carries pass. Fail: the rainbow-coat Void lies on its side (upDot 0.00, off-centre). About 12 cats show a tight "loaf" pose box and the rest a sitting pose; both are on the arms. Re-run after #1968 merges.

#1880 notes: item 20 (Store v2) cannot show "Worth R$X" or Best Value in Studio because prices load only on the published place, so check it on live. Blocked without screen control: trading, diving on a carrier, a second player seeing a carry (items 15 to 17), the 8-client load and heartbeat, pity across servers.

Studio-only console line worth a ticket: 3x `ContentId: rbxassetid://203785492 failed due to: Asset type does not match requested type`.

## What Derek or a second person still has to do
1. One F9 > Memory reading on a live client, and one F9 > Server Stats heartbeat on a live server.
2. Real low-end phone, iPhone or iPad, and console runs from the device matrix, or OK the emulator.
3. Second-player checks (#1880 items 15 to 17).
