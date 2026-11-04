#!/usr/bin/env bash
# List, make and change the experience's developer products (Open Cloud Developer Products API, beta), so the
# products the Store sells exist with the names and prices in products.json and their ids can go in Config, without
# Creator Hub. A developer product is a Robux purchase the player can make again and again (a potion pack); the
# server grants it in MarketplaceService.ProcessReceipt (src/server/Services/ProductService.luau).
# Products cannot be deleted, so `create` only makes the products whose names are not there yet: running it twice
# makes nothing new. `create` always makes them off sale, so nobody can buy one before the code that grants it is in;
# `set <name> forSale=true` puts one on sale once ProductService and its Catalog.products entry are merged.
# Same pattern as game-passes.sh. Run by .github/workflows/dev-products.yml; also works from Git Bash on a PC with
# the same variables set.
#
#   ROBLOX_PUBLISH_KEY   Open Cloud API key with developer-product:read and developer-product:write on Cat Cafe
#   ROBLOX_UNIVERSE_ID   the experience: default 10773193456, Cat Cafe
#
# Usage:
#   dev-products.sh list [file]                every product: id, name, price, on or off sale, and its Config line
#   dev-products.sh create [file]              make each product in the file that is missing (file: products.json)
#   dev-products.sh set <id or name> change... change one product. Changes: price=N, forSale=true|false,
#                                              regional=true|false, icon=<.png or .jpg path from the repo root>
# Needs curl and jq (both on GitHub's ubuntu runners).
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../../.." && pwd)
UNIVERSE=${ROBLOX_UNIVERSE_ID:-10773193456}
ACTION=${1:-list}
API=https://apis.roblox.com/developer-products/v2/universes/$UNIVERSE/developer-products
: "${ROBLOX_PUBLISH_KEY:?set ROBLOX_PUBLISH_KEY (an Open Cloud key with developer-product:read and :write)}"

