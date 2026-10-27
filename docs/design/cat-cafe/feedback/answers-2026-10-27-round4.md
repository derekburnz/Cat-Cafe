# Answers to round 4, questions 1 to 16 (2026-10-27)

All sixteen round 4 questions were answered on the bullets under them in the Cat Cafe tab of the Game Ideas Google Doc. Derek relayed it on 2026-10-27 at 20:09 UTC: "google doc feedback updated save and delete it and also delete the paragraph above explaining what has been saved just have new questions and #set of questions and put set 4 questions there for what you might need me or gavin to answer". The doc does not say who wrote each answer, so this file does not either. The questions below are the ones in the doc (round 3 questions 7 to 22, renumbered); each answer is copied word for word from its bullet. What changed in the design because of them is in [data-model.md](../data-model.md) (v0.10 notes), [golden-fish.md](../golden-fish.md), [features.md](../features.md) section 2g, [area-ideas.md](../area-ideas.md) and docs/decisions.md. The next questions are Set 4 in [questions-for-gavin.md](../questions-for-gavin.md). Round 3's first six answers are in [gavin-2026-10-27-round3.md](gavin-2026-10-27-round3.md).

## Questions and answers

### Catching controls

**Q1. Hold to start.** You now hold E for half a second to start a catch, so walking past a cat never starts one by accident. Then the circles pop up and you press Space as each ring closes. Does the hold feel right, or should it be shorter or a single tap?

> I think the hold is fine for now.

**Q2. One miss or enough hits.** Right now one miss ends the catch and the cat runs off. Should it instead be "hit enough of them", for example 2 of 3 for an Epic, so one slip doesn't lose the cat? Our plan: keep one miss ends it, because tries are unlimited and the chase is part of the fun.

> I agree

**Q3. Circles by rarity.** A Common has 1 circle, a Rare 2, an Epic 3, a Legendary 4 and a Mythical 5, and each ring closes faster the rarer the cat (1.4 seconds for a Common down to 0.65 for a Mythical). Too many, too few or about right?

> Sounds good for now

**Q4. Drop button.** While carrying, the Drop button (or G) puts the cat down. In a catching area it lands at your feet and anyone can pick it up with the half-second hold, the same as a cat knocked loose by a shove (your round 3 answer); anywhere else it runs back to its own area. Is that what you'd expect, or should dropping let the cat go for good?

> Dropping it makes it start walking back to its original spot but still able to be picked up until it makes it back if it makes it back then need to be caught again

### Safe zone

**Q5. Where it starts.** Red SAFE ZONE stripes mark where each catching area ends, and on the cafe side nobody can shove. Should the safe zone start at those stripes (our plan), or only at your own cafe door, so the walk home down the street is risky too? (Picture: the red SAFE ZONE line under the arch where Alley Square meets the cafe street.)

> safezone at stripes.

### Cats and outfits

**Q6. Themed cats.** Derek wants the cats to be more than colours, so every Rare and rarer cat becomes a character with one prop. Alleyway: Pirate Cat (eye patch), Rocker Cat (mini guitar), DJ Cat (headphones), Bandit Cat (eye mask), Ninja Cat (headband), Wizard Cat (wizard hat). Park: Nerd Cat (round glasses), Explorer Cat (safari hat), Sleepy Cat (nightcap), Fancy Cat (top hat and monocle), Fairy Cat (wings), Astro Cat (space helmet). Commons stay plain cats, so a prop means a rarer cat. Any you'd rename, swap or add? Ideas for the Neighbourhood, Woods and Sewer are welcome too. (Picture: the themed cats.)

> good ideas and looks good one or two props is fine do some research for possible ideas for those areas

**Q7. Role outfits.** Working cats wear a two-piece outfit for their job: Barista an apron and cap, Waiter a bow tie and vest, Greeter a sash and straw hat, Entertainer a party hat and cape. A themed cat keeps its own prop and leaves off the outfit piece in the same spot, so a Wizard Cat barista wears the apron and keeps its wizard hat. Good? (Picture: the outfit pieces for each job.)

> Make sure all cats can at least where one tell tale sign of role

**Q8. Gold cats.** Gold cats are the same cat in gold with a sparkle, and they keep their prop. Should the Legendary and Mythical ones also keep their special effects (Ninja Cat's glowing eyes, Wizard Cat's stars, Fairy Cat's petals, Astro Cat's glow), turned gold? Our plan: yes.

> Yes thats a great idea make them special because of rarity

### Rewards and shops

**Q9. Daily rewards.** A 7-day calendar that moves forward one step each day you play; missing a day never sends you back to day 1. Our plan: coins on days 1, 3 and 5 and foods on days 2, 4 and 6. Day 7 gives a Caviar, a free spin and a Classic Crate, because Derek wants decor to come from crates rather than be handed out. Good, or should day 7 be something bigger? (Picture: a daily rewards screen from another game.)

> Thats good I think the day 2/4 rewards should be pretty good also so people come back and 7 be really good like a random legendary or mythical+ cat crate or cosmetic crate up to you

**Q10. Playtime gifts.** Up to 12 gifts you unlock by playing in one session, from 5 minutes up to about 2 hours, each with a countdown. Our plan: coins and foods that get better the longer you play, with free spins on the last ones. Good, or would you rather have fewer, bigger gifts? (Picture: a playtime rewards screen from another game.)

> add a pretty good reward also earlier on like 1 hour so people are inticed to stay on and 2h really good so the regulars will play 2h a day

