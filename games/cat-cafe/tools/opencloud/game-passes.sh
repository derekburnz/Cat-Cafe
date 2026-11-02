#!/usr/bin/env bash
# List, make and change the experience's game passes (Open Cloud Game Passes API, beta), so the passes the shop sells
# exist with the names and prices in passes.json and their ids can go in Config, without Creator Hub. A game pass is
# a one-time Robux purchase the player keeps for good; the game asks MarketplaceService whether a player owns its id.
# Passes cannot be deleted, so `create` only makes the passes whose names are not there yet: running it twice makes
# nothing new. New passes start off sale unless FOR_SALE=true, so nobody can buy one before the shop is ready.
# An entry's "id" in passes.json only records the pass Roblox made for it (create matches passes by name).
# Run by .github/workflows/game-passes.yml; also works from Git Bash on a PC with the same variables set.
#
#   ROBLOX_PUBLISH_KEY   Open Cloud API key with game-pass:read and game-pass:write on Cat Cafe (docs/setup-guide.md step 22)
#   ROBLOX_UNIVERSE_ID   the experience: default 10773193456, Cat Cafe
#   FOR_SALE             create only: true puts the new passes on sale at once (default false)
#
# Usage:
#   game-passes.sh list [file]                every pass: id, name, price, on or off sale, and the Config line it fills
#   game-passes.sh create [file]              make each pass in the file that is missing (file: passes.json here)
#   game-passes.sh set <id or name> change... change one pass. Changes: price=N, forSale=true|false,
#                                             regional=true|false, icon=<.png or .jpg path from the repo root>
# Needs curl and jq (both on GitHub's ubuntu runners).
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../../.." && pwd)
UNIVERSE=${ROBLOX_UNIVERSE_ID:-10773193456}
ACTION=${1:-list}
API=https://apis.roblox.com/game-passes/v1/universes/$UNIVERSE/game-passes
: "${ROBLOX_PUBLISH_KEY:?set ROBLOX_PUBLISH_KEY (docs/setup-guide.md step 22)}"

# The answer's price and regional pricing. The beta reference leaves priceInformation's shape open, so this reads
# the field names the other Open Cloud monetization APIs use and the raw JSON is printed as well.
JQ_DEFS='
def price: (.priceInformation.defaultPriceInRobux? // .price? // null);
def regional: ([.priceInformation.enabledFeatures?[]? | tostring | ascii_downcase | select(test("regional"))] | length > 0);
def key: (.name // "" | ascii_downcase | gsub("^\\s+|\\s+$"; ""));
def line: "\(.gamePassId)  \(.name)  "
	+ (if price == null then "no price" else "R$\(price)" end)
	+ (if .isForSale then ", on sale" else ", off sale" end)
	+ (if regional then ", regional pricing on" else "" end);
'

reply=$(mktemp)
trap 'rm -f "$reply"' EXIT

# request url [curl args...] -> sets $status and $body, one try.
request() {
	local url=$1
	shift
	status=$(curl -sS -o "$reply" -w '%{http_code}' "$url" -H "x-api-key: $ROBLOX_PUBLISH_KEY" "$@") || status=000
	body=$(cat "$reply")
}

retryable() {
	case "$status" in
	5?? | 429 | 000) return 0 ;;
	*) return 1 ;;
	esac
}

fail() {
	echo "Open Cloud answered HTTP $status: $body" >&2
	case "$status" in
	401 | 403) echo "The key needs game-pass:read and game-pass:write on the Cat Cafe experience (docs/setup-guide.md step 22)." >&2 ;;
	esac
	exit 1
}

# call url [curl args...]: request, with three more tries over about half a minute on 5xx, 429 or no answer; exits
# unless Roblox answers 200 or 204. Only for reads and changes, which are safe to send twice.
call() {
	local wait
	for wait in 5 10 20 0; do
		request "$@"
		retryable || break
		[ "$wait" = 0 ] && break
		echo "Open Cloud answered HTTP $status; trying again in ${wait}s." >&2
		sleep "$wait"
	done
	case "$status" in
	200 | 204) ;;
	*) fail ;;
	esac
}

# Sets $passes to every pass on the experience as one JSON array, following the pages.
fetch_passes() {
	local token='' query
	passes='[]'
	while :; do
		query='pageSize=50'
		[ -z "$token" ] || query="$query&pageToken=$(jq -rn --arg t "$token" '$t | @uri')"
		call "$API/creator?$query"
		# An answer in a shape this does not know would read as no passes, and create would then make every pass
		# again, for good. Only a gamePasses list, or {} for an experience with none, counts.
		if ! jq -e 'type == "object" and ((has("gamePasses") and (.gamePasses | type) == "array") or . == {})' <<<"$body" >/dev/null 2>&1; then
			echo "Open Cloud's pass list came back in a shape this script does not know, so nothing was changed: $body" >&2
			exit 1
		fi
		passes=$(jq -c --argjson all "$passes" '$all + (.gamePasses // [])' <<<"$body")
		token=$(jq -r '.nextPageToken // ""' <<<"$body")
		[ -n "$token" ] || break
	done
}

