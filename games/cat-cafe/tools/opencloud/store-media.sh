#!/usr/bin/env bash
# Change the experience's store page pictures from the repo, without Creator Hub: the icon, the thumbnails (the
# gallery of 16:9 pictures and videos on the game's page) and the homepage thumbnails (the pictures Roblox may show
# on the Home page and runs as an A/B test). Every call here is an experimental Open Cloud endpoint, so each change
# prints Roblox's raw answer and then reads the pictures back, because a key without the right scope can get a
# success answer that changes nothing.
# Run by .github/workflows/store-media.yml; also works from Git Bash on a PC with the same variables set.
#
#   ROBLOX_PUBLISH_KEY   Open Cloud API key on Cat Cafe with legacy-universe:manage (icon and thumbnails) and
#                        universe.thumbnail:read + universe.thumbnail:write (homepage thumbnails)
#   ROBLOX_UNIVERSE_ID   the experience: default 10773193456, Cat Cafe
#   LANGUAGE_CODE        the language the icon and thumbnails are for: default en, the game's source language
#
# Usage (image paths are from the repo root; .png or .jpg):
#   store-media.sh list                       icon, thumbnails, homepage thumbnails and the active homepage test
#   store-media.sh icon <path>                set the icon (512 x 512)
#   store-media.sh thumbnails <path>...       add thumbnails (1920 x 1080), in the order given
#   store-media.sh order <id>...              put the thumbnails in this order (ids from list)
#   store-media.sh delete <id>                take one thumbnail off the page
#   store-media.sh alt <id> <text>...         set a thumbnail's alt text
#   store-media.sh home <path>...             upload homepage thumbnails (they show once a homepage test uses them)
#   store-media.sh home-delete <id>...        delete homepage thumbnails (ids from list)
# Needs curl and jq (both on GitHub's ubuntu runners).
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../../.." && pwd)
UNIVERSE=${ROBLOX_UNIVERSE_ID:-10773193456}
LANG_CODE=${LANGUAGE_CODE:-en}
ACTION=${1:-list}
[ $# -gt 0 ] && shift
APIS=https://apis.roblox.com
GI=$APIS/legacy-game-internationalization/v1
HOME_API=$APIS/thumbnail-personalization-api/v1/universes/$UNIVERSE
: "${ROBLOX_PUBLISH_KEY:?set ROBLOX_PUBLISH_KEY (docs/setup-guide.md step 23)}"

case "$LANG_CODE" in
[a-z][a-z] | [a-z][a-z]-[a-z][a-z] | [a-z][a-z]_[a-z][a-z]) ;;
*)
	echo "LANGUAGE_CODE is a code such as en or pt-br, got: $LANG_CODE" >&2
	exit 2
	;;
esac

reply=$(mktemp)
trap 'rm -f "$reply"' EXIT

