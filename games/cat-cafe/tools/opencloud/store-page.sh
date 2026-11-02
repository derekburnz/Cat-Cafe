#!/usr/bin/env bash
# Read or set the experience's name and description (the store page text) from the repo, without Creator Hub. Roblox
# keeps the experience's name and description on its root place, so this updates the root place through Open Cloud
# (Places PATCH) and reads the experience back.
# Run by .github/workflows/store-page.yml; also works from Git Bash on a PC with the same variables set.
#
#   ROBLOX_PUBLISH_KEY   Open Cloud API key on Cat Cafe with universe:write and universe.place:write
#   ROBLOX_UNIVERSE_ID   the experience: default 10773193456, Cat Cafe
#   ROBLOX_PLACE_ID      its root place: default 119569792798199
#
# Usage:
#   store-page.sh show            the experience's name, description and visibility as Roblox has them now
#   store-page.sh set [file]      name and description from the file (default store-page.txt next to this script):
#                                 line 1 is the name, line 2 is blank, the rest is the description
# Changing the text never changes who can join: the game stays private until someone makes it public in Creator
# Hub. Roblox answers 409 while the place is open in Team Create (close Studio, then run again).
# Needs curl and jq (both on GitHub's ubuntu runners).
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
UNIVERSE_ID=${ROBLOX_UNIVERSE_ID:-10773193456}
PLACE_ID=${ROBLOX_PLACE_ID:-119569792798199}
: "${ROBLOX_PUBLISH_KEY:?set ROBLOX_PUBLISH_KEY (docs/setup-guide.md step 15)}"
universe=https://apis.roblox.com/cloud/v2/universes/$UNIVERSE_ID
NAME_MAX=50 # Roblox's limits for an experience
DESCRIPTION_MAX=1000

usage() {
	echo "usage: store-page.sh show | set [file]" >&2
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
	401 | 403) echo "The key needs universe:write and universe.place:write on universe $UNIVERSE_ID." >&2 ;;
	409) echo "The place is open in Team Create. Close Studio on every device, then run this again." >&2 ;;
	esac
	exit 1
}

show() {
	call GET "$universe"
	[ "$status" = 200 ] || fail
	echo "$body" | jq -r '"Name:        \(.displayName)", "Visibility:  \(.visibility // "unknown")", "Root place:  \(.rootPlace // "unknown")", "Description:", (.description // "" | split("\n") | map("  " + .) | .[])'
}

set_text() {
	local file=${1:-$HERE/store-page.txt} name blank description
	[ -f "$file" ] || {
		echo "No file at $file" >&2
		exit 2
	}
	name=$(sed -n 1p "$file")
	blank=$(sed -n 2p "$file")
	description=$(tail -n +3 "$file")
	if [ -z "$name" ] || [ -n "$blank" ] || [ -z "$description" ]; then
		echo "$file: line 1 is the name, line 2 is blank, the description starts on line 3." >&2
		exit 2
	fi
	if [ "${#name}" -gt "$NAME_MAX" ] || [ "${#description}" -gt "$DESCRIPTION_MAX" ]; then
		echo "Too long: the name is ${#name} of $NAME_MAX characters, the description ${#description} of $DESCRIPTION_MAX." >&2
		exit 2
	fi
	echo "Setting the name to \"$name\" and a ${#description} character description on root place $PLACE_ID."
	call PATCH "$universe/places/$PLACE_ID?updateMask=displayName,description" -H "Content-Type: application/json" \
		--data "$(jq -n --arg n "$name" --arg d "$description" '{displayName: $n, description: $d}')"
	[ "$status" = 200 ] || fail
	echo "Roblox answered 200. The experience now reads:"
	show
	# Roblox's text filter can replace words with #s; say so when the text read back differs from the file.
	call GET "$universe"
	if [ "$(echo "$body" | jq -r .displayName)" != "$name" ] || [ "$(echo "$body" | jq -r .description)" != "$description" ]; then
		echo "::warning::The text Roblox shows differs from $file (filtered words, or the experience name not updated yet). Compare above."
	fi
}

case "${1:-}" in
show) show ;;
set) set_text "${2:-}" ;;
*) usage ;;
esac
