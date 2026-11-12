#!/usr/bin/env bash
# Schedule, list or remove Cafe Events (#2486, #2488) in the data store CatCafe_Events through Open Cloud, so an event
# can be set up days ahead with no publish. EventService reads the list under the key "schedule" every
# Config.EventPollSeconds (60 s) and the shared clock starts and ends each event in every server together
# (src/shared/CafeEvents.luau has the record format and the server's own checks; Studio reads CatCafe_Events_dev).
# Run by .github/workflows/events.yml; also works from Git Bash on a PC with the same variables set.
#
#   ROBLOX_PUBLISH_KEY   Open Cloud API key with universe-datastores.objects:read, :create and :update on the Cat Cafe
#                        experience (the same scopes as flags.sh, docs/setup-guide.md step 24)
#   UNIVERSE_ID          default below
#   EVENTS_STORE         live (CatCafe_Events, default) or dev (CatCafe_Events_dev, what Studio reads)
#
# Usage:  events.sh show
#         events.sh add <id> <title> <start "YYYY-MM-DD HH:MM" UTC> <minutes> [big] [effects JSON]
#         events.sh test [effects JSON]       a 5 minute event starting in about 2 minutes (id test-<time>)
#         events.sh remove <id>
#         events.sh clear                     an empty schedule: no event runs or counts down
#         events.sh roblox                    list the experience's Roblox Experience Events (Creator Hub > Engagement >
#                                             Events & Updates; Open Cloud game-events, needs universe.event:read)
#         events.sh roblox-create <title> <subtitle> <description> <start> <end> [category] [image asset id]
#                                             create a public Experience Event (the "Notify Me" card on the game page);
#                                             start and end "YYYY-MM-DD HH:MM" UTC; needs universe.event:write
#         events.sh roblox-update <event id> [title] [subtitle] [description] [start] [end] [category] [image id]
#                                             change only the fields given (empty ones are left as they are)
# Keys: the workflow passes OWNER_KEY (the group owner's key, full scope, Derek2 2026-11-09) when it is set, else
# ROBLOX_PUBLISH_KEY. When a call answers 401 or 403 with the publish key, try again with OWNER_KEY.
# effects, every part optional (left out: no boost), for example
#   {"days":["lucky","golden","rainbow"],"money":2,"luck":0.5,"showers":{"count":8,"gapSeconds":900,"firstAfter":600},
#    "reward":{"cosmeticId":"Decor_PartyBunting"}}
# The script refuses what the server would drop (a bad id or title, a length outside 5 to 120 minutes, an end already
# past, an unknown day kind, an incomplete shower or reward, a duplicate id, an overlap) and, unlike the server, which
# clamps, also refuses a value over a Config cap (money, luck, shower count, shower gap), a big event less than 6 days
# from another big one, a big event announced less than 3 hours ahead (the countdown, Config.EventCountdownSeconds),
# and more than Config.EventScheduleMax records. Ended events are dropped on every write. Every change reads the
# schedule back. Prints only event fields, never player data. Needs curl and jq (both on GitHub's ubuntu runners).
set -euo pipefail

UNIVERSE_ID=${UNIVERSE_ID:-10773193456}
case "${EVENTS_STORE:-live}" in
live) STORE=CatCafe_Events ;;
dev) STORE=CatCafe_Events_dev ;;
*)
	echo "EVENTS_STORE must be live or dev, got: $EVENTS_STORE" >&2
	exit 2
	;;
esac
KEY=schedule # CafeEvents.KEY
: "${ROBLOX_PUBLISH_KEY:?set ROBLOX_PUBLISH_KEY (docs/setup-guide.md step 24)}"
entries=https://apis.roblox.com/cloud/v2/universes/$UNIVERSE_ID/data-stores/$STORE/entries