**Q11. Spin wheel.** A big wheel on the cafe street that you walk up to, not a button (it's in the game now). Everyone gets one free spin a day, and the last two playtime gifts and some Index rewards add more. Spins are never bought with Robux, and every slice shows its chance. Six slices: coins (30% and 18%), 3 Tuna (22%), 2 Salmon (15%), 4 golden fish (10%) and a Cafe Crate (5%). Should a spin ever give a cat? Our plan: no, cats only come from catching, rescuing and bait. (Picture: a spin wheel from another game.)

> sounds good for now make the food for bait noticable rarities so people know whats good also have the odds be a button you can click for the spin so you can see whats likely to hit

**Q12. Index rewards.** Derek asked for rewards worth chasing, so each area's page in the Index has a normal track (3, 6 and all 10 cats) and its own gold track (1, 2, 4, 6, 8 and all 10 gold cats), plus an All Cats track for every different cat you find. Prizes are coins, food, golden fish (our new rare coin with a cat face), wheel spins, Cafe Crates and small "tips forever" bonuses, with a bigger bonus for finishing an area. Anything you'd want for finishing an area or finding every gold cat that isn't there? (Picture: a collection index with a rewards bar from another game.)

> Thats good do different permanent bonuses and big reward bonuses at milestones depending on track also

**Q13. Codes.** Derek wants a Codes Cat on the cafe street: walk up, type a code in the box and it pays once per player, and capitals don't matter. The first code is "playtest" for testers. Got any code words you'd like at launch? (Picture: a settings screen with a code box from another game.)

> launch for release and then we will do ones for milestones hit of concurrent players and likes. Will eventually move game to be owned by my group and then group! can be a code that gives really good rewards but requires people to join the community group

**Q14. Passes.** Robux only buys game passes, one-time with the price shown before you buy: Double Tips, an extra cafe room and decor packs. Nothing random is ever sold for Robux, and food is coins only because it decides which cats come. Any passes you'd add or drop? (Picture: a pass shop from another game.)

> We will make a monetization agent that will do research and decide what to add and what sells well

**Q15. Cafe cosmetics.** Decor now comes from Cafe Crates: one per area plus a Classic Crate, bought with golden fish, each holding 10 pieces (wallpaper, flooring, paint, furniture and decorations) that add a small tip bonus while in use, from +2% for a Common to +25% for a Mythical. The odds show before you open one, and a duplicate gives fish back. Our plan: if we ever sell decor packs for Robux, they are looks only, so paying never makes your cafe earn more. Good? (Picture: a skins screen from another game.)

> Not just looks everything should be possible to obtain in game like cosmetics/cats/items but p2w should also be fine to be not just cosmetic

### New areas

**Q16. Area cats.** Derek asked for ideas for the three locked areas, so here are the themed cats for each (the plain Commons stay as they are). Neighbourhood: Skater Cat (skateboard), Painter Cat (beret), Chef Cat (chef hat), Mail Cat (mail carrier's cap), Super Cat (hero cape), Ice Cream Cat (cone hat). Woods: Scout Cat (backpack), Lumberjack Cat (plaid cap), Mushroom Cat (mushroom cap), Firefly Cat (firefly jar), Antler Cat (mossy antlers), Unicorn Cat (glowing horn). Sewer, a hidden canal town under the city: Miner Cat (hard hat with a lamp), Bubble Cat (bubble pipe), Steampunk Cat (goggles), Diver Cat (snorkel), King Cat (bottle cap crown), Dragon Cat (little wings). Any you'd rename, swap or add?

> These are good for now

## How we read them

- Q1 to Q3 and Q5: the plans stand as built (hold E 0.5 s, one miss ends a catch, 1 to 5 circles, the safe zone at the stripes). Q16: the 18 area cats stand.
- Q4: the Drop button no longer leaves the cat at your feet or sends it straight to its area. The cat walks back to the spot it was caught from at a slow walk, and anyone can pick it up with the hold E on the way. Once it gets there it is a normal stray again and has to be caught with the circles. A cat knocked loose by a shove stays where it fell, as decided in round 3, because the question was about the Drop button.
- Q6: a themed cat may wear one or two props, in different slots. The research for the Neighbourhood, Woods and Sewer is in [area-ideas.md](../area-ideas.md), with second prop ideas for their 18 cats; the picks go to Set 4.
- Q7: every working cat shows at least one piece of its role outfit. The apron, the bow tie and vest and the sash sit on the body, where no prop goes, so baristas, waiters and greeters always show their job. An Entertainer whose props fill both its head and its back wears the party hat in place of its head prop while it works.
- Q8: gold Legendary and Mythical cats keep their effects, turned gold.
- Q9: day 2 and day 4 of the Daily Treat get bigger prizes. Day 7 (the answer left it to us) gives a Golden Classic Crate, a Star Treat, golden fish and spins. The Star Treat is the night dealer's best bait, so day 7 gives a good chance at a Legendary or Mythical cat while cats still only come from catching, rescue and bait.
- Q10: the Tip Jar's 60 minute step becomes a pretty good gift and the 120 minute step a really good one.
- Q11: the spin wheel stands. Every food gets a rarity badge in its colour, and the Spin window gets an Odds button that lists every slice's chance.
- Q12: each Index track gets its own kind of permanent bonus: the normal track keeps tips forever, the gold track gives gold luck forever and the All Cats track makes bait faster forever. The milestones that finish a track get bigger prizes.
- Q13: the launch code is `launch`. Codes for concurrent player and like milestones come later, as the milestones are hit. Once the game belongs to Derek's group, a group code pays really good rewards to group members only.
- Q14: passes wait for the monetization agent.
- Q15: things sold for Robux do not have to be looks only and may help a player, as long as everything can also be earned in the game. The paid random items rules and the young audience rules still apply to anything that is sold.