# find_id name -> the id of the pass with that name (case and outer spaces ignored), or nothing.
find_id() {
	jq -r --arg name "$1" "$JQ_DEFS"'
		($name | ascii_downcase | gsub("^\\s+|\\s+$"; "")) as $want | first(.[] | select(key == $want) | .gamePassId) // empty' <<<"$passes"
}

# image_args path -> the multipart field for an icon from the repo, in $image.
image_args() {
	local path=$1 ctype
	case "$path" in
	/* | *..*)
		echo "the icon path is from the repo root, without '..': $path" >&2
		exit 2
		;;
	esac
	case "$(printf '%s' "${path##*.}" | tr '[:upper:]' '[:lower:]')" in
	png) ctype=image/png ;;
	jpg | jpeg) ctype=image/jpeg ;;
	*)
		echo "a pass icon is a .png or .jpg, got: $path" >&2
		exit 2
		;;
	esac
	[ -f "$REPO/$path" ] || {
		echo "no such icon in the repo: $path" >&2
		exit 2
	}
	image=(-F "imageFile=@\"$REPO/$path\";type=$ctype")
}

# The file's passes by name -> Config target, for the list.
config_map() {
	jq -c "$JQ_DEFS"'map(select(.config) | {(key): .config}) | add // {}' "$1"
}

show() {
	local file=$1 cfg
	cfg=$(config_map "$file")
	echo "== $(jq length <<<"$passes") passes on experience $UNIVERSE"
	jq -r --argjson cfg "$cfg" "$JQ_DEFS"'.[] | line + (if $cfg[key] then "  -> Config \($cfg[key])" else "" end)' <<<"$passes"
	echo "== passes as JSON"
	jq -c '.[]' <<<"$passes"
	if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
		{
			echo "| Id | Pass | Price | On sale | Config |"
			echo "|---|---|---|---|---|"
			jq -r --argjson cfg "$cfg" "$JQ_DEFS"'.[] | "| \(.gamePassId) | \(.name) | "
				+ (if price == null then "-" else "R$\(price)" end) + " | " + (if .isForSale then "yes" else "no" end)
				+ " | " + ($cfg[key] // "-") + " |"' <<<"$passes"
		} >>"$GITHUB_STEP_SUMMARY"
	fi
}

check_file() {
	local file=$1
	[ -f "$file" ] || {
		echo "no such file: $file" >&2
		exit 2
	}
	jq -e 'type == "array" and length > 0 and all(.[];
		(.name | type) == "string" and (.name | length) > 0 and (.price | type) == "number" and .price >= 1
		and .price == (.price | floor) and (.regionalPricing | type) == "boolean")' "$file" >/dev/null || {
		echo "$file must be a list of passes, each with a name, a whole price of at least 1 and regionalPricing true or false" >&2
		exit 2
	}
	if [ "$(jq '[.[].name | ascii_downcase] | length != (unique | length)' "$file")" = true ]; then
		echo "$file names a pass twice" >&2
		exit 2
	fi
}

create() {
	local file=$1 n i entry name id wait made=0 sale=${FOR_SALE:-false} icon
	case "$sale" in
	true | false) ;;
	*)
		echo "FOR_SALE must be true or false, got: $sale" >&2
		exit 2
		;;
	esac
	check_file "$file"
	fetch_passes
	n=$(jq length "$file")
	for ((i = 0; i < n; i++)); do
		entry=$(jq -c ".[$i]" "$file")
		name=$(jq -r '.name | gsub("^\\s+|\\s+$"; "")' <<<"$entry")
		id=$(find_id "$name")
		if [ -n "$id" ]; then
			echo "$name is there already as $id; left as it is."
			continue
		fi
		local args=(
			--form-string "name=$name"
			--form-string "description=$(jq -r '.description // ""' <<<"$entry")"
			--form-string "price=$(jq -r .price <<<"$entry")"
			--form-string "isForSale=$sale"
			--form-string "isRegionalPricingEnabled=$(jq -r .regionalPricing <<<"$entry")"
			--form-string "isManagedPricingEnabled=false"
		)
		icon=$(jq -r '.icon // ""' <<<"$entry")
		if [ -n "$icon" ]; then
			image_args "$icon"
			args+=("${image[@]}")
		fi
		# A make that timed out may still have gone through, and a second pass of the same name could never be
		# deleted, so before each new try the list is read again.
		for wait in 5 10 20 0; do
			request "$API" -X POST "${args[@]}"
			retryable || break
			[ "$wait" = 0 ] && break
			echo "Open Cloud answered HTTP $status making $name; looking whether it went through, then trying again in ${wait}s." >&2
			sleep "$wait"
			fetch_passes
			id=$(find_id "$name")
			[ -z "$id" ] || break
		done
		if [ -z "$id" ]; then
			case "$status" in
			200 | 201) ;;
			*) fail ;;
			esac
			id=$(jq -r '.gamePassId // empty' <<<"$body")
			[ -n "$id" ] || {
				echo "Open Cloud made $name but gave no id: $body" >&2
				exit 1
			}
		fi
		echo "Made $name as $id."
		made=$((made + 1))
		sleep 1 # 5 makes a second at most
	done

	fetch_passes
	show "$file"
	echo "== Config lines (games/cat-cafe/src/shared/Config.luau)"
	jq -r --argjson have "$passes" "$JQ_DEFS"'
		($have | map({(key): .gamePassId}) | add // {}) as $ids
		| .[] | select(.config) | "\(.config) = \($ids[key] // 0)"' "$file"
	# Roblox's beta API has been known to drop fields, so the made passes are checked against the file.
	jq -r --argjson have "$passes" "$JQ_DEFS"'
		($have | map({(key): .}) | add // {}) as $by
		| .[] | . as $want | $by[key] as $got | select($got)
		| ($got | price) as $p
		| if $p != null and $p != $want.price then "::warning::\($want.name) costs R$\($p) on Roblox, R$\($want.price) in the file"
		  elif $p == null then "::warning::\($want.name): the answer shows no price; check it in Creator Hub"
		  else empty end' "$file"
	echo "Made $made new pass(es)."
	[ -z "${GITHUB_STEP_SUMMARY:-}" ] || echo "- Made $made new pass(es) from \`${file#"$REPO"/}\`" >>"$GITHUB_STEP_SUMMARY"
}

set_pass() {
	local target=${1:-} id change value
	shift || true
	[ -n "$target" ] || {
		echo "set needs the pass id or its name" >&2
		exit 2
	}
	[ "$#" -gt 0 ] || {
		echo "set needs at least one change: price=N, forSale=true|false, regional=true|false or icon=<path>" >&2
		exit 2
	}
	local args=()
	for change in "$@"; do
		value=${change#*=}
		case "$change" in
		price=*)
			[[ $value =~ ^[1-9][0-9]*$ ]] || {
				echo "price must be a whole number of Robux of at least 1, got: $value" >&2
				exit 2
			}
			args+=(--form-string "price=$value")
			;;
		forSale=true | forSale=false) args+=(--form-string "isForSale=$value") ;;
		regional=true | regional=false) args+=(--form-string "isRegionalPricingEnabled=$value") ;;
		icon=*)
			image_args "$value"
			args+=("${image[@]}")
			;;
		*)
			echo "unknown change: $change (use price=N, forSale=true|false, regional=true|false or icon=<path>)" >&2
			exit 2
			;;
		esac
	done
	fetch_passes
	if [[ $target =~ ^[0-9]+$ ]]; then
		id=$(jq -r --argjson id "$target" 'first(.[] | select(.gamePassId == $id) | .gamePassId) // empty' <<<"$passes")
	else
		id=$(find_id "$target")
	fi
	[ -n "$id" ] || {
		echo "no pass $target on experience $UNIVERSE; run list for the ids" >&2
		exit 2
	}
	echo "Before: $(jq -r --argjson id "$id" "$JQ_DEFS"'.[] | select(.gamePassId == $id) | line' <<<"$passes")"
	call "$API/$id" -X PATCH "${args[@]}"
	fetch_passes
	echo "After:  $(jq -r --argjson id "$id" "$JQ_DEFS"'.[] | select(.gamePassId == $id) | line' <<<"$passes")"
	jq -c --argjson id "$id" '.[] | select(.gamePassId == $id)' <<<"$passes"
	[ -z "${GITHUB_STEP_SUMMARY:-}" ] || echo "- Pass $id changed: $*" >>"$GITHUB_STEP_SUMMARY"
}

case "$ACTION" in
list)
	check_file "${2:-$HERE/passes.json}"
	fetch_passes
	show "${2:-$HERE/passes.json}"
	;;
create) create "${2:-$HERE/passes.json}" ;;
set)
	shift
	set_pass "$@"
	;;
*)
	echo "usage: game-passes.sh list [file] | create [file] | set <id or name> change..." >&2
	exit 2
	;;
esac