# The caps, from src/shared/Config.luau when it has them (defaults are the values #2486 shipped with).
here=$(cd "$(dirname "$0")" && pwd)
config=$here/../../src/shared/Config.luau
cap() { # name default
	local v=
	[ -f "$config" ] && v=$(sed -nE "s/^[[:space:]]*$1 = ([0-9.]+),.*/\1/p" "$config" | head -n 1)
	printf '%s' "${v:-$2}"
}
MIN_S=$(cap EventMinSeconds 300)
MAX_S=$(cap EventMaxSeconds 7200)
MONEY_MAX=$(cap EventMoneyMax 2)
LUCK_MAX=$(cap EventLuckMax 1.0)
SHOWER_MAX=$(cap EventShowerMax 12)
GAP_MIN=$(cap EventShowerGapMinSeconds 300)
COUNTDOWN=$(cap EventCountdownSeconds 10800)
BIG_GAP=$(cap EventBigMinGapSeconds 518400)
LIST_MAX=$(cap EventScheduleMax 10)

usage() {
	echo 'usage: events.sh show | roblox | roblox-create <title> <subtitle> <description> <start> <end> [category] [image id] | roblox-update <event id> [title] [subtitle] [description] [start] [end] [category] [image id] | add <id> <title> <"YYYY-MM-DD HH:MM" UTC> <minutes> [big] [effects JSON] | test [effects JSON] | remove <id> | clear' >&2
	exit 2
}

reply=$(mktemp)
trap 'rm -f "$reply"' EXIT
# call method url [curl args...] -> sets $status and $body; 5xx and 429 get three more tries over about half a minute
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

refuse() {
	echo "Refused: $*" >&2
	[ -z "${GITHUB_STEP_SUMMARY:-}" ] || echo "### Refused: $*" >>"$GITHUB_STEP_SUMMARY"
	exit 1
}

# read_list -> $list, the stored records as a JSON array ([] with no entry or a value that is not a list)
read_list() {
	call GET "$entries/$KEY"
	if [ "$status" = 404 ]; then
		list='[]'
	elif [ "$status" = 200 ]; then
		list=$(jq -c '.value | if type == "array" then . else [] end' <<<"$body")
	else
		fail
	fi
}

write_list() { # json-array
	call PATCH "$entries/$KEY?allowMissing=true" -H "Content-Type: application/json" \
		--data "$(jq -cn --argjson v "$1" '{value: $v}')"
	[ "$status" = 200 ] || fail
	echo "Wrote $STORE/$KEY: $(jq length <<<"$1") event(s)"
}

when() { date -u -d "@$1" '+%Y-%m-%d %H:%M UTC'; }

