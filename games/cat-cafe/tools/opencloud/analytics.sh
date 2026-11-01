#!/usr/bin/env bash
# Print the first-session numbers from Roblox analytics (Open Cloud Analytics Query API, beta), so a thread reads
# where new players quit without Creator Hub. Read only. Sections:
#   1. every funnel, players per step: the onboarding funnel (src/shared/Onboarding.luau) and the recurring ones
#      (docs/growth/analytics-plan.md section 4), with the share of step 1 left and the players lost since the step
#      before; the biggest loss is the first thing to fix
#   2. players per day, new and returning; average session length; day 1 retention
#   3. how long new players' first sessions lasted (Roblox's session time buckets)
#   4. the most logged custom events (tutorial_step, intro_cutscene, travel and the rest of Telemetry.CustomEvent)
# Run by .github/workflows/analytics.yml; also works from Git Bash on a PC with the same variables set.
#
#   ROBLOX_PUBLISH_KEY   Open Cloud API key that also has universe-analytics universe.analytics:read on the Cat Cafe
#                        experience (docs/setup-guide.md step 20)
#   UNIVERSE_ID          default below
#
# Usage:  tools/opencloud/analytics.sh [days] [funnel]
#   days    whole UTC days back from today (default 14). Today is left out: Roblox fills a day about a day late.
#   funnel  only this funnel (default: every funnel)
# Every raw answer is printed after "== raw", since the API is in beta and its shapes may change.
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