# request url [curl args...] -> sets $status and $body, one try. The key goes only to Roblox's own hosts.
request() {
	local url=$1 auth=()
	shift
	case "$url" in
	"$APIS"/*) auth=(-H "x-api-key: $ROBLOX_PUBLISH_KEY") ;;
	esac
	status=$(curl -sS -o "$reply" -w '%{http_code}' "$url" "${auth[@]}" "$@") || status=000
	body=$(cat "$reply")
}

hint() {
	case "$status" in
	401 | 403)
		case "$1" in
		*thumbnail-personalization*) echo "The key needs universe.thumbnail:read and :write on Cat Cafe (docs/setup-guide.md step 23)." >&2 ;;
		*) echo "The key needs legacy-universe:manage on Cat Cafe (docs/setup-guide.md step 23)." >&2 ;;
		esac
		;;
	esac
}

# call url [curl args...]: a read or a change that is safe to send twice, with three more tries over about half a
# minute on 5xx, 429 or no answer. Returns 1 unless Roblox answers 2xx.
call() {
	local wait
	for wait in 5 10 20 0; do
		request "$@"
		case "$status" in
		5?? | 429 | 000) ;;
		*) break ;;
		esac
		[ "$wait" = 0 ] && break
		echo "Roblox answered HTTP $status; trying again in ${wait}s." >&2
		sleep "$wait"
	done
	case "$status" in
	2??) return 0 ;;
	esac
	echo "Roblox answered HTTP $status: $body" >&2
	hint "$1"
	return 1
}

# send url [curl args...]: an upload, which could land twice if sent again after a lost answer, so it is retried
# only on 429 (Roblox refused it before doing anything). Exits unless Roblox answers 2xx.
send() {
	local wait
	for wait in 10 30 0; do
		request "$@"
		[ "$status" = 429 ] || break
		[ "$wait" = 0 ] && break
		echo "Roblox answered HTTP 429; trying again in ${wait}s." >&2
		sleep "$wait"
	done
	case "$status" in
	2??) return 0 ;;
	esac
	echo "Roblox answered HTTP $status: $body" >&2
	hint "$1"
	exit 1
}

# image path field -> the multipart form argument for an image from the repo, in $form.
image() {
	local path=$1 field=$2 ctype size
	case "$path" in
	/* | *..*)
		echo "image paths are from the repo root, without '..': $path" >&2
		exit 2
		;;
	esac
	case "$(printf '%s' "${path##*.}" | tr '[:upper:]' '[:lower:]')" in
	png) ctype=image/png ;;
	jpg | jpeg) ctype=image/jpeg ;;
	*)
		echo "store pictures are .png or .jpg, got: $path" >&2
		exit 2
		;;
	esac
	[ -f "$REPO/$path" ] || {
		echo "no such image in the repo: $path" >&2
		exit 2
	}
	size=$(wc -c <"$REPO/$path")
	if [ "$size" -gt 10000000 ]; then
		echo "$path is $size bytes; keep store pictures under 10 MB (homepage thumbnails under 3 MB)" >&2
		exit 2
	fi
	form=(-F "$field=@\"$REPO/$path\";type=$ctype")
}

need_ids() {
	[ $# -gt 0 ] || {
		echo "$ACTION needs at least one id (run list for the ids)" >&2
		exit 2
	}
	local id
	for id in "$@"; do
		case "$id" in
		'' | *[!0-9]*)
			echo "ids are numbers, got: $id" >&2
			exit 2
			;;
		esac
	done
}

summary() {
	[ -z "${GITHUB_STEP_SUMMARY:-}" ] || printf '%s\n' "$@" >>"$GITHUB_STEP_SUMMARY"
}

show_icon() {
	echo "== icon ($LANG_CODE and other languages)"
	if call "$GI/game-icon/games/$UNIVERSE?width=512&height=512"; then
		jq -r '(.data // [])[] | "\(.languageCode)  image \(.imageId)  \(.state)  \(.imageUrl)"' <<<"$body"
		jq -c . <<<"$body"
	fi
	# The public icon, as players see it (no key).
	if call "https://thumbnails.roblox.com/v1/games/icons?universeIds=$UNIVERSE&size=512x512&format=Png"; then
		jq -r '(.data // [])[] | "shown to players: \(.state)  \(.imageUrl)"' <<<"$body"
	fi
}

show_thumbnails() {
	echo "== thumbnails (store page gallery, in order)"
	if call "https://games.roblox.com/v2/games/$UNIVERSE/media"; then
		jq -r '(.data // []) | to_entries[] | .value as $m
			| "\(.key + 1). \($m.assetType // "Image")  id \($m.imageId // $m.videoId // "-")  approved \($m.approved)"
			+ (if ($m.altText // "") != "" then "  alt: \($m.altText)" else "" end)' <<<"$body"
		jq -c . <<<"$body"
		summary "| # | Type | Id | Approved |" "|---|---|---|---|"
		summary "$(jq -r '(.data // []) | to_entries[] | "| \(.key + 1) | \(.value.assetType // "Image") | \(.value.imageId // .value.videoId // "-") | \(.value.approved) |"' <<<"$body")"
	fi
	# The media list above stays empty while the game is private; this one shows the pictures players get either way.
	if call "https://thumbnails.roblox.com/v1/games/multiget/thumbnails?universeIds=$UNIVERSE&countPerUniverse=25&size=768x432&format=Png"; then
		echo "shown to players: $(jq '[(.data // [])[].thumbnails[]?] | length' <<<"$body") thumbnail(s)"
		jq -r '(.data // [])[].thumbnails[]? | "  \(.state)  \(.imageUrl)"' <<<"$body"
	fi
}

show_home() {
	echo "== homepage thumbnails"
	if call "$HOME_API/thumbnails?limit=50"; then
		jq -r '(.homepageThumbnails // [])[] | "\(.homepageThumbnailId)  asset \(.assetId)  \(.moderationStatus)  \(.homepageThumbnailStatus)  test \(.personalizedConfigStatus)"' <<<"$body"
		jq -c . <<<"$body"
	fi
	local s
	for s in Active Inactive; do
		echo "== homepage tests: $s"
		if call "$HOME_API/personalization?status=$s&limit=10"; then
			jq -c . <<<"$body"
		fi
	done
}

case "$ACTION" in
list)
	show_icon
	show_thumbnails
	show_home
	;;
icon)
	[ $# = 1 ] || {
		echo "icon takes one image path" >&2
		exit 2
	}
	image "$1" Files
	send "$GI/game-icon/games/$UNIVERSE/language-codes/$LANG_CODE" -X POST "${form[@]}"
	echo "Roblox answered HTTP $status: $body"
	show_icon
	;;
thumbnails)
	[ $# -gt 0 ] || {
		echo "thumbnails takes one or more image paths" >&2
		exit 2
	}
	for path in "$@"; do image "$path" Files; done
	summary "| Picture | Thumbnail id |" "|---|---|"
	for path in "$@"; do
		image "$path" Files
		send "$GI/game-thumbnails/games/$UNIVERSE/language-codes/$LANG_CODE/image" -X POST "${form[@]}"
		id=$(jq -r '.mediaAssetId // empty' <<<"$body" 2>/dev/null || true)
		echo "Added $path as thumbnail ${id:-?} (HTTP $status: $body)"
		summary "| $path | ${id:-?} |"
	done
	show_thumbnails
	;;
order)
	need_ids "$@"
	call "$GI/game-thumbnails/games/$UNIVERSE/language-codes/$LANG_CODE/images/order" -X POST \
		-H 'Content-Type: application/json' -d "$(printf '%s\n' "$@" | jq -sc '{mediaAssetIds: map(tonumber)}')" || exit 1
	echo "Roblox answered HTTP $status: $body"
	show_thumbnails
	;;
delete)
	[ $# = 1 ] || {
		echo "delete takes one thumbnail id" >&2
		exit 2
	}
	need_ids "$1"
	call "$GI/game-thumbnails/games/$UNIVERSE/language-codes/$LANG_CODE/images/$1" -X DELETE || exit 1
	echo "Roblox answered HTTP $status: $body"
	show_thumbnails
	;;
alt)
	[ $# -ge 2 ] || {
		echo "alt takes a thumbnail id and the text" >&2
		exit 2
	}
	need_ids "$1"
	id=$1
	shift
	call "$GI/game-thumbnails/games/$UNIVERSE/language-codes/$LANG_CODE/alt-text" -X POST \
		-H 'Content-Type: application/json' -d "$(jq -nc --argjson id "$id" --arg t "$*" '{thumbnailId: $id, altText: $t}')" || exit 1
	echo "Roblox answered HTTP $status: $body"
	show_thumbnails
	;;
home)
	[ $# -gt 0 ] || {
		echo "home takes one or more image paths" >&2
		exit 2
	}
	files=()
	for path in "$@"; do
		image "$path" files
		files+=("${form[@]}")
	done
	send "$HOME_API/thumbnails/uploads" -X POST "${files[@]}"
	echo "Roblox answered HTTP $status: $body"
	ops=$(jq -r '(.fileToOperationIdDict // {}) | [.[]] | map("operationIds=" + (. | @uri)) | join("&")' <<<"$body" 2>/dev/null || true)
	if [ -n "$ops" ]; then
		for wait in 3 5 10 20 30; do
			sleep "$wait"
			call "$HOME_API/thumbnails/uploads/status?$ops" || break
			echo "upload status: $body"
			jq -e '(.uploadStatus // "") | test("finish|complete|fail"; "i")' <<<"$body" >/dev/null 2>&1 && break
		done
	fi
	show_home
	;;
home-delete)
	[ $# -gt 0 ] || {
		echo "home-delete needs at least one homepage thumbnail id (run list for the ids)" >&2
		exit 2
	}
	for id in "$@"; do
		case "$id" in
		'' | *[!A-Za-z0-9-]*)
			echo "homepage thumbnail ids are letters, digits and dashes, got: $id" >&2
			exit 2
			;;
		esac
	done
	query=$(printf 'homepageThumbnailIds=%s&' "$@")
	call "$HOME_API/thumbnails?${query%&}" -X DELETE || exit 1
	echo "Roblox answered HTTP $status: $body"
	show_home
	;;
*)
	echo "unknown action: $ACTION (list, icon, thumbnails, order, delete, alt, home, home-delete)" >&2
	exit 2
	;;
esac
