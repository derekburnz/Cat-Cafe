#!/usr/bin/env bash
# Add or remove one "Idea from <display name>" credit for the Thank You board (docs/design/cat-cafe/idea-credits.md,
# #1083) through Open Cloud data stores. Run by .github/workflows/idea-credits.yml; also works from Git Bash on a PC
# with the same variables set.
#
#   ROBLOX_PUBLISH_KEY   Open Cloud API key with universe-datastores.objects:read and :create on the Cat Cafe
#                        experience (add mode), and :delete (remove mode)
#   UNIVERSE_ID          default below
#
# Usage:  tools/opencloud/idea-credits.sh add <report key> <idea text> <place version>
#         tools/opencloud/idea-credits.sh remove <credit key>
#
# add reads the report from BugReports_v1 (written by src/server/Services/BugReportService.luau, key
# BugReport.key: r_<YYYYMMDD>_<os.time()>_<userId>) and refuses unless its kind is "idea" and its featureName is
# exactly true (the player ticked "Feature my name if you use my idea"). Then it creates a new entry in
# IdeaCredits_v1 under c_<addedAt>_<random hex>: { userId, idea, version, addedAt }. The credit key has no user id
# in it, so it is printed, for a later remove.
#
# The Actions log of this public repo is public, and the reporters are players, many of them young. So this script
# never prints a user id, a name, the report text or any Open Cloud reply body; only "credit added <key>",
# "credit removed <key>" or why it refused. The report key holds the user id, so it is masked and never echoed.
# Needs curl, jq and openssl (all on GitHub's ubuntu runners).
set -euo pipefail
export LC_ALL=C.UTF-8 # ${#idea} counts characters, not bytes

UNIVERSE_ID=${UNIVERSE_ID:-10773193456}
REPORTS=BugReports_v1 # BugReportService
CREDITS=IdeaCredits_v1 # idea-credits.md section 4
IDEA_MAX=48
: "${ROBLOX_PUBLISH_KEY:?set ROBLOX_PUBLISH_KEY (docs/setup-guide.md step 17)}"
API=https://apis.roblox.com/cloud/v2/universes/$UNIVERSE_ID/data-stores

refuse() {
	echo "refused: $1" >&2
	[ -z "${GITHUB_STEP_SUMMARY:-}" ] || echo "### refused: $1" >>"$GITHUB_STEP_SUMMARY"
	exit 1
}

usage() {
	echo "usage: idea-credits.sh add <report key> <idea text> <place version> | remove <credit key>" >&2
	exit 2
}

mask() { # hide a value from the rest of the Actions log; a no-op outside Actions
	[ -z "${GITHUB_ACTIONS:-}" ] || echo "::add-mask::$1"
}

reply=$(mktemp)
trap 'rm -f "$reply"' EXIT
# call method url [curl args...] -> sets $status and $body. Roblox answers 5xx or 429 now and then, so those get
# three more tries over about half a minute (as flags.sh and bug-reports.sh). The URL can hold the report key, so
# curl's own error lines are dropped and only the HTTP status is ever shown.
call() {
	local method=$1 url=$2 wait
	shift 2
	for wait in 5 10 20 0; do
		status=$(curl -s -o "$reply" -w '%{http_code}' -X "$method" "$url" -H "x-api-key: $ROBLOX_PUBLISH_KEY" "$@" \
			2>/dev/null) || status=000
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

# fail what scopes: the reply body can echo the report or its key, so only the status and Roblox's error code show
fail() {
	local code
	code=$(jq -r '.code // empty' <<<"$body" 2>/dev/null | tr -cd 'A-Z_' || true)
	echo "Open Cloud answered HTTP $status${code:+ ($code)} while trying to $1." >&2
	case "$status" in
	401 | 403) echo "The key needs universe-datastores.objects:$2 on universe $UNIVERSE_ID." >&2 ;;
	esac
	exit 1
}

