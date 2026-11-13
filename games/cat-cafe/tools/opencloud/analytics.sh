#!/usr/bin/env bash
# Print the first-session numbers from Roblox analytics (Open Cloud Analytics Query API, beta), so a thread reads
# where new players quit without Creator Hub. Read only. Sections:
#   1. every funnel, players (or runs, for catch_attempt and bait_cycle) per step: the onboarding funnels
#      (src/shared/Onboarding.luau: onboarding_v4 and onboarding_v4_intro since #1888, onboarding_v3 and its intro
#      since #1273, onboarding_v2 before it and the alpha's twelve step one before that), the Store funnel (store,
#      src/shared/StoreFunnel.luau: opened, tab_viewed, buy_pressed, completed) and the recurring ones
#      (docs/growth/analytics-plan.md section 4),
#      with the share of step 1 left and how many were
#      lost since the step before; the biggest loss is the first thing to fix. Roblox lets FunnelName be a filter
#      only, so the script asks which funnels were logged (dimension-values) and then reads each funnel on its own.
#   2. players per day, new and returning; average session length; day 1 retention
#   3. how long new players' first sessions lasted (Roblox's session time buckets)
#   4. the most logged custom events (tutorial_step, intro_cutscene, travel and the rest of Telemetry.custom), each
#      read on its own the same way, since CustomEventName is a filter only too
#      (session_start carries the join source in its first field: organic, unknown or ad_<tag> from a link's
#      launchData=ad_<tag>; robux_purchase, store_cancelled, cafe_pass_level and jukebox_pick since #1888)
#   5. audience (#2391): players new and returning and day 1 retention by Platform, Country, AgeGroupV2 and Gender; average
#      session by Platform; the current onboarding funnel and first_hour (time steps, played_30s to played_60m) by
#      Platform, so phone and PC drop-offs read side by side. Funnels take no Country breakdown.
#   6. event fields (2026-11-09): quit_state, step_time, cat_caught_area, bait_rolled, bait_resolved (#3030),
#      first_bait_wait and first_bait_arrived read
#      by their custom fields (CustomField1 to 3) and by Platform, players or the average value
# The API takes 30 queries a minute, and a window with 40 custom events needs about 100, so a run paces itself and can
# take three or four minutes.
# Run by .github/workflows/analytics.yml; also works from Git Bash on a PC with the same variables set.
#
#   ROBLOX_PUBLISH_KEY   Open Cloud API key that also has universe-analytics universe.analytics:read on the Cat Cafe
#                        experience (docs/setup-guide.md step 20)
#   UNIVERSE_ID          default below
#
# Usage:  tools/opencloud/analytics.sh [days] [funnel]
#   days    whole UTC days back from today (default 14). Today is left out: Roblox fills a day about a day late.
#   funnel  only this funnel (default: every funnel); "ads" reads the ad campaigns instead (ads.sh)
# Every raw answer is printed after "== raw", since the API is in beta and its shapes may change. Fields are as in the
# Open Cloud reference (create.roblox.com/docs/cloud/reference/features/analytics): QueryRequest and
# DimensionValuesRequest, filters as {dimension, operation: "In", values}.
# Needs curl and jq (both on GitHub's ubuntu runners).
set -euo pipefail

DAYS=${1:-}
DAYS=${DAYS:-14}
FUNNEL=${2:-}
# funnel "ads": read the ad campaigns instead (ads.sh, Ads API beta, read only)
if [ "$FUNNEL" = ads ]; then
	exec bash "$(dirname "$0")/ads.sh"
fi
UNIVERSE_ID=${UNIVERSE_ID:-10773193456}
: "${ROBLOX_PUBLISH_KEY:?set ROBLOX_PUBLISH_KEY (docs/setup-guide.md step 20)}"

[[ $DAYS =~ ^[1-9][0-9]*$ ]] && [ "$DAYS" -le 365 ] || {
	echo "days must be 1 to 365, got: $DAYS" >&2
	exit 2
}
end=$(date -u +%Y-%m-%dT00:00:00Z)
start=$(date -u -d "$DAYS days ago" +%Y-%m-%dT00:00:00Z)
api=https://apis.roblox.com/analytics-query-api
here=$(cd "$(dirname "$0")" && pwd)
onboarding=$here/../../src/shared/Onboarding.luau

reply=$(mktemp)
raw=$(mktemp)
out=$(mktemp)
trap 'rm -f "$reply" "$raw" "$out"' EXIT

# pace: the metrics and dimension-values POSTs share a limit of 30 a minute per key owner (polling the answers has
# its own, far higher one). Keep at most 28 in any 60 seconds, waiting out the oldest when that many went out.
posted=()
pace() {
	local now kept=() t
	while :; do
		now=$(date +%s)
		kept=()
		for t in "${posted[@]}"; do
			[ $((now - t)) -lt 60 ] && kept+=("$t")
		done
		posted=("${kept[@]}")
		[ "${#posted[@]}" -lt 28 ] && break
		sleep $((60 - (now - posted[0])))
	done
	posted+=("$now")
}

# call method url [json] -> sets $status and $body, and fails on an answer other than 200 or 202. Roblox answers 5xx
# or 429 now and then, so those get three more tries over about half a minute. A key without the analytics
# permission stops the whole run.
call() {
	local method=$1 url=$2 data=${3:-} wait
	for wait in 5 10 20 0; do
		if [ "$method" = POST ]; then
			pace
			status=$(curl -sS -o "$reply" -w '%{http_code}' -X POST "$url" -H "x-api-key: $ROBLOX_PUBLISH_KEY" \
				-H 'Content-Type: application/json' --data "$data") || status=000
		else
			status=$(curl -sS -o "$reply" -w '%{http_code}' "$url" -H "x-api-key: $ROBLOX_PUBLISH_KEY") || status=000
		fi
		case "$status" in
		5?? | 429 | 000) ;;
		*) break ;;
		esac
		[ "$wait" = 0 ] && break
		echo "Open Cloud answered HTTP $status; trying again in ${wait}s." >&2
		sleep "$wait"
	done
	body=$(cat "$reply")
	case "$status" in
	200 | 202) ;;
	401 | 403)
		echo "Open Cloud answered HTTP $status: $body" >&2
		echo "The key needs universe-analytics universe.analytics:read on universe $UNIVERSE_ID (docs/setup-guide.md step 20)." >&2
		[ -z "${GITHUB_STEP_SUMMARY:-}" ] || echo "### The key cannot read analytics yet: docs/setup-guide.md step 20" >>"$GITHUB_STEP_SUMMARY"
		exit 1
		;;
	*) return 1 ;; # the caller reports it and goes on with the next section
	esac
}

