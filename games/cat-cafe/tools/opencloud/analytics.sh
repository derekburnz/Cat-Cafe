#!/usr/bin/env bash
# Print the first-session numbers from Roblox analytics (Open Cloud Analytics Query API, beta), so a thread reads
# where new players quit without Creator Hub. Read only. Sections:
#   1. every funnel, players per step: the onboarding funnels (src/shared/Onboarding.luau: onboarding_v2 since F87,
#      and the alpha's twelve step one before it) and the recurring ones
#      (docs/growth/analytics-plan.md section 4), with the share of step 1 left and the players lost since the step
#      before; the biggest loss is the first thing to fix. Roblox lets FunnelName be a filter only, so the script
#      asks which funnels were logged (dimension-values) and then reads each funnel on its own.
#   2. players per day, new and returning; average session length; day 1 retention
#   3. how long new players' first sessions lasted (Roblox's session time buckets)
#   4. the most logged custom events (tutorial_step, intro_cutscene, travel and the rest of Telemetry.custom), each
#      read on its own the same way, since CustomEventName is a filter only too
# The API takes 30 queries a minute, and a window with 40 custom events needs about 90, so a run paces itself and can
# take three or four minutes.
# Run by .github/workflows/analytics.yml; also works from Git Bash on a PC with the same variables set.
#
#   ROBLOX_PUBLISH_KEY   Open Cloud API key that also has universe-analytics universe.analytics:read on the Cat Cafe
#                        experience (docs/setup-guide.md step 20)
#   UNIVERSE_ID          default below
#
# Usage:  tools/opencloud/analytics.sh [days] [funnel]
#   days    whole UTC days back from today (default 14). Today is left out: Roblox fills a day about a day late.
#   funnel  only this funnel (default: every funnel)
# Every raw answer is printed after "== raw", since the API is in beta and its shapes may change. Fields are as in the
# Open Cloud reference (create.roblox.com/docs/cloud/reference/features/analytics): QueryRequest and
# DimensionValuesRequest, filters as {dimension, operation: "In", values}.
# Needs curl and jq (both on GitHub's ubuntu runners).
set -euo pipefail

DAYS=${1:-}
DAYS=${DAYS:-14}
FUNNEL=${2:-}
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
# from Telemetry.luau. Roblox labels a step with its name when it has one, which wins. Since F87 (#691) the funnel
# named Onboarding.FUNNEL (onboarding_v2) numbers its 24 steps by Onboarding.STEPS; the alpha's funnel before it went
# through Roblox's own onboarding call and numbers its twelve by Onboarding.V1_STEPS.
declare -A names=(
	[catch_attempt.1]=swing_hit [catch_attempt.2]=engaged [catch_attempt.3]=caught [catch_attempt.4]=checked_in
	[catch_attempt.5]=working [bait_cycle.1]=set [bait_cycle.2]=seen [bait_cycle.3]=tamed
)
onboardingFunnel=onboarding_v2
onboardingSteps=()
onboardingV1Steps=()
if [ -f "$onboarding" ]; then
	luaNames() { sed -n "/^Onboarding\.$1 = {/,/^}/p" "$onboarding" | grep -o '"[a-z0-9_]*"' | tr -d '"'; }
	mapfile -t onboardingSteps < <(luaNames STEPS)
	mapfile -t onboardingV1Steps < <(luaNames V1_STEPS)
	funnelName=$(sed -n 's/^Onboarding\.FUNNEL = "\([A-Za-z0-9_]*\)".*/\1/p' "$onboarding")
	onboardingFunnel=${funnelName:-$onboardingFunnel}
fi
stepName() { # funnel step label
	local funnel=$1 step=$2 label=$3
	local -a list=()
	if [ -n "$label" ] && [ "$label" != "$step" ]; then
		printf '%s' "$label"
	elif [ -n "${names[$funnel.$step]:-}" ]; then
		printf '%s' "${names[$funnel.$step]}"
	elif [[ $step =~ ^[0-9]+$ ]] && [ "$step" -ge 1 ]; then
		if [[ ${funnel,,} == *"${onboardingFunnel,,}"* ]]; then
			list=("${onboardingSteps[@]}")
		elif [[ ${funnel,,} == *onboarding* ]]; then
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
# one): the players who reached each step in the window.
funnelTable() { # funnel: the table for one funnel, or its error
	local funnel=$1 line step label users first=0 previous=0 share lost
	local -a lines=()
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
	say "| Step | Name | Players | Of step 1 | Lost since the step before |"
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
}

say "### Funnels: players per step"
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

cat "$out"
echo "== raw (request, then answer, one query per line)"
cat "$raw"
[ -z "${GITHUB_STEP_SUMMARY:-}" ] || cat "$out" >>"$GITHUB_STEP_SUMMARY"