# Field names from the Open Cloud reference (DeveloperProductConfigV2, read 2026-11-04): the list answers
# {"developerProducts": [...], "nextPageToken": ...} and each product has a numeric productId. Any other shape stops
# the script before anything is made.
JQ_DEFS='
def pid: .productId;
def items: .developerProducts;
def price: (.priceInformation.defaultPriceInRobux? // null);
def regional: ([.priceInformation.enabledFeatures?[]? | tostring | ascii_downcase | select(test("regional"))] | length > 0);
def key: (.name // "" | ascii_downcase | gsub("^\\s+|\\s+$"; ""));
def line: "\(pid)  \(.name)  "
	+ (if price == null then "no price" else "R$\(price)" end)
	+ (if .isForSale then ", on sale" else ", off sale" end)
	+ (if regional then ", regional pricing on" else "" end);
'

reply=$(mktemp)
trap 'rm -f "$reply"' EXIT

# request url [curl args...] -> sets $status and $body, one try. The key goes in a header read from a pipe, so it is
# never on curl's command line or in the output.
request() {
	local url=$1
	shift
	status=$(curl -sS --connect-timeout 10 --max-time 60 -o "$reply" -w '%{http_code}' "$url" \
		-H @<(printf 'x-api-key: %s\n' "$ROBLOX_PUBLISH_KEY") "$@") || status=000
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
	401 | 403) echo "The key needs developer-product:read and developer-product:write on the Cat Cafe experience." >&2 ;;
	404) echo "Open Cloud has no developer products API at $API (or no such product)." >&2 ;;
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

# Sets $products to every developer product on the experience as one JSON array, following the pages.
fetch_products() {
	local token='' query
	products='[]'
	while :; do
		query='pageSize=50'
		[ -z "$token" ] || query="$query&pageToken=$(jq -rn --arg t "$token" '$t | @uri')"
		call "$API/creator?$query"
		# An answer in a shape this does not know would read as no products, and create would then make every product
		# again, for good. Only a developerProducts list whose entries have a numeric productId and a name counts.
		if ! jq -e "$JQ_DEFS"'type == "object" and (items | type) == "array" and all(items[]; (pid | type) == "number" and (.name | type) == "string")' <<<"$body" >/dev/null 2>&1; then
			echo "Open Cloud's product list came back in a shape this script does not know, so nothing was changed: $body" >&2
			exit 1
		fi
		products=$(jq -c --argjson all "$products" "$JQ_DEFS"'$all + (items // [])' <<<"$body")
		token=$(jq -r '.nextPageToken // ""' <<<"$body")
		[ -n "$token" ] || break
	done
}

# find_id name -> the id of the product with that name (case and outer spaces ignored), or nothing.
find_id() {
	jq -r --arg name "$1" "$JQ_DEFS"'
		($name | ascii_downcase | gsub("^\\s+|\\s+$"; "")) as $want | first(.[] | select(key == $want) | pid) // empty' <<<"$products"
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
		echo "a product icon is a .png or .jpg, got: $path" >&2
		exit 2
		;;
	esac
	[ -f "$REPO/$path" ] && [ ! -L "$REPO/$path" ] || {
		echo "no such icon in the repo (or it is a link): $path" >&2
		exit 2
	}
	image=(-F "imageFile=@\"$REPO/$path\";type=$ctype")
}

# The file's products by name -> Config target, for the list.
config_map() {
	jq -c "$JQ_DEFS"'map(select(.config) | {(key): .config}) | add // {}' "$1"
}

show() {
	local file=$1 cfg
	cfg=$(config_map "$file")
	echo "== $(jq length <<<"$products") developer products on experience $UNIVERSE"
	jq -r --argjson cfg "$cfg" "$JQ_DEFS"'.[] | line + (if $cfg[key] then "  -> Config \($cfg[key])" else "" end)' <<<"$products"
	echo "== products as JSON"
	jq -c '.[]' <<<"$products"
	if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
		{
			echo "| Id | Product | Price | On sale | Config |"
			echo "|---|---|---|---|---|"
			jq -r --argjson cfg "$cfg" "$JQ_DEFS"'.[] | "| \(pid) | \(.name) | "
				+ (if price == null then "-" else "R$\(price)" end) + " | " + (if .isForSale then "yes" else "no" end)
				+ " | " + ($cfg[key] // "-") + " |"' <<<"$products"
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
		(.name | type) == "string" and (.name | length) > 0 and (.name | length) <= 50
		and ((.description // "") | type) == "string" and ((.description // "") | length) <= 1000
		and ((.config // "ProductIds.x") | type == "string" and test("^ProductIds\\.[a-z0-9_]+$"))
		and (.price | type) == "number" and .price >= 1
		and .price == (.price | floor) and (.regionalPricing | type) == "boolean")' "$file" >/dev/null || {
		echo "$file must be a list of products, each with a name of 1 to 50 characters, a description of at most 1000, a config of ProductIds.<id>, a whole price of at least 1 and regionalPricing true or false" >&2
		exit 2
	}
	if [ "$(jq '[.[].name | ascii_downcase] | length != (unique | length)' "$file")" = true ]; then
		echo "$file names a product twice" >&2
		exit 2
	fi
}

create() {
	local file=$1 n i entry name id wait made=0 icon got made_ids='{}'
	check_file "$file"
	fetch_products
	n=$(jq length "$file")
	for ((i = 0; i < n; i++)); do
		entry=$(jq -c ".[$i]" "$file")
		name=$(jq -r '.name | gsub("^\\s+|\\s+$"; "")' <<<"$entry")
		id=$(find_id "$name")
		if [ -n "$id" ]; then
			echo "$name is there already as $id; left as it is."
			continue
		fi
		# The price is always sent on create: a product made with no price has been seen stuck unbuyable. Regional
		# pricing (a deprecated field) is only sent to turn it on.
		local args=(
			--form-string "name=$name"
			--form-string "description=$(jq -r '.description // ""' <<<"$entry")"
			--form-string "price=$(jq -r .price <<<"$entry")"
			--form-string "isForSale=false"
		)
		[ "$(jq -r .regionalPricing <<<"$entry")" != true ] || args+=(--form-string "isRegionalPricingEnabled=true")
		icon=$(jq -r '.icon // ""' <<<"$entry")
		if [ -n "$icon" ]; then
			image_args "$icon"
			args+=("${image[@]}")
		fi
		# Only a 429 (refused, so nothing was made) is tried again. A 5xx or no answer may still have made the product,
		# and a second one of the same name could never be deleted, so the run stops and asks for a list first.
		for wait in 5 10 20 0; do
			request "$API" -X POST "${args[@]}"
			[ "$status" = 429 ] || break
			[ "$wait" = 0 ] && break
			echo "Open Cloud answered HTTP 429 making $name; trying again in ${wait}s." >&2
			sleep "$wait"
		done
		case "$status" in
		200 | 201) ;;
		5?? | 000)
			echo "Open Cloud answered HTTP $status making $name, so it may or may not exist now. Made so far: $made_ids. Run list, then create again (it skips names that are there)." >&2
			exit 1
			;;
		*)
			echo "Made so far: $made_ids" >&2
			fail
			;;
		esac
		id=$(jq -r "$JQ_DEFS"'pid // empty' <<<"$body")
		[ -n "$id" ] || {
			echo "Open Cloud made $name but gave no id: $body" >&2
			exit 1
		}
		made_ids=$(jq -c --arg k "$name" --argjson id "$id" '. + {($k | ascii_downcase): $id}' <<<"$made_ids")
		echo "Made $name as $id."
		made=$((made + 1))
		# Roblox's filter can change a name; the next create would then not find it and make it again.
		got=$(jq -r '.name // ""' <<<"$body")
		if [ -n "$got" ] && [ "$got" != "$name" ]; then
			echo "::error::Roblox stored $name as '$got'. Change products.json to match before the next create." >&2
			exit 1
		fi
		sleep 1
	done

	fetch_products
	show "$file"
	echo "== Config lines (games/cat-cafe/src/shared/Config.luau)"
	jq -r --argjson have "$products" --argjson made "$made_ids" "$JQ_DEFS"'
		(($have | map({(key): pid}) | add // {}) + $made) as $ids
		| .[] | select(.config) | "\(.config) = \($ids[key] // 0)"' "$file"
	# The beta API has been known to drop fields, so the made products are checked against the file, and any product
	# on sale is called out.
	jq -r --argjson have "$products" "$JQ_DEFS"'
		($have | map({(key): .}) | add // {}) as $by
		| .[] | . as $want | $by[key] as $got | select($got)
		| ($got | price) as $p
		| (if $p != null and $p != $want.price then "::warning::\($want.name) costs R$\($p) on Roblox, R$\($want.price) in the file"
		   elif $p == null then "::warning::\($want.name): the answer shows no price; check it in Creator Hub"
		   else empty end),
		  (if $got.isForSale == true then "::warning::\($want.name) is ON SALE on Roblox" else empty end),
		  (if ($got | regional) != $want.regionalPricing then "::warning::\($want.name): regional pricing on Roblox differs from the file" else empty end)' "$file"
	echo "Made $made new product(s)."
	[ -z "${GITHUB_STEP_SUMMARY:-}" ] || echo "- Made $made new product(s) from \`${file#"$REPO"/}\`" >>"$GITHUB_STEP_SUMMARY"
}

set_product() {
	local target=${1:-} id change value
	shift || true
	[ -n "$target" ] || {
		echo "set needs the product id or its name" >&2
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
	fetch_products
	if [[ $target =~ ^[0-9]+$ ]]; then
		id=$(jq -r --argjson id "$target" "$JQ_DEFS"'first(.[] | select(pid == $id) | pid) // empty' <<<"$products")
	else
		id=$(find_id "$target")
	fi
	[ -n "$id" ] || {
		echo "no product $target on experience $UNIVERSE; run list for the ids" >&2
		exit 2
	}
	echo "Before: $(jq -r --argjson id "$id" "$JQ_DEFS"'.[] | select(pid == $id) | line' <<<"$products")"
	call "$API/$id" -X PATCH "${args[@]}"
	fetch_products
	echo "After:  $(jq -r --argjson id "$id" "$JQ_DEFS"'.[] | select(pid == $id) | line' <<<"$products")"
	jq -c --argjson id "$id" "$JQ_DEFS"'.[] | select(pid == $id)' <<<"$products"
	[ -z "${GITHUB_STEP_SUMMARY:-}" ] || echo "- Product $id changed: $*" >>"$GITHUB_STEP_SUMMARY"
}

case "$ACTION" in
list)
	check_file "${2:-$HERE/products.json}"
	fetch_products
	show "${2:-$HERE/products.json}"
	;;
create) create "${2:-$HERE/products.json}" ;;
set)
	shift
	set_product "$@"
	;;
*)
	echo "usage: dev-products.sh list [file] | create [file] | set <id or name> change..." >&2
	exit 2
	;;
esac
