#!/usr/bin/env bash
# Move every running Cat Cafe server onto the newest published version (Open Cloud's Restart Universe Servers, the
# same as Creator Hub's "Restart servers for updates"; it does nothing when every server already runs the newest).
# A publish alone only reaches new servers. Needed when the publish changes the save version: a player saved by a
# new server who lands on an old one is kicked by the newer-save guard.
# Run by .github/workflows/publish.yml with restart_servers on and by restart-servers.yml on its own; also works
# from Git Bash with the same variables.
#
#   ROBLOX_PUBLISH_KEY   Open Cloud API key that also has universe Write on the Cat Cafe experience
#                        (docs/setup-guide.md step 19)
#   UNIVERSE_ID          the experience (not secret; default below)
set -euo pipefail

UNIVERSE_ID=${UNIVERSE_ID:-10773193456}
: "${ROBLOX_PUBLISH_KEY:?set ROBLOX_PUBLISH_KEY (docs/setup-guide.md step 19)}"

# Roblox answers 5xx or 429 now and then, so those get three more tries over about half a minute.
for wait in 5 10 20 0; do
	response=$(curl -sS -w '\n%{http_code}' -X POST \
		"https://apis.roblox.com/cloud/v2/universes/$UNIVERSE_ID:restartServers" \
		-H "x-api-key: $ROBLOX_PUBLISH_KEY" \
		-H "Content-Type: application/json" \
		--data '{}') || response=$'\n000'
	status=${response##*$'\n'}
	body=${response%$'\n'*}
	case "$status" in
	5?? | 429 | 000) ;;
	*) break ;;
	esac
	[ "$wait" = 0 ] && break
	echo "Open Cloud answered HTTP $status; trying again in ${wait}s." >&2
	sleep "$wait"
done

if [ "$status" != 200 ]; then
	echo "Open Cloud answered HTTP $status: $body" >&2
	echo "The new version is live; only the restart of the running servers failed." >&2
	case "$status" in
	401 | 403) echo "The key needs universe Write on universe $UNIVERSE_ID (docs/setup-guide.md step 19), or press Restart servers for updates in Creator Hub." >&2 ;;
	esac
	exit 1
fi

echo "Asked Roblox to move the running servers of universe $UNIVERSE_ID onto the newest version."
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
	echo "- Running servers restarted onto the newest version" >>"$GITHUB_STEP_SUMMARY"
fi
