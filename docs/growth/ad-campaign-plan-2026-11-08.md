# First ad campaign: what works on Roblox, and the week-one plan (2026-11-08, #2422)
Owner: growth-analyst (Monetization-Agent). Asked by Derek2 on 2026-11-08 (his words are quoted in #2422). This is a plan only. Nothing in the ad account, store page, prices or settings changes without Derek2 doing it or saying yes. It replaces the "days 2 to 8" ad line in `first-four-weeks-2026-11-07.md`; the daily read in that file stays.

## The "good" bar (Derek2's numbers)
| Metric | Good | How it is worked out | Where to read it |
|---|---|---|---|
| CTR (click-through rate) | above **2.5%** | clicks / impressions | Ads Manager table, per thumbnail |
| CPP (cost per play) | under **$0.008** | spend / plays (1 ad credit = $1 assumed) | Ads Manager table, per thumbnail |
| Click-to-play (added by me) | above about **5%** | plays / clicks | Ads Manager table, per thumbnail |

At $0.008 a play, $10 to $15 a day buys about 1,250 to 1,900 plays a day, or about 9,000 to 13,000 plays in the week. I added click-to-play because a DevForum report shows two thumbnails with the same CTR (2.6% and 2.7%) where one got 2 plays from 852 clicks and the other 37 plays from 466 clicks. CTR alone would have kept the wrong one.

## What the research says (short)
1. **Ads do not make Home recommendations by themselves.** Roblox's Discovery FAQ says engagement and retention from ad players are left out of the Recommended For You (RFY) ranking, and ads never down-rank a game. RFY only uses players who joined from the RFY tile. So ads do two jobs for us: they get the game its first plays (RFY needs "only a very low minimum number of plays from any source" to start testing it), and they tell us which pictures and which first minutes work. The Home recs then come from how organic RFY players behave.
2. **What RFY rewards (June 2026 update).** Play-through rate (PTR: people who see the tile and play), first-play bounce rate, play days, playtime, co-play days and spend days, measured over day 1, days 2 to 7 and days 8 to 28. Signals are averages per player, so a small game with players who come back is not at a disadvantage. New games are tested daily from day one and are not punished for a weak start. Creator Hub shows the signals under Acquisition > Home Recommendations.
3. **RFY can dip while ads run.** Players who already came through an ad are not shown the game again in RFY, so RFY impressions can look lower during the ad week. That is not a penalty, and it is why the gates below read RFY as a trend, not a single day.
4. **Ads Manager facts.** Placements are Home and Search together. One campaign holds up to **10 thumbnails** (16:9), which fits Derek2's 6 to 10 ads in one campaign. Objectives are Plays, Earnings and Engagement; Engagement costs more per play, so we use **Plays**. Audience: **New Players** (never played, or not in 180 days); Recent and Lapsed need 10,000 and 20,000 players, so they are not open to us yet. Bidding is automatic: we set a daily budget and Roblox sets the bid. **Plays can take up to 48 hours to show up** (impressions and clicks are live), which matters for the day 2 to 3 cut.
5. **Thumbnails that win** (Roblox staff tips on thumbnail personalization, Feb 2025): make each one clearly different (a different player reason to play, not the same scene recoloured), show real gameplay and new content, never clickbait (it can trigger low-quality warnings and players bounce). Games that tested up to 5 organic thumbnails saw an average +12% in play-through, up to +56%. Don't restart a thumbnail test before 7 days or the next update.
6. **What popular games do.** Grow a Garden: a friendly, non-competitive loop, a clear hook on the icon ("Grows Offline"), and an update at a fixed time every Saturday with a limited-time event, so players learn when to come back. SpongeBob Tower Defense shipped 52 weekly updates in a row. Deconstructor of Fun's 2026 read: Roblox ads cost "less than a penny per user" and are best for starting the flywheel and boosting after a big update; Home recommendations are the real engine, and the thumbnail, details page and first minutes are what move them.

## The 10 starting thumbnails (Derek2: start with 6 to 10)
The finished pictures are in `store-art/2026-11-08-ads/`, and its README has the claim check for each one. Each picture shows a different reason to play, uses the game's own models, and shows nothing paid.
| # | Hook | File |
|---|---|---|
| 1 | Cats at work, serving customers (Derek2, 2026-11-08) | `Ad_01_CatsAtWork.png` |
| 2 | Cute cat and the brand | `Ad_02_BellhopCafe.png` |
| 3 | Catch moment (Mythical) | `Ad_03_MythicalCatch.png` |
| 4 | Income (+$6,075/s) | `Ad_04_TopEarner.png` |
| 5 | The night dealer: rare foods every night | `Ad_05_NightDealer.png` |
| 6 | Earn while offline (Derek2, 2026-11-08) | `Ad_06_EarnOffline.png` |
| 7 | Rescue stuck cats | `Ad_07_RescueCats.png` |
| 8 | Rainbow cats, x2 money | `Ad_08_RainbowCats.png` |
| 9 | Collection: 50 cats to catch | `Ad_09_FiftyCats.png` |
| 10 | Golden cats | `Ad_10_GoldenCats.png` |
Next round (needs new Blender renders): friends rescuing cats together, and a cozy night cafe.

## The 16+ limit and the 250 highly engaged players (Derek2, 2026-11-08)
Until the game passes the Kids and Select evaluation, both Ads Manager and Roblox only show it to players 16 and over. The game becomes eligible for Kids and Select audiences once it has **250 unique plays by highly engaged, age-checked players 16+ within 60 days**, counted hourly in Creator Hub > Audience Reach. Roblox says a highly engaged player has an older account, has played your game for a while, and has bought something anywhere on Roblox in the last 60 days. It does not publish the exact numbers. A highly engaged player does not have to spend in our game.

**Estimate of the plays needed.** Derek2's friend's game, which started running ads in November 2026, sees **2 highly engaged plays in every 100** ad plays (Derek2, 2026-11-08). That is the real number we plan with. My earlier guess was 2 to 9 in 100, with 5 as the middle, so this sits at the bottom of that range. At 2 in 100, 250 qualifying plays takes about **12,500 ad plays**, which costs about **$100** at our $0.008 bar, or more if our CPP is worse. That is about the whole week's budget, so expect to reach it near day 7, not day 3. Ads Manager also has an **Engagement** objective that aims only at players who count toward this threshold. It costs more per play, and one DevForum report says it only reached a few players at a time.

**Changes to the plan:**
- Run the Plays campaign as planned. Each day, read Audience Reach next to the ad table.
- If Audience Reach is under about 60 by the end of day 3 (on track at 2 in 100 is roughly 35 to 40 a day), move $3 to $5 a day into a small Engagement campaign using the best 1 or 2 thumbnails.
- Until eligibility, every number comes from a 16+ audience, and our game is made for younger players. CTR, retention and Home recs will probably look weaker than they will after eligibility. So:
  - The day 5 gate is read as "Some" at worst while eligibility is pending.
  - Once eligibility lands, the week clock restarts for the gates: one more week of ads at the same budget, now reaching all ages, before the strong / some / none call.
- Kids and Select needs the game's maturity questionnaire to say Minimal or Mild. The same Audience Reach page shows the age result.
- Roblox also offers a 50,000 Robux expedited review. It is refundable but slow to pay for and does not skip the 250, so I do not recommend it.

## Which day to start
It matters a little, not a lot. Roblox traffic peaks on weekends and school holidays, so a weekend gives more plays for the same budget, but Ads Manager sets the bid automatically, and weekend CPP can rise with competition. **Start on a Thursday.** Days 2 and 3 (Friday and Saturday) then give the busiest data for the cuts. The week includes one full weekend. Day 5 lands on Monday, so an event update for week 2 can be ready for the next Saturday, which is the day Grow a Garden also updates. Avoid starting just before a big platform event (a Roblox-wide event or a top game's major update), when ad prices jump.

## The week, day by day (Derek2's plan with numbers)
Ad day 1 is launch day 2 (launch day 1 stays friends-only, per the launch plan).
| Ad day | Spend | What happens | Decision rule |
|---|---|---|---|
| 1 | $10 to $15 | One Plays campaign, New Players, all 10 thumbnails, daily budget. Targeting left broad (all devices, all locations Roblox offers) unless Derek2 picks otherwise. | none, just let it run |
| 2 | same | First look. Plays may still be catching up, so judge on CTR and clicks. | Pause any thumbnail under **1.5% CTR** with at least 2,000 impressions. |
| 3 | same | Plays from day 1 are in now. | Pause any thumbnail with CPP over **$0.016** (twice the bar) or click-to-play under 2%, once it has 100 or more clicks. Keep at most 4 to 5. |
| 4 | same | Run the survivors. | Lower or pause the weakest if one is clearly behind on CPP. |
| 5 | same | **Checkpoint.** Keep the best 2 to 3, different from each other. Read RFY (below). If the game is doing decently (gate "Strong" or "Some" below), raise to about **$15 to $20** and add 1 to 2 new thumbnails built on what won. | see gates |
| 6 to 7 | $10 to $20 | Run the 2 to 3 winners plus the 1 to 2 new ones. | End-of-week gate. |

A thumbnail with too few impressions to judge (under 2,000 by day 3) is neither kept nor cut; Roblox's auto bidding may be starving it, and I flag that.

Week total: about **$70 to $105**, up to about $125 if the day 5 raise happens.

## The gates (day 5 and day 7)
Roblox does not publish an RFY threshold, so these lines are my starting guesses for Derek2 to change. "RFY" means Home recommendation impressions and plays in Creator Hub (Acquisition > Home Recommendations), read as a day-by-day trend.
| Gate | What it looks like | What we do |
|---|---|---|
| **Strong** | RFY impressions rising most days, and organic RFY plays a day getting close to or above ad plays a day | Stop ads at the end of the week and let it grow. Start the weekly update rhythm (one fixed day and time, Saturday like Grow a Garden) from the drop menu in `first-four-weeks-2026-11-07.md`. Use ads again only to boost a big update. |
| **Some** | RFY impressions every day but flat or small (a few thousand a day or less) | Ship an event update (Rescue Rally weekend or Lucky Day Saturday from the drop menu, both nearly ready) and run a second ad week with the 2 to 3 winners plus fresh thumbnails that show the event. Same gates at the end. |
| **None** (day 5 onward) | RFY near zero after 5 days **and** bad stats (CTR under 2.5% or CPP over $0.008 on the best thumbnail, or D1 under 8%, or a big first-minute bounce) | Stop ads. Derek2 chooses: (a) stop and keep it as a learning project, or (b) make big changes and try one last week. |

What "big changes" means, in the order I'd check them:
1. **First minutes.** If `new_player_left` shows most leave in 0 to 60 seconds or at one tutorial step, fix that first; first-play bounce now feeds RFY directly.
2. **Thumbnail and icon.** If the best CTR is under 2.5%, new art with a clearer hook.
3. **Coming back.** If D1 is under 8%, a reason to return tomorrow (daily gift, a cat that only shows up on certain days, the Saturday event).

## What I need each day (from Derek2, since I can't open Ads Manager or Creator Hub)
- A screenshot of the Ads Manager table split by thumbnail (impressions, clicks, plays, CPP, spend).
- From day 3 on, the Creator Hub Acquisition > Home Recommendations chart.
I turn those plus our own events (`session_start` join source, `session_end`, `new_player_left`) into the daily read and a one-line keep or cut list. I never change the campaign myself.

## Young-audience rules for every ad
Accurate pictures of the real game, no fake prizes or "free Robux", no countdowns or "hurry", nothing paid in the picture, original art only (no other games' characters).

## Sources
- Roblox Ads Manager docs: https://create.roblox.com/docs/production/promotion/ads-manager
- Roblox Discovery FAQ: https://create.roblox.com/docs/discovery-faq
- RFY update, June 2026: https://devforum.roblox.com/t/recommended-for-you-algorithm-improvements-that-better-value-long-term-retention/4684575
- Staff thumbnail tips, Feb 2025: https://devforum.roblox.com/t/5-tips-from-roblox-staff-to-get-the-most-out-of-thumbnail-personalization/3471689
- CTR vs plays example: https://devforum.roblox.com/t/need-advice-on-my-games-ad-performance-and-next-steps/4760265
- Grow a Garden: https://newsletter.gamediscover.co/p/what-grow-a-gardens-89-million-ccu
- Deconstructor of Fun, 2026: https://www.deconstructoroffun.com/blog/how-to-build-a-real-business-on-roblox-in-2026
