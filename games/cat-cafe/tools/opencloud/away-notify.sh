#!/usr/bin/env bash
# Send the "Your cats earned $X while you were away!" notifications that are due (#2768, Derek2 2026-11-10: "Yes,
# once a day, 12 h after leaving"). Run every hour by .github/workflows/away-notify.yml; also works from Git Bash on
# a PC with the same variables set.
#
# How it fits together (src/shared/AwayNotify.luau): when a player leaves, the game server writes a note to the
# MemoryStore sorted map CatCafe_AwayNotify (key the user id, value the amount's text such as "$1.24M", sort key the
# time the message is due, 12 h after leaving). Coming back removes the note. This script reads the notes whose time
# has come, sends each one as a Roblox experience notification through Open Cloud, and deletes it. So a player gets
# one message per time away at most, and Roblox itself delivers only to players aged 13 and up who turned
# notifications on for the game, at most one a day.
#
#   ROBLOX_PUBLISH_KEY   Open Cloud API key (never commit it) with memory-store.sorted-map:read and :write on the
#                        experience and user.user-notification:write. The workflow passes the repo secret OWNER_KEY.
#   UNIVERSE_ID          the experience (not secret; default below)
#   AWAY_MESSAGE_ID      the notification text's asset id from Creator Hub (Engagement > Notifications > the string
#                        "Your cats earned {amount} while you were away!" > Copy Asset ID). Not secret. Default below;
#                        empty means the text does not exist yet, and send does nothing.
#
# Usage:  tools/opencloud/away-notify.sh count   how many notes there are and how many are due; sends nothing
#         tools/opencloud/away-notify.sh send    send the due ones
#
# The repo and its Actions logs are public, so this never prints a user id, a response body or a path: counts and
# error codes only. Needs curl and jq (both on GitHub's ubuntu runners).
set -euo pipefail

UNIVERSE_ID=${UNIVERSE_ID:-10773193456}
MAP=CatCafe_AwayNotify # AwayNotify.MAP
LAUNCH_DATA=notify_away # JoinSource.NOTIFY: session_start's source for a join from the message
MESSAGE_ID=${AWAY_MESSAGE_ID:-}
MAX_PAGES=50 # 100 notes a page; a page with nothing due ends the read (the map is sorted by due time)
: "${ROBLOX_PUBLISH_KEY:?set ROBLOX_PUBLISH_KEY}"

items=https://apis.roblox.com/cloud/v2/universes/$UNIVERSE_ID/memory-store/sorted-maps/$MAP/items

usage() {
	echo "usage: away-notify.sh count | send" >&2
	exit 2
}

reply=$(mktemp)
due=$(mktemp)
trap 'rm -f "$reply" "$due"' EXIT

# call method url [curl args...] -> sets $status; the body is in $reply. A 5xx or a dropped connection gets two more
# tries. A 429 is not retried here: the caller decides, since for a notification it can mean this player's daily
# limit.
call() {
	local method=$1 url=$2 wait
	shift 2
	for wait in 5 10 0; do
		status=$(curl -sS -o "$reply" -w '%{http_code}' -X "$method" "$url" -H "x-api-key: $ROBLOX_PUBLISH_KEY" "$@" 2>/dev/null) ||
			status=000
		case "$status" in
		5?? | 000) ;;
		*) break ;;
		esac
		[ "$wait" = 0 ] && break
		sleep "$wait"
	done
}

# the error's code with any long number masked, so a log line can never carry a user id
code() {
	jq -r '(.code // .error // "none") | tostring' "$reply" 2>/dev/null | sed -E 's/[0-9]{5,}/#/g' | head -c 60
}

