#!/usr/bin/env bash
# Add, remove or list the player idea credits on the Thank You board (#1083, docs/design/cat-cafe/idea-credits.md)
# in the data store IdeaCredits_v1 through Open Cloud. IdeaCreditsService (src/server/Services/IdeaCreditsService.luau)
# reads the credit/ keys at server start and every 30 minutes; it never writes them. A credit's key is
# credit/<yyyymmddhhmmss UTC>-<report key>: IdeaCreditsService lists every credit/ key, sorts the names newest first
# and reads the newest 120, so the date-first name is what orders the board. The hide/<userId> keys belong
# to the game (SetHideCredit), so this script only counts them and never writes or deletes one.
# Run by .github/workflows/idea-credits.yml; also works from Git Bash on a PC with the same variables set.
#
#   ROBLOX_PUBLISH_KEY   Open Cloud API key that also has universe-datastores.objects:list, :read, :create and
#                        :update on the Cat Cafe experience (docs/setup-guide.md step 24). With :delete too, remove
#                        deletes the key; without it, remove writes {removed = true}, which IdeaCredits.sanitize
#                        drops, so the board stops showing it all the same.
#   UNIVERSE_ID          default below
#
# Usage:  tools/opencloud/idea-credits.sh list
#         tools/opencloud/idea-credits.sh add <report> <version> <idea>
#         tools/opencloud/idea-credits.sh remove <report>
#   report   the bug report's key in BugReports_v1 (r_<YYYYMMDD>_<time>_<userId>), or better just its start
#            r_<YYYYMMDD>_<time>: the script finds the one key under it, so the player's id is never typed into
#            the run's inputs, which are public like its log
#   version  the place version the idea shipped in (publish prints it)
#   idea     our words for the idea, 1 to 48 bytes, shown on the board as is (never the player's own text)
# add refuses unless the report is an idea whose player ticked "Feature my name" (kind "idea", featureName true),
# and takes the player's user id from the report itself. The log is public, so it prints counts, keys with the user
# id cut to its last three digits, ideas and versions, never a full user id or a name. add and remove end with a
# list, so every change is read back. Needs curl and jq.
set -euo pipefail

UNIVERSE_ID=${UNIVERSE_ID:-10773193456}
STORE=IdeaCredits_v1        # IdeaCredits.STORE
REPORTS=BugReports_v1       # BugReportService
CREDIT=credit/              # IdeaCredits.CREDIT_PREFIX
HIDE=hide/                  # IdeaCredits.HIDE_PREFIX
IDEA_BYTES=48               # IdeaCredits.IDEA_BYTES
: "${ROBLOX_PUBLISH_KEY:?set ROBLOX_PUBLISH_KEY (docs/setup-guide.md step 24)}"
base=https://apis.roblox.com/cloud/v2/universes/$UNIVERSE_ID/data-stores

usage() {
	echo "usage: idea-credits.sh list | add <report> <version> <idea> | remove <report>" >&2
	exit 2
}

summary() { [ -z "${GITHUB_STEP_SUMMARY:-}" ] || echo "$*" >>"$GITHUB_STEP_SUMMARY"; }

# r_20261104_1762262400_12345678 -> r_20261104_1762262400_...678 (the log and the summary are public)
mask() { sed -E 's/_[0-9]*([0-9]{3})$/_...\1/; s/_[0-9]{1,2}$/_.../' <<<"$1"; }

uri() { jq -rn --arg s "$1" '$s | @uri'; }

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
	# Roblox's error can echo the entry key, which ends in a user id: digit runs of 6 or more keep only their last 3
	echo "Open Cloud answered HTTP $status: $(sed -E 's/[0-9]{3,}([0-9]{3})/...\1/g' <<<"$body")" >&2
	case "$status" in
	401 | 403) echo "The key needs universe-datastores.objects:list, :read, :create and :update on universe $UNIVERSE_ID (docs/setup-guide.md step 24)." >&2 ;;
	esac
	exit 1
}

# keys store prefix -> prints every key under prefix, one a line (none when the store does not exist yet)
keys() {
	local store=$1 prefix=$2 token=
	while :; do
		local args=(--get --data-urlencode "filter=id.startsWith(\"$prefix\")" --data-urlencode maxPageSize=256)
		[ -z "$token" ] || args+=(--data-urlencode "pageToken=$token")
		call GET "$base/$store/entries" "${args[@]}"
		if [ "$status" = 404 ] && [[ $body == *"not found"* ]]; then
			return 0
		fi
		[ "$status" = 200 ] || fail
		jq -r '.dataStoreEntries[]?.id' <<<"$body"
		token=$(jq -r '.nextPageToken // empty' <<<"$body")
		[ -n "$token" ] || break
	done
}

# report_key report -> the one BugReports_v1 key that is report or starts with report_
report_key() {
	local report=$1 found
	[[ $report =~ ^[rs]_[0-9]{8}_[0-9]+(_[0-9]+)?$ ]] || {
		echo "report must look like r_<YYYYMMDD>_<time> or r_<YYYYMMDD>_<time>_<userId>" >&2
		exit 2
	}
	if [[ $report =~ ^[rs]_[0-9]{8}_[0-9]+_[0-9]+$ ]]; then
		echo "$report"
		return
	fi
	mapfile -t found < <(keys "$REPORTS" "${report}_")
	case ${#found[@]} in
	1) echo "${found[0]}" ;;
	0)
		echo "No bug report under $report in $REPORTS." >&2
		exit 1
		;;
	*)
		echo "${#found[@]} bug reports start with $report; give the full key." >&2
		exit 1
		;;
	esac
}