show() {
	local now line
	now=$(date +%s)
	read_list
	echo "== $STORE/$KEY (servers pick a change up within about 60 s; now $(when "$now"))"
	[ -z "${GITHUB_STEP_SUMMARY:-}" ] || echo "### $STORE/$KEY" >>"$GITHUB_STEP_SUMMARY"
	if [ "$(jq length <<<"$list")" = 0 ]; then
		echo "No events scheduled."
		[ -z "${GITHUB_STEP_SUMMARY:-}" ] || echo "No events scheduled." >>"$GITHUB_STEP_SUMMARY"
		return
	fi
	while IFS= read -r line; do
		echo "$line"
		[ -z "${GITHUB_STEP_SUMMARY:-}" ] || echo "- $line" >>"$GITHUB_STEP_SUMMARY"
	done < <(jq -r --argjson now "$now" 'sort_by(.startsAt // 0)[] |
		(if (.endsAt // 0) <= $now then "ended" elif (.startsAt // 0) <= $now then "RUNNING"
			else "starts in \(((.startsAt - $now) / 60) | floor) min" end) as $state
		| "\(.id) \"\(.title)\" \(.startsAt | strftime("%Y-%m-%d %H:%M"))-\(.endsAt | strftime("%H:%M")) UTC"
			+ " (\(((.endsAt - .startsAt) / 60) | floor) min\(if .big then ", big" else "" end)), \($state);"
			+ " effects \(.effects // {} | tojson)"' <<<"$list")
}

# check record list now: refuses with the first problem of the record against the rules and the other records
check() {
	local record=$1 others=$2 now=$3 problem
	problem=$(jq -r --argjson o "$others" --argjson now "$now" --argjson minS "$MIN_S" --argjson maxS "$MAX_S" \
		--argjson moneyMax "$MONEY_MAX" --argjson luckMax "$LUCK_MAX" --argjson showerMax "$SHOWER_MAX" \
		--argjson gapMin "$GAP_MIN" --argjson countdown "$COUNTDOWN" --argjson bigGap "$BIG_GAP" '
		def num: type == "number";
		def int: num and . == floor;
		. as $r
		| (.effects // {}) as $e
		| [
			(if (.id | type) != "string" or (.id | test("^[a-z0-9_-]{1,32}$") | not)
				then "id must be 1 to 32 of a-z, 0-9, - and _" else empty end),
			(if (.title | type) != "string" or (.title | length) < 1 or (.title | length) > 24
				then "title must be 1 to 24 characters" else empty end),
			(if (.startsAt | int | not) or (.endsAt | int | not) then "start and end must be whole unix seconds"
				elif .endsAt - .startsAt < $minS or .endsAt - .startsAt > $maxS
				then "length must be \($minS / 60) to \($maxS / 60) minutes"
				elif .endsAt <= $now then "the end is already past" else empty end),
			(if has("big") and (.big | type) != "boolean" then "big must be true or false" else empty end),
			(if ($e | type) != "object" then "effects must be an object" else empty end),
			(if ($e.days // [] | type) != "array" or ([$e.days // [] | .[] | select(IN("lucky", "golden", "rainbow") | not)] | length) > 0
				then "days may only hold lucky, golden and rainbow" else empty end),
			(if $e | has("money") then (if ($e.money | num | not) or $e.money < 1 or $e.money > $moneyMax
				then "money must be 1 to \($moneyMax)" else empty end) else empty end),
			(if $e | has("luck") then (if ($e.luck | num | not) or $e.luck < 0 or $e.luck > $luckMax
				then "luck must be 0 to \($luckMax)" else empty end) else empty end),
			(if $e | has("showers") then ($e.showers as $s
				| if ($s | type) != "object" or ($s.count | int | not) or ($s.gapSeconds | num | not) or ($s.firstAfter | num | not)
				then "showers needs count, gapSeconds and firstAfter"
				elif $s.count < 1 or $s.count > $showerMax then "showers count must be 1 to \($showerMax)"
				elif $s.gapSeconds < $gapMin then "showers gapSeconds must be at least \($gapMin)"
				elif $s.firstAfter < 0 then "showers firstAfter must be 0 or more" else empty end) else empty end),
			(if $e | has("reward") then (if ($e.reward | type) != "object" or ($e.reward.cosmeticId | type) != "string"
				or ($e.reward.cosmeticId | length) < 1 or ($e.reward.cosmeticId | length) > 64
				then "reward needs a cosmeticId of 1 to 64 characters" else empty end) else empty end),
			(if ([$o[] | select(.id == $r.id)] | length) > 0 then "the id \(.id) is already scheduled" else empty end),
			(. as $r | [$o[] | select(.startsAt < $r.endsAt and $r.startsAt < .endsAt)][0]
				| if . then "it overlaps \(.id)" else empty end),
			(if .big == true then
				(. as $r | [$o[] | select(.big == true and ((.startsAt - $r.startsAt) | fabs) < $bigGap)][0]
					| if . then "big events must be \($bigGap / 86400) days apart (\(.id) is closer)" else empty end),
				(if .startsAt - $now < $countdown then "a big event needs \($countdown / 3600) hours of countdown: start it later"
					else empty end)
			else empty end)
		] | first // empty' <<<"$record" 2>&1) ||
		problem="the record is not valid JSON"
	[ -z "$problem" ] || refuse "$problem"
	if [ "$(jq -r '.big // false' <<<"$record")" != true ] &&
		[ $(($(jq -r '.startsAt' <<<"$record") - now)) -lt "$COUNTDOWN" ]; then
		echo "Note: it starts in under $((COUNTDOWN / 3600)) hours, so the in-game countdown will be shorter than usual."
	fi
}

# add_record record: checks it against the live list, keeps the events that have not ended, writes, reads back
add_record() {
	local record=$1 now others merged
	now=$(date +%s)
	read_list
	others=$(jq -c --argjson now "$now" '[.[] | select((.endsAt // 0) > $now)]' <<<"$list")
	check "$record" "$others" "$now"
	merged=$(jq -c --argjson r "$record" '. + [$r] | sort_by(.startsAt)' <<<"$others")
	[ "$(jq length <<<"$merged")" -le "$LIST_MAX" ] || refuse "at most $LIST_MAX events can be scheduled at once"
	write_list "$merged"
}

# effects text -> a JSON object with nulls dropped (DataStore values must not hold null), or refuses
effects_json() {
	local text=${1:-}
	[ -n "$text" ] || text='{}'
	jq -ce 'if type == "object" then del(..|nulls) else error("not an object") end' <<<"$text" 2>/dev/null ||
		refuse "effects must be a JSON object, got: $text"
}


# roblox: the experience's Roblox Experience Events (the "Notify Me" ones on the game page), read only. Open Cloud
# game-events (create.roblox.com/docs/cloud/reference/features/virtual-events); prints only event fields.
roblox() {
	call GET "https://apis.roblox.com/virtual-events/v3/universes/$UNIVERSE_ID/game-events"
	if [ "$status" != 200 ]; then
		echo "Open Cloud answered HTTP $status: $body" >&2
		case "$status" in
		401 | 403) echo "The key needs universe.event:read on universe $UNIVERSE_ID." >&2 ;;
		esac
		exit 1
	fi
	echo "== Roblox Experience Events (HTTP $status; fields: $(jq -r '[(.gameEvents // .data // .events // [])[0] // {} | keys[]] | join(", ")' <<<"$body"))"
	jq -r '(.gameEvents // .data // .events // []) as $l | if ($l | length) == 0 then "No Experience Events."
		else $l[] | "\(.id // .path // "?") \"\(.title // .displayTitle // "")\" \(.startTime // .eventTime.startTime // "?") to \(.endTime // .eventTime.endTime // "?"), \(.visibility // .eventVisibility // "?"), \(.status // .eventStatus // "")" end' <<<"$body"
}

# iso "YYYY-MM-DD HH:MM" (UTC) -> 2026-11-09T23:00:00.000Z, refusing anything else
iso() {
	[[ $1 =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}[T\ ][0-9]{2}:[0-9]{2}Z?$ ]] || refuse "times must be \"YYYY-MM-DD HH:MM\" in UTC, got: $1"
	date -u -d "${1/T/ } UTC" +%Y-%m-%dT%H:%M:00.000Z 2>/dev/null || refuse "not a real date: $1"
}

# event_body title subtitle description start end category image -> the JSON fields that are not empty
event_body() {
	local start='' end='' sec
	[ -z "$4" ] || start=$(iso "$4")
	[ -z "$5" ] || end=$(iso "$5")
	if [ -n "$start" ] && [ -n "$end" ]; then
		sec=$(($(date -u -d "$end" +%s) - $(date -u -d "$start" +%s)))
		[ "$sec" -gt 0 ] || refuse "the end must be after the start"
	fi
	[ -z "$7" ] || [[ $7 =~ ^[0-9]{1,20}$ ]] || refuse "the image must be an asset id (digits), got: $7"
	jq -cn --arg title "$1" --arg sub "$2" --arg desc "$3" --arg start "$start" --arg end "$end" --arg cat "$6" \
		--arg img "$7" '{}
		+ (if $title != "" then {title: $title} else {} end)
		+ (if $sub != "" then {subtitle: $sub} else {} end)
		+ (if $desc != "" then {description: $desc} else {} end)
		+ (if $start != "" then {startTime: $start} else {} end)
		+ (if $end != "" then {endTime: $end} else {} end)
		+ (if $cat != "" then {categories: [{category: $cat, rank: 0}]} else {} end)
		+ (if $img != "" then {thumbnails: [{mediaId: ($img | tonumber), rank: 1}]} else {} end)'
}

event_fail() {
	echo "Open Cloud answered HTTP $status: $body" >&2
	case "$status" in
	401 | 403) echo "The key needs universe.event:write on universe $UNIVERSE_ID; OWNER_KEY has it." >&2 ;;
	esac
	exit 1
}

action=${1:-show}
case "$action" in
show)
	[ $# -le 1 ] || usage
	;;
roblox)
	[ $# -le 1 ] || usage
	roblox
	exit 0
	;;
roblox-create)
	[ $# -ge 6 ] && [ $# -le 8 ] || usage
	[ -n "$2" ] && [ -n "$3" ] || refuse "title and subtitle are required"
	data=$(event_body "$2" "$3" "$4" "$5" "$6" "${7:-}" "${8:-}")
	data=$(jq -c --argjson place "${PLACE_ID:-119569792798199}" '. + {visibility: "public", placeId: $place}' <<<"$data")
	echo "Creating: $data"
	call POST "https://apis.roblox.com/virtual-events/v3/universes/$UNIVERSE_ID/game-events" \
		-H 'Content-Type: application/json' --data "$data"
	case "$status" in 2??) ;; *) event_fail ;; esac
	echo "== Created (HTTP $status): $(jq -c '{id, title, startTime, endTime, visibility}' <<<"$body" 2>/dev/null || echo "$body")"
	roblox
	exit 0
	;;
