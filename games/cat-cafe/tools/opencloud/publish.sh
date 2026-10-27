#!/usr/bin/env bash
# Upload a Cat Cafe place file to Roblox through Open Cloud place publishing, so a publish needs no Studio window.
# Run by .github/workflows/publish.yml; also works from Git Bash on a PC with the same variables set.
#
#   ROBLOX_PUBLISH_KEY   Open Cloud API key with universe-places Write on the Cat Cafe experience (never commit it)
#   UNIVERSE_ID          the experience (not secret; default below)
#   PLACE_ID             its start place (not secret; default below)
#
# Usage, from games/cat-cafe:  tools/opencloud/publish.sh Saved|Published [CatCafe.rbxl]
#   Saved      adds a version to the place history; players keep the current live version
#   Published  makes it the live version; new servers start on it, running servers keep theirs
# Builds the place file with `rojo build default.project.json` first when it does not exist.
set -euo pipefail
cd "$(dirname "$0")/../.."

VERSION_TYPE=${1:-Saved}
PLACE_FILE=${2:-CatCafe.rbxl}
UNIVERSE_ID=${UNIVERSE_ID:-10773193456}
PLACE_ID=${PLACE_ID:-119569792798199}
: "${ROBLOX_PUBLISH_KEY:?set ROBLOX_PUBLISH_KEY (docs/setup-guide.md step 15)}"

case "$VERSION_TYPE" in
Saved | Published) ;;
*)
	echo "version type must be Saved or Published, got: $VERSION_TYPE" >&2
	exit 2
	;;
esac

if [ ! -f "$PLACE_FILE" ]; then
	rojo build default.project.json -o "$PLACE_FILE"
fi

response=$(curl -sS -w '\n%{http_code}' -X POST \
	"https://apis.roblox.com/universes/v1/$UNIVERSE_ID/places/$PLACE_ID/versions?versionType=$VERSION_TYPE" \
	-H "x-api-key: $ROBLOX_PUBLISH_KEY" \
	-H "Content-Type: application/octet-stream" \
	--data-binary @"$PLACE_FILE")
status=${response##*$'\n'}
body=${response%$'\n'*}

if [ "$status" != 200 ]; then
	echo "Open Cloud answered HTTP $status: $body" >&2
	case "$status" in
	401 | 403) echo "The key needs universe-places Write on universe $UNIVERSE_ID, and its IP list must allow 0.0.0.0/0 for GitHub runners." >&2 ;;
	429) echo "Rate limited (10 uploads a minute); run it again in a minute." >&2 ;;
	esac
	exit 1
fi

version=$(printf '%s' "$body" | grep -oE '"versionNumber": *[0-9]+' | grep -oE '[0-9]+$')
echo "$VERSION_TYPE version $version of place $PLACE_ID ($(du -h "$PLACE_FILE" | cut -f1))"
if [ -n "${GITHUB_OUTPUT:-}" ]; then
	echo "version=$version" >>"$GITHUB_OUTPUT"
fi
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
	echo "- $VERSION_TYPE place version **$version** (https://www.roblox.com/games/$PLACE_ID)" >>"$GITHUB_STEP_SUMMARY"
fi
