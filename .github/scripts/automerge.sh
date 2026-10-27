#!/usr/bin/env bash
# One merge-queue step for one PR. Called by .github/workflows/automerge.yml when the `automerge` label goes on,
# which only starts check.yml on the branch, and by the last job of check.yml, which merges.
#
# It merges only when the project rule holds: the PR is open, not a draft, based on main, labeled `automerge`,
# and CI passed on its head merged with the latest main. check.yml checks every PR merged with main
# (.github/scripts/merge-main.sh), so the code that passed is the code main gets.
#   - Main moved since the run started: start check.yml on the branch with the new main merged in. Nothing is
#     pushed to the branch, so nobody gets mail and no dead "check" run is left behind. That run's last job comes
#     back here and merges.
#   - Conflict with main, or GitHub refuses the merge (for example a PR that changes .github/workflows, which the
#     workflow token may not touch): drop the label and comment, so the PR's own thread gets woken and finishes
#     by hand.
#   - CI failed: check.yml's last job never starts, so the label stays on until a push goes green.
# After a merge it starts check.yml on main (the merge push started none) and, with AUTO_PUBLISH=true, publish.yml.
#
# Usage: automerge.sh [pr-number]   (no number: the open PR whose branch is GITHUB_REF_NAME)
# Needs GH_TOKEN and GITHUB_REPOSITORY, and in check.yml GITHUB_WORKFLOW, GITHUB_EVENT_NAME, GITHUB_EVENT_PATH,
# GITHUB_SHA, CHECKED_MAIN and CHECKED_MAIN_UNITS (the main commit each job checked against).
set -euo pipefail

REPO=${GITHUB_REPOSITORY:?}
LABEL=automerge
PR=${1:-}

if [ -z "$PR" ]; then
	PR=$(gh pr list --repo "$REPO" --head "${GITHUB_REF_NAME:?}" --state open --json number --jq '.[0].number // empty')
	if [ -z "$PR" ]; then
		echo "No open PR for branch $GITHUB_REF_NAME."
		exit 0
	fi
fi

view() { gh pr view "$PR" --repo "$REPO" --json state,isDraft,baseRefName,headRefName,headRefOid,mergeable,labels; }

# REST calls for the label and comment: `gh pr edit` also reads project cards, which the workflow token cannot.
drop() {
	gh api -X DELETE "repos/$REPO/issues/$PR/labels/$LABEL" >/dev/null || true
	gh api "repos/$REPO/issues/$PR/comments" -f body="$1

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
main=$(gh api "repos/$REPO/git/ref/heads/main" --jq .object.sha)

# Starts check.yml on the branch with $main merged in. A branch made before this flow (2026-10-27) has a check.yml
# without the `main` input, which GitHub refuses; its run then brings the branch up to date the old way.
run_check() {
	gh workflow run check.yml --repo "$REPO" --ref "$branch" -f main="$main" 2>/dev/null ||
		gh workflow run check.yml --repo "$REPO" --ref "$branch"
}

# From automerge.yml, when the label goes on: start check.yml on the branch. Its last job comes back here once the
# gate and the unit tests passed. Nothing here reads the checks API, which went on reporting finished jobs as
# running for over five minutes on 2026-10-27 (PR #190 and the first try of #196 stalled on it).
if [ "${GITHUB_WORKFLOW:-}" != check ]; then
	run_check
	echo "Started check.yml on $branch ($head) with main $main merged in; its last job merges PR #$PR once it passes."
	exit 0
fi

# From check.yml's last job, which starts only after the gate and the unit tests passed in this same run. They are
# the whole CI today; a required check in another workflow would have to be checked here too. The run must have
# checked the PR's current head.
if [ "${GITHUB_EVENT_NAME:-}" = pull_request ]; then
	ran_on=$(jq -r .pull_request.head.sha "${GITHUB_EVENT_PATH:?}")
else
	ran_on=${GITHUB_SHA:?}
fi
if [ "$ran_on" != "$head" ]; then
	echo "This run checked $ran_on but PR #$PR is at $head now; the run on $head comes back here."
	exit 0
fi
checked=${CHECKED_MAIN:-}
if [ -z "$checked" ] || [ "$checked" != "${CHECKED_MAIN_UNITS:-}" ] || [ "$checked" != "$main" ]; then
	if [ "$(jq -r .mergeable <<<"$pr")" = CONFLICTING ]; then
		drop "Automerge stopped: this branch conflicts with main. Merge main in and resolve the conflict by hand."
		exit 0
	fi
	run_check
	echo "This run checked $head against main ${checked:-?} (unit tests: ${CHECKED_MAIN_UNITS:-?}), but main is at $main now: started check.yml on $branch with it merged in."
	exit 0
fi
echo "The gate and the unit tests passed on $head merged with the latest main ($main) in this run."

if gh api -X PUT "repos/$REPO/pulls/$PR/merge" -f merge_method=merge -f sha="$head" >/dev/null; then
	echo "Merged PR #$PR at $head."
	gh workflow run check.yml --repo "$REPO" --ref main || true
	if [ "${AUTO_PUBLISH:-}" = true ]; then
		gh workflow run publish.yml --repo "$REPO" --ref main -f version_type=Published || true
		echo "Started publish.yml (AUTO_PUBLISH is on)."
	fi
	exit 0
fi

# Another run merged it first, or a push landed while we looked (the head moved, so the merge refused and that
# push's CI comes back here).
pr=$(view)
if [ "$(jq -r .state <<<"$pr")" != OPEN ] || [ "$(jq -r .headRefOid <<<"$pr")" != "$head" ]; then
	echo "PR #$PR was merged elsewhere or its head moved; nothing to do."
	exit 0
fi
drop "Automerge stopped: GitHub refused the merge. A PR that changes .github/workflows has to be merged by hand (the workflow token may not), otherwise see this job's log."