roblox-update)
	[ $# -ge 2 ] && [ $# -le 9 ] || usage
	[[ $2 =~ ^[0-9A-Za-z_-]{1,64}$ ]] || refuse "event id must be the id that roblox lists, got: $2"
	data=$(event_body "${3:-}" "${4:-}" "${5:-}" "${6:-}" "${7:-}" "${8:-}" "${9:-}")
	[ "$data" != '{}' ] || refuse "nothing to change: give at least one field"
	echo "Updating $2: $data"
	call PATCH "https://apis.roblox.com/virtual-events/v3/game-events/$2" -H 'Content-Type: application/json' --data "$data"
	case "$status" in 2??) ;; *) event_fail ;; esac
	echo "== Updated (HTTP $status)"
	roblox
	exit 0
	;;
add)
	[ $# -ge 5 ] && [ $# -le 7 ] || usage
	id=$2 title=$3 startText=$4 minutes=$5 big=false effects='{}'
	shift 5
	for arg in "$@"; do
		if [ "$arg" = big ]; then big=true; elif [ -n "$arg" ]; then effects=$arg; fi
	done
	[[ $startText =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}[T\ ][0-9]{2}:[0-9]{2}Z?$ ]] ||
		refuse "start must be \"YYYY-MM-DD HH:MM\" in UTC, got: $startText"
	startsAt=$(date -u -d "${startText/T/ } UTC" +%s 2>/dev/null) || refuse "start is not a real date: $startText"
	[[ $minutes =~ ^[0-9]{1,4}$ ]] || refuse "minutes must be a whole number, got: $minutes"
	effects=$(effects_json "$effects") || exit 1
	record=$(jq -cn --arg id "$id" --arg title "$title" --argjson s "$startsAt" --argjson m "$minutes" \
		--argjson big "$big" --argjson e "$effects" \
		'{id: $id, title: $title, startsAt: $s, endsAt: ($s + $m * 60), effects: $e} + (if $big then {big: true} else {} end)')
	add_record "$record"
	;;
test)
	[ $# -le 2 ] || usage
	now=$(date +%s)
	effects=$(effects_json "${2:-}") || exit 1
	record=$(jq -cn --arg id "test-$now" --argjson s "$((now + 120))" --argjson e "$effects" \
		'{id: $id, title: "Test Event", startsAt: $s, endsAt: ($s + 300), effects: $e}')
	add_record "$record"
	;;
remove)
	[ $# -eq 2 ] || usage
	read_list
	[ "$(jq --arg id "$2" '[.[] | select(.id == $id)] | length' <<<"$list")" -gt 0 ] || refuse "no event with id $2"
	write_list "$(jq -c --arg id "$2" '[.[] | select(.id != $id)]' <<<"$list")"
	;;
clear)
	[ $# -eq 1 ] || usage
	write_list '[]'
	;;
*) usage ;;
esac
show
