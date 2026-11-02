#!/usr/bin/env bash
# Run a Luau file inside a real Roblox server for one place version (Open Cloud Luau Execution), print what it
# printed, and exit non-zero when the task fails. In a task the place's own scripts do not run and physics is off;
# the script can require any ModuleScript in the place. Changes it makes to the data model are thrown away, but
# DataStore calls are real, so the scripts here never start services.
#
#   ROBLOX_PUBLISH_KEY   Open Cloud API key with luau-execution-sessions Write on the Cat Cafe experience
#   UNIVERSE_ID, PLACE_ID  defaults below
#
# Usage, from games/cat-cafe:  tools/opencloud/run-luau.sh tools/opencloud/Smoke.luau <place version>
# Needs curl and jq (both on GitHub's ubuntu runners).
set -euo pipefail
cd "$(dirname "$0")/../.."

SCRIPT=${1:?script file}
VERSION=${2:?place version, as printed by publish.sh}
UNIVERSE_ID=${UNIVERSE_ID:-10773193456}
PLACE_ID=${PLACE_ID:-119569792798199}
: "${ROBLOX_PUBLISH_KEY:?set ROBLOX_PUBLISH_KEY (docs/setup-guide.md step 15)}"
API=https://apis.roblox.com/cloud/v2

reply=$(mktemp)
trap 'rm -f "$reply"' EXIT
call() { # method url [json body] -> sets $status and $body
	if [ $# -ge 3 ]; then
		status=$(curl -sS -o "$reply" -w '%{http_code}' -X "$1" "$2" -H "x-api-key: $ROBLOX_PUBLISH_KEY" \
			-H "Content-Type: application/json" --data "$3")
	else
		status=$(curl -sS -o "$reply" -w '%{http_code}' -X "$1" "$2" -H "x-api-key: $ROBLOX_PUBLISH_KEY")
	fi
	body=$(cat "$reply")
}

request=$(jq -n --rawfile script "$SCRIPT" '{script: $script, timeout: "180s"}')
# Roblox answers 5xx or a busy 409 now and then (a 502 here stopped a publish on 2026-10-27), so those and 429 get
# three more tries over about two and a half minutes. A task started by one that went through anyway just runs on
# its own; this script follows the last one.
for wait in 20 40 80 0; do
	call POST "$API/universes/$UNIVERSE_ID/places/$PLACE_ID/versions/$VERSION/luau-execution-session-tasks" "$request"
	case "$status" in
	5?? | 429 | 409) ;;
	*) break ;;
	esac
	[ "$wait" = 0 ] && break
	echo "Creating the task answered HTTP $status; trying again in ${wait}s." >&2
	sleep "$wait"
done
created=$body
if [ "$status" != 200 ]; then
	echo "Creating the task answered HTTP $status: $created" >&2
	if [ "$status" = 401 ] || [ "$status" = 403 ]; then
		echo "The key needs luau-execution-sessions Write on universe $UNIVERSE_ID." >&2
	fi
	exit 1
fi
task_path=$(jq -r .path <<<"$created")
echo "Task $task_path"

deadline=$((SECONDS + 240))
while :; do
	sleep 3
	call GET "$API/$task_path"
	task=$body
	state=$(jq -r '.state // "UNKNOWN"' <<<"$task" 2>/dev/null || echo "HTTP $status")
	case "$state" in
	COMPLETE | FAILED | CANCELLED) break ;;
	esac
	if [ "$SECONDS" -gt "$deadline" ]; then
		echo "Gave up waiting; last state $state" >&2
		exit 1
	fi
done

echo "== output of $SCRIPT"
call GET "$API/$task_path/logs?maxPageSize=10000"
jq -r '.luauExecutionSessionTaskLogs[]?.messages[]?' <<<"$body" 2>/dev/null || printf '%s\n' "$body"

if [ "$state" = COMPLETE ]; then
	echo "== $state: $(jq -c '.output' <<<"$task")"
	exit 0
fi
echo "== $state: $(jq -c '.error' <<<"$task")" >&2
exit 1
