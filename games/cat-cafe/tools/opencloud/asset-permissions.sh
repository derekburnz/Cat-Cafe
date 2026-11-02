#!/usr/bin/env bash
# Share the sounds and pictures the game uses with the experience itself, so they keep working after the game moves
# from Derek's account to the group (docs: Tools-Agent going-public-plan section 3 step 9). The ids were uploaded
# under Derek's user (creator id 40908216) and stay his after the transfer. Audio his user owns plays only in
# experiences it is shared with, and a game owned by a group no longer counts as his, so each id gets the "Use"
# permission for universe 10773193456. The universe id survives the transfer, so the grant can be made before it.
# Run by .github/workflows/asset-permissions.yml; also works from Git Bash on a PC with the same variables set.
#
#   ROBLOX_PUBLISH_KEY   Open Cloud API key with asset-permissions:write (docs/setup-guide.md step 25)
#   ROBLOX_UNIVERSE_ID   the experience: default 10773193456, Cat Cafe
#
# Usage:
#   asset-permissions.sh list     every rbxassetid the shipped game uses (src and the Rojo model files), with its file
#   asset-permissions.sh grant    give the experience Use permission on each of them
# Roblox's Asset Permissions API (beta) cannot take a grant back, and that is fine here: the only subject is our own
# experience. Ids that are not Derek's (a public Roblox asset) are reported and left alone.
# Needs curl and jq (both on GitHub's ubuntu runners).
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../../.." && pwd)
UNIVERSE_ID=${ROBLOX_UNIVERSE_ID:-10773193456}
API=https://apis.roblox.com/asset-permissions-api/v1/assets/permissions
BATCH=25 # ids per request; the API allows 100 requests a minute per key owner
# What ships: the Luau code and the Rojo model files. Tests and docs are left out.
SOURCES=(games/cat-cafe/src assets/cat-cafe/rbx)

usage() {
	echo "usage: asset-permissions.sh list | grant" >&2
	exit 2
}

# One line per id: "<id> <file>", the first file that uses it, sorted by file.
ids_with_files() {
	(cd "$REPO" && grep -rnoE 'rbxassetid://[0-9]+' "${SOURCES[@]}") |
		sed -E 's#^([^:]+):[0-9]+:rbxassetid://([0-9]+)$#\2 \1#' |
		sort -k1,1 -u | sort -k2,2 -k1,1n
}

list() {
	local lines
	lines=$(ids_with_files)
	[ -n "$lines" ] || {
		echo "No rbxassetid found under ${SOURCES[*]}." >&2
		exit 1
	}
	echo "$lines" | awk '{ print "  " $1 "  " $2 }'
	echo
	echo "$lines" | awk '{ n[$2]++ } END { for (f in n) print n[f] "  " f }' | sort -k2
	echo "$(echo "$lines" | wc -l | tr -d ' ') ids in all."
}

reply=$(mktemp)
trap 'rm -f "$reply"' EXIT
# call body -> sets $status and $body. Roblox answers 5xx or 429 now and then, so those get three more tries.
call() {
	local data=$1 wait
	for wait in 5 10 20 0; do
		status=$(curl -sS -o "$reply" -w '%{http_code}' -X PATCH "$API" -H "x-api-key: $ROBLOX_PUBLISH_KEY" \
			-H "Content-Type: application/json" --data "$data") || status=000
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

grant() {
	: "${ROBLOX_PUBLISH_KEY:?set ROBLOX_PUBLISH_KEY (docs/setup-guide.md step 25)}"
	local lines ids granted=0 notours=0 failed=0 i batch data id code file
	lines=$(ids_with_files)
	mapfile -t ids < <(echo "$lines" | awk '{ print $1 }')
	echo "Giving universe $UNIVERSE_ID Use permission on ${#ids[@]} ids, $BATCH per request."
	for ((i = 0; i < ${#ids[@]}; i += BATCH)); do
		batch=("${ids[@]:i:BATCH}")
		data=$(printf '%s\n' "${batch[@]}" | jq -Rn --arg u "$UNIVERSE_ID" \
			'{subjectType: "Universe", subjectId: $u, action: "Use", requests: [inputs | {assetId: tonumber, grantToDependencies: false}]}')
		call "$data"
		case "$status" in
		200) ;;
		401 | 403)
			echo "Open Cloud answered HTTP $status: $body" >&2
			echo "The key needs asset-permissions:write (docs/setup-guide.md step 25). Nothing more was sent." >&2
			exit 1
			;;
		*)
			echo "Open Cloud answered HTTP $status for ids ${batch[0]} to ${batch[-1]}: $body" >&2
			failed=$((failed + ${#batch[@]}))
			continue
			;;
		esac
		granted=$((granted + $(echo "$body" | jq '.successAssetIds // [] | length')))
		# Per-id errors: the id, Roblox's code and the file that uses it.
		while read -r id code; do
			[ -n "$id" ] || continue
			file=$(echo "$lines" | awk -v id="$id" '$1 == id { print $2; exit }')
			case "$code" in
			PublicAssetCannotBeGrantedTo | CannotManageAsset)
				# Not Derek's to share: a public asset works in every experience already.
				echo "  $id ($file): $code, not ours to share; it keeps working if it is public."
				notours=$((notours + 1))
				;;
			*)
				echo "::warning::$id ($file): $code"
				failed=$((failed + 1))
				;;
			esac
		done < <(echo "$body" | jq -r '.errors // [] | .[] | "\(.assetId) \(.code)"')
	done
	echo "Granted $granted, not ours $notours, failed $failed, of ${#ids[@]}."
	[ "$failed" = 0 ] || exit 1
}

case "${1:-}" in
list) list ;;
grant) grant ;;
*) usage ;;
esac
