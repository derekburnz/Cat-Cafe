#!/usr/bin/env bash
# Print the in-game bug reports (data store BugReports_v1, written by src/server/Services/BugReportService.luau)
# through Open Cloud, so a thread reads them without Studio. Read only: it never writes or deletes an entry.
# Run by .github/workflows/bug-reports.yml; also works from Git Bash on a PC with the same variables set.
#
#   ROBLOX_PUBLISH_KEY   Open Cloud API key that also has universe-datastores.objects:list and :read on the Cat Cafe
#                        experience (docs/setup-guide.md step 17)
#   UNIVERSE_ID          default below
#
# Usage:  tools/opencloud/bug-reports.sh [day] [count] [studio]
#   day     UTC day as YYYYMMDD (default today)
#   count   the newest this many reports of that day (default 50), printed oldest first
#   studio  read the Studio playtests' reports (s_ keys) instead of the players' (r_ keys)
# Prints one line per report, as Debug.bugReports does, then every record as one JSON line.
# Needs curl and jq (both on GitHub's ubuntu runners).
set -euo pipefail

DAY=${1:-}
DAY=${DAY:-$(date -u +%Y%m%d)}
COUNT=${2:-50}
UNIVERSE_ID=${UNIVERSE_ID:-10773193456}
STORE=BugReports_v1
: "${ROBLOX_PUBLISH_KEY:?set ROBLOX_PUBLISH_KEY (docs/setup-guide.md step 17)}"

[[ $DAY =~ ^[0-9]{8}$ ]] || {
	echo "day must be YYYYMMDD, got: $DAY" >&2
	exit 2
}
[[ $COUNT =~ ^[1-9][0-9]*$ ]] || {
	echo "count must be a positive number, got: $COUNT" >&2
	exit 2
}
prefix=r_${DAY}_ # BugReport.prefix: r_<YYYYMMDD>_ from live servers, s_ from Studio
if [ "${3:-}" = studio ]; then
	prefix=s_${DAY}_
fi
entries=https://apis.roblox.com/cloud/v2/universes/$UNIVERSE_ID/data-stores/$STORE/entries

reply=$(mktemp)
trap 'rm -f "$reply"' EXIT
# get url [curl args...] -> sets $status and $body. Roblox answers 5xx or 429 now and then, so those get three more
# tries over about half a minute.
get() {
	local url=$1 wait
	shift
	for wait in 5 10 20 0; do
		status=$(curl -sS -o "$reply" -w '%{http_code}' --get "$url" -H "x-api-key: $ROBLOX_PUBLISH_KEY" "$@") || status=000
		case "$status" in
		5?? | 429 | 000) ;;
		*) break ;;
		esac
		[ "$wait" = 0 ] && break
		echo "Open Cloud answered HTTP $status; trying again in ${wait}s." >&2
		sleep "$wait"
	done
	body=$(cat "$reply")
	if [ "$status" != 200 ]; then
		echo "Open Cloud answered HTTP $status: $body" >&2
		case "$status" in
		401 | 403) echo "The key needs universe-datastores.objects:list and :read on universe $UNIVERSE_ID (docs/setup-guide.md step 17)." >&2 ;;
		esac
		exit 1
	fi
}

# Keys end in <os.time()>_<userId> with a ten-digit time, so a day's keys list in time order; keep the newest COUNT.
keys=()
token=
while :; do
	args=(--data-urlencode "filter=id.startsWith(\"$prefix\")" --data-urlencode maxPageSize=256)
	[ -z "$token" ] || args+=(--data-urlencode "pageToken=$token")
	get "$entries" "${args[@]}"
	mapfile -t -O "${#keys[@]}" keys < <(jq -r '.dataStoreEntries[]?.id' <<<"$body")
	token=$(jq -r '.nextPageToken // empty' <<<"$body")
	[ -n "$token" ] || break
done
total=${#keys[@]}
if [ "$total" -gt "$COUNT" ]; then
	keys=("${keys[@]:total-COUNT}")
fi

records=()
for key in "${keys[@]}"; do
	get "$entries/$key"
	records+=("$(jq -c '.value' <<<"$body")")
done

echo "== $total reports under $prefix in $STORE; showing the newest ${#records[@]}"
# The same fields and order as BugReportService's line(), times in UTC.
line='(if (.at | type) == "number" then .at else 0 end | strftime("%H:%M")) + " \(.kind) \(.name) (\(.userId))'
line+=' v\(.placeVersion) \(.area) \(.device): \(.text) | client \(.clientErrors // [] | join(" / "))'
line+=' | server \(.serverErrors // [] | join(" / "))"'
for record in "${records[@]}"; do
	jq -r "$line" <<<"$record"
done
echo "== records as JSON"
[ "${#records[@]}" = 0 ] || printf '%s\n' "${records[@]}"

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
	{
		echo "### $total bug reports under \`$prefix\`, newest ${#records[@]}"
		echo '```text'
		for record in "${records[@]}"; do
			jq -r "$line" <<<"$record" | tr '`' "'"
		done
		echo '```'
	} >>"$GITHUB_STEP_SUMMARY"
fi