# Reads the map into $due as "id<TAB>text" lines for notes whose time has come. Sets $total and $pages.
read_due() {
	local now token="" page=0 page_due
	now=$(date +%s)
	total=0
	: >"$due"
	while [ "$page" -lt "$MAX_PAGES" ]; do
		if [ -n "$token" ]; then
			call GET "$items" -G --data-urlencode "maxPageSize=100" --data-urlencode "pageToken=$token"
		else
			call GET "$items" -G --data-urlencode "maxPageSize=100"
		fi
		if [ "$status" != 200 ]; then
			echo "Reading the notes failed: HTTP $status ($(code))." >&2
			case "$status" in
			401 | 403) echo "The key needs memory-store.sorted-map:read and :write on universe $UNIVERSE_ID." >&2 ;;
			esac
			exit 1
		fi
		page=$((page + 1))
		if [ "$page" = 1 ]; then
			# the answer's shape, names only, so a change in Open Cloud shows in the log
			echo "List fields: $(jq -r 'keys | join(", ")' "$reply"); note fields: $(jq -r '[(.memoryStoreSortedMapItems // .items // [])[0] // {} | keys[]] | join(", ")' "$reply")"
		fi
		total=$((total + $(jq '(.memoryStoreSortedMapItems // .items // []) | length' "$reply")))
		page_due=$(jq -r --argjson now "$now" '
			(.memoryStoreSortedMapItems // .items // [])[]
			| {id: (.id // ""), at: (.numericSortKey // .sortKey // null), text: .value}
			| select((.at | type) == "number" and .at <= $now)
			| select((.id | test("^[0-9]{1,20}$")) and (.text | type) == "string" and (.text | test("^\\$[0-9][0-9A-Za-z.,]{0,11}$")))
			| "\(.id)\t\(.text)"' "$reply")
		[ -n "$page_due" ] && printf '%s\n' "$page_due" >>"$due"
		token=$(jq -r '.nextPageToken // ""' "$reply")
		if [ -z "$token" ] || [ -z "$page_due" ]; then
			break
		fi
	done
	pages=$page
}

count() {
	read_due
	echo "Away notes: $total read on $pages page(s), $(wc -l <"$due" | tr -d ' ') due now. Nothing sent."
}

send() {
	if [ -z "$MESSAGE_ID" ]; then
		echo "No notification text id yet (AWAY_MESSAGE_ID is empty), so nothing is sent. The notes just expire."
		return 0
	fi
	[[ $MESSAGE_ID =~ ^[0-9a-fA-F-]{8,64}$ ]] || {
		echo "AWAY_MESSAGE_ID does not look like a Creator Hub asset id." >&2
		exit 2
	}
	read_due
	local id text payload sent=0 back=0 refused=0 limited=0 later=0 streak=0
	declare -A why=()
	while IFS=$'\t' read -r id text; do
		[ -n "$id" ] || continue
		# still away? A player who came back in the last minute has no note any more
		call GET "$items/$id"
		if [ "$status" = 404 ]; then
			back=$((back + 1))
			continue
		elif [ "$status" != 200 ]; then
			later=$((later + 1))
			continue
		fi
		payload=$(jq -n --arg universe "universes/$UNIVERSE_ID" --arg message "$MESSAGE_ID" --arg amount "$text" \
			--arg launch "$LAUNCH_DATA" '{
				source: {universe: $universe},
				payload: {
					message_id: $message,
					type: "MOMENT",
					parameters: {amount: {string_value: $amount}},
					join_experience: {launch_data: $launch},
					analytics_data: {category: "away_earnings"}
				}
			}')
		call POST "https://apis.roblox.com/cloud/v2/users/$id/notifications" -H "Content-Type: application/json" --data "$payload"
		case "$status" in
		200 | 201)
			sent=$((sent + 1))
			streak=0
			call DELETE "$items/$id"
			;;
		401 | 403)
			echo "Sending was refused: HTTP $status ($(code)). The key needs user.user-notification:write. Nothing deleted." >&2
			echo "Sent $sent before the stop."
			exit 1
			;;
		429)
			# this player's daily limit, or ours for the hour: the note stays and expires by itself
			limited=$((limited + 1))
			streak=$((streak + 1))
			if [ "$streak" -ge 5 ]; then
				echo "Five 429 answers in a row, so Roblox is rate limiting this run. Stopping; the rest go next hour." >&2
				break
			fi
			;;
		4??)
			# Roblox will not deliver to this player (for example the text was moderated, or the request is not
			# valid for them): drop the note so it is not tried every hour
			refused=$((refused + 1))
			streak=0
			why["$status $(code)"]=$((${why["$status $(code)"]:-0} + 1))
			call DELETE "$items/$id"
			;;
		*)
			later=$((later + 1))
			streak=0
			;;
		esac
	done <"$due"
	echo "Away notes: $total read, $(wc -l <"$due" | tr -d ' ') due. Sent $sent, came back first $back, refused $refused, limited $limited, left for next hour $later."
	local reason
	for reason in "${!why[@]}"; do
		echo "  refused with $reason: ${why[$reason]}"
	done
}

case "${1:-}" in
count)
	[ $# -eq 1 ] || usage
	count
	;;
send)
	[ $# -eq 1 ] || usage
	send
	;;
*) usage ;;
esac
