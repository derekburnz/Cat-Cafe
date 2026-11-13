#!/usr/bin/env bash
# List the game's badges, or create release badges (#1957, release.md section 1) through Open Cloud's legacy badges
# API, so they no longer need Creator Hub on Derek's PC. Run by .github/workflows/badges.yml.
#
#   badges.sh list                 every badge of the universe (public API, no key): id, name, enabled, how many
#                                  players hold it and got it in the last day, description
#   badges.sh create key[,key...]  creates each listed badge from the table below, at most 5 a run, with its icon from
#                                  assets/cat-cafe/exports/icons/, enabled
#
# Free only: every create sends expectedCost=0, so once the day's free badges are used up Roblox refuses the create
# (error 18, "expected cost mismatch") instead of charging (R$100 each). Nothing here can spend Robux. A key whose
# name already exists on the universe is skipped, so a re-run never makes a duplicate.
#
#   ROBLOX_PUBLISH_KEY  Open Cloud key with legacy-universe.badge:manage-and-spend-robux (the workflow passes OWNER_KEY)
#   UNIVERSE_ID         default below
#   PAYMENT_SOURCE      1 user, 2 group (default; the experience is group owned). With expectedCost=0 nothing is paid.
#
# Prints badge ids, names and errors only, never the key. Needs curl and jq (both on GitHub's ubuntu runners).
set -euo pipefail

UNIVERSE_ID=${UNIVERSE_ID:-10773193456}
PAYMENT_SOURCE=${PAYMENT_SOURCE:-2}
here=$(cd "$(dirname "$0")" && pwd)
icons=$here/../../../../assets/cat-cafe/exports/icons

# key|name|description|icon file (Config.Badges key; the name and one plain line as players see them)
TABLE='rainbowCoat|Rainbow Coat|Find your first rainbow cat.|CatCafe_Icon_Badge_RainbowCoat.png
pageComplete|Page Complete|Fill a whole area page in your Cat Index.|CatCafe_Icon_Badge_PageComplete.png
helpingPaw|Helping Paw|Help another player free a stuck cat.|CatCafe_Icon_Badge_HelpingPaw.png
firstTrade|First Trade|Finish your first trade with another player.|CatCafe_Icon_Badge_FirstTrade.png
purrfectStreak|Purrfect Streak|Land 5 PURRFECT catches in a row.|CatCafe_Icon_Badge_PurrfectStreak.png
partyGuest|Cafe Party Guest|Catch a cat during a Cafe Event.|CatCafe_Icon_Badge_PartyGuest.png
metOwner|Met the Owner|Be in a server while the game'\''s owner is playing.|CatCafe_Icon_Badge_MetOwner.png
firstHome|Home Sweet Home|Carry your first cat home to your cafe.|CatCafe_Icon_Badge_HomeSweetHome.png
firstUpgrade|Fixing Up|Upgrade your cafe for the first time.|CatCafe_Icon_Badge_FixingUp.png
firstFlight|Liftoff|Fly from the cannon for the first time.|CatCafe_Icon_Badge_Liftoff.png
cornerCafe|Corner Cafe|Open your Tier 1 cafe.|CatCafe_Icon_Badge_CornerCafe.png
sunstoneCafe|Sunstone Cafe|Rank your cafe up to Tier 6.|CatCafe_Icon_Badge_SunstoneCafe.png
wonderCafe|Wonder Cafe|Rank your cafe up to Tier 7.|CatCafe_Icon_Badge_WonderCafe.png'

usage() {
	echo "usage: badges.sh list | create key[,key...] (at most 5; keys: $(cut -d'|' -f1 <<<"$TABLE" | paste -sd, -))" >&2
	exit 2
}

existing_names() {
	local cursor="" page
	while :; do
		page=$(curl -sS --fail-with-body "https://badges.roblox.com/v1/universes/$UNIVERSE_ID/badges?limit=100&sortOrder=Asc${cursor:+&cursor=$cursor}")
		jq -r '.data[].name' <<<"$page"
		cursor=$(jq -r '.nextPageCursor // empty' <<<"$page")
		[ -n "$cursor" ] || break
	done
}

list() {
	local cursor="" page
	while :; do
		page=$(curl -sS --fail-with-body "https://badges.roblox.com/v1/universes/$UNIVERSE_ID/badges?limit=100&sortOrder=Asc${cursor:+&cursor=$cursor}")
		# #3617: with how many players hold it and how many got it in the last day (counts only), so a badge that is
		# never awarded stands out
		jq -r '.data[] | "\(.id)  \(.name)  (\(if .enabled then "on" else "off" end))  awarded \(.statistics.awardedCount // "?") (last day \(.statistics.pastDayAwardedCount // "?"))  \(.description)"' <<<"$page"
		cursor=$(jq -r '.nextPageCursor // empty' <<<"$page")
		[ -n "$cursor" ] || break
	done
}

create() {
	: "${ROBLOX_PUBLISH_KEY:?set ROBLOX_PUBLISH_KEY (the workflow passes OWNER_KEY)}"
	local keys=$1 count made=0 failed=0
	IFS=, read -ra list_keys <<<"$keys"
	count=${#list_keys[@]}
	if [ "$count" -lt 1 ] || [ "$count" -gt 5 ]; then
		echo "Give 1 to 5 keys (5 free badges a day)." >&2
		exit 2
	fi
	local have
	have=$(existing_names)
	local reply
	reply=$(mktemp)
	for key in "${list_keys[@]}"; do
		local row name desc icon status
		row=$(awk -F'|' -v k="$key" '$1 == k' <<<"$TABLE")
		if [ -z "$row" ]; then
			echo "$key: not in the table" >&2
			failed=$((failed + 1))
			continue
		fi
		IFS='|' read -r _ name desc icon <<<"$row"
		if grep -Fxq "$name" <<<"$have"; then
			echo "$key: \"$name\" exists already, skipped"
			continue
		fi
		if [ ! -f "$icons/$icon" ]; then
			echo "$key: no icon at assets/cat-cafe/exports/icons/$icon" >&2
			failed=$((failed + 1))
			continue
		fi
		status=$(curl -sS -o "$reply" -w '%{http_code}' -X POST \
			"https://apis.roblox.com/legacy-badges/v1/universes/$UNIVERSE_ID/badges" \
			-H "x-api-key: $ROBLOX_PUBLISH_KEY" \
			-F "name=$name" -F "description=$desc" -F "paymentSourceType=$PAYMENT_SOURCE" \
			-F "expectedCost=0" -F "isActive=true" -F "files=@$icons/$icon;type=image/png") || status=000
		if [ "$status" = 200 ]; then
			echo "$key = $(jq -r '.id' "$reply"),  -- $name"
			made=$((made + 1))
		else
			echo "$key: HTTP $status $(jq -c '.errors // .' "$reply" 2>/dev/null | head -c 300)" >&2
			if grep -q '"code":18' "$reply" 2>/dev/null; then
				echo "Error 18: this badge would cost Robux (today's free badges are used up). Nothing was spent; stopping." >&2
				failed=$((failed + 1))
				break
			fi
			failed=$((failed + 1))
		fi
	done
	rm -f "$reply"
	echo "made $made, failed $failed"
	[ "$failed" -eq 0 ]
}

case "${1:-}" in
list) list ;;
create) [ $# -eq 2 ] || usage; create "$2" ;;
*) usage ;;
esac
