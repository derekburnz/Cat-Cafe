# Clean icons, 2026-11-15 batch: the three late stations

Same clean style as `../icons-clean-2026-11-03/` (one SVG source, 64 by 64 view box, dark outline). These replace the emoji placeholders on the station ring cards and window headers.

| File | Station | Issue |
|---|---|---|
| `Icon_Clean_TicketBooth.png` | Ticket Booth (two tickets) | #4061 |
| `Icon_Clean_Observatory.png` | Observatory (dome with telescope) | #4062 |
| `Icon_Clean_DragonKeep.png` | Dragon Keep (dragon head) | #4104 |
| `Icon_Clean_Ticket.png` | one prize ticket, for the booth balance and prices | #4061 |

Source: the `ticketBooth`, `observatory` and `dragonKeep` entries at the end of `../icons-clean-2026-11-03/source/icons.js`.

Render again: `cd ../icons-clean-2026-11-03/source` then `node iconshot.cjs <full path to icons-render.html> <out folder> ticketBooth,observatory,dragonKeep`. Output is 256 px, checked at 40 px.

Still to do by whoever wires them: upload (workflow `upload-image.yml`) and add the ids to the station icon table.
