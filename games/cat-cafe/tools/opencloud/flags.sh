#!/usr/bin/env bash
# Read or change the live switches in the data store CatCafe_Flags through Open Cloud, so trading can be turned off
# (or its minimum tier changed) in every running server without a publish. TradeVault.flags
# (src/server/Services/TradeVault.luau) reads both keys every Config.TradeFlagCheckSeconds (60 s):
#   trading       false turns trading off everywhere; anything else (or no entry) leaves it on
#   tradeMinTier  a number 0 to 99 is the live minimum cafe tier; anything else (or no entry) means Config.TradeMinTier
# and LiveFlagService (src/shared/LiveFlags.luau) reads five more the same way, true or false. Only false turns off:
#   codes         false pauses code redeeming
#   rally         false stops the Rescue Rally
#   tradeCrates   false takes crates out of trading (#2745, trading.md section 1c); cat and decor trades go on
#   awayNotes     false stops the game noting who is due an away notification (#2768), if the notes crowd MemoryStore
#   starterRefill false stops the starting areas' camp trap refilling by day for players who never rescued (#3049)
#   swiftPaws     false hides the Golden Fish Market's Swift Paws perk and drops its speed (#3063); levels are kept
#   alleyBin      false hides the Rummage Bin at the Alleyway camp and refuses a rummage (#3050); its waits are kept
#   arcade        false hides the Cat Arcade's prompt and menu tile (#3062); a game already running finishes and pays
#   circleStreak  false vaults Circle Streak (#3296): no start from the cabinet, the Menu row or the remote; its
#                 save and board stay. The swap is mouseDash true and this false
# and some start off, so only true turns them on (LiveFlags.OFF_BY_DEFAULT):
#   nightCatch    true lets a Tier 1 player in their first session keep catching in the Alleyway at night (#3035);
#                 false or no entry is the normal night for them
#   goldenDrops   true starts the rare drop-only Golden lawn pieces from freed cats (#3222); only once no older
#                 server is running
#   traits        true opens the Cat Trainer's cat traits (#3196); only with or after the restart publish that ships
#                 the trait save fields
#   swiftPaws5    true opens Swift Paws levels 3 to 5 in the Fish Market (#3317); only once no server older than
#                 the publish that added them is running (an older one keeps a saved level only up to 2)
#   mouseDash     true makes Mouse Dash the Cat Arcade's game (#3296); only after QA passes
#   cartTier6     true opens the Day Cart's Tier 6 shelf (#3462); only once every server runs a build that has it
#   secretCats    true lets Secret cats roll (#3470); only once every server runs a build that has them
#   luckyCharm    true shows and sells the Fish Market's Lucky Charm perk and counts its Luck (#3298); only once
#                 every server runs a build that has it (an older one drops the saved perk level)
#   rareCatsTab   true gives the chat its own "Rare Cats" tab with every Mythical or better line (#3053); only
#                 after Derek has seen the pictures (he asked for no tab of our own on 2026-11-10)
#   loadingScreen true brings back the loading screen before the opening scenes (#3179: Derek had it removed);
#                 false or no entry is no loading screen. Players who join after the change see it
#   tradeFish     true lets golden fish into trades (#2745, section 1d). Turn it on only after QA and the security
#                 review pass, and after a restart publish, so no old server settles a fish record without the fish
# Run by .github/workflows/flags.yml; also works from Git Bash on a PC with the same variables set.
#
#   ROBLOX_PUBLISH_KEY   Open Cloud API key that also has universe-datastores.objects:read, :create and :update on
#                        the Cat Cafe experience (docs/setup-guide.md step 24)
#   UNIVERSE_ID          default below
#
# Usage:  tools/opencloud/flags.sh show
#         tools/opencloud/flags.sh set trading true|false
#         tools/opencloud/flags.sh set tradeMinTier <0-99>
#         tools/opencloud/flags.sh set codes|rally|tradeCrates|awayNotes|starterRefill|swiftPaws|alleyBin|arcade|circleStreak|tradeFish|nightCatch|loadingScreen|goldenDrops|traits|swiftPaws5|mouseDash|cartTier6|secretCats|luckyCharm|rareCatsTab true|false
#         tools/opencloud/flags.sh clear trading|tradeMinTier|codes|rally|tradeCrates|awayNotes|starterRefill|swiftPaws|alleyBin|arcade|circleStreak|tradeFish|nightCatch|loadingScreen|goldenDrops|traits|swiftPaws5|mouseDash|cartTier6|secretCats|luckyCharm|rareCatsTab
# clear writes the text "config" for trading and tradeMinTier, which TradeVault reads as unset (trading on, Config's
# minimum tier), true for codes, rally, tradeCrates, awayNotes, starterRefill, swiftPaws, alleyBin, arcade and circleStreak, and false for tradeFish, nightCatch, loadingScreen, goldenDrops, traits, swiftPaws5, mouseDash, cartTier6, secretCats, luckyCharm and rareCatsTab (their default), so no key needs delete
# permission. Every change reads both keys back. Needs curl and jq (both on GitHub's ubuntu runners).
set -euo pipefail