add() {
	local report_key=$1 idea=$2 version=$3
	mask "$report_key"
	# r_ only: Studio playtests' reports (s_) are test data, not a player's idea
	[[ $report_key =~ ^r_[0-9]{8}_[0-9]{10}_[1-9][0-9]*$ ]] ||
		refuse "report_key must be a live report key, r_<YYYYMMDD>_<time>_<id> (as bug-reports prints it)"
	# our own words, one line, at most 48 characters, no control characters
	idea=$(sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' <<<"$idea")
	[ -n "$idea" ] || refuse "idea is empty"
	[ "${#idea}" -le "$IDEA_MAX" ] || refuse "idea is ${#idea} characters; at most $IDEA_MAX"
	[[ $idea != *[[:cntrl:]]* ]] || refuse "idea has a control character or line break"
	[[ $version =~ ^[1-9][0-9]{0,8}$ ]] || refuse "version must be a place version number, like 190"

	call GET "$API/$REPORTS/entries/$report_key"
	if [ "$status" = 404 ]; then
		refuse "no report under that key in $REPORTS"
	fi
	[ "$status" = 200 ] || fail "read the report" read
	# Only these three fields are taken from the record; the rest (text, name, ...) never leaves jq.
	local kind feature user_id
	kind=$(jq -r 'if (.value.kind | type) == "string" then .value.kind else "" end' <<<"$body")
	feature=$(jq -r '.value.featureName == true' <<<"$body")
	user_id=$(jq -r 'if (.value.userId | type) == "number" then .value.userId | floor | tostring else "" end' \
		<<<"$body")
	body=
	[ -z "$user_id" ] || mask "$user_id"
	[ "$kind" = idea ] || refuse "the report is not an idea"
	[ "$feature" = true ] || refuse "the player did not tick \"Feature my name if you use my idea\""
	[[ $user_id =~ ^[1-9][0-9]*$ ]] || refuse "the report has no valid userId"
	# the key ends in the reporter's id (BugReport.key); a record that disagrees is not trusted
	[ "${report_key##*_}" = "$user_id" ] || refuse "the report's userId does not match its key"

	local added_at credit_key value
	added_at=$(date -u +%s)
	credit_key=c_${added_at}_$(openssl rand -hex 4)
	value=$(jq -nc --argjson userId "$user_id" --arg idea "$idea" --argjson version "$version" \
		--argjson addedAt "$added_at" '{userId: $userId, idea: $idea, version: $version, addedAt: $addedAt}')
	# users tags the entry with the player, as BugReportService's SetAsync does, so a data request finds it.
	# POST creates only: it never overwrites an existing credit.
	call POST "$API/$CREDITS/entries?id=$credit_key" -H "Content-Type: application/json" \
		--data "$(jq -nc --argjson value "$value" --arg user "users/$user_id" '{value: $value, users: [$user]}')"
	[ "$status" = 200 ] || fail "write the credit" create
	echo "credit added $credit_key"
	[ -z "${GITHUB_STEP_SUMMARY:-}" ] || echo "### credit added \`$credit_key\`" >>"$GITHUB_STEP_SUMMARY"
}

remove() {
	local credit_key=$1
	[[ $credit_key =~ ^c_[0-9]{10}_[0-9a-f]{8}$ ]] || refuse "remove_key must be a credit key, c_<time>_<8 hex>"
	call DELETE "$API/$CREDITS/entries/$credit_key"
	if [ "$status" = 404 ]; then
		refuse "no credit under $credit_key in $CREDITS"
	fi
	[ "$status" = 200 ] || fail "remove the credit" delete
	echo "credit removed $credit_key"
	[ -z "${GITHUB_STEP_SUMMARY:-}" ] || echo "### credit removed \`$credit_key\`" >>"$GITHUB_STEP_SUMMARY"
}

case "${1:-}" in
add)
	[ $# = 4 ] || usage
	add "$2" "$3" "$4"
	;;
remove)
	[ $# = 2 ] || usage
	remove "$2"
	;;
*) usage ;;
esac