list() {
	local credits hides key
	mapfile -t credits < <(keys "$STORE" "$CREDIT")
	mapfile -t hides < <(keys "$STORE" "$HIDE")
	echo "== $STORE: ${#credits[@]} credit(s), ${#hides[@]} player(s) hiding their name (servers rebuild the board every 30 min)"
	summary "### $STORE: ${#credits[@]} credit(s), ${#hides[@]} hidden"
	for key in "${credits[@]}"; do
		call GET "$base/$STORE/entries/$(uri "$key")"
		[ "$status" = 200 ] || fail
		local line
		if [ "$(jq -r '.value.removed // false' <<<"$body")" = true ]; then
			line="$(mask "$key")  (removed: the board skips it)"
		else
			line="$(mask "$key")  v$(jq -r '.value.version' <<<"$body")  $(jq -r '.value.addedAt | tonumber? // 0 | strftime("%Y-%m-%d")' <<<"$body")  \"$(jq -r '.value.idea' <<<"$body")\""
		fi
		echo "$line"
		summary "- \`$line\`"
	done
}

add() {
	local report version=$2 idea=$3 key bytes userId record value
	[[ $version =~ ^[0-9]{1,9}$ ]] || {
		echo "version must be a place version number, got: $version" >&2
		exit 2
	}
	if ! iconv -f UTF-8 -t UTF-8 <<<"$idea" >/dev/null 2>&1 || LC_ALL=C grep -q '[[:cntrl:]]' <<<"$idea"; then
		echo "idea must be plain UTF-8 text with no control characters" >&2
		exit 2
	fi
	idea=$(sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' <<<"$idea")
	bytes=$(printf '%s' "$idea" | LC_ALL=C wc -c)
	if [ "$bytes" -lt 1 ] || [ "$bytes" -gt "$IDEA_BYTES" ]; then
		echo "idea must be 1 to $IDEA_BYTES bytes, got $bytes" >&2
		exit 2
	fi
	report=$(report_key "$1")
	call GET "$base/$REPORTS/entries/$(uri "$report")"
	[ "$status" = 200 ] || fail
	record=$(jq -c '.value' <<<"$body")
	if [ "$(jq -r '.kind' <<<"$record")" != idea ] || [ "$(jq -r '.featureName' <<<"$record")" != true ]; then
		echo "Refused: $(mask "$report") is not an idea report with \"Feature my name\" ticked, so it gets no credit." >&2
		exit 1
	fi
	userId=$(jq -r '.userId' <<<"$record")
	[[ $userId =~ ^[1-9][0-9]{0,15}$ ]] || {
		echo "The report's user id is not a number." >&2
		exit 1
	}
	local existing now
	existing=$(credits_for "$report")
	if [ -n "$existing" ]; then
		echo "Refused: $(mask "$report") already has a credit ($(mask "$existing")); remove it first to change it." >&2
		exit 1
	fi
	now=$(date -u +%s)
	key=$CREDIT$(date -u -d "@$now" +%Y%m%d%H%M%S)-$report
	value=$(jq -cn --argjson u "$userId" --arg i "$idea" --argjson v "$version" --argjson t "$now" \
		'{userId: $u, idea: $i, version: $v, addedAt: $t}')
	call PATCH "$base/$STORE/entries/$(uri "$key")?allowMissing=true" -H "Content-Type: application/json" \
		--data "$(jq -cn --argjson v "$value" --arg u "users/$userId" '{value: $v, users: [$u]}')"
	[ "$status" = 200 ] || fail
	echo "Wrote $(mask "$key"): v$version \"$idea\""
	summary "Wrote \`$(mask "$key")\`: v$version \"$idea\""
}

# credits_for report -> that report's live credit keys (credit/<yyyymmddhhmmss>-<report>), one a line; a credit
# blanked by remove ({removed = true}, when the key had no :delete) is skipped, so it never blocks a new add
credits_for() {
	local key
	for key in $(keys "$STORE" "$CREDIT" | grep -E "^${CREDIT}[0-9]{14}-$1\$" || true); do
		call GET "$base/$STORE/entries/$(uri "$key")"
		[ "$status" = 200 ] || continue
		[ "$(jq -r '.value.removed // false' <<<"$body")" = true ] || echo "$key"
	done
}

remove() {
	local report key found=0
	report=$(report_key "$1")
	while IFS= read -r key; do
		[ -n "$key" ] || continue
		found=1
		call DELETE "$base/$STORE/entries/$(uri "$key")"
		case "$status" in
		200 | 204) echo "Removed $(mask "$key")" && summary "Removed \`$(mask "$key")\`" ;;
		404) echo "No credit at $(mask "$key"); nothing to remove." ;;
		403)
			# no :delete on the key: blank the credit instead (no userId, so IdeaCredits.sanitize drops it)
			call PATCH "$base/$STORE/entries/$(uri "$key")" -H "Content-Type: application/json" \
				--data '{"value":{"removed":true},"users":[]}'
			case "$status" in
			200) echo "Blanked $(mask "$key") (the key has no delete permission); the board skips it" &&
				summary "Blanked \`$(mask "$key")\`" ;;
			404) echo "No credit at $(mask "$key"); nothing to remove." ;;
			*) fail ;;
			esac
			;;
		*) fail ;;
		esac
	done <<<"$(credits_for "$report")"
	[ "$found" = 1 ] || echo "No credit for $(mask "$report"); nothing to remove."
}

action=${1:-list}
case "$action" in
list) [ $# -le 1 ] || usage ;;
add)
	[ $# -eq 4 ] || usage
	add "$2" "$3" "$4"
	;;
remove)
	[ $# -eq 2 ] || usage
	remove "$2"
	;;
*) usage ;;
esac
list