UNIVERSE_ID=${UNIVERSE_ID:-10773193456}
STORE=CatCafe_Flags # TradeVault.FLAGS
: "${ROBLOX_PUBLISH_KEY:?set ROBLOX_PUBLISH_KEY (docs/setup-guide.md step 24)}"
entries=https://apis.roblox.com/cloud/v2/universes/$UNIVERSE_ID/data-stores/$STORE/entries

usage() {
	echo "usage: flags.sh show | set trading true|false | set tradeMinTier <0-99> | set codes|rally|tradeCrates|awayNotes|starterRefill|swiftPaws|alleyBin|arcade|circleStreak|tradeFish|nightCatch|loadingScreen|goldenDrops|traits|swiftPaws5|mouseDash|cartTier6|secretCats|luckyCharm|rareCatsTab true|false | clear trading|tradeMinTier|codes|rally|tradeCrates|awayNotes|starterRefill|swiftPaws|alleyBin|arcade|circleStreak|tradeFish|nightCatch|loadingScreen|goldenDrops|traits|swiftPaws5|mouseDash|cartTier6|secretCats|luckyCharm|rareCatsTab" >&2
	exit 2
}

reply=$(mktemp)
trap 'rm -f "$reply"' EXIT
# call method url [curl args...] -> sets $status and $body. Roblox answers 5xx or 429 now and then, so those get
# three more tries over about half a minute.
call() {
	local method=$1 url=$2 wait
	shift 2
	for wait in 5 10 20 0; do
		status=$(curl -sS -o "$reply" -w '%{http_code}' -X "$method" "$url" -H "x-api-key: $ROBLOX_PUBLISH_KEY" "$@") ||
			status=000
		case "$status" in
		5?? | 429 | 000) ;;
		*) break ;;
		esac
		[ "$wait" = 0 ] && break
		echo "Open Cloud answered HTTP $status; trying again in ${wait}s." >&2
		sleep "$wait"
	done
	body=$(cat "$reply")
}

fail() {
	echo "Open Cloud answered HTTP $status: $body" >&2
	case "$status" in
	401 | 403) echo "The key needs universe-datastores.objects:read, :create and :update on universe $UNIVERSE_ID (docs/setup-guide.md step 24)." >&2 ;;
	esac
	exit 1
}