# operation kind request label -> POSTs request to $api/v1/universes/$UNIVERSE_ID/<kind> (metrics or
# dimension-values) and sets $result to the finished operation's .response, or returns 1 with the reason in $result.
# A slow query answers 202 with a path, polled every 2 s for up to 2 minutes.
operation() {
	local kind=$1 request=$2 label=$3 tries=0 path
	if ! call POST "$api/v1/universes/$UNIVERSE_ID/$kind" "$request"; then
		result="$label: HTTP $status: $body"
		return 1
	fi
	while [ "$(jq -r 'if .response or .error then true else (.done // false) end' <<<"$body")" != true ]; do
		path=$(jq -r '.path // empty' <<<"$body")
		if [ -z "$path" ] || [ "$tries" -ge 60 ]; then
			result="no answer for $label (HTTP $status): $body"
			return 1
		fi
		tries=$((tries + 1))
		sleep 2
		if ! call GET "$api/$path"; then
			result="$label: HTTP $status: $body"
			return 1
		fi
	done
	printf '%s %s\n' "$request" "$body" >>"$raw"
	if jq -e '.error' <<<"$body" >/dev/null; then
		result="$label failed: $(jq -c '.error' <<<"$body")"
		return 1
	fi
	result=$(jq -c '.response' <<<"$body")
}

# only dimension value -> the filter list that keeps one value of a dimension, for query's fourth argument
only() {
	jq -nc --arg dimension "$1" --arg value "$2" '[{dimension: $dimension, operation: "In", values: [$value]}]'
}

# query metric granularity [breakdown,...] [filters] -> sets $result to the metric's .response (see operation).
# filters is a JSON list of QueryFilter, such as only's.
query() {
	local request
	request=$(jq -nc --arg metric "$1" --arg granularity "$2" --arg breakdown "${3:-}" --arg start "$start" \
		--arg end "$end" --argjson filter "${4:-[]}" '{metric: $metric, granularity: $granularity, startTime: $start,
			endTime: $end}
		+ (if $breakdown == "" then {} else {breakdown: ($breakdown | split(","))} end)
		+ (if $filter == [] then {} else {filter: $filter} end)
		+ (if $breakdown != "" and $granularity == "None" then {limit: 500} else {} end)')
	operation metrics "$request" "$1"
}

