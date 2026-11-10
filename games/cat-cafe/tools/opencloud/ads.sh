#!/usr/bin/env bash
# Read the ad campaigns with Open Cloud (Ads API, beta), read only: each campaign's name, status, delivery, objective,
# budget, targeting and creatives, and the creative names. Run by analytics.yml when its funnel input is "ads".
# Campaign performance (spend, impressions, clicks, plays) is not in the Ads API: Roblox says it will come through the
# Analytics API, so the script also tries a few likely metric names there and prints what the API answers.
#   ROBLOX_PUBLISH_KEY  a user-owned key with ad.campaign:read (group-owned keys are not supported by the Ads API beta),
#                       plus universe.analytics:read for the metric probe
# Never prints the key.
set -uo pipefail
: "${ROBLOX_PUBLISH_KEY:?set ROBLOX_PUBLISH_KEY}"
UNIVERSE_ID=${UNIVERSE_ID:-10773193456}
ads=https://apis.roblox.com/ads-management/v1
reply=$(mktemp)
trap 'rm -f "$reply"' EXIT

get() {
	local status
	status=$(curl -sS -o "$reply" -w '%{http_code}' "$1" -H "x-api-key: $ROBLOX_PUBLISH_KEY") || status=000
	echo "GET ${1#https://apis.roblox.com} -> HTTP $status"
	[ "$status" = 200 ]
}

echo "== campaigns"
url="$ads/campaigns?maxPageSize=50"
if get "$url"; then
	jq -r '.campaigns[]? | "\(.name) | status \(.status) | delivery \(.deliveryStatus) \(.deliveryStatusReasons // [] | join(","))
  objective \(.objective) | payment \(.paymentType) | budget \(.budget | tostring) | bid \(.bid | tostring)
  schedule \(.schedule | tostring)
  targeting \(.targeting | tostring)
  creatives \(.creativeAssetIds // [] | join(",")) | id \(.id)"' "$reply"
	echo "== raw campaigns"
	cat "$reply"
	echo
else
	cat "$reply"
	echo
fi

echo "== creatives"
if get "$ads/creatives?maxPageSize=100"; then
	jq -r '.creatives[]? | "\(.assetId) \(.assetName) \(.createTime)"' "$reply"
else
	cat "$reply"
	echo
fi

echo "== advertisable universes"
get "$ads/advertisable-universes" && jq -c . "$reply" || cat "$reply"
echo

# Performance metric probe (names are guesses; the docs list none yet). Last 3 days, one day buckets.
echo "== analytics metric probe"
start=$(date -u -d '3 days ago' +%Y-%m-%dT00:00:00Z)
end=$(date -u +%Y-%m-%dT00:00:00Z)
for metric in AdSpend AdImpressions AdClicks AdPlays CampaignSpend CampaignImpressions CampaignClicks CampaignPlays \
	SponsoredImpressions SponsoredClicks SponsoredPlays; do
	body=$(jq -nc --arg m "$metric" --arg s "$start" --arg e "$end" \
		'{metric: $m, granularity: "OneDay", startTime: $s, endTime: $e}')
	status=$(curl -sS -o "$reply" -w '%{http_code}' -X POST \
		"https://apis.roblox.com/analytics-query-api/v1/universes/$UNIVERSE_ID/metrics" \
		-H "x-api-key: $ROBLOX_PUBLISH_KEY" -H 'Content-Type: application/json' -d "$body") || status=000
	echo "$metric -> HTTP $status $(head -c 300 "$reply")"
	sleep 2
done
