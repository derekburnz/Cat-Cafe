# Auto Equip: free, automatic Equip Best (Set 11 Q3)

Status: specced 2026-11-07 by Design-Agent (friend's project). Derek2, Set 11 Q3: "no need to make that pass just make that a free feature". This replaces #1168's R$99 Auto Equip pass idea, and nothing about it is sold. Builders: Gameplay-Engineer (server) and UI-Engineer (toggle).

- **What it does:** with Auto Equip on, the server runs Equip Best (`shared/EquipBest.luau`, the same algorithm as the button) whenever the player gets a cat that would change the best lineup: a check-in, a tamed bait cat, a level up that changes ratings, a trade or a rank-up that adds slots. It also runs once on join.
- **Never moves a locked cat**, a cat the player placed by hand in the last 10 minutes, or a cat being carried, traded or rescued. Placing a cat by hand doesn't switch Auto Equip off. That one slot just stays as the player set it for 10 minutes.
- **Toggle:** a small "Auto" switch next to the Equip Best button in My Cats, plus the same switch in Settings. It's **on by default** for new accounts and off for existing ones until they turn it on. It's saved as `settings.autoEquip` with no version bump (an optional field).
- **Feedback:** when Auto Equip swaps a cat in, a small toast says "Auto Equip: Mochi is now your Barista (+12/s)". Several swaps within 2 seconds become one toast.
- **Rate limit:** at most one auto run every 3 seconds per player. Runs that come in between are merged.
- **QA:** a fresh account's first better cat gets equipped with the toast, a locked cat never moves, and with the toggle off nothing moves. No new console errors.
