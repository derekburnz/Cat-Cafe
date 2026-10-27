#!/usr/bin/env bash
# Upload one image file to Roblox (Open Cloud Assets API) and print its asset id, so a thread can put
# rbxassetid://<id> in the code without Studio's Asset Manager. Every run makes a new asset (images cannot be
# updated), owned by the account below. Roblox moderates each image; until it is approved it draws blank.
# Run by .github/workflows/upload-image.yml; also works from Git Bash on a PC with the same variables set.
#
#   ROBLOX_PUBLISH_KEY      Open Cloud API key that also has assets Read and Write (docs/setup-guide.md step 17)
#   ROBLOX_CREATOR_USER_ID  the account that owns the image: default 40908216, Derek, who owns the experience
#   ASSET_TYPE              Image (default; the id goes straight into ImageLabel.Image, Texture and the like) or
#                           Decal (an asset to put on a part from the Toolbox)
#
# Usage:  upload-image.sh <file .png|.jpg|.jpeg|.bmp|.tga> [name on Roblox, default the file name without extension]
# Needs curl and jq (both on GitHub's ubuntu runners).
set -euo pipefail

FILE=${1:?image file}
NAME=${2:-}
NAME=${NAME:-$(basename "${FILE%.*}")}
CREATOR=${ROBLOX_CREATOR_USER_ID:-40908216}
TYPE=${ASSET_TYPE:-Image}
: "${ROBLOX_PUBLISH_KEY:?set ROBLOX_PUBLISH_KEY (docs/setup-guide.md step 17)}"
API=https://apis.roblox.com/assets/v1

ext=$(printf '%s' "${FILE##*.}" | tr '[:upper:]' '[:lower:]')
case "$ext" in
png) ctype=image/png ;;
jpg | jpeg) ctype=image/jpeg ;;
bmp) ctype=image/bmp ;;
tga) ctype=image/tga ;;
*)
	echo "Open Cloud takes .png, .jpg, .bmp or .tga images, got: $FILE" >&2
	exit 2
	;;
esac
case "$TYPE" in
Image | Decal) ;;
*)
	echo "ASSET_TYPE must be Image or Decal, got: $TYPE" >&2
	exit 2
	;;
esac
[ -f "$FILE" ] || {
	echo "no such file: $FILE" >&2
	exit 2
}
[ "$(wc -c <"$FILE")" -le $((20 * 1024 * 1024)) ] || {
	echo "$FILE is over Open Cloud's 20 MB limit" >&2
	exit 2
}

reply=$(mktemp)
trap 'rm -f "$reply"' EXIT
# call url [curl args...] -> sets $status and $body. Roblox answers 5xx or 429 now and then, so those get three
# more tries over about half a minute. A retried upload that went through anyway leaves one unused image behind.
call() {
	local url=$1 wait
	shift
	for wait in 5 10 20 0; do
		status=$(curl -sS -o "$reply" -w '%{http_code}' "$url" -H "x-api-key: $ROBLOX_PUBLISH_KEY" "$@") || status=000
		case "$status" in
		5?? | 429 | 000) ;;
		*) break ;;
		esac
		[ "$wait" = 0 ] && break
		echo "Open Cloud answered HTTP $status; trying again in ${wait}s." >&2
		sleep "$wait"
	done
	body=$(cat "$reply")
	if [ "$status" != 200 ]; then
		echo "Open Cloud answered HTTP $status: $body" >&2
		case "$status" in
		401 | 403) echo "The key needs the assets API with Read and Write, owned by user $CREATOR (docs/setup-guide.md step 17)." >&2 ;;
		esac
		exit 1
	fi
}

request=$(jq -cn --arg type "$TYPE" --arg name "$NAME" --arg creator "$CREATOR" \
	'{assetType: $type, displayName: $name, description: $name, creationContext: {creator: {userId: $creator}}}')
call "$API/assets" -X POST --form-string "request=$request" -F "fileContent=@\"$FILE\";type=$ctype"
operation=$(jq -r '.operationId // (.path // "" | sub("^operations/"; ""))' <<<"$body")
[ -n "$operation" ] || {
	echo "Open Cloud gave no operation for the upload: $body" >&2
	exit 1
}

# The upload finishes in the background; Roblox's pattern is to poll with growing waits.
deadline=$((SECONDS + 300))
wait=1
while :; do
	call "$API/operations/$operation"
	[ "$(jq -r '.done // false' <<<"$body")" = true ] && break
	if [ "$SECONDS" -gt "$deadline" ]; then
		echo "Gave up waiting for operation $operation; check it again later." >&2
		exit 1
	fi
	sleep "$wait"
	[ "$wait" -ge 16 ] || wait=$((wait * 2))
done
if [ "$(jq -r 'has("error")' <<<"$body")" = true ]; then
	echo "Roblox refused the upload: $(jq -c .error <<<"$body")" >&2
	exit 1
fi

id=$(jq -r '.response.assetId' <<<"$body")
moderation=$(jq -r '.response.moderationResult.moderationState // "unknown"' <<<"$body")
echo "Uploaded $FILE as $TYPE $id: rbxassetid://$id (moderation: $moderation)"
case "$moderation" in
*Rejected* | *REJECTED*)
	echo "Roblox moderation rejected the image." >&2
	exit 1
	;;
*Approved* | *APPROVED*) ;;
*) echo "It draws blank until moderation approves it, usually within minutes." ;;
esac
if [ -n "${GITHUB_OUTPUT:-}" ]; then
	echo "asset_id=$id" >>"$GITHUB_OUTPUT"
fi
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
	echo "- \`$FILE\` uploaded as $TYPE **$id**: \`rbxassetid://$id\` (moderation: $moderation)" >>"$GITHUB_STEP_SUMMARY"
fi
