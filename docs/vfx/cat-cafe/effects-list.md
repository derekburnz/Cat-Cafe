# Cat Cafe animation and VFX list

Draft v0.4.16, 2026-10-27: the Tackle (F74): a dust streak behind the lunge, the shove's puff and stars on a hit for as long as the tackled player is down, and a skid of dust when a miss slides to a stop. v0.4.15 the same day: potion glows (F64's four and the three quest potions of F73) and the Mystery Visitor's puffs, gift twinkle and ribbon pop (F64). v0.4.14 the same day: opening a crate at the Golden Fish Market, golden fish landing in your wallet and the six Mythical cafe styles and decor (F53). v0.4.13 the same day: the Legendary and Mythical themed cats' signature effects, in gold on a gold cat (design v0.10, round 4 Q8), and the soft glow on the Codes Cat's walk-in circle (F65). v0.4.12 the same day: bigger everyday moments (a catch pops by rarity, purchases pop where they appear, your own rank up, a good spin). v0.4.11 the same day: the getaway ring and speed lines after a catch (F55), the startled stars after a miss (F57), and a haze at dusk and a sparkle at sunrise over the area gates (F66). v0.4.10 the same day: a cat only stretches when it gets up to walk off (a napping stray, the server's `StretchAt`) or now and then while a stray stands still, not in its seat; paws peek out at the sides when a cat lies down. v0.4.9 the same day: cats stretch when they wake and now and then while a stray stands still, lie down slowly and get up a little quicker, and walk one leg at a time at a wander with a head nod, a little sway and the tail held up. v0.4.8 the same day: a sleeping cat breathes with its belly (the body swells and settles) instead of floating up and down, and its z's float up one per breath out and start again at the bottom. Cat motion (Pose, Cats, the cat-motion parts of Logic and Presets) moved to the Animation-Engineer the same day, by agreement with the vfx-animator. v0.4.7, 2026-10-27: the new cat bodies (PR #259) move piece by piece: Model-Agent's sleep and loaf poses on resting walking cats, a paw lick now and then on a resting sitting cat, blinks and ear flicks on every cat. v0.4.6 the same day: working cats seated at their stations on the sitting body (`Pose = "sit"`, PR #260) doze where they sit at night and never sink. v0.4.5 the same day: the Spin Wheel station turns for everyone nearby. v0.4.4 the same day: resting cafe cats sit up into a loaf now and then. v0.4.3 the same day: effects follow the Screen shake and Low performance settings. v0.4.2 the same day: shiny cats are now gold cats (Derek picked gold coats); the sparkle and reveal are gold and read the `Gold` attribute. v0.4.1 the same day: upright working cats (F25) doze on their feet. v0.4 the same day added the design v0.5 build below (Effects v1.1). v0.3, 2026-10-26, added the design v0.4 build (Effects v1); v0.2 earlier the same day was rewritten for design v0.3; v0.1 was written for design v0.2. Owner: vfx-animator. Readers: luau-engineer (hooks and the cat rig), ui-designer (screen versus world), sound-designer (same moment names), asset-artist (parts and swatches), game-designer, luau-reviewer, qa-playtester. How each tool works, the style rules and the phone budgets are in `.claude/skills/animation-vfx/SKILL.md`; this file is the what and the when. The mechanics come from `docs/design/cat-cafe/features.md` v0.3 and `data-model.md` sections 4, 5, 5b, 8, 8b, 10, 10b, 10c, 12 and 13.

Nothing here changes gameplay. Every entry runs on the client, reads state the client already has and fits the low tier budget. Priorities: **P1** makes the ten-minute slice loop read, **P2** ships in the slice if time allows, **P3** after the slice. Tools: **proc** is procedural joint motion (`Motor6D.Transform`), **tween** is TweenService, **clip** is a published Animation Editor clip, **fx** is ParticleEmitter, Beam, Trail or Highlight. Particle counts are high tier; the low tier halves them and drops anything marked "high only".

Moment names are the shared v0.3 list in `docs/audio/cat-cafe/sound-list.md` section 6 (agreed with the sound thread) and become Signals in `src/client/Moments.luau`. Effects that other players must see also read replicated state (tags, attributes, models appearing), listed in the hook column.

What design v0.3 removed from v0.1 of this list: the hold-and-release ring and its windup, the 4 s rescue hold, lure spots in the areas with the calm heart and the expiry, the v0.2 stuck props (box and drainpipe; the tree comes back as the Park rescue tree), the cafe level, the Park pass gate and customers leaving at night.

## The Tackle (F74, 2026-10-27)

Derek turned the Shove into a Tackle at 22:31: a press lunges 12 studs straight ahead in 0.35 s and can miss (data-model 10c and 13 v0.11, docs PR #356). A hit is still a landed shove, so its puff, dust and stars stay as they are; the stars now last as long as the tackled player is down (TackledDownSeconds, 0.8) plus 0.4 s while they get up, 1.2 s in all as before. The dive, the belly slide, the get up and the target's fall are the Animation-Engineer's; the toasts and the arrow on the ground are the UI's. File: `Shove.luau` in `src/client/Effects`, numbers in `Presets.tackle`.

| Effect | Look | Hook |
|---|---|---|
| Lunge | A flat ribbon of cream dust 1.4 studs wide along the ground under the tackler, trailing 0.45 s behind and fading, with 2 kick puffs at their feet every 0.06 s while they move faster than 28 studs a second. It stops when the lunge slows (two looks in a row under that speed), or after TackleLungeSeconds plus TackleHitGraceSeconds (0.6 s) at most | `TackleAt` (server time of the press) on the tackler's character, under 0.6 s old |
| Hit | The shove: 10 grey puffs where it lands (between the two players), a skid of kick dust at the tackled player's feet, three dizzy stars circling their head while they are down and getting up, and for them the 0.3 s camera bump | `ShovedAt` and `ShovedBy` on the tackled player's character |
| Miss | 3 kick puffs every 0.06 s while the tackler still slides faster than 3 studs a second (0.6 s at most), then 8 dust puffs where they stop on their belly | `TackleMissAt` (server time the lunge ended with no hit) on the tackler's character, under 0.6 s old |

Everyone within `ambientRadius` (80 studs on a phone) sees them, and the tackler always sees their own. Budget: one Trail for 0.6 s at most per lunge and bursts that are 1 or 2 particles each on a phone; nothing steady. Screen shake off drops the hit's camera bump; Reduce Motion holds the stars still, as for a shove. Five checks are in `docs/vfx/cat-cafe/specs/EffectsTackle.spec.luau` for QA.

Studio checks once F74 is in: lunge at nobody and check the streak follows the dive and ends with it, then the skid dust and the puff where you stop; lunge into a second player and check the puff, their stars for about a second and the bump on their screen only; watch a second player tackle from 30 studs away and see the same. No new console errors.

## Potions and the Mystery Visitor (F64, 2026-10-27)

From data-model 12b and the display hooks Design-Agent added for these effects in v0.10.1 (section 13): the character's `ActivePotions`, the plot's `MysteryVisitorUntil` and `MysteryGiftAt`, the `MysteryVisitor` and `MysteryGift` tags on the models each client builds under a Plot, and `MysteryGiftResult`. Drafted on the preview page, now a file in the library: `VFX-Agent/previews/effect-drafts.html`. Files: `Potions.luau` and `Mystery.luau` in `src/client/Effects`. They wait for the engineer's F64 build; until then nothing carries the attribute or the tags and they do nothing.

| Effect | Look | Hook |
|---|---|---|
| Potion drunk | 10 catch sparkles in the potion's colour at your chest and a 3 stud ring at your feet. Only you see it | an id in your ProfileSync `buffs` whose `endsAt` moved later (`Logic.potionDrunk`) |
| Tip Potion running | Gold glints drifting slowly up off the body (`potionTip`, Rate 2.5), the sparkle shape until a coin sprite is uploaded | the newest id in the drinker's `ActivePotions` is `tip_potion` (`Logic.newestPotion`) |
| Lucky Potion running | Green, mint and pale gold glints twinkling all round the body (`potionLucky`, Rate 2) | `lucky_potion` |
| Swift Potion running | Light blue wisps left behind at the feet, a trail while you move (`potionSwift`, Rate 4, 0.4 to 0.6 s each) | `swift_potion` |
| Steady Paw Potion running | Soft mint and white sparkles on both hands (`potionSteady`, Rate 2 split between them) | `steady_potion` |
| Big Tip Potion running (F73 quests) | A brighter, busier stream of gold and pale gold glints rising off the body than the Tip Potion's (`potionBigTip`, Rate 3.5) | `big_tip_potion` |
| Gold Rush Potion running (F73) | Pale gold, gold and white glints twinkling all round the body (`potionGoldRush`, Rate 2) | `gold_rush_potion` |
| Quick Bait Potion running (F73) | Little salmon and cream food crumbs falling from both hands (`potionQuickBait`, Rate 2 split between them) | `quick_bait_potion` |
| Visitor arrives or leaves | A puff of 6 purple smoke where the hooded visitor sits, within `animRadius`; one already sitting when you arrive gets no arrival puff | a `MysteryVisitor` model appearing or going |
| Gift appears | 6 pale sparkles off the gift's top; over your own gift a faint twinkle stays while it waits (`giftTwinkle`, Rate 1.5) | a `MysteryGift` model appearing; the twinkle when its plot's `OwnerUserId` is you |
| Gift opened | Confetti in the ribbon colours (pink, violet, pale gold, white; 40 % of the budget's), 8 sparkles and a 3 stud ring in the colour of what was inside: the potion's own colour, salmon pink for the Salmon, gold for fish, warm yellow for a spin. In that colour from the first frame, never anything better first. Only the owner sees it | your `MysteryGiftResult(kind, id, count)` (`Logic.giftColour`), at your gift or where it just was |

A gift that runs out or goes with a plot release leaves with no pop, so it never looks opened. The nearest `potionGlows` drinkers within 50 studs show their glow, your own first (6 on a PC, 3 on a phone); Low performance shows none, and the HUD timer still shows your own. Reduce Motion keeps the glows, the sparkles and the confetti (cut to 40 %, as everywhere) and drops the flash rings of the drink and the gift, as it does every ring.

Studio checks once F64 is in: drink each potion and check its pop and glow, then a second kind (the newest shows) and let one run out (the glow goes); a second player sees your glow and you see theirs; switch on Low performance (no glows); wait for a Mystery Visitor and check the arrival puff, the gift sparkle and the twinkle over your own gift only; open it for each kind of prize and check the pop's colour; let one run out (no pop). No new console errors.

## Crates, golden fish and Mythical cafe styles (F53, 2026-10-27)

From golden-fish.md section 4 (F52 to F54, approved by Derek at 19:27) and the engineer's #316: `CrateResult`, the plots' `Wallpaper`, `Floor` and `Paint` attributes and `DecorId` on placed pieces. Drafted on the preview page "Cat Cafe Effect Drafts" (version 4). Files: `Market.luau`, `Fish.luau` and `Decor.luau` in `src/client/Effects`.

| Effect | Look | Hook |
|---|---|---|
| Crate opened | At the stall nearest you (within 30 studs), a puff of ice sparkle comes off the counter, over the golden fish on ice in front of the shopkeeper cat, and the won piece's rarity bursts out of it the way a catch of that rarity does (`Catch.pop`): sparkles and a ring in the rarity colour, confetti from Epic up, a beam from Legendary up, a second ring and showers for a Mythical. It plays the moment the answer arrives, together with the window's card, in the piece's own colour from the first frame, and never builds up or shows a better rarity first, so nothing looks like a near miss (monetization-policy). A duplicate pops the same; its fish back sparkle as below. Only the opener sees it | this player's `CrateResult(crateId, decorId, ...)`; the rarity from the piece's `DecorDef`; the stall is the `FishMarket` tag in Workspace; the pop comes from 3.1 studs up and 0.65 toward the front from its pivot (market.py's counter), or from the top of the stand-in's `FishCrate` |
| Golden fish gained | Gold catch sparkles round you (8, 14 or 22 for a gain of 1, 10 or 40 and up), half as many gold glints floating up (`fishRise`) and a gold ring at your feet 3, 4.5 or 6 studs across. Every way of earning fish shows it; spending never does. Only you see it | `goldenFish` rising between this player's ProfileSyncs (`Logic.fishGain`, `Logic.fishPickup`) |
| Midnight Sky (wallpaper) | Stars on the back and side walls (16 and 10 each, half of them twinkling between their own brightness and faint every 1.2 to 2.6 s), a full moon in soft rings of lamp-warm glow drifting along the back wall and back every 45 s | the plot's `Wallpaper` = `alley_midnight_sky` |
| Aurora Sky (wallpaper) | Three soft curtains of light on the same walls, violet at the top through mint to teal at the foot, swaying 5 degrees and drifting over 7, 9 and 11 s, with 6 still stars a wall behind them | `Wallpaper` = `woods_aurora_sky` |
| Glimmer Canal (floor) | Four bands of milk and sky light sliding across the floor under the glass, 9 to 15 s a crossing, and a glint now and then over the floor (`decorGlint`, Rate 2) | `Floor` = `sewer_glimmer_canal` |
| Rainbow Shimmer (paint) | A soft rainbow tint (shirt red, gold, leaf, fish blue, aurora violet, nose pink) over the whole cafe front up to the eave, scrolling once across every 18 s; it covers the windows and door too. Seen from the street by everyone | `Paint` = `neighbourhood_rainbow_shimmer` |
| Gold Leaf (paint) | A light sheen sweeping over the gold front once every 7 s and glints twinkling on it (`decorGlint`, Rate 2). Its still look is the foil itself. Seen from the street | `Paint` = `classic_gold_leaf` |
| Blossom Tree (decoration) | Rose, blush and white petals fluttering down from its canopy with a little sideways drift (`decorPetals`, Rate 2, 3 to 4.5 s each), using the sparkle shape until a petal sprite is uploaded. Until the model exists they fall from the top of the stand-in block | a placed piece with `DecorId` = `park_blossom_tree`; the child model `CatCafe_Decor_BlossomTree_Canopy` (Model-Agent's crate decor PR), else a model or part named `...Canopy` or `...Blossom` |

Every Mythical style in use shows its still look on any cafe: the stars, the moon, the light bands and the rainbow tint, as pictures on a see-through sheet laid just over the wall, floor or front (the walls, floor and front are measured from the plot's parts with the same tags StyleController paints). The nearest `decorEffects` pieces within `ambientRadius` (4 on a PC, 2 on a phone, none in Low performance) also move, and Ambient leaves that many fewer steady emitters for steam, chimney smoke and fireflies, so the steady budget holds. Reduce Motion stills the twinkles, drifts and scrolls but keeps the glints and petals; rings and beams are skipped as everywhere. Five cases in `docs/vfx/cat-cafe/specs/EffectsDecor.spec.luau` wait for QA to move into `tests/specs`. Studio checks: open a crate of each rarity you can get (`CatCafeDebug:Invoke("giveCrate", ...)`) and see the pop come off the counter's ice in the card's colour with nothing brighter first; claim an Index milestone that pays fish and see the gold sparkle, then buy a crate with fish and see none; put each Mythical style in use and see its look, then walk away from your cafe and see it go still while the picture stays; turn on Low performance and see every style go still.

## Signature effects and the Codes Cat circle (design v0.10, 2026-10-27)

Gavin's round 4 Q8 answer ("Yes thats a great idea make them special because of rarity") keeps the Legendary and Mythical cats' effects on their gold versions, recoloured gold, so the rarest gold cats look the most special. The signature effects in section 1 were not built yet, so `Signature.luau` builds them for all ten cats at once with their gold colours. Glowing eyes had been a Studio step on the models (set the iris Neon) that Rojo would undo, so Effects now does it on the client.

| Cat | Effect | Gold version | Hook |
|---|---|---|---|
| Ninja Cat (void) | glowing amber eyes, a twinkle of sparkle and white on the black coat | gold eyes and gold twinkles | `CatId`, `Gold` |
| Wizard Cat (midnight) | glowing eyes, little sparkle stars drifting up off the fur | gold stars | same |
| Fairy Cat (blossom) | a rose, pink or white petal fluttering down now and then | gold petals | same |
| Astro Cat (aurora) | glowing mint eyes, a soft glow round it shifting from galaxy blue through violet to mint | a glow from dark gold to light gold | same |
| Super Cat (marshmallow) | a white and red whoosh behind it, only while it moves | a gold whoosh | same |
| Ice Cream Cat (comet) | glowing eyes, sprinkles floating up off the cone hat in pink, teal, yellow, blue and mint | gold sprinkles | same |
| Antler Cat (old_oak) | a green leaf drifting down off the antlers | gold leaves | same |
| Unicorn Cat (wisp) | glowing eyes, a sparkle trail off the horn in sky blue, pale yellow and blush | gold sparkle | same |
| King Cat (bottlecap) | white glints off the bottle cap crown | gold glints | same |
| Dragon Cat (eclipse) | glowing eyes, tiny sparks that cool to smoke | gold sparks | same |

Budget: one emitter per cat at Rate 2 or less, on the nearest 6 such cats within 40 studs on a PC, 3 on a phone and 1 in Low performance, so a phone adds about 12 particles at most. The gold sparkle every gold cat already has stays, so a gold Legendary gets both. Petals and leaves use the sparkle sprite until our own sprites are uploaded (`Presets.textures`). Every number is in `Presets.signature` and `Presets.signatureFx`.

The Codes Cat circle (Derek 20:10: "make code cat have a stand and a clear area circle to walk into to open code entering menu"): a soft mint glow over the modelled `CodesCircle` breathes between faint and a little brighter every 2.4 s (steady with Reduce Motion), turns brighter while you stand in it, sends a few mint and sparkle motes up while you are within the ambient range (off in Low performance) and answers your step in with a mint ring and ten sparkles. It goes in at CodesCircleRadius (4) and out past 5 studs, the same edges as the code box, so the two never disagree. It waits for the engineer's station (tag `CodesCat`, README hook 14). Numbers: `Presets.codes`.

Three cases are in `tests/specs/EffectsSignature.spec.luau` (QA moved them in, PR #329). Studio checks: spawn each of the ten cats plain and gold and see the effect in its own colours and in gold; Ninja, Wizard, Astro, Ice Cream, Unicorn and Dragon cats' eyes glow; walk a Super Cat and see the whoosh stop when it stops; on a phone-sized viewport with Low performance on, only the nearest one shows its effect; walk into the Codes Cat's circle and see the ring and the brighter glow as the box opens, walk out past the edge and see it dim.

## Everyday moments (2026-10-27)

Derek asked for effects "for basic stuff in game like catching or clicking upgrade or unlocking new tiers or landing on a good item on the spin the wheel". The drafts were shown first next to how each looks today, in a preview page (claude.ai artifact "Cat Cafe Effect Drafts"). All of them listen to signals the game already has, so they need nothing from the engineer, and they play on this client only.

| Moment | Today | Now | Hook |
|---|---|---|---|
| Catch | sparkles in the rarity colour (8 to 28) | also a ring in the rarity colour under the cat (4 studs for a Common up to 11 for a Mythical); confetti in the rarity colour from Epic up (40, 60 and 90 % of the budget's confetti); a beam of light 16 studs tall from Legendary up; for a Mythical a second, wider sparkle-yellow ring and three slow showers of sparkles from the top of the beam. A Purrfect keeps its gold burst, ring and confetti and adds the beam | this player's CatchSchedule and CatchResult |
| Upgrade bought | nothing in the world | whatever it adds to your cafe (a table set, the espresso machine, the bait bowl, decor) gets a sparkle above it, a mint ring at its foot, a puff of dust and a few confetti as it appears; a purchase that adds nothing there (the net, a food, or a food won on the wheel) gives a sparkle swirl and a small mint ring at your feet | `Moments.Purchase` and the piece appearing in your own plot within 1.5 s before or 1 s after |
| Tier unlocked | confetti and a smoke puff at the cafe door | your own cafe: a gold beam rising from roof height over the door, a gold ring 18 studs across the street, confetti from 4 studs either side of the door and three sparkle fountains 0.3 s apart. Other cafes keep today's version | the plot's `Tier` (unchanged) |
| Spin prize | gold sparkles at the pointer and three blinks for any prize | unchanged for a prize with more than a 16 % chance; at 16 % or less (Salmon, Sardines) a mint ring and confetti from the top of the wheel; at 6 % or less (Caviar) gold confetti, a gold ring, three falling sparkle showers and six blinks over 1.2 s. It all starts only after the wheel has stopped on the prize, and everyone near the wheel sees it | `LastSlice` and the slice's weight in `Catalog.spinWheel` |

Reduce Motion drops the rings and beams and cuts confetti to 40 %. A phone gets half of each burst and half the confetti, Low performance about a third. The UI's own button feedback in the Upgrades window belongs to the ui-designer. Three cases are in `tests/specs/EffectsMoments.spec.luau` (QA moved them in, PR #329). Studio checks: catch a Common and an Epic and see the ring and confetti grow; buy a table and see it sparkle as it appears, buy the net and see the swirl; rank up and see the beam and both confetti bursts at your own door while a second player sees today's version at yours; spin until a Salmon or Caviar and see the bigger finish only after the wheel stops.

## Getaway, Startled, dusk and sunrise (F55, F57, F66, 2026-10-27)

From design v0.8 and v0.9 (features.md section 2f, data-model sections 9, 10c and 13): Gavin's round 3 answers and Derek's short night. All of it waits on the engineer's builds and plays nothing until their attributes appear; the hooks are 12 and 13 in the Effects README.

| Effect | Look | Hook | Status |
|---|---|---|---|
| F55 getaway | A net catch or rescue pushes the other players within 10 studs away: a flat white ring spreads from the catcher's feet to 20 studs across over 0.6 s, so it ends where the push does, with a puff of dust. While the Catch Rush lasts (5 s at walk speed 24), thin white speed lines stream off the catcher's body whenever they move: 3 on a PC, 2 on a phone, 1 in Low performance. Each pushed player skids on a little dust | `RushUntil` (server time the rush ends) on the catcher's character; `PushedAt` (server time) on each pushed player's character for the dust | waits on the engineer's F55; `PushedAt` is optional |
| F57 Startled | The player who missed gets the shove's three dizzy stars circling their head for as long as they are slowed (2 s), and for them a 0.24 s camera bump that takes over from the miss shake, so the two read as one. A startle and a shove together show one ring of stars | `StartledUntil` (server time the slow ends) on the character of the player who missed | waits on the engineer's F57 |
| F66 dusk | As the areas close for the night, a soft violet haze rolls over every area gate this player can use within 70 studs, rising from three places along its width | the Clock's `AreasOpen` turning false | waits on the engineer's F66 |
| F66 sunrise | As the areas open with the fresh wave, the same gates sparkle in sparkle yellow and mint and a warm lamp-coloured ring spreads at their foot | the Clock's `AreasOpen` turning true | waits on the engineer's F66 |

Reduce Motion drops both rings and the camera bump and holds the stars still; the Screen shake setting drops the bump alone. Low performance cuts the speed lines to one and every burst to 35 %. Speed lines, stars and dust show only within `ambientRadius` of this player (on themselves always). Neither moment plays for the first value a client sees, so a player joining mid-rush gets the rest of the speed lines without the ring, and one joining at night sees nothing until sunrise. Four cases are in `tests/specs/EffectsChase.spec.luau` (QA moved them in, PR #308). Studio checks (once the engineer's builds are in): a catch next to a second player shows the ring reaching about where they land and speed lines while the catcher runs, stopping after 5 s; a miss shows stars over the misser for 2 s and one bump, not two; at dusk the gates by the cafe haze over as the fences close and at sunrise they sparkle as they open; a player standing far from every gate sees neither.

Next: nothing queued. The Tackle (F74), the potion glows and the Mystery Visitor (F64), the crate opening, golden fish and Mythical styles are built (see their sections above); F74's and F64's wait for the engineer's builds.

## Walking, stretching and changing pose (2026-10-27)

Derek also asked for "walking animations and changing between positions and stretching". All three are cat motion in `Logic.luau`, numbers in `Presets.motion`.

- **Stretch** (`Logic.stretch`, `motion.stretch`). On all fours (body A and the older Part cats) the cat rises out of whatever pose it was in, bows (front legs reaching 70 degrees ahead, body 22 degrees nose down and lowered so the back feet stay down, tail up, ears back, eyes shut, head kept nearly level with a small yawn), then rocks forward and stretches each back leg out behind in turn, and settles back, over 3.2 s. Derek (later the same day): a cat stretches when it gets up to go somewhere, not when it is not going anywhere, and cats nap when idle, not only at night. So the stretch plays when a napping stray gets up on its own (the server sets `StretchAt`, its time, as it clears `Napping`, and waits for the stretch before walking it off; a catch or shove wakes it with no stretch), and every 35 to 80 s while a stray stands still. Seated cats (body B, working cats at dawn) and resting cafe cats turning between their nap and their loaf do not stretch. A stray that sets off or hisses mid-stretch lets it go over 0.35 s.
- **Paws** (Derek: "show paws on side a bit when loafing lying down"). In the sleep and the loaf the folded legs also turn out to the sides, front 30 degrees and back 26, so the paws peek out a little past the body. Model-Agent's manifest and pose sheet carry the same turns since #296.
- **Changing pose** (`Logic.settleSeconds`). Lying down (into a nap or a loaf) now takes 1.2 s and getting up 0.9 s; any other change still takes 0.8 s.
- **Walk** (`Logic.gait`, `motion.gait`). Below 3.4 studs a second (strays wander at 3) the cat walks one leg at a time, back left, front left, back right, front right, a quarter cycle apart, its body swaying 3 degrees side to side with the head held level, the head nodding 4 degrees with each step and the tail held 18 degrees up and swaying with the steps. On the move at any speed it keeps only 30 % of its idle look around, so it mostly watches where it is going. From 4 studs a second it trots as before, and the gallop from 9 is unchanged.

Nine cases are in `tests/specs/EffectsStretch.spec.luau` (QA moved them in). Studio checks: a resting cat turning from its nap into its loaf settles in slowly without standing up, its paws peeking out at the sides; working cats at dawn go back to work in their seats without a stretch; a stray napping in a pause gets up, stretches and only then walks off (once the server pause is in); a stray standing still stretches now and then and walking off mid-stretch blends out rather than snapping; a wandering stray's legs step one at a time without its feet sliding much, and a stray chased into a run trots then gallops as before.

## Sleeping breath and z's (2026-10-27)

Derek asked for a breathing cat while it sleeps, "slightly lifting and lowering cat belly", with z's that loop up and reset. Until now a sleeping cat breathed by lifting its whole body 0.05 studs, so its belly left the floor. Now the body swells instead (`Pose`, Offsets `belly`): the body's own blocks (the parts named `_Body`) grow from the bottom of the body, the top of the back rising 0.09 studs on a nap, 0.06 on a doze and 0.05 in a loaf, and out to the sides by half that. Whatever rides the body moves with it, and the head, tail and legs ride up by how high their joint sits, so the head lifts a little with each breath and the folded legs stay on the floor. One breath takes 3.2 s asleep (3.6 dozing, 4.2 in a loaf): it fills over 38 % of that, lets out over 47 % and rests for the rest (`Logic.breath`, `Presets.motion.breath`). Only the big blocks of the body grow (a quarter of its height or more); stripes and patches just ride the swell. Sizes are written in steps of 1 % of the body's height (under 0.01 studs), about a dozen times a second while it breathes in or out and not at all while it rests between breaths or is awake (review S70). An upright cat or a Motor6D rig still lifts whole. Awake cats keep their small whole-body breath.

The z's (`Logic.napZ`, `Presets.nap`) are three labels, z, z, Z, that take turns: one pops up small beside the head each time the cat breathes out, rises 1.8 studs while it grows to full size and drifts right with a little sway and tilt, fades out at the top after 2.5 breaths, and waits for its next turn at the bottom. The box hangs up and to the right of the head in the camera's axes, so the z's always rise away from the cat on screen. Reduce Motion holds them still as before; the budget's `napLabels` still caps how many cats show them.

Six cases are in `tests/specs/EffectsBreath.spec.luau` (QA moved them in). A preview of the real code on the real models, rendered outside Studio, is made with `assets/cat-cafe/anim/preview/`. Studio checks: a napping cat's back rises and falls with no gap opening under it and no part sliding off; its head bobs a little with each breath; a z appears as each breath goes out and the old ones fade at the top; a dozing working cat breathes the same way in its outfit with the outfit staying on; a cat waking (dawn, or picked up) snaps back to its normal size with no leftover swell.

## Spin Wheel station (F49, 2026-10-27)

Derek asked for spins to be a station you walk up to. The engineer's PR #223 puts the wheel in the street plaza (tag `SpinWheel`) and sets its `LastSpinAt` (server time) on every spin. `Effects/Wheel.luau` turns the world wheel on every client within 120 studs: three whole turns and on, easing to a stop over 3.4 s, inside the 4 s spin cooldown. The rim lights chase round while it turns, the pointer is knocked aside by each slice edge and springs back, and when it stops a gold sparkle bursts at the pointer and the rim lights blink three times together. It stops on the won slice, which the server sets as `LastSlice` just before `LastSpinAt` (reviewer S64): somewhere inside the slice, never within a fifth of a slice of an edge, so it never looks like a near miss of a better prize. Every client works out the same angle, and a player who joins later sees it at the same resting angle. With no `LastSlice` it stops anywhere. A spin seen late starts as far in as it is late. Reduce Motion keeps the lights still and turns the wheel once instead of three times. Sounds come from the Spin window's moments (Sound-Agent), not from here. Five cases are in `tests/specs/EffectsWheel.spec.luau` (QA moved them in, PR #272). Studio checks: after a spin the plaza wheel turns, slows and stops on the slice the Spin window shows while the lights chase; a second player sees it turn and stop at the same angle; standing 150 studs away, nothing plays.

## Loaf (2026-10-27)

Derek picked the cat bodies on 2026-10-27: strays walk on draft A and rest on B, and cafe cats rest with an occasional still "loaf" from draft E. The loaf is drawn in code (`Logic.idle("loaf")`, numbers in `Presets.motion.loaf`). The cat is down on its belly with every leg folded under and the front paws peeking out. Its head is up and level, and its tail lies along its right side. It is very still: a slow breath, a slow look to one side every 11 s and a quick ear flick. A resting cafe cat (`Napping`, no station) curls up as before. By day it sits up into the loaf for 24 s of every 75, each cat at its own offset taken from its `Uid` and the server clock, so every player sees the same cat loaf at the same time and the cat room takes turns. It settles in and out over 0.8 s like any change of pose. Its z's go while it loafs, and at night every resting cat stays curled up. `Effects.isLoafing(model)` gives the same answer to Audio, which purrs from loafing cats. The asset thread is exporting the new bodies with each leg (`LegF1`, `LegF2`, `LegB1`, `LegB2`), eye (`Eye1`, `Eye2`) and ear (`EarL`, `EarR`) as its own piece pivoted at its hinge, named `<Cat>_<Piece>`. Pose now reads those names. Loaf and sleep will not be separate models: the manifest will carry their pose numbers, which then replace the ones in `Presets.motion.loaf`. Blinks and ear twitches come once eyes and ears are their own pieces. Four cases are in `tests/specs/EffectsLoaf.spec.luau` (QA moved them in, PR #272). Studio checks: resting cats in the cat room take turns sitting up into a loaf and curl back up; no two neighbours always loaf together; no loaf at night.

## Settings: Screen shake and Low performance (2026-10-27)

Derek asked for a bigger Settings menu with a screen shake switch and a Low performance mode. Effects follows both through `Effects.applySettings(settings)`, which the engineer calls next to `Audio.applySettings` (hook 10 in the Effects README). Screen shake off: no camera shake on a missed catch and no camera bump on a shove, and a running one stops at once; the hiss, the puff and the stars still play. Low performance on, on any device: 4 moving cats (phone 8) within 45 studs at 20 updates a second, 2 steady emitters at half their rate (phone 4 at full rate), 1 gold sparkle, 2 butterflies, bursts at 35 % and 8 at most, 8 confetti pieces and 2 sets of z's; `Effects.tier()` reads "low", so the street keeps its phone customer cap too. The change shows within a second. Screen shake starts on and Low performance off. Show other cats off: the engineer marks each hidden cat `HiddenLocal` on this client only, and Effects then gives it no motion, gold sparkle, burst, hiss or loaf until the mark clears. Four cases are in `tests/specs/EffectsSettings.spec.luau` (QA moved them in, PR #272). Studio checks: with Screen shake off a missed catch and a shove move nothing on the camera; with Low performance on fewer cats move and the steam thins within a second, and turning it off brings them back.

## Upright working cats (F25, 2026-10-27)

The engineer's PR #159 stands every working cat on its back legs at its station in its role outfit (manifest `poses.upright`: the whole model turned +90 degrees about X, `Pose = "upright"`, outfit parts with `Follows = "Body"` or `"Head"`). Effects reads that so the role idles still look right: a bob still lifts the cat, the waiter's sway still rocks it side to side, a nod still dips the head and the entertainer's yarn ball stays on the floor in front. Legs are found in the body part's own axes, so the turned model finds the same four legs, and an outfit part is never taken for a leg. At night an upright cat dozes on its feet (chin on its chest with a slow nod, a little sway, z, z, Z) instead of curling up, and it never sinks, so it cannot dip into the counter. Three cases are in `tests/specs/EffectsUpright.spec.luau` (QA moved them in). From PR #260 working cats sit at their stations on the sitting body instead (`CatCafe_Cat_<Name>_Sit`, `Pose = "sit"`, the model in the floor's own axes): they get the same rule, a doze at night and no sink, so the counter barista stays on the counter. Studio checks: each role idle on an upright cat moves the way it does on all fours; at nightfall the upright cats doze standing with z's and wake at dawn; outfit pieces ride the body and head and never swing like legs.


## New bodies (PR #259)

Every cat is now two models on the chunky draft bodies Derek picked: `CatCafe_Cat_<Name>` (body A, on all fours: strays, carried and stuck cats, resting cafe cats) and `CatCafe_Cat_<Name>_Sit` (body B, sitting up: working cats at their stations from PR #260), with `_Gold` twins. Each hinged piece is its own Model pivoted at its joint: Head (neck) with Eye1, Eye2 (eye centre) and EarL, EarR (ear base) nested in it, Tail (root), LegF1 and LegF2, plus LegB1 and LegB2 on A. Effects turns each piece about its own pivot, so nothing has to guess where a joint is.

- **Sleep and loaf.** A resting cafe cat on A naps in the manifest's `sleep` pose (legs folded under, head down and turned, tail curled round), lowered by its `lift` times the model's `Scale` but never further than to 0.02 studs (at its scale) above the floor (`motion.lieGap`: the Munchkin's shorter legs give it 0.19, as the manifest's `pose_lifts_roblox` says, and Chonk and Tuxedo stop dipping a hundredth of a stud in), and sits up into the `loaf` pose now and then by day as before. Only a slow breath, a slow look aside and the tail tip move. Settling from one to the other blends the two poses, so the cat stays on the floor.
- **Paw lick.** A resting cat on B (none yet: resting cats stay on A) washes a paw now and then by day (`lick`, 9 s of every 60 at its own time): the left front paw up at the mouth, the head bobbing to it and the paw rubbing in short bursts, eyes half shut.
- **Blinks.** Every cat blinks about every 4 s: each eye part squashes to 12% of its height about the eye centre for 0.16 s. Asleep or dozing the eyes stay shut, in a loaf they stay half shut with a slow blink.
- **Ear flicks.** Each ear flicks back and out 22 degrees about its base, the left every 5.3 s and the right every 7.7 s, half as often asleep.
- **The older Part cats** and the placeholders keep folding their own legs (`sink`), so nothing changes for them.

Eleven cases are in `tests/specs/EffectsBodies.spec.luau` (QA moved them in, PR #272). Studio checks: a resting cafe cat on A lies down into the sleep pose with its legs under it and no part in the floor, sits up into the loaf and back; the seated barista on B taps with its front paw; every awake cat blinks and flicks an ear now and then; a sleeping cat's eyes are shut; turning Show other cats off and on leaves no squashed eyes behind.
## Design v0.5 build: Effects v1.1 (2026-10-27)

Design v0.5 (`docs/design/cat-cafe/features.md` F40 to F44, PR #122) gave this role four effects, F40 first. All four are in `games/cat-cafe/src/client/Effects/`; the numbers are in `Presets.luau` (`motion.gait`, `motion.pant`, `motion.nap`, `shove`, `reveal`).

| effect | what you see | trigger | status |
|---|---|---|---|
| F40 sprint after a miss | Every cat that moves now walks: a trot (diagonal legs together) at a walk, a gallop (front pair then back pair, body rocking, head stretched forward and down, tail out) from 9 studs a second, full at 18; StrayFleeSpeed 26 is a flat-out gallop. Dust kicks from the feet while it runs. When it stops it pants for the rest of the sprint: quick shallow breaths, head and tail low, a small breath puff every 0.7 s | the cat's measured speed (the server moves it; nothing extra needed); the pant reads `FleeingUntil` (server time the sprint and rest end) | works with the engineer's chase PR (#130); the gait works now for any moving cat |
| Settle between poses | A cat eases from one pose into the next over 0.8 s (sit to nap, stray to carried) instead of snapping | any change of style | works now |
| F44 night nap | Working cats curl up at their stations at night: the body sinks to lie down, legs tucked under, head turned and tucked toward the tail, tail wrapped round to meet it, slow breathing and z, z, Z. They stand up again at dawn | Clock `Phase` is `"night"` on a cat tagged `WorkingCat` (or with a `SpotId`); `Napping = true` still naps any cat | works now (read on the client from the Clock, no new hook) |
| F42 gold sparkle | The steady sparkle is gold (warm white glints, sparkle yellow and golden) to match the gold coats Derek picked on 2026-10-27 (it was frost before), and also shows on a gold cat someone is carrying. A gold cat gets a one-off burst and a golden ring when it is revealed: when `Gold` turns on, or when a gold cat is picked up | `Gold = true` on the cat or on a `HeldCat` model under a character (the old `Shiny` is still read until the engineer's rename lands) | works now; the sparkle sprite still waits on Derek's upload (`Presets.textures.goldSparkle`) |
| F41 shove | A puff where the shove lands (between the two players), a skid of dust at the shoved player's feet, three dizzy stars circling their head for 1.2 s (since F74 TackledDownSeconds plus 0.4 s), and for the shoved player a 0.3 s camera bump bigger than a missed catch's. Stars hold still and the bump is off under Reduce Motion | `ShovedAt` (server time) and `ShovedBy` (shover's UserId) on the shoved player's character | needs the engineer to set those two attributes in the shove PR; nothing plays until then |

Budget: the gait and pant add no emitters; dust is 3 particles a kick every 0.14 s per running cat (about 1 on a phone after halving), the pant puff 2, the shove puff 10 and the reveal 20, all capped at 12 on a phone. Only one shove star loop runs however many players are dizzy.

Requests from this build:
- Engineer: on a shove, set `ShovedAt = Workspace:GetServerTimeNow()` and `ShovedBy = <shover UserId>` on the shoved player's character (README hook 9). `FleeingUntil` (#130) is read as is.
- Game-designer: add `ShovedAt` and `ShovedBy` (character attributes) to data-model section 13.
- QA: five more cases (curl, settle, trot and gallop, pant, presets) are in `tests/specs/EffectsMotion.spec.luau`. Studio checks: a missed stray gallops off with dust and pants when it stops; working cats curl up at nightfall and stand at dawn; a forced shiny shows the frost sparkle and the reveal burst, and keeps sparkling while carried; a shove shows the puff, dust, stars and the bump for the target only; a sprinting stray moves smoothly rather than in steps (anchored server moves can look choppy; say if so and I will add client smoothing).

## Design v0.4 build: Effects v1 (2026-10-26)

Derek, 2026-10-26 23:03: make the game clean looking and playable, cafes lively like the sketch, misses that matter. Design v0.4 (`docs/design/cat-cafe/world-and-feel.md` section 7) gave this role: miss hiss and jump-back, Purrfect burst, gate dissolve, rank up confetti, shutter roll-up, station idles for the four roles, napping loops, steam, smoke, butterflies and fireflies. All of them are built in `games/cat-cafe/src/client/Effects/` (file map and hooks in its README). Everything is procedural or a built-in Roblox particle sprite, so nothing waits on an upload and there are no animation ids yet.

"Works now" means it plays as soon as the engineer adds `Effects.start()` to `Main.client.luau`; the other rows wait on the hook named.

| effect | what you see | trigger | status |
|---|---|---|---|
| Role idles | Barista dips its head and taps a paw toward the machine every 1.6 s; waiter sways side to side with a little step; greeter waves a front paw every 3.2 s with a head tilt; entertainer swats a client-side yarn ball rolling in front of it | working cat under `Plot/Cats`, role from `Role` or its station's `SpotType` | works now |
| Every moving cat | Breathing bob and a tail swish; strays also look around; stuck cats shake in their trap every 2.6 s | tags `Stray`, `StuckCat` | works now |
| Miss hiss and hop | A grey puff, a pink "!" over the head, the cat rears and hops back with its tail straight up; a server jump-back landing during the hop is drawn as travel, not a snap. The player who missed also gets a 0.18 s camera shake | CatchResult not a success (catcher); `HissAt` on the stray (everyone) | works for the catcher; everyone else once PR #71 (F34) is on main |
| Catch sparkle | A burst in the rarity colour, 8 (Common) to 28 (Mythical) on PC, at most 12 on a phone | CatchResult success | works now |
| Purrfect | Gold sparkle burst, a gold flash ring on the ground and gold confetti | CatchResult success with every grade `"perfect"` (v0.4) or every score 1 (v0.3) | works now |
| Rank up | Confetti and a smoke puff at the cafe door, for any cafe within 120 studs; more confetti for your own | a plot's `Tier` rising with the same owner | works now |
| Gate dissolve | A copy of the closed barrier fades and swells over the open gate, with rising sparkles, confetti and a mint ring; plays when you are within 70 studs, so a gate that opens while you are far away dissolves when you walk up | your own plot's `Tier` crossing a gate's `RequiresTier` | works now (once per session; a saved "seen" flag would need data) |
| Shutter roll-up | Each For Rent shutter rolls up into its top edge with a dust puff, the For Rent sign flips and fades, a little confetti at the door | a plot's `OwnerUserId` going from 0 to a player | needs the asset thread's `CatCafe_Plot_ForRent` with `_Shutter` and `_Sign` parts; until then a dust puff and confetti |
| Naps | Slow breathing, head drooped, floating z, z, Z | `Napping = true` (or `Pose = "nap"`) | needs the engineer's cafe life PR (F37: up to four idle cats at `NapSpots`) |
| Shiny sparkle | A soft steady sparkle on the cat | `Shiny = true` | needs the server to set `Shiny` (data-model section 13); uses the ShinySparkle sprite once uploaded |
| Espresso steam | A thin white wisp above the machine | `_Steam`, else the top of the plot's `Espresso` model | works now |
| Chimney smoke | Cream-grey smoke drifting with the wind | `_Chimney` parts | needs the asset thread's cafe roofs |
| Butterflies | Two pastel butterflies per flower bed by day. Since 2026-10-27 22:43 (Derek: they flapped at the door all the time) each wanders the whole bed and 1 stud past it, flying spot to spot at about 2.6 studs a second and often hovering, and comes and goes: out 6 to 14 s, then away 8 to 20 s, fading in as it comes down 1.5 studs and out as it rises. The first ones arrive one at a time over 10 s. So about one shows at a cafe front at a time, sometimes two, sometimes none. Clip: `VFX-Agent/previews/butterflies-before-after.mp4` | `_Flowers`, else the pavement in front of each door | works now |
| Fireflies | Warm glowing specks drifting in a box of air at night | `_Fireflies` boxes, else the street lamps | works now (fallback) |

Budget per device (low = phone or tablet): 8 moving cats within 60 studs at 30 updates a second, 4 steady emitters, 3 shiny sparkles, 6 butterflies, bursts of at most 12, 14 confetti pieces a burst, 80 alive at most. High: 16 cats within 80 studs at 60 a second, 10 emitters, 8 sparkles, 14 butterflies, bursts up to 30, 28 confetti. Steam (about 7 live particles each), chimney smoke (about 9) and fireflies (about 10) share the steady slots, so a phone in the street holds about 40 steady particles plus one burst: well inside 150. Measure on the device emulator with the MicroProfiler in the next Studio run and record the numbers here.

Requests from this build:
- Engineer: the start line, `HissAt` on a Miss, `Napping = true`, and Motor6Ds rather than WeldConstraints if cats get welded (Effects README, "Hooks for the luau-engineer"). Sent 2026-10-26 23:27. Answered 2026-10-27 02:45: `HissAt` is in PR #71, `Napping = true` comes with the cafe life PR, the start line goes in once this module is on main, carry welds move to Motor6Ds the next time carry changes. Reviewer S37 added `ModelStreamingMode = Atomic` on cat models and N50 the server removing the For Rent dressing at a claim (README hooks 6 and 7).
- Asset-artist: name suffixes `_Chimney`, `_Steam`, `_Flowers`, `_Shutter` and `_Sign` (inside the For Rent model) and `_Fireflies` boxes. Upload list: the ShinySparkle sprite (PR #46) goes in `Presets.textures.goldSparkle`.
- UI-designer: the screen side of a catch stays yours (PERFECT, GOOD and MISS pops, the paw row, the hiss icon at zero paws); the world side and the camera shake are here. Say if the UI already shakes the camera.
- Game-designer: add `HissAt` (number, server time of the latest miss) and `Napping` (true while a cat naps) to data-model section 13.
- QA: an 11-case spec for `Effects/Logic.luau` and `Presets.luau` passes in cloudcheck; it is in `tests/specs/EffectsLogic.spec.luau`. Checks for the next Studio run: a Miss plays the puff, "!" and hop; an all-Perfect catch plays the gold burst; a rank up shows confetti at the door; a gate dissolves once; steam, butterflies by day and fireflies at night appear near you; a phone-sized viewport stays at 30 frames or more in the street.

## 0. Foundation (build first)

| id | what | owner | P | notes |
|---|---|---|---|---|
| A0.1 | Cat rig on clone: invisible anchored `Root` at the floor pivot as PrimaryPart, Motor6D Root to Body, Body to Head, Body to Tail at `joints_roblox`, parts renamed `Body`, `Head`, `Tail`, AnimationController with Animator | engineer (recipe in skill section 3) | P1 | One function for strays, stuck cats, working cats, the bait cat, the held cat and placeholders. The held cat's weld loop skips parts with a Motor6D and its `HoldWeld` goes from HumanoidRootPart to Root |
| A0.2 | Upright through the rig, not by moving parts: a working cat is the same rig with the manifest's `poses.upright` (and its `head_offset_roblox`) as the rest offset of the Body and Head joints. Uniforms (Apron, BowTie, Sash, PartyHat) weld to Body or Head at `upright_attachments` so they follow every bob and turn | engineer, vfx-animator | P1 | This answers the "upright pose swap when assigned" risk in gdd.md: standing up and dropping to all fours become a 0.4 s tween of two joint offsets |
| A0.3 | `src/client/Moments.luau`: one Signal per moment in the shared list, fired from the controllers | engineer | P1 | Proposed in decisions.md with the sound thread |
| A0.4 | `src/client/Effects/` skeleton: `init.luau`, `Presets.luau`, `CatMotion.luau`, `PropMotion.luau`, `NightGlow.luau`, `AnimationIds.luau`, tier picked once on join, emitter pool under `workspace.Terrain` | vfx-animator | P1 | Started from `Main.client.luau` after the controllers |
| A0.5 | Exit attribute: before removing a stray, stuck cat or bait cat the server sets `Exit` (`caught`, `fled`, `wave`, `tamed`, `letgo`), disables its prompt and destroys it 0.5 s later | engineer | P1 | Lets every client play the right exit on a model that still exists. Today `despawn` destroys at once (CatService.luau:167) |
| A0.6 | Net on the character: the owned net's model on the right hand by a Motor6D named `NetGrip` while the player is in an area and not carrying | engineer, asset-artist for the grip offset | P1 | v0.3 nets are Basic, Sturdy, Pro and Master (data-model section 10); the three existing net models cover the upgrades and Basic can reuse the first |

## 1. Cats at work (roles)

| moment | what you see | tool | budget | hook | P |
|---|---|---|---|---|---|
| CatPlaced | The cat hops onto its station and stands up into the upright pose (0.4 s Back Out); its uniform pops in with 6 sparkles | proc, tween, fx | 6 particles | a new child under `Plot/Cats` with `Role` | P1 |
| barista idle | Upright at the counter: breathing bob, head turns between the espresso machine and the nearest customer, tail sway | proc | shared loop | `Role = barista` | P1 |
| waiter idle | Upright between the tables: a slow side-to-side sway as if balancing a tray, head follows the nearest seated customer | proc | shared loop | `Role = waiter` | P1 |
| greeter idle | Upright inside the door: a small bow (Body joint forward 15 degrees, 0.5 s) when a customer walks in, otherwise watches the door | proc | shared loop | `Role = greeter`, customer spawn | P1 |
| entertainer idle | On the cat tree stage: a bounce and head tilt dance loop, tail swish on the beat | proc | shared loop | `Role = entertainer` | P1 |
| favorite role | A happy tail curl every 10 to 15 s for a cat in its `favoriteRole`, so the 1.5x is visible without UI | proc | none | catalog `favoriteRole` vs `Role` | P2 |
| UnplaceCat | The cat drops to all fours (0.3 s) and trots out of the station, then a small puff | proc, fx | 4 particles | the child removed from `Plot/Cats` | P2 |
| front paw wave | Greeters wave and baristas hold a cup; needs front paws as their own objects | clip or proc | none | asset request, section 10 | P3 |
| signature effects | Built in v0.4.13 for all ten Legendary and Mythical themed cats, with gold versions (see "Signature effects and the Codes Cat circle" above). Strays, stuck cats, working and napping cats and a carried cat alike | fx | 1 emitter per signature cat within 40 studs, Rate 2 or less, on 6, 3 or 1 cats by budget | `CatId`, `Gold` | P2 |

## 2. Strays and shiny

| moment | what you see | tool | budget | hook | P |
|---|---|---|---|---|---|
| walk and idle | On all fours: head nods in step with Mover's walk bob, tail up while walking and down when it stops, a sit-and-wash idle now and then | proc | shared loop, strays within 60 studs | `Stray` tag | P1 |
| shiny on sight | A slow sparkle on shiny strays and shiny working cats (`sparkle` swatch, Size 0.4 to 0.6 so it reads at 30 studs on a phone), stronger at night | fx preset `ShinySparkle` | 8 shiny emitters at most (4 on low tier), Rate 3 | `Shiny` attribute | P1 |
| RareStrayNearby | Epic, Legendary and Mythical strays shimmer in their rarity color | fx | 2 emitters within 40 studs, Rate 2 | `Rarity` | P2 |
| outline | A soft outline in the rarity color on Legendary and Mythical strays within 40 studs, hidden behind walls | fx (Highlight, `DepthMode = Occluded`) | 2 at once | `Rarity` | P2. Open question 2 |

The placeholder rule in features.md section 3 puts a ParticleEmitter named `ShinySparkle` on the Body. Effects reuses that emitter when it is there and adds its own preset when it is not, so the two never stack. A stuck cat and a bait cat that is not ready yet carry no `Shiny` attribute (reviewer N30), and Effects never reads shininess from anywhere else, so the reveal stays a surprise.

## 3. Net: closing circles

The circles are UI (ui-designer). The world answers each one so a player watching the cat, not the HUD, still feels the rhythm.

| moment | what you see | tool | budget | hook | P |
|---|---|---|---|---|---|
| CatchStart | The net lifts (0.3 s); the stray crouches and flattens its ears | proc | none | `CatchSchedule` arrives | P1 |
| CircleAppear | The stray's ears perk and its head tracks the net | proc | none | each circle's start | P2 |
| NetSwing | A quick net flick towards the cat on every press (0.15 s out, 0.2 s back) with a short Trail | proc on `NetGrip`, fx (Trail 0.15 s) | 1 Trail | every circle press | P1 |
| CircleGrade | Perfect: a soft gold star pop on the cat (5 particles) and it freezes for a beat; Good: 3 mint dots and a flinch; Miss: the cat side-steps half a stud | fx, proc | 5 particles at most per press | the client's grade at the press, as the UI shows it | P1 |
| CatchSuccess | The stray hops into the player's arms (0.25 s), then a burst by rarity: Common 8 offwhite dots; Rare adds 6 blue sparkles; Epic adds a purple ring; Legendary adds 10 gold sparkles and a 0.8 s gold Highlight on the held cat; Mythical adds a coral ring and 12 sparkles in its own colors and the Highlight lasts 1.2 s. A shiny adds its sparkle on top | proc, fx | 30 particles at most (a shiny Mythical), 1 Highlight | local: `CatchResult` success; everyone else: `Exit = caught` | P1 |
| CatchFail, retry | Startle hop (Body joint 0.4 stud, 0.2 s), 4 fur puffs in the cat's base color, the net bounces back | proc, fx | 4 particles | `CatchResult` fail on a Common, or on a dropped stray (which never flees, reviewer S26) | P1 |
| StrayFlee | The stray dashes 3 studs away over 0.4 s, then a small soft puff and it is gone | tween on the pivot (the server no longer moves it once `Exit` is set), fx | 6 particles | `Exit = fled` | P1 |
| arm swing | The player's arm swings the net and others see it | clip on the player's own Animator, keying `NetGrip` too, so it replicates | 1 track | NetSwing | P2. The first published clip; it proves the ownership flow in skill section 4 |

## 4. Rescue traps

Traps are `CatCafe_Alley_TrashBin`, `CatCafe_Alley_GarbageBags`, `CatCafe_Park_RescueTree` (its branch is its own part) and `CatCafe_Park_TrashCan`, each with a stuck pose from the asset thread (head and paws poking out). The bar is UI; the trap and the cat answer it.

| moment | what you see | tool | budget | hook | P |
|---|---|---|---|---|---|
| stuck idle | Head and paws poke out and look around every 2 to 4 s, a tail flick where the tail shows; one faint sparkle in the rarity color every 2 s so occupied traps can be found at night. Never the shiny sparkle | proc, fx | 1 emitter per occupied trap, Rate 0.5 | `RescueSpot` with `Occupied` | P1 |
| RescueStart | The bin or can lid lifts a little and settles, the bags rustle, the branch dips | tween | none | `RescueChallenge` arrives | P1 |
| RescueHit, bar traps | The lid jolts up, the bags puff, the can wobbles, and the cat pokes further out with each hit | tween, proc, fx | 3 particles per hit | each hit, with `trapType` | P1 |
| RescueHit, tree | The branch shakes (rotation tween on the branch part) and 2 leaves fall per hit | tween, fx | 2 particles per hit | each hit on a `tree` | P1 |
| RescueMiss | The trap rattles and the cat ducks back in for a moment | tween, proc | none | a paw lost | P1 |
| RescueDrop | The tree cat falls from the branch in a 0.5 s arc, then its one catch circle; on a miss it lands on its feet and climbs back up over 0.8 s | tween on the pivot, proc | none | the drop, then that circle's grade | P1 |
| RescueFail, RescueCancel | The cat settles back into its stuck pose and the trap settles | tween, proc | none | out of paws, the tree catch missed, or a cancel | P1 |
| RescueDone | The cat leaps out into the player's arms with 8 blush hearts (plus 6 leaves from a tree) | proc, fx | 14 particles | local: `RescueResult` success; everyone: `Exit = caught` on the stuck cat | P1 |
| ShinyReveal | The surprise: a ring of 12 sparkles bursts out with the cat and the shiny sparkle stays on it | fx | 12 particles | `CatCaught` with shiny, or `Shiny` appearing on the held cat | P1 |

## 5. Carry and bumps

| moment | what you see | tool | budget | hook | P |
|---|---|---|---|---|---|
| CarryStart | The held cat settles into the carried pose with a small dip (Body joint 0.1 stud, 0.2 s) | proc | none | a `HeldCat` model under any character | P1 |
| carried idle | Slow tail sway, head looks ahead, breathing; every client animates every held cat within 60 studs. Ragdoll goes limp: head and tail droop | proc | shared loop | `HeldCat`, `CarryingCatId` | P1 |
| BumpLoose | A soft "boop" of 4 stars where the two players meet; the cat lands at the carrier's feet and scurries 6 to 10 studs with its tail up and a fast head bob, kicking 3 dust dots; a faint ring on the ground under it fades out when `DropProtectUntil` passes, so everyone can see when it can be netted | fx, proc | 7 particles, 1 ring | the new stray with `Dropped` and `DropProtectUntil` | P1 |
| BumpHeld | The held cat clings (a squeeze wobble, 0.3 s) and a mint shimmer ring circles the carrier while `BumpImmune` lasts | proc, fx | 1 ring | `BumpImmune` on the carrier | P1 |
| CheckIn | A heart and sparkle burst at the cafe door; the carrier also sees the cat hop towards the door | fx, proc | 10 particles | local: CheckIn; everyone: `HeldCat` removed near a plot `Door` | P1 for the burst, P2 for the hop |

No effect may make a bump feel like an attack: no impact flash, no knockback on the characters, no sad cat. The cat looks surprised, then playful. If the engineer adds the old carrier's first-claim window from reviewer S25, the protect ring gets a second phase in mint that only the old carrier sees.

## 6. Bait bowl at the cafe

| moment | what you see | tool | budget | hook | P |
|---|---|---|---|---|---|
| BaitPlaced | The food model drops into the bowl with a Back Out bounce (0.3 s) and 4 crumbs in the food's swatch | tween, fx | 4 particles | `UseLure` accepted; plot `BaitReadyAt` set | P1 |
| waiting | A soft scent wisp rises from the bowl for the 10 minutes, tinted by food; dealer foods get a faint twinkle | fx | 1 emitter, Rate 0.5 | plot `BaitReadyAt` in the future | P2 |
| BaitArrive | The cat walks up the street to the bowl and sits eating: head dips every 1.5 s, tail sway, a crumb now and then. After an offline wait it is already eating when the player joins | proc, fx | Rate 0.5 | `BaitReady`, the bait cat model at `BaitBowl` | P1 |
| ShinyReveal at the bowl | If the bait cat is shiny, a ring of 12 sparkles the moment it sits down, then the shiny sparkle | fx | 12 particles | the bait cat's `Shiny`, set only once it is ready | P1 |
| BaitTame | 8 hearts and the cat hops through the door into the cafe | fx, proc | 8 particles | `Exit = tamed` | P1 |
| BaitLetGo | The cat stretches, flicks its tail and trots off towards the street, then a small puff | proc, fx | 4 particles | `Exit = letgo` | P2 |

## 7. Coins, rich tips, purchases, rank up

| moment | what you see | tool | budget | hook | P |
|---|---|---|---|---|---|
| CoinPop | 3 small gold coins pop 1 stud up from the table and fade (0.6 s), next to `UI.floatText`; night owls pop at half the rate | fx | about 4 particles a second for a full cafe | CustomerController.luau:135; low tier keeps the float text only | P1 |
| RichArrive | The rich customer's gold tip pile on the table glitters | fx | 1 emitter, Rate 2 | plot `RichTipAmount` and `RichTipExpiresAt` | P1 |
| RichTipClaim | A fountain of 12 gold coins from the pile; the auto-collect on expiry gets a smaller puff of 4 | fx | 12 particles | `ClaimRichTip` accepted, or the attribute cleared at expiry | P1 |
| Purchase | The new table, chair set or decor drops in from 0.5 studs with a Back Out bounce and 10 sparkles; espresso upgrades add a steam burst and, on the bigger machines, a slow steam wisp (high only) | tween on a `CFrameValue` driving `PivotTo`, fx | 10 particles; steam Rate 1 | a model appearing under its anchor | P1 |
| RankUp | Palette confetti at the cafe door (16 particles), the new expansion floor rises into place with sparkles along its edge, each newly opened role station gets a soft ring | tween, fx | 16 plus 1 per new station | plot `Tier` rising | P1 |
| AreaUnlock | The area's gate leaves swing open (0.8 s Back Out) with a sparkle arch, for the player who ranked up | tween, fx | 12 particles | the player's tier reaching the gate's tier | P1 |

## 8. Day, night and the dealer

The 4 s lighting change and the night parts turning Neon with their lights already exist (WorldController.luau, style guide section 9). Days and nights are 5 minutes each now and the cafe stays open at night.

| moment | what you see | tool | budget | hook | P |
|---|---|---|---|---|---|
| lamp halos | One soft warm halo per lit bulb (street lamps, string lights, shop windows, the dealer's lantern), fading in with the lighting change | fx (1 locked particle, LightEmission 1, Size 2.5, Transparency 0.6) | bulbs within 80 studs, about 12 particles | NightStart, night parts by suffix | P1 |
| cafe sign | The sign flips from sun to moon and back (rotate 90 degrees, swap faces, rotate back, 0.4 s) | tween | none | Clock `Phase` | P1 |
| wave arrival | Each of the ten new strays per area appears with a soft puff, staggered 0.1 s apart so ten puffs never land on one frame | fx | 6 particles each, 60 per area over 1 s | NightStart plus new `Stray` tags | P1 |
| DealerArrive | The cart rolls the last 10 studs into place over 3 s (a local tween towards the server position), its lantern lights, the stars on the cart twinkle; the dealer idles with Roblox's own default R15 idle | tween, fx, Roblox-owned idle animation | 1 emitter, Rate 1 | `DealerCart` tag, `Open` | P1 |
| dealer purchase | A swirl of 6 star sparkles over the cart as the food changes hands | fx | 6 particles | Purchase with a dealer food id | P2 |
| DealerLeave | The lantern dims and the cart rolls off at dawn | tween | none | `Open` false | P2 |
| street lamp cone | A faint light cone under each street lamp | fx (Beam, Transparency 0.88, Segments 1) | 1 per lamp within 80 studs | NightStart | P2 |
| window shafts | One warm light shaft from each lit shop window onto the alley floor | fx (Beam) | 1 per window within 60 studs | NightStart | P2 |
| fireflies | Three slow fireflies near park plants and the patio | fx | 2 emitters at most, Rate 1, Lifetime 4 s, high only | NightStart | P2 |
| DayStart | Halos and beams fade with the lighting; working cats stretch once (head and tail up, 0.8 s) | fx, proc | none | DayStart | P2 |

## 9. Worst case on a phone (low tier)

Night start in the Alleyway: ten strays arriving with a shiny among them, a trap rescue going on, one bump nearby, other cafes out of range.

| source | particles alive |
|---|---|
| wave arrival puffs (halved, staggered over 1 s) | about 20 at the peak |
| lamp halos | 12 |
| shiny strays (2 at most in view) | 6 |
| occupied traps (3) | 3 |
| rescue hits | 2 |
| BumpLoose boop and dust | 4 |
| a Mythical catch burst (halved) | 15 for 0.8 s |
| total | about 62, against the 150 budget |

Highlights in that scene: one from the catch and at most two outlines. Trails: one. The procedural loop covers about 10 strays, 3 trapped cats and 2 held cats within 60 studs. A Tier 5 cafe on the same phone adds 10 working cats to the loop and about 2 coin particles alive. The numbers get measured in Studio once A0.1 to A0.4 exist.

## 10. Requests to other roles

- **luau-engineer**: A0.1 cat rig, A0.2 upright through the rig with uniforms welded to Body or Head, A0.3 Moments, A0.5 `Exit` attribute (including `tamed` and `letgo` for the bait cat), A0.6 the net on the hand. The bait cat model at the plot's `BaitBowl` once `BaitReadyAt` has passed. The dropped stray's scurry moved by `Mover` on the server at a scurry speed, so Effects only adds the run cycle. Noticed while planning, not an Effects matter: strays walk by the server calling `PivotTo` every Heartbeat (Mover.luau), which sends every stray's position every frame; with ten per area it is worth a look if the night alley lags on phones.
- **asset-artist**: a palette swatch for Mythical (the designer proposes #FF5E7E; palette row 7 is spare) so the Mythical burst stays on the palette; trap lids (`TrashBin`, `TrashCan`) and the tree branch as their own objects so they can move; the dealer's lantern bulb named with the `_Bulb` suffix so the night glow picks it up; the `NetGrip` offset per net; front paws as their own objects on the upright cat if waving and cup holding are wanted (P3).
- **game-designer**: features.md section 5 lists "Shiny sparkle VFX, `CatCafe_VFX_ShinySparkle`" for the asset thread. Proposal: it is the vfx-animator's `ShinySparkle` preset in `src/client/Effects/Presets.luau`, built in code like the placeholder, not a model in `assets/`. Also open question 2 below.
- **ui-designer**: none required. The circles, the rescue bar and the bump prompt stay yours; Effects only answers them in the world.
- **sound-designer**: same moment names; markers in published clips (`Land`, `Pounce`) can fire sound cues too.

## 11. Build order

1. A0.1 to A0.4 (rig, upright through the rig, Moments, Effects skeleton), then the four role idles, stray walk and carried idle. Every later item reuses these.
2. Net circles: CatchStart, NetSwing, CircleGrade, CatchSuccess by rarity, CatchFail, StrayFlee (A0.5, A0.6).
3. Shiny on sight and ShinyReveal.
4. Rescue traps: stuck idle, hits, misses, the tree drop, done.
5. Bumps: BumpLoose with the protect ring, BumpHeld.
6. Bait bowl: placed, arrive and eat, tame.
7. Coins, rich tips, purchases, rank up, gates.
8. Night: halos, sign flip, wave arrival, the dealer.
9. The first published clip (the R15 arm swing) to prove the ownership flow before anything depends on clips; then P2 items in the order the playtest asks for them.

## 12. Open questions

1. Upright cats (Gavin, question 15) are settled: working cats stand up. The three-part rig handles it through the Body joint (the asset thread proved the pose in PR #24), so Blender skinned rigs still wait until after the slice. Waving greeters and cup-holding baristas need front paws as their own objects (P3, asset-artist).
2. Outlines: drawing Legendary and Mythical outlines through walls (`DepthMode = AlwaysOnTop`) would work as a radar in a first-catch-wins race, and shiny strays already sparkle on sight. The draft keeps outlines `Occluded`; the game-designer decides.
3. Reduce Motion: the draft drops idle loops except breathing when the player has Reduce Motion on, which also stills the entertainer's dance. Derek, say if you would rather keep the dance and the tail wag.