# call method url [json] -> sets $status and $body, and fails on an answer other than 200 or 202. Roblox answers 5xx
# or 429 now and then, so those get three more tries over about half a minute. A key without the analytics
# permission stops the whole run.
call() {
	local method=$1 url=$2 data=${3:-} wait
	for wait in 5 10 20 0; do
		if [ "$method" = POST ]; then
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

# query metric granularity [breakdown,...] -> sets $result to the finished operation's .response, or returns 1 with
# the reason in $result. A slow query answers 202 with a path, polled every 2 s for up to 2 minutes.
query() {
	local request tries=0 path
	request=$(jq -nc --arg metric "$1" --arg granularity "$2" --arg breakdown "${3:-}" --arg start "$start" \
		--arg end "$end" '{metric: $metric, granularity: $granularity, startTime: $start, endTime: $end}
		+ (if $breakdown == "" then {} else {breakdown: ($breakdown | split(","))} end)
		+ (if $breakdown != "" and $granularity == "None" then {limit: 500} else {} end)')
	if ! call POST "$api/v1/universes/$UNIVERSE_ID/metrics" "$request"; then
		result="$1: HTTP $status: $body"
		return 1
	fi
	while [ "$(jq -r 'if .response or .error then true else (.done // false) end' <<<"$body")" != true ]; do
		path=$(jq -r '.path // empty' <<<"$body")
		if [ -z "$path" ] || [ "$tries" -ge 60 ]; then
			result="no answer for $1 (HTTP $status): $body"
			return 1
		fi
		tries=$((tries + 1))
		sleep 2
		if ! call GET "$api/$path"; then
			result="$1: HTTP $status: $body"
			return 1
		fi
	done
	printf '%s %s\n' "$request" "$body" >>"$raw"
	if jq -e '.error' <<<"$body" >/dev/null; then
		result="$1 failed: $(jq -c '.error' <<<"$body")"
		return 1
	fi
	result=$(jq -c '.response' <<<"$body")
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

# Step names: the onboarding funnel's from Onboarding.STEPS (names never change once shipped), the recurring ones'
# from Telemetry.luau. Roblox labels a step with its name when it has one, which wins.
declare -A names=(
	[catch_attempt.1]=engaged [catch_attempt.2]=caught [catch_attempt.3]=checked_in [catch_attempt.4]=working
	[bait_cycle.1]=set [bait_cycle.2]=seen [bait_cycle.3]=tamed
)
onboardingSteps=()
if [ -f "$onboarding" ]; then
	mapfile -t onboardingSteps < <(sed -n '/^Onboarding.STEPS = {/,/^}/p' "$onboarding" | grep -o '"[a-z0-9_]*"' | tr -d '"')
fi
stepName() { # funnel step label
	local funnel=$1 step=$2 label=$3
	if [ -n "$label" ] && [ "$label" != "$step" ]; then
		printf '%s' "$label"
	elif [ -n "${names[$funnel.$step]:-}" ]; then
		printf '%s' "${names[$funnel.$step]}"
	elif [[ ${funnel,,} == *onboarding* ]] && [[ $step =~ ^[0-9]+$ ]] && [ "$step" -ge 1 ] && [ "$step" -le "${#onboardingSteps[@]}" ]; then
		printf '%s' "${onboardingSteps[step - 1]}"
	fi
}

say "## Cat Cafe analytics, ${start:0:10} to the end of $(date -u -d "1 day ago" +%Y-%m-%d) (UTC)"
say ""
say "Roblox fills a day about a day late, and records only live servers (not Studio)."
say ""

# 1. Funnels. FunnelUserTotalCount by FunnelName and FunnelStep: the players who reached each step in the window.
say "### Funnels: players per step"
say ""
if query FunnelUserTotalCount None FunnelName,FunnelStep; then
	# FunnelStep values are the step numbers; the label column keeps a step name when Roblox sends one. Fields are
	# joined with | rather than tabs, since read folds runs of tabs and would lose an empty label.
	mapfile -t lines < <(jq -r '.values[]? | (.breakdowns // []) as $b
		| ($b | map(select(.dimension == "FunnelName"))[0] // $b[0] // {}) as $f
		| ($b | map(select(.dimension == "FunnelStep"))[0] // $b[1] // {}) as $s
		| [($f.value // "" | tostring), ($s.value // "" | tostring), ($s.displayValue // "" | tostring),
			((.dataPoints // [])[0].value // 0 | tostring)] | join("|")' <<<"$result" | sort -t'|' -k1,1 -k2,2n)
	if [ "${#lines[@]}" = 0 ]; then
		say "No funnel steps logged in this window."
		say ""
	elif [ -n "$FUNNEL" ] && ! printf '%s\n' "${lines[@]}" | cut -d'|' -f1 | grep -qxF "$FUNNEL"; then
		say "No steps of $FUNNEL in this window. Funnels logged: $(printf '%s\n' "${lines[@]}" | cut -d'|' -f1 | sort -u | paste -sd, -)."
		say ""
	fi
	current=
	first=0
	previous=0
	for line in "${lines[@]}"; do
		IFS='|' read -r funnel step label users <<<"$line"
		[ -z "$FUNNEL" ] || [ "$funnel" = "$FUNNEL" ] || continue
		users=${users%.*}
		if [ "$funnel" != "$current" ]; then
			[ -z "$current" ] || say ""
			current=$funnel
			first=$users
			previous=0 # step 1 has no step before it
			say "#### $funnel"
			say ""
			say "| Step | Name | Players | Of step 1 | Lost since the step before |"
			say "|---:|---|---:|---:|---:|"
		fi
		share=$(awk -v a="$users" -v b="$first" 'BEGIN { if (b > 0) printf "%d%%", a * 100 / b; else print "-" }')
		lost=$(awk -v a="$users" -v b="$previous" 'BEGIN { if (b > 0 && b >= a) printf "%d (%d%%)", b - a, (b - a) * 100 / b; else print "-" }')
		say "| $step | $(stepName "$funnel" "$step" "$label") | $users | $share | $lost |"
		previous=$users
	done
	say ""
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
	say "| Session length | Sessions |"
	say "|---|---:|"
	while IFS=$'\t' read -r bucket count; do
		say "| $bucket | ${count%.*} |"
	done < <(rows)
	say ""
else
	failed
fi

# 4. Custom events: the most logged, with how many players logged each.
say "### Custom events"
say ""
declare -A eventUsers=()
if query CustomEventCountUser None CustomEventName; then
	while IFS=$'\t' read -r event count; do
		eventUsers[$event]=${count%.*}
	done < <(rows)
fi
if query CustomEventCount None CustomEventName; then
	say "| Event | Times | Players |"
	say "|---|---:|---:|"
	while IFS=$'\t' read -r event count; do
		say "| $event | ${count%.*} | ${eventUsers[$event]:--} |"
	done < <(rows | sort -t$'\t' -k2,2nr)
	say ""
else
	failed
fi

cat "$out"
echo "== raw (request, then answer, one query per line)"
cat "$raw"
[ -z "${GITHUB_STEP_SUMMARY:-}" ] || cat "$out" >>"$GITHUB_STEP_SUMMARY"
