#!/usr/bin/env bash
# One merge-queue step for one PR. Called by .github/workflows/automerge.yml when the `automerge` label goes on
# (with --wait, so it sits out a CI run that is still going) and by the last job of check.yml after CI.
#
# It merges only when the project rule holds: the PR is open, not a draft, based on main, labeled `automerge`,
# every check on its head passed, and the head already contains the latest main.
#   - Head behind main: merge main into the branch (update-branch) and start check.yml on it, because a push made
#     with the workflow token starts no workflows. That run's last job comes back here and merges.
#   - Conflict with main, or GitHub refuses the update or the merge (for example a PR that changes
#     .github/workflows, which the workflow token may not touch): drop the label and comment, so the PR's own
#     thread gets woken and finishes by hand.
#   - Checks failed: leave the label on and wait for the next push.
# After a merge it starts check.yml on main (the merge push started none) and, with AUTO_PUBLISH=true, publish.yml.
#
# Usage: automerge.sh [pr-number] [--wait]   (no number: the open PR whose branch is GITHUB_REF_NAME)
# Needs GH_TOKEN and GITHUB_REPOSITORY (both set in Actions).
set -euo pipefail

REPO=${GITHUB_REPOSITORY:?}
LABEL=automerge
SELF="Merge if labeled automerge" # this job's check run name in both workflows; still running while we look
PR=${1:-}
WAIT=${2:-}

if [ -z "$PR" ]; then
	PR=$(gh pr list --repo "$REPO" --head "${GITHUB_REF_NAME:?}" --state open --json number --jq '.[0].number // empty')
	if [ -z "$PR" ]; then
		echo "No open PR for branch $GITHUB_REF_NAME."
		exit 0
	fi
fi

view() { gh pr view "$PR" --repo "$REPO" --json state,isDraft,baseRefName,headRefName,headRefOid,mergeable,labels; }

drop() {
	gh pr edit "$PR" --repo "$REPO" --remove-label "$LABEL" >/dev/null || true
	gh pr comment "$PR" --repo "$REPO" --body "$1

The \`$LABEL\` label is off; put it back after fixing and the merge goes ahead once CI is green.

---
_Posted by the automerge workflow (.github/scripts/automerge.sh)_" >/dev/null || true
	echo "Dropped the label: $1"
}

pr=$(view)
if [ "$(jq -r .state <<<"$pr")" != OPEN ]; then
	echo "PR #$PR is not open."
	exit 0
fi
if ! jq -e --arg l "$LABEL" 'any(.labels[]; .name == $l)' <<<"$pr" >/dev/null; then
	echo "PR #$PR has no $LABEL label."
	exit 0
fi
if [ "$(jq -r .isDraft <<<"$pr")" = true ] || [ "$(jq -r .baseRefName <<<"$pr")" != main ]; then
	echo "PR #$PR is a draft or not based on main; automerge only merges ready PRs into main."
	exit 0
fi
head=$(jq -r .headRefOid <<<"$pr")
branch=$(jq -r .headRefName <<<"$pr")

# The latest run of every check on the head, leaving out this job itself.
read_checks() {
	gh api "repos/$REPO/commits/$head/check-runs?per_page=100" \
		--jq "[.check_runs[] | select(.name != \"$SELF\") | {status, conclusion}]"
}
checks=$(read_checks)
if [ "$WAIT" = --wait ]; then
	for _ in $(seq 1 40); do
		if [ "$(jq 'length' <<<"$checks")" -gt 0 ] &&
			[ "$(jq '[.[] | select(.status != "completed")] | length' <<<"$checks")" -eq 0 ]; then
			break
		fi
		sleep 10
		checks=$(read_checks)
	done
fi
if [ "$(jq 'length' <<<"$checks")" -eq 0 ] ||
	[ "$(jq '[.[] | select(.status != "completed")] | length' <<<"$checks")" -gt 0 ]; then
	echo "Checks are still running on $head; check.yml's last job will come back here."
	exit 0
fi
if [ "$(jq '[.[] | select((.conclusion // "") as $c | ["success", "skipped", "neutral"] | index($c) | not)] | length' <<<"$checks")" -gt 0 ]; then
	echo "A check failed on $head; waiting for the next push."
	exit 0
fi

behind=$(gh api "repos/$REPO/compare/main...$head" --jq .behind_by)
if [ "$behind" -gt 0 ]; then
	if [ "$(jq -r .mergeable <<<"$pr")" = CONFLICTING ]; then
		drop "Automerge stopped: this branch conflicts with main. Merge main in and resolve the conflict by hand."
		exit 0
	fi
	if ! gh api -X PUT "repos/$REPO/pulls/$PR/update-branch" -f expected_head_sha="$head" >/dev/null; then
		drop "Automerge stopped: GitHub refused to merge main into this branch (a conflict, or the PR changes .github/workflows). Merge main in by hand and push."
		exit 0
	fi
	for _ in $(seq 1 30); do
		now=$(gh api "repos/$REPO/git/ref/heads/$branch" --jq .object.sha)
		[ "$now" != "$head" ] && break
		sleep 2
	done
	if [ "$now" = "$head" ]; then
		drop "Automerge stopped: GitHub accepted the update from main but the branch did not move within a minute. Merge main in by hand and push."
		exit 0
	fi
	gh workflow run check.yml --repo "$REPO" --ref "$branch"
	echo "Branch was $behind commit(s) behind main: merged main in ($now) and started check.yml on it."
	exit 0
fi

if gh pr merge "$PR" --repo "$REPO" --merge --match-head-commit "$head"; then
	echo "Merged PR #$PR at $head."
	gh workflow run check.yml --repo "$REPO" --ref main || true
	if [ "${AUTO_PUBLISH:-}" = true ]; then
		gh workflow run publish.yml --repo "$REPO" --ref main -f version_type=Published || true
		echo "Started publish.yml (AUTO_PUBLISH is on)."
	fi
	exit 0
fi

# A push that landed while we looked changes the head and makes the merge refuse; that push's CI comes back here.
if [ "$(view | jq -r .headRefOid)" != "$head" ]; then
	echo "The head moved while merging; the new head's CI decides."
	exit 0
fi
drop "Automerge stopped: GitHub refused the merge. A PR that changes .github/workflows has to be merged by hand (the workflow token may not), otherwise see this job's log."
