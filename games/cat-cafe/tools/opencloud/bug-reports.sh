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
# The report text printed is only the copy BugReportService kept through Roblox's broadcast filter (filteredText,
# record v 2, decisions.md 2026-11-01), since every Actions log on this public repo is public and once the game is
# public the reporters are strangers, many of them young. A v 1 record (before the filter) or one whose filtering
# failed shows a placeholder instead; its raw text stays in the data store, for Debug.bugReports in Studio.
# Names and ids are masked (#3103): each name shrinks to its first letter and each user id to its last three digits,
# the error lists lose names and ids too (the comment by the print step says how), and the JSON records are left out
# of the log and the summary. That is the default, and in GitHub Actions it is the only way: every Actions log on this repo is public, a run started by hand as much as the daily one.
#   MASK=0  full names, ids and JSON records, only when run on a PC (ignored when GITHUB_ACTIONS is true)
# Needs curl and jq (both on GitHub's ubuntu runners).
set -euo pipefail

DAY=${1:-}
DAY=${DAY:-$(date -u +%Y%m%d)}
COUNT=${2:-50}
UNIVERSE_ID=${UNIVERSE_ID:-10773193456}
STORE=BugReports_v1
: "${ROBLOX_PUBLISH_KEY:?set ROBLOX_PUBLISH_KEY (docs/setup-guide.md step 17)}"
# #3103: masked unless MASK=0 on a PC; a GitHub Actions log is public, so there it is always masked
if [ "${GITHUB_ACTIONS:-}" = true ] || [ "${MASK:-1}" != 0 ]; then
	MASK=1
else
	MASK=0
fi

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
	# The data store only exists once a server has saved the first report, so until then Roblox answers 404.
	if [ "$status" = 404 ] && [[ $body == *"Data store not found"* ]]; then
		echo "== 0 reports: no server has saved a bug report yet, so $STORE does not exist."
		[ -z "${GITHUB_STEP_SUMMARY:-}" ] || echo "### 0 bug reports: \`$STORE\` is made by the first report" >>"$GITHUB_STEP_SUMMARY"
		exit 0
	fi
	if [ "$status" != 200 ]; then
		echo "Open Cloud answered HTTP $status: $body" >&2
		case "$status" in
		401 | 403) echo "The key needs universe-datastores.objects:list and :read on universe $UNIVERSE_ID (docs/setup-guide.md step 17)." >&2 ;;
		esac
		exit 1
	fi
}

# Keys end in <os.time()>_<userId> with a ten-digit time, so a day's keys list in time order; keep the newest COUNT.
# #2082: Open Cloud lists an entry's id as "<scope>/<key>" ("global/r_2026..."), and SetAsync saves under the global
# scope, so the filter starts with "global/"; a bare prefix matched nothing and every day read 0 reports.
keys=()
token=
while :; do
	args=(--data-urlencode "filter=id.startsWith(\"global/$prefix\")" --data-urlencode maxPageSize=256)
	[ -z "$token" ] || args+=(--data-urlencode "pageToken=$token")
	get "$entries" "${args[@]}"
	mapfile -t -O "${#keys[@]}" keys < <(jq -r '.dataStoreEntries[]?.id' <<<"$body")
	token=$(jq -r '.nextPageToken // empty' <<<"$body")
	[ -n "$token" ] || break
done
total=${#keys[@]}
if [ "$total" = 0 ]; then
	# 0 under this day's prefix: say what the store holds at all, so "nothing saved" (nobody's report arrived) can be
	# told from "saved somewhere this listing does not look" (#2082). Only the first 10 characters of each key are
	# printed (the day), never a user id, since this log is public.
	shapes=()
	token=
	for _ in 1 2 3 4; do
		args=(--data-urlencode maxPageSize=256)
		[ -z "$token" ] || args+=(--data-urlencode "pageToken=$token")
		get "$entries" "${args[@]}"
		mapfile -t -O "${#shapes[@]}" shapes < <(jq -r '.dataStoreEntries[]?.id | sub("^global/"; "") | .[0:10]' <<<"$body")
		token=$(jq -r '.nextPageToken // empty' <<<"$body")
		[ -n "$token" ] || break
	done
	echo "== the store holds ${#shapes[@]} entries without a filter (first 4 pages); key starts:"
	[ "${#shapes[@]}" = 0 ] || printf '%s\n' "${shapes[@]}" | sort | uniq -c
fi
if [ "$total" -gt "$COUNT" ]; then
	keys=("${keys[@]:total-COUNT}")
fi

records=()
for key in "${keys[@]}"; do
	get "$entries/${key#global/}" # the listed id is "global/<key>"; the entry path takes the bare key (#2082)
	# the raw text never leaves this script: filteredText stands in for it, or a placeholder
	records+=("$(jq -c '.value | .text = (if (.filteredText | type) == "string" then .filteredText
		elif (.v // 1) < 2 then "(v1 report from before the filter: read it with Debug.bugReports in Studio)"
		else "(the filter failed on this one: read it with Debug.bugReports in Studio)" end) | del(.filteredText)' \
		<<<"$body")")
done

echo "== $total reports under $prefix in $STORE; showing the newest ${#records[@]}"
# The same fields and order as BugReportService's line(), times in UTC.
who='\(.name) (\(.userId))'
client='\(.clientErrors // [] | join(" / "))'
server='\(.serverErrors // [] | join(" / "))'
# Masked, the error lists lose names and ids as well (#3103). An error line carries the instance path, and a
# player's own scripts, character and screens sit under their name ("Players.<Name>.PlayerScripts...",
# "Workspace.<Name>..."), so that name becomes ***; the reporter's name becomes *** wherever else it stands, and a
# run of 6 or more digits (a user id, a save key) becomes #. A client line is text the player's device chose and no
# filter has read, so only its script and line number are printed ("Players.***.PlayerScripts.Client.UI:12"); a
# line of any other shape prints as "(text left out)".
defs='def scrub($n): tostring | gsub("(?<w>Players|Workspace)\\.[^.:\\s]+"; "\(.w).***")
	| (if ($n | length) > 2 then split($n) | join("***") else . end) | gsub("[0-9]{6,}"; "#");
def where: (capture("^(?<p>[A-Za-z0-9_.*]+:[0-9]+)(:|$)") | .p) // "(text left out)";
'
if [ "$MASK" = 1 ]; then
	who='\(.name | tostring | .[0:1])*** (...\(.userId | tostring | .[-3:])) at=\(.at)' # at is the key's time: idea-credits add takes r_<day>_<at>
	client='\((.name | tostring) as $n | .clientErrors // [] | map(scrub($n) | where) | join(" / "))'
	server='\((.name | tostring) as $n | .serverErrors // [] | map(scrub($n)) | join(" / "))'
fi
line=$defs'(if (.at | type) == "number" then .at else 0 end | strftime("%H:%M")) + " \(.kind) '"$who"
line+=' v\(.placeVersion) \(.area) \(.device): \(.text) | client '"$client"
line+=' | server '"$server"'"'
for record in "${records[@]}"; do
	jq -r "$line" <<<"$record"
done
if [ "$MASK" = 1 ]; then
	echo "== records as JSON left out (masked); for full records use Debug.bugReports in Studio, or this script on a PC with MASK=0"
else
	echo "== records as JSON"
	[ "${#records[@]}" = 0 ] || printf '%s\n' "${records[@]}"
fi

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