# values metric dimension -> sets $result to the values Roblox has for that dimension of that metric in the window,
# one per line, or returns 1 with the reason (see operation). For a dimension that can only be a filter, this is
# how to learn what to filter on.
values() {
	local request
	request=$(jq -nc --arg metric "$1" --arg dimension "$2" --arg start "$start" --arg end "$end" \
		'{metric: $metric, dimensions: [$dimension], startTime: $start, endTime: $end, limit: 500}')
	operation dimension-values "$request" "$1 $2 values" || return 1
	result=$(jq -r --arg d "$2" '.values[]? | select((.dimension // $d) == $d) | .values[]? | .value // empty
		| tostring | select(. != "")' <<<"$result" | sort -u)
}

# total -> the sum of every data point in $result, as a whole number (one point for a query with no breakdown or
# granularity)
total() {
	jq -r '[.values[]? | (.dataPoints // [])[] | .value // 0] | add // 0 | floor' <<<"$result"
}

# The rows of $result as tab-separated lines: each breakdown's value (its label when Roblox has one), then each data
# point as time=value, or the one value when the query has no granularity.
rows() {
	jq -r '.values[]? | [(.breakdowns // [])[] | (.displayValue // .value // "" | tostring)]
		+ [(.dataPoints // [])[] | if .time then "\(.time[0:10])=\(.value)" else (.value | tostring) end] | @tsv' \
		<<<"$result"
}

say() { printf '%s\n' "$*" >>"$out"; }
failed() { say "_${result//|/\\|}_" && say ""; }

# Step names: the onboarding funnels' from Onboarding.luau (names never change once shipped), the recurring ones'
# from Telemetry.luau, the Store funnel's from StoreFunnel.luau. Roblox labels a step with its name when it has one,
# which wins. Since #1888 the funnel named Onboarding.FUNNEL (onboarding_v4) numbers its 45 steps by Onboarding.STEPS
# and Onboarding.INTRO_FUNNEL (onboarding_v4_intro) its 13 by Onboarding.INTRO_STEPS; onboarding_v3 and
# onboarding_v3_intro (#1273 to #1888, still in a window that starts before it) keep their first 37 steps
# (Onboarding.V3_STEPS) and the same intro steps; onboarding_v2 (F87 to #1273) uses Onboarding.V2_STEPS, and the
# alpha's funnel before it Onboarding.V1_STEPS. The store funnel (one run per Store visit) uses StoreFunnel.STEPS.
declare -A names=(
	[catch_attempt.1]=swing_hit [catch_attempt.2]=engaged [catch_attempt.3]=caught [catch_attempt.4]=checked_in
	[catch_attempt.5]=working [bait_cycle.1]=set [bait_cycle.2]=seen [bait_cycle.3]=tamed
)
# first_hour (#2391, one session per player, account playtime): Onboarding.FIRST_HOUR_FUNNEL and FIRST_HOUR_STEPS
# win when Onboarding.luau has them; these are the names Research-Agent proposed.
firstHourFunnel=first_hour
firstHourSteps=(joined played_2m played_5m played_10m played_20m played_30m played_45m played_60m)
firstHourV2Steps=()
onboardingFunnel=onboarding_v4
introFunnel=onboarding_v4_intro
# #3695: the clean funnel (Onboarding.CLEAN_FUNNEL, onboarding_v7) and playtime_v1 (Onboarding.PLAYTIME_FUNNEL). Once
# Onboarding.luau has them they are the two the by Platform tables read; the ledger funnel (FUNNEL, onboarding_v6)
# and first_hour_v3 stopped being sent with them and keep their labels for a window that starts before.
cleanFunnel=
cleanSteps=()
playtimeFunnel=
playtimeSteps=()
onboardingSteps=()
introSteps=()
onboardingV3Steps=()
onboardingV2Steps=()
storeFunnel=store
storeSteps=()
onboardingV1Steps=()
onboardingV4Steps=()
if [ -f "$onboarding" ]; then
	luaNames() { sed -n "/^Onboarding\.$1 = {/,/^}/p" "$onboarding" | grep -o '"[a-z0-9_]*"' | tr -d '"'; }
	luaString() { sed -n "s/^Onboarding\.$1 = \"\([A-Za-z0-9_]*\)\".*/\1/p" "$onboarding"; }
	mapfile -t onboardingSteps < <(luaNames STEPS)
	mapfile -t introSteps < <(luaNames INTRO_STEPS)
	# V3_STEPS is the first V3_COUNT of STEPS (a table.move, not a literal), so cut them here
	v3Count=$(sed -n 's/^Onboarding\.V3_COUNT = \([0-9]*\).*/\1/p' "$onboarding")
	onboardingV3Steps=("${onboardingSteps[@]:0:${v3Count:-37}}")
	mapfile -t onboardingV2Steps < <(luaNames V2_STEPS)
	mapfile -t onboardingV1Steps < <(luaNames V1_STEPS)
	# once FUNNEL moves on (onboarding_v5), v4 keeps its labels only through V4_STEPS; without it, numbers only
	mapfile -t onboardingV4Steps < <(luaNames V4_STEPS)
	mapfile -t list < <(luaNames FIRST_HOUR_STEPS)
	[ "${#list[@]}" = 0 ] || firstHourSteps=("${list[@]}")
	# #3308: first_hour_v3 put played_3m and played_4m in; v2's rows keep their labels through FIRST_HOUR_V2_STEPS
	mapfile -t firstHourV2Steps < <(luaNames FIRST_HOUR_V2_STEPS)
	funnelName=$(luaString FIRST_HOUR_FUNNEL)
	firstHourFunnel=${funnelName:-$firstHourFunnel}
	funnelName=$(luaString FUNNEL)
	onboardingFunnel=${funnelName:-$onboardingFunnel}
	funnelName=$(luaString INTRO_FUNNEL)
	introFunnel=${funnelName:-$introFunnel}
	cleanFunnel=$(luaString CLEAN_FUNNEL)
	mapfile -t cleanSteps < <(luaNames CLEAN_STEPS)
	playtimeFunnel=$(luaString PLAYTIME_FUNNEL)
	mapfile -t playtimeSteps < <(luaNames PLAYTIME_STEPS)
fi
storeFunnelFile=$here/../../src/shared/StoreFunnel.luau
if [ -f "$storeFunnelFile" ]; then
	mapfile -t storeSteps < <(sed -n '/^StoreFunnel\.STEPS = {/p' "$storeFunnelFile" | grep -o '"[a-z0-9_]*"' | tr -d '"')
	funnelName=$(sed -n 's/^StoreFunnel\.NAME = "\([A-Za-z0-9_]*\)".*/\1/p' "$storeFunnelFile")
	storeFunnel=${funnelName:-$storeFunnel}
fi
# #3378: arcade_v1 (shared/ArcadeFunnel), one run per player per UTC day; the defaults hold until that file is on main
arcadeFunnel=arcade_v1
arcadeSteps=(arcade_seen arcade_opened arcade_started arcade_first_circle arcade_finished arcade_played_again)
arcadeFunnelFile=$here/../../src/shared/ArcadeFunnel.luau
if [ -f "$arcadeFunnelFile" ]; then
	mapfile -t list < <(sed -n '/^ArcadeFunnel\.STEPS = /,/^})/p' "$arcadeFunnelFile" | grep -o '"[a-z0-9_]*"' | tr -d '"')
	[ "${#list[@]}" = 0 ] || arcadeSteps=("${list[@]}")
	funnelName=$(sed -n 's/^ArcadeFunnel\.NAME = "\([A-Za-z0-9_]*\)".*/\1/p' "$arcadeFunnelFile")
	arcadeFunnel=${funnelName:-$arcadeFunnel}
fi
stepName() { # funnel step label
	local funnel=$1 step=$2 label=$3
	local -a list=()
	if [ -n "$label" ] && [ "$label" != "$step" ]; then
		printf '%s' "$label"
	elif [ -n "${names[$funnel.$step]:-}" ]; then
		printf '%s' "${names[$funnel.$step]}"
	elif [[ $step =~ ^[0-9]+$ ]] && [ "$step" -ge 1 ]; then
		# exact names first: onboarding_v4_intro also contains onboarding_v4
		if [ "${funnel,,}" = "${introFunnel,,}" ] || [[ ${funnel,,} =~ ^onboarding_v[0-9]+_intro$ ]]; then
			list=("${introSteps[@]}")
		elif [ -n "$cleanFunnel" ] && [ "${funnel,,}" = "${cleanFunnel,,}" ]; then
			list=("${cleanSteps[@]}")
		elif [ -n "$playtimeFunnel" ] && [ "${funnel,,}" = "${playtimeFunnel,,}" ]; then
			list=("${playtimeSteps[@]}")
		elif [ "${funnel,,}" = "${onboardingFunnel,,}" ]; then
			list=("${onboardingSteps[@]}")
		elif [ "${funnel,,}" = "${firstHourFunnel,,}" ]; then
			list=("${firstHourSteps[@]}")
		elif [ "${funnel,,}" = first_hour_v2 ]; then
			list=("${firstHourV2Steps[@]}")
		elif [ "${funnel,,}" = onboarding_v4 ]; then
			list=("${onboardingV4Steps[@]}")
		elif [ "${funnel,,}" = onboarding_v3 ]; then
			list=("${onboardingV3Steps[@]}")
		elif [ "${funnel,,}" = "${storeFunnel,,}" ]; then
			list=("${storeSteps[@]}")
		elif [ "${funnel,,}" = "${arcadeFunnel,,}" ]; then
			list=("${arcadeSteps[@]}")
		elif [ "${funnel,,}" = onboarding_v2 ]; then
			list=("${onboardingV2Steps[@]}")
		elif [[ ${funnel,,} == *onboarding* && ! ${funnel,,} =~ onboarding_v[0-9]+ ]]; then
			list=("${onboardingV1Steps[@]}")
		fi
		if [ "$step" -le "${#list[@]}" ]; then
			printf '%s' "${list[step - 1]}"
		fi
	fi
}

say "## Cat Cafe analytics, ${start:0:10} to the end of $(date -u -d "1 day ago" +%Y-%m-%d) (UTC)"
say ""
say "Roblox fills a day about a day late, and records only live servers (not Studio)."
say ""

# 1. Funnels. FunnelUserTotalCount by FunnelStep, one funnel at a time (FunnelName is a filter only, and a required
# one): the funnel sessions that reached each step in the window. The onboarding funnels have one session per player,
# so they count players; catch_attempt (a GUID per attempt) and bait_cycle (one per bait) count runs.
# Funnels whose steps were renumbered under the same name: funnel -> "first clean day|what changed". Roblox keys steps
# by number, so a window that starts before that day adds the old step N to the new step N.
declare -A renumbered=(
	[catch_attempt]="2026-11-03|F93 (live v87, 11-02 02:58 UTC) put swing_hit in as step 1; before it step 1 was engaged, 2 caught, 3 checked_in and 4 working, and old servers ran past the publish."
)
# Funnels the game no longer sends (#2444, live from 2026-11-08): funnel -> "last day sent|where to read instead".
# Roblox still returns their rows for a window that reaches back that far, and those rows do not add up: bait_cycle
# kept one run per bowl of food and its timer runs while the player is away, so a bowl set before the window (or on a
# server that had already stopped sending) still lands in it as "tamed", and the step shows more runs than "set"
# (#3030: 53 tamed to 43 set).
declare -A retired=(
	[bait_cycle]="2026-11-08|bait_rolled and bait_resolved under Event fields"
	[grand_opening]="2026-11-08|the Grand Opening steps of the onboarding funnel"
	[onboarding_v4_intro]="2026-11-08|the intro_cutscene custom event"
	[onboarding_v6]="2026-11-13|onboarding_v7, the clean funnel (#3695)"
	[first_hour_v3]="2026-11-13|playtime_v1 (#3695)"
)
funnelTable() { # funnel: the table for one funnel, or its error
	local funnel=$1 line step label users first=0 previous=0 share lost unit=Runs change= gone=
	local -a lines=()
	[[ ${funnel,,} != *onboarding* && ${funnel,,} != first_hour* && ${funnel,,} != playtime* ]] || unit=Players
	[ "${funnel,,}" != "${arcadeFunnel,,}" ] || unit="Player days" # #3378: one run per player per UTC day
	say "#### $funnel"
	say ""
	if ! query FunnelUserTotalCount None FunnelStep "$(only FunnelName "$funnel")"; then
		failed
		return
	fi
	# FunnelStep values are the step numbers; the label column keeps a step name when Roblox sends one. Fields are
	# joined with | rather than tabs, since read folds runs of tabs and would lose an empty label.
	mapfile -t lines < <(jq -r '.values[]? | (.breakdowns // []) as $b
		| ($b | map(select(.dimension == "FunnelStep"))[0] // $b[0] // {}) as $s
		| [($s.value // "" | tostring), ($s.displayValue // "" | tostring),
			((.dataPoints // [])[0].value // 0 | tostring)] | join("|")' <<<"$result" | sort -t'|' -k1,1n)
	if [ "${#lines[@]}" = 0 ]; then
		say "No steps of $funnel logged in this window."
		say ""
		return
	fi
	gone=${retired[$funnel]:-}
	if [ -n "$gone" ]; then
		say "_Retired: the game stopped sending $funnel on ${gone%%|*} (#2444). These rows are what is left from before then, a later step can count more than an earlier one, and they are not live numbers. Read ${gone#*|} instead._"
		say ""
	fi
	say "| Step | Name | $unit | Of step 1 | Lost since the step before |"
	say "|---:|---|---:|---:|---:|"
	for line in "${lines[@]}"; do
		IFS='|' read -r step label users <<<"$line"
		users=${users%.*}
		[ "$first" -gt 0 ] || first=$users # step 1 has no step before it
		share=$(awk -v a="$users" -v b="$first" 'BEGIN { if (b > 0) printf "%d%%", a * 100 / b; else print "-" }')
		lost=$(awk -v a="$users" -v b="$previous" 'BEGIN { if (b > 0 && b >= a) printf "%d (%d%%)", b - a, (b - a) * 100 / b; else print "-" }')
		say "| $step | $(stepName "$funnel" "$step" "$label") | $users | $share | $lost |"
		previous=$users
	done
	say ""
	if [ "$unit" = Runs ]; then
		say "_Runs, not players: each attempt is its own funnel session, so one player counts many times._"
		say ""
	fi
	change=${renumbered[$funnel]:-}
	if [ -n "$change" ] && [[ ${start:0:10} < ${change%%|*} ]]; then
		say "_Mixed numbering: ${change#*|} This window starts before ${change%%|*}, so old and new steps add up under one number and the losses between steps are wrong._"
		say ""
	fi
}

say "### Funnels: players (onboarding) or runs per step"
say ""
if values FunnelUserTotalCount FunnelName; then
	# the onboarding funnels first, then the rest by name
	mapfile -t funnels < <(printf '%s\n' "$result" | sed '/^$/d' | awk '{ print (tolower($0) ~ /onboarding/ ? 0 : 1) "\t" $0 }' \
		| sort -t$'\t' -k1,1n -k2,2 | cut -f2-)
	if [ -n "$FUNNEL" ]; then
		# read the one asked for even when the list leaves it out, so a misspelt name still shows Roblox's answer
		if [ "${#funnels[@]}" -gt 0 ] && ! printf '%s\n' "${funnels[@]}" | grep -qxF "$FUNNEL"; then
			say "Funnels logged in this window: $(printf '%s\n' "${funnels[@]}" | paste -sd, - | sed 's/,/, /g')."
			say ""
		fi
		funnels=("$FUNNEL")
	elif [ "${#funnels[@]}" = 0 ]; then
		say "No funnel steps logged in this window."
		say ""
	fi
	for funnel in "${funnels[@]}"; do
		funnelTable "$funnel"
	done
else
	failed
fi

# 2. Players, sessions and day 1 retention per day.
say "### Players and sessions per day"
say ""
declare -A newUsers=() returning=() session=() d1=()
days=()
for ((i = DAYS; i >= 1; i--)); do
	days+=("$(date -u -d "$i days ago" +%Y-%m-%d)")
done
if query DailyActiveUsers OneDay IsNewUser; then
	while IFS=$'\t' read -r isNew points; do
		for point in $points; do # time=value pairs, split on the tabs
			if [[ ${isNew,,} == true || ${isNew,,} == new* ]]; then
				newUsers[${point%%=*}]=${point#*=}
			else
				returning[${point%%=*}]=${point#*=}
			fi
		done
	done < <(rows)
else
	failed
fi
if query AverageSessionLengthMinutes OneDay; then
	for point in $(rows); do
		session[${point%%=*}]=$(awk -v v="${point#*=}" 'BEGIN { printf "%.1f", v }')
	done
else
	failed
fi
if query ForwardD1Retention OneDay; then
	for point in $(rows); do
		d1[${point%%=*}]=$(awk -v v="${point#*=}" 'BEGIN { if (v <= 1) v *= 100; printf "%.0f%%", v }')
	done
else
	failed
fi
say "| Day | New players | Returning | Avg session (min) | Day 1 retention |"
say "|---|---:|---:|---:|---:|"
for day in "${days[@]}"; do
	say "| $day | ${newUsers[$day]:--} | ${returning[$day]:--} | ${session[$day]:--} | ${d1[$day]:--} |"
done
say ""

# 2b. The six Creator Hub benchmark items (Derek 2026-11-12: every stats update breaks them down): average playtime,
# day 1 and day 7 retention, payer conversion, revenue per paying user and qualified play-through. Day 1 is in the
# table above. Read 2026-11-12 (run 43126077718): the Query API answers ForwardD7Retention, PayingUsers,
# AverageRevenuePerPayingUser (Robux after Roblox's share) and AveragePlayTimeMinutesPerDAU; it has no
# PayerConversionRate, QualifiedPlayThroughRate or Revenue metric, so payer conversion is worked out here as paying
# users over the day's players, and qualified play-through and the genre 50th and 90th lines stay Creator Hub only.
say "### Benchmark items per day"
say ""
declare -A playtime=() d7=() payers=() arppu=()
if query AveragePlayTimeMinutesPerDAU OneDay; then
	for point in $(rows); do
		playtime[${point%%=*}]=$(awk -v v="${point#*=}" 'BEGIN { printf "%.1f", v }')
	done
else
	failed
fi
if query ForwardD7Retention OneDay; then
	for point in $(rows); do
		d7[${point%%=*}]=$(awk -v v="${point#*=}" 'BEGIN { if (v <= 1) v *= 100; printf "%.1f%%", v }')
	done
else
	failed
fi
if query PayingUsers OneDay; then
	for point in $(rows); do
		payers[${point%%=*}]=${point#*=}
	done
else
	failed
fi
if query AverageRevenuePerPayingUser OneDay; then
	for point in $(rows); do
		arppu[${point%%=*}]=${point#*=}
	done
else
	failed
fi
# Payer conversion is an estimate: paying users over new plus returning players, which is right only when those two
# add up to the day's players. Day 7 retention uses the same rule as pct(): a value of 1 or less is read as a fraction.
say "| Day | Playtime per player (min) | Day 7 retention | Paying users | Payer conversion (est.) | Robux per paying user |"
say "|---|---:|---:|---:|---:|---:|"
for day in "${days[@]}"; do
	conversion=$(awk -v p="${payers[$day]:-}" -v n="${newUsers[$day]:-0}" -v r="${returning[$day]:-0}" \
		'BEGIN { if (p != "" && n + r > 0) printf "%.2f%%", p * 100 / (n + r); else print "-" }')
	say "| $day | ${playtime[$day]:--} | ${d7[$day]:--} | ${payers[$day]:--} | $conversion | ${arppu[$day]:--} |"
done
say ""
say "_Qualified play-through and the genre 50th and 90th lines are only on Creator Hub (Overview, Acquisition)._"
say ""
say "A dash is a day Roblox sent nothing for: no players, or not filled yet."
say ""

# 3. First sessions: how long new players stayed before they left, in Roblox's buckets.
say "### How long new players' first sessions lasted"
say ""
if query TotalSessionsEndedInBucket None SessionTimeBucket; then
	# each bucket comes back as one point stamped with the window's start, so keep only its value
	say "| Session length bucket (s) | Sessions |"
	say "|---:|---:|"
	while IFS=$'\t' read -r bucket count; do
		count=${count#*=}
		say "| $bucket | ${count%.*} |"
	done < <(rows | sort -t$'\t' -k1,1n)
	say ""
else
	failed
fi

# 4. Custom events: the most logged, with how many players logged each. CustomEventName is a filter only, so each
# event is two queries of its own (times, then players).
say "### Custom events"
say ""
if values CustomEventCount CustomEventName; then
	mapfile -t events < <(printf '%s\n' "$result" | sed '/^$/d')
	eventRows=()
	eventError=
	for event in "${events[@]}"; do
		times='?'
		players='?'
		if query CustomEventCount None "" "$(only CustomEventName "$event")"; then
			times=$(total)
		else
			eventError=${eventError:-$result}
		fi
		if query CustomEventCountUser None "" "$(only CustomEventName "$event")"; then
			players=$(total)
		else
			eventError=${eventError:-$result}
		fi
		eventRows+=("$event|$times|$players")
	done
	if [ "${#events[@]}" = 0 ]; then
		say "No custom events logged in this window."
		say ""
	else
		say "| Event | Times | Players |"
		say "|---|---:|---:|"
		while IFS='|' read -r event times players; do
			say "| $event | $times | $players |"
		done < <(printf '%s\n' "${eventRows[@]}" | sort -t'|' -k2,2nr)
		say ""
		if [ -n "$eventError" ]; then
			say "A ? is a query Roblox refused. The first refusal:"
			say ""
			result=$eventError
			failed
		fi
	fi
else
	failed
fi

# 5. Audience (#2391). Players are summed over the window's days, so one player on three days counts three times
# (player-days); retention and session length are the average of the days Roblox filled. Every breakdown is one
# dimension at a time (plus IsNewUser), never two crossed, so no cell gets smaller than the report needs.
say "### Audience"
say ""
say "Players are player-days: each day's players added up over the window. Day 1 retention and session length are"
say "the average of the days Roblox filled. Roblox sends only the top values of a breakdown."
say "Those averages are not weighted by players: a day with one player counts as much as a day with a hundred, so"
say "check the per-day table before acting on a split."
say ""
pct() { awk -v v="$1" 'BEGIN { if (v == "") { print "-"; exit } if (v <= 1) v *= 100; printf "%.0f%%", v }'; }
# byNew dim: $result's rows as "value<TAB>new<TAB>returning", the biggest first (DailyActiveUsers by dim,IsNewUser)
byNew() {
	jq -r --arg d "$1" '[.values[]? | (.breakdowns // []) as $b
		| {k: (($b | map(select(.dimension == $d))[0] // $b[0] // {}) | (.displayValue // .value // "?") | tostring),
			n: (($b | map(select(.dimension == "IsNewUser"))[0] // $b[1] // {}) | (.value // "") | tostring
				| ascii_downcase | test("^(true|new)")),
			v: ([(.dataPoints // [])[] | .value // 0] | add // 0)}]
		| group_by(.k) | map({k: .[0].k, new: (map(select(.n)) | map(.v) | add // 0),
			ret: (map(select(.n | not)) | map(.v) | add // 0)})
		| sort_by(-(.new + .ret)) | .[] | [.k, (.new | floor), (.ret | floor)] | @tsv' <<<"$result"
}
# mean dim: $result's rows as "value<TAB>average of its data points", for a metric broken down by dim
mean() {
	jq -r --arg d "$1" '.values[]? | (.breakdowns // []) as $b
		| [(($b | map(select(.dimension == $d))[0] // $b[0] // {}) | (.displayValue // .value // "?") | tostring),
			([(.dataPoints // [])[] | .value | select(. != null)] | if length > 0 then add / length else "" end
				| tostring)] | @tsv' <<<"$result"
}
for dim in Platform Country AgeGroupV2 Gender; do
	say "#### By $dim"
	say ""
	declare -A dayOne=() minutes=()
	order=()
	if query ForwardD1Retention OneDay "$dim"; then
		while IFS=$'\t' read -r key value; do
			dayOne[$key]=$value
		done < <(mean "$dim")
	else
		failed
	fi
	if [ "$dim" = Platform ] || [ "$dim" = Gender ]; then
		if query AverageSessionLengthMinutes OneDay "$dim"; then
			while IFS=$'\t' read -r key value; do
				minutes[$key]=$value
			done < <(mean "$dim")
		else
			failed
		fi
	fi
	if ! query DailyActiveUsers OneDay "$dim,IsNewUser"; then
		failed
		unset dayOne minutes
		continue
	fi
	mapfile -t order < <(byNew "$dim")
	if [ "${#order[@]}" = 0 ]; then
		say "No players by $dim in this window."
		say ""
		unset dayOne minutes
		continue
	fi
	if [ "$dim" = Platform ] || [ "$dim" = Gender ]; then
		say "| $dim | New players | Returning | Day 1 retention | Avg session (min) |"
		say "|---|---:|---:|---:|---:|"
	else
		say "| $dim | New players | Returning | Day 1 retention |"
		say "|---|---:|---:|---:|"
	fi
	for line in "${order[@]}"; do
		IFS=$'\t' read -r key fresh back <<<"$line"
		row="| ${key//|/\\|} | $fresh | $back | $(pct "${dayOne[$key]:-}") |"
		if [ "$dim" = Platform ] || [ "$dim" = Gender ]; then
			value=${minutes[$key]:-}
			row="$row $( [ -n "$value" ] && awk -v v="$value" 'BEGIN { printf "%.1f", v }' || printf -- -) |"
		fi
		say "$row"
	done
	say ""
	unset dayOne minutes
done

# The onboarding funnel and first_hour by Platform: players per step on each kind of device, with each column's share
# of its own step 1, so a phone drop that PC players do not have shows as a gap between the columns. Platform is a
# filter only for FunnelUserTotalCount (a breakdown answers HTTP 400), so (#2703) the script asks which platforms
# were logged (dimension-values) and reads the funnel once per platform with a FunnelName and a Platform filter.
platformsLogged=()
if values FunnelUserTotalCount Platform && [ -n "$result" ]; then
	mapfile -t platformsLogged <<<"$result"
else
	platformsLogged=(Phone Computer Tablet Console)
fi
for funnel in "${cleanFunnel:-$onboardingFunnel}" "${playtimeFunnel:-$firstHourFunnel}" "$arcadeFunnel"; do
	say "#### $funnel by Platform"
	say ""
	declare -A cell=() firstOf=() label=()
	steps=()
	platforms=()
	errors=()
	for platform in "${platformsLogged[@]}"; do
		filter=$(jq -nc --arg funnel "$funnel" --arg platform "$platform" \
			'[{dimension: "FunnelName", operation: "In", values: [$funnel]},
				{dimension: "Platform", operation: "In", values: [$platform]}]')
		if ! query FunnelUserTotalCount None FunnelStep "$filter"; then
			errors+=("$platform: $result")
			continue
		fi
		mapfile -t lines < <(jq -r '.values[]? | ((.breakdowns // [])[0] // {}) as $s
			| [($s.value // "" | tostring), ($s.displayValue // "" | tostring),
				((.dataPoints // [])[0].value // 0 | floor | tostring)] | join("|")' <<<"$result")
		[ "${#lines[@]}" -gt 0 ] || continue
		platforms+=("$platform")
		for line in "${lines[@]}"; do
			IFS='|' read -r step name users <<<"$line"
			[ -n "$step" ] || continue
			[ -n "${label[$step]+x}" ] || steps+=("$step")
			label[$step]=$name
			cell[$step.$platform]=$users
		done
	done
	for error in "${errors[@]}"; do
		say "_${error//|/\\|}_"
	done
	if [ "${#steps[@]}" = 0 ]; then
		say "No steps of $funnel logged in this window."
		say ""
		unset cell firstOf label
		continue
	fi
	mapfile -t steps < <(printf '%s\n' "${steps[@]}" | sort -n)
	header="| Step | Name |"
	rule="|---:|---|"
	for platform in "${platforms[@]}"; do
		header="$header ${platform//|/\\|} |"
		rule="$rule---:|"
		firstOf[$platform]=${cell[${steps[0]}.$platform]:-0}
	done
	say "$header"
	say "$rule"
	for step in "${steps[@]}"; do
		row="| $step | $(stepName "$funnel" "$step" "${label[$step]}") |"
		for platform in "${platforms[@]}"; do
			users=${cell[$step.$platform]:-0}
			row="$row $users ($(awk -v a="$users" -v b="${firstOf[$platform]}" 'BEGIN { if (b > 0) printf "%d%%", a * 100 / b; else print "-" }')) |"
		done
		say "$row"
	done
	say ""
	unset cell firstOf label
done

# 6. Event fields (Research-Agent, 2026-11-09): the funnel events from #2774/#2776 read by their custom fields, so a
# report says where the leavers stopped and how long each step took, not only how many logged the event. Each line of
# fieldEvents is "event|fields|metric|label": fields is the breakdown (CustomField1, CustomField2, CustomField3 and
# Platform, comma separated), metric is CustomEventCountUser (players) or CustomEventAvgValue (the average of the
# event's value, in seconds for these). CustomEventName is a filter only, as in section 4.
#   quit_state          value seconds played; fields furthest step, where, "carry|empty bait|nobait" (Tier < 2 leavers)
#   step_time           value account seconds of play at the step; field the onboarding step name
#   step_gap            value seconds between two steps; fields the gap, the bucket (#3530, shared/StepGaps)
#   quit_have           value seconds played; fields kinds of cat, coin share of Tier 2, ready or not_ready (#3530)
#   cat_caught_area     value 1; fields area id, rarity
#   bait_rolled         value 1; fields food, rarity rolled, Lucky Potion or none (food into a bowl; #3030)
#   bait_resolved       value 1; fields food, rarity, choice (tame or letgo)
#   first_bait_wait     value seconds from food in to resolve; fields lure, rarity, choice
#   first_bait_arrived  value seconds from food in to arrival; field where the player was
#   first_bait_cutscene value 1; field how the first bait cutscene ended (#2946)
fieldEvents=(
	"quit_state|CustomField1|CustomEventCountUser|Leavers before Tier 2 by furthest step"
	"quit_state|CustomField1|CustomEventAvgValue|Leavers: average seconds played by furthest step"
	"quit_state|CustomField2|CustomEventCountUser|Leavers by where they were"
	"quit_state|CustomField3|CustomEventCountUser|Leavers by carry and bait state"
	"quit_state|Platform|CustomEventCountUser|Leavers by device"
	"quit_state|Platform,CustomField1|CustomEventCountUser|Leavers by device and furthest step"
	"step_time|CustomField1|CustomEventAvgValue|Average seconds of play when each step came"
	"step_time|CustomField1|CustomEventCountUser|Players per step (step_time)"
	"step_gap|CustomField1,CustomField2|CustomEventCountUser|Players per gap between two steps, by time bucket (#3530)"
	"step_gap|CustomField1|CustomEventAvgValue|Average seconds per gap (earlier_visit and no_start rows count as 0)"
	"quit_have|CustomField1|CustomEventCountUser|Leavers before Tier 2 by kinds of cat owned (#3530)"
	"quit_have|CustomField2|CustomEventCountUser|Leavers before Tier 2 by coins as a share of Tier 2's cost"
	"quit_have|CustomField3|CustomEventCountUser|Leavers before Tier 2: ready to rank up or not (rank_up_ready_quit)"
	"cat_caught_area|CustomField1,CustomField2|CustomEventCountUser|Players catching by area and rarity"
	"bait_rolled|CustomField1|CustomEventCountUser|Bait: players who put food in a bowl, by food"
	"bait_resolved|CustomField3|CustomEventCountUser|Bait: players who met their bait cat, by choice (tame or let go)"
	"bait_resolved|CustomField1,CustomField3|CustomEventCountUser|Bait: players who met their bait cat, by food and choice"
	"first_bait_wait|CustomField3|CustomEventAvgValue|First bait: average seconds food in to resolve, by choice"
	"first_bait_arrived|CustomField1|CustomEventAvgValue|First bait cat arrived: average seconds, by where the player was"
	"first_bait_arrived|Platform,CustomField1|CustomEventCountUser|First bait cat arrived: players by device and where they were (#3815)"
	"first_bait_wait|Platform,CustomField3|CustomEventCountUser|First bait: players by device and choice, tame or let go (#3815)"
	"first_bait_cutscene|Platform,CustomField1|CustomEventCountUser|First bait cutscene: players by device and outcome (#3815)"
	"quit_state|Platform,CustomField1,CustomField3|CustomEventCountUser|Leavers by device, furthest step and carry or bait state (#3815)"
	"catch_circles|Platform,CustomField3|CustomEventCountUser|Catch results (caught, purrfect, missed, forfeit) by device"
	"catch_finish|Platform,CustomField1|CustomEventCountUser|Catch finish kind (bolt is the cat running off) by device"
	"first_catch_tries|Platform,CustomField1|CustomEventAvgValue|Tries before the first catch, by method and device"
	"first_catch_tries|Platform|CustomEventCountUser|Players with a first catch, by device"
	"left_in_phase|CustomField1|CustomEventCount|Leaves by in-game phase (#2562; night is 70 of 390 s, about 18%)"
	"left_in_phase|CustomField1|CustomEventCountUser|Players leaving by in-game phase"
	"left_in_phase|CustomField2|CustomEventCount|Leaves by third of the phase"
	"left_in_phase|CustomField1,CustomField3|CustomEventCount|Leaves by phase and tier, first session or return"
	"left_in_phase|CustomField1|CustomEventAvgValue|Average seconds played before leaving, by phase"
	"station_open|CustomField1,CustomField2|CustomEventCount|Station opens by ring or prompt (#2910)"
	"rescue_attempt|CustomField3|CustomEventCountUser|Players by rescue result (freed, missed_catch, out_of_paws, too_slow, walked_away, cancelled)"
	"rescue_attempt|Platform,CustomField3|CustomEventCount|Rescue results by device"
	"station_open|CustomField3,CustomField2|CustomEventCount|Station opens by device, ring or prompt (#2910)"
	"station_open|CustomField1,CustomField3,CustomField2|CustomEventCount|Station opens by station, device, ring or prompt (#2910)"
	"session_feedback|CustomField1|CustomEventCountUser|Session feedback answers (up, down, skipped) (#3272)"
	"session_feedback|CustomField1,CustomField2|CustomEventCount|Session feedback answers by device (#3272)"
	"session_feedback|CustomField1,CustomField3|CustomEventCount|Session feedback answers by session length (#3272)"
	"session_feedback_ctx|CustomField1,CustomField2|CustomEventCount|Session feedback answers by furthest step (#3272)"
	"session_feedback_ctx|CustomField1,CustomField3|CustomEventCount|Session feedback answers by cats owned (#3272)"
	"session_feedback_where|CustomField1,CustomField2|CustomEventCount|Session feedback answers by screen at the time (#3272)"
	"arcade_run|CustomField3|CustomEventCountUser|Cat Arcade: players by result (win, over) (#3378)"
	"arcade_run|CustomField3|CustomEventCount|Cat Arcade: games by result (#3378)"
	"arcade_run|Platform|CustomEventCountUser|Cat Arcade: players by device (#3378)"
	"arcade_run|Platform|CustomEventAvgValue|Cat Arcade: average points a game, by device (#3378)"
	"arcade_run|CustomField1|CustomEventCount|Cat Arcade: games by circles hit (#3378)"
	"arcade_run|CustomField2|CustomEventCount|Cat Arcade: games by prizes paid (#3378)"
	"upgrade_bought|CustomField2,CustomField3|CustomEventCountUser|Players buying each upgrade level (Swift Paws 5 levels, #3332)"
	"client_memory|CustomField1,CustomField2|CustomEventAvgValue|Client memory: average MB by device and minutes into the session (#3743)"
	"client_memory|CustomField1,CustomField3|CustomEventCountUser|Client memory: players by device and growth since their first mark (#3743)"
	"client_memory_tag|CustomField1,CustomField2|CustomEventAvgValue|Client memory by Roblox memory group: average MB at 5 and 30 minutes (#3743)"
	"client_memory_tag|CustomField3,CustomField1|CustomEventAvgValue|Client memory by device and memory group: average MB (#3743)"
	"badge_awarded|CustomField1|CustomEventCountUser|Badges: players awarded each badge (#3617)"
	"badge_awarded|CustomField1,CustomField2|CustomEventCountUser|Badges: players by badge, earned live or caught up on join (#3617)"
	"arcade_quit|CustomField1|CustomEventCount|Cat Arcade: games left early, free or paid (#3378)"
	"arcade_quit|CustomField1|CustomEventAvgValue|Cat Arcade: average circles hit before leaving early (#3378)"
	"arcade_blocked|CustomField1|CustomEventCount|Cat Arcade: Start refused, by reason (closed, loading, running, busy, no_fish) (#3378)"
	"arcade_blocked|CustomField1|CustomEventCountUser|Cat Arcade: players refused at Start, by reason (#3378)"
	"arcade_board_top|CustomField1|CustomEventCountUser|Cat Arcade: players with a new best in the leaderboard's top, free or paid (#3378)"
	"arcade_board_top|CustomField1|CustomEventAvgValue|Cat Arcade: average leaderboard place of a new best (#3378)"
	"title_set|CustomField1|CustomEventCountUser|Titles tab: players picking each title, or off (#3378)"
	"tackle_shield|Platform|CustomEventCount|Tackle shield: server minutes with a blocked tackle, by the tackler's device (#3378)"
	"tackle_shield|Platform|CustomEventAvgValue|Tackle shield: average blocked tackles in such a minute (#3378)"
	"stray_call|CustomField1|CustomEventCount|Stray calls: followed by a catch start within 10 s, yes or no (#3378)"
	"stray_call|CustomField1|CustomEventCountUser|Stray calls: players by yes or no (#3378)"
	"stray_call|CustomField1|CustomEventAvgValue|Stray calls: average call number (1 to 4), by yes or no (#3378)"
	"event_join|CustomField1|CustomEventCountUser|Cafe Event: players in the event, by event id (#3423)"
	"event_join|CustomField1,CustomField3|CustomEventCountUser|Cafe Event: players by how they joined (#3423)"
	"event_join|CustomField1,Platform|CustomEventCountUser|Cafe Event: players by device (#3423)"
	"event_money|CustomField1|CustomEventCountUser|Cafe Event: players the money boost paid, by event id (#3423)"
	"event_money|CustomField1|CustomEventAvgValue|Cafe Event: average extra coins per player, by event id (#3423)"
	"event_money|CustomField1,CustomField2|CustomEventAvgValue|Cafe Event: average extra coins by tier (#3423)"
	"event_reward|CustomField1,CustomField2|CustomEventCountUser|Cafe Event: rewards given, first or again (#3423)"
	"update_gift|CustomField1|CustomEventCountUser|Update gift: players who got the gift, by gift id (#3423)"
	"event_shower|CustomField1|CustomEventCount|Cafe Event: shower cats logged, by event id (#3423)"
	"event_shower|CustomField1,CustomField3|CustomEventCount|Cafe Event: shower cats by kind and outcome, e.g. mythical_caught (#3423)"
	"session_start|CustomField1|CustomEventCountUser|Players by join source (organic, unknown, ad_<tag>)"
	"session_start|CustomField3|CustomEventCountUser|Players by tier at join (store_v1 per Tier 2+ base)"
	"robux_purchase|CustomField1|CustomEventCount|Robux purchases by sku"
	"robux_purchase|CustomField1|CustomEventAvgValue|Average Robux per purchase, by sku (x count = revenue)"
	"store_cancelled|CustomField1|CustomEventCount|Purchase prompts closed without buying, by sku"
	"step_ready|CustomField1|CustomEventCountUser|First five minutes (#3098): players ready for each step"
	"step_ready|CustomField1|CustomEventAvgValue|First five minutes: average account seconds when each step became ready"
	"step_stall|CustomField1,CustomField2|CustomEventCountUser|First five minutes: players stalled by awaited step and 30/60/120 s"
	"step_stall|CustomField1,CustomField3|CustomEventCountUser|First five minutes: stalls by awaited step and last hint shown"
	"quit_snapshot|CustomField1|CustomEventCountUser|Leavers below Tier 2 by furthest step"
	"quit_snapshot|CustomField1,CustomField2|CustomEventCountUser|Leavers below Tier 2 by furthest step, idle and open screen"
	"quit_snapshot|CustomField1,CustomField3|CustomEventCountUser|Leavers below Tier 2 by furthest step and whether they could afford the next buy"
	"quit_snapshot|Platform,CustomField1|CustomEventCountUser|Leavers below Tier 2 by device and furthest step"
	"health_check|Platform,CustomField1|CustomEventCountUser|Health check (#3101): players by device and ping"
	"health_check|Platform,CustomField2|CustomEventCountUser|Health check: players by device and memory"
	"health_check|Platform|CustomEventAvgValue|Health check: average fps by device"
	"quick_return|CustomField1,CustomField2|CustomEventCountUser|Quick returns by furthest step and minutes away"
	"quick_return|CustomField3|CustomEventCountUser|Quick returns by session number"
	"quit_cafe|CustomField1|CustomEventCountUser|Leavers by cats working"
	"quit_cafe|CustomField2|CustomEventCountUser|Leavers by table level"
	"quit_cafe|CustomField3|CustomEventCountUser|Leavers by cats owned"
	"quit_scene|CustomField1|CustomEventCountUser|Leavers below Tier 2 by scene (#3101)"
	"quit_scene|CustomField2,CustomField1|CustomEventCountUser|Leavers below Tier 2 by device and scene"
	"quit_scene|CustomField1,CustomField3|CustomEventCountUser|Leavers below Tier 2 by scene and seconds bucket"
	"first_scene|CustomField1|CustomEventAvgValue|Average seconds from join to the first intro shot, by device (minus step_time loaded = still wait)"
	"first_scene|CustomField1,CustomField3|CustomEventCountUser|Players by device and wait before the first intro shot"
)
say "### Event fields"
say ""
for line in "${fieldEvents[@]}"; do
	IFS='|' read -r event fields metric heading <<<"$line"
	say "#### $heading ($event, $metric by $fields)"
	say ""
	if ! query "$metric" None "$fields" "$(only CustomEventName "$event")"; then
		failed
		continue
	fi
	mapfile -t lines < <(rows)
	if [ "${#lines[@]}" = 0 ]; then
		say "Not logged in this window."
		say ""
		continue
	fi
	header="|"
	rule="|"
	IFS=',' read -r -a dims <<<"$fields"
	for dim in "${dims[@]}"; do
		header="$header $dim |"
		rule="$rule---|"
	done
	say "$header Value |"
	say "$rule---:|"
	while IFS=$'\t' read -r -a cols; do
		row="|"
		for ((i = 0; i < ${#cols[@]}; i++)); do
			value=${cols[$i]//|/\\|}
			if [ "$i" = $((${#cols[@]} - 1)) ]; then
				# rows prints a data point as "<day>=<value>"; with granularity None there is one, so keep the value
				value=${value##*=}
				value=$(awk -v v="$value" 'BEGIN { if (v == int(v)) printf "%d", v; else printf "%.1f", v }')
			fi
			row="$row $value |"
		done
		say "$row"
	done < <(printf '%s\n' "${lines[@]}" | sort -t$'\t' -k"$((${#dims[@]} + 1))","$((${#dims[@]} + 1))"nr)
	say ""
done

cat "$out"
echo "== raw (request, then answer, one query per line)"
cat "$raw"
[ -z "${GITHUB_STEP_SUMMARY:-}" ] || cat "$out" >>"$GITHUB_STEP_SUMMARY"