# show_key key -> prints "key = value" as the servers will read it
show_key() {
	local key=$1 raw meaning
	call GET "$entries/$key"
	if [ "$status" = 404 ]; then
		raw="(no entry)"
	elif [ "$status" = 200 ]; then
		raw=$(jq -c '.value' <<<"$body")
	else
		fail
	fi
	case "$key" in
	trading)
		if [ "$raw" = false ]; then meaning="trading OFF in every server"; else meaning="trading on"; fi
		;;
	codes) if [ "$raw" = false ]; then meaning="code redeeming PAUSED in every server"; else meaning="codes on"; fi ;;
	rally) if [ "$raw" = false ]; then meaning="Rescue Rally OFF in every server"; else meaning="rally on"; fi ;;
	tradeCrates) if [ "$raw" = false ]; then meaning="crate trading OFF in every server"; else meaning="crate trading on"; fi ;;
	awayNotes) if [ "$raw" = false ]; then meaning="away notes OFF in every server (no new away notifications)"; else meaning="away notes on"; fi ;;
	starterRefill) if [ "$raw" = false ]; then meaning="starter trap refill OFF in every server (one cat a day there)"; else meaning="starter trap refill on"; fi ;;
	swiftPaws) if [ "$raw" = false ]; then meaning="Swift Paws OFF in every server (row hidden, no speed)"; else meaning="Swift Paws on"; fi ;;
	alleyBin) if [ "$raw" = false ]; then meaning="Rummage Bin OFF in every server (prompt hidden)"; else meaning="Rummage Bin on"; fi ;;
	arcade) if [ "$raw" = false ]; then meaning="Cat Arcade OFF in every server (no new games)"; else meaning="Cat Arcade on"; fi ;;
	tradeFish) if [ "$raw" = true ]; then meaning="golden fish trading ON in every server"; else meaning="golden fish trading off (its default)"; fi ;;
	nightCatch) if [ "$raw" = true ]; then meaning="first-session night catching ON in every server"; else meaning="first-session night catching off (its default)"; fi ;;
	loadingScreen) if [ "$raw" = true ]; then meaning="loading screen ON before the opening scenes in every server"; else meaning="no loading screen (its default)"; fi ;;
	goldenDrops) if [ "$raw" = true ]; then meaning="Golden lawn drops ON from freed cats in every server"; else meaning="Golden lawn drops off (its default)"; fi ;;
	traits) if [ "$raw" = true ]; then meaning="Cat Trainer traits ON in every server"; else meaning="Cat Trainer traits off (its default)"; fi ;;
	swiftPaws5) if [ "$raw" = true ]; then meaning="Swift Paws levels 3 to 5 ON in every server"; else meaning="Swift Paws stops at level 2 (its default)"; fi ;;
	mouseDash) if [ "$raw" = true ]; then meaning="Mouse Dash ON in every server (the Cat Arcade's game)"; else meaning="Mouse Dash off (its default)"; fi ;;
	cartTier6) if [ "$raw" = true ]; then meaning="Day Cart Tier 6 shelf ON in every server (its own baits and potions)"; else meaning="Day Cart Tier 6 shelf off (its default)"; fi ;;
	secretCats) if [ "$raw" = true ]; then meaning="Secret cats ON in every server"; else meaning="Secret cats off (its default)"; fi ;;
	luckyCharm) if [ "$raw" = true ]; then meaning="Lucky Charm perk ON in every server"; else meaning="Lucky Charm perk off (its default)"; fi ;;
	rareCatsTab) if [ "$raw" = true ]; then meaning="Rare Cats chat tab ON in every server"; else meaning="Rare Cats chat tab off (its default)"; fi ;;
	circleStreak) if [ "$raw" = false ]; then meaning="Circle Streak VAULTED in every server (no new games)"; else meaning="Circle Streak on"; fi ;;
	tradeMinTier)
		if [[ $raw =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
			meaning="live minimum tier $(jq -n "[[$raw | floor, 0] | max, 99] | min")"
		else
			meaning="Config.TradeMinTier"
		fi
		;;
	esac
	echo "$key = $raw ($meaning)"
	[ -z "${GITHUB_STEP_SUMMARY:-}" ] || echo "- \`$key\` = \`$raw\`: $meaning" >>"$GITHUB_STEP_SUMMARY"
}

show() {
	echo "== $STORE (servers pick a change up within about 60 s)"
	[ -z "${GITHUB_STEP_SUMMARY:-}" ] || echo "### $STORE" >>"$GITHUB_STEP_SUMMARY"
	show_key trading
	show_key tradeMinTier
	show_key codes
	show_key rally
	show_key tradeCrates
	show_key awayNotes
	show_key starterRefill
	show_key swiftPaws
	show_key alleyBin
	show_key arcade
	show_key tradeFish
	show_key nightCatch
	show_key loadingScreen
	show_key goldenDrops
	show_key traits
	show_key swiftPaws5
	show_key mouseDash
	show_key circleStreak
	show_key cartTier6
	show_key secretCats
	show_key luckyCharm
	show_key rareCatsTab
}

# write key json-value
write() {
	local key=$1 value=$2
	call PATCH "$entries/$key?allowMissing=true" -H "Content-Type: application/json" \
		--data "$(jq -cn --argjson v "$value" '{value: $v}')"
	[ "$status" = 200 ] || fail
	echo "Wrote $key = $value"
}

action=${1:-show}
case "$action" in
show)
	[ $# -le 1 ] || usage
	;;
set)
	[ $# -eq 3 ] || usage
	case "$2" in
	trading | codes | rally | tradeCrates | awayNotes | starterRefill | swiftPaws | alleyBin | arcade | circleStreak | tradeFish | nightCatch | loadingScreen | goldenDrops | traits | swiftPaws5 | mouseDash | cartTier6 | secretCats | luckyCharm | rareCatsTab) [[ $3 == true || $3 == false ]] || usage ;;
	tradeMinTier) [[ $3 =~ ^[0-9]{1,2}$ ]] || usage ;;
	*) usage ;;
	esac
	write "$2" "$3"
	;;
clear)
	[ $# -eq 2 ] || usage
	case "$2" in
	trading | tradeMinTier) write "$2" '"config"' ;;
	codes | rally | tradeCrates | awayNotes | starterRefill | swiftPaws | alleyBin | arcade | circleStreak) write "$2" true ;;
	tradeFish | nightCatch | loadingScreen | goldenDrops | traits | swiftPaws5 | mouseDash | cartTier6 | secretCats | luckyCharm | rareCatsTab) write "$2" false ;;
	*) usage ;;
	esac
	;;
*) usage ;;
esac
show
