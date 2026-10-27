#!/usr/bin/env bash
# Makes a PR run check the code main would get from the merge, without pushing anything to the branch. A push made
# with the workflow token emails everyone on the PR and leaves a jobless "check" run behind that ends as a failure,
# which is how automerge used to bring branches up to date (Derek asked for the mail to stop, 2026-10-27).
# Writes main=<sha> to $GITHUB_OUTPUT: the main commit the checked tree contains. automerge.sh merges only when
# that is still main.
#   - pull_request: actions/checkout already checked out GitHub's test merge of the PR into main, whose first
#     parent is that main.
#   - workflow_dispatch on a branch: merge main in here (the commit automerge.sh passed, or the latest main).
#   - main itself: nothing to merge.
# Needs the full history (checkout fetch-depth 0; filter blob:none keeps it small).
#
# Usage: merge-main.sh [main-sha]
set -euo pipefail

if [ "${GITHUB_REF:?}" = refs/heads/main ]; then
	main=$(git rev-parse HEAD)
elif [ "${GITHUB_EVENT_NAME:?}" = pull_request ]; then
	main=$(git rev-parse HEAD^1)
else
	git fetch --no-tags --quiet origin main
	main=${1:-$(git rev-parse FETCH_HEAD)}
	if ! git -c user.name=ci -c user.email=ci@localhost merge --no-ff --no-edit --quiet "$main"; then
		echo "::error::This branch conflicts with main ($main). Merge main in by hand, resolve it and push."
		exit 1
	fi
fi
echo "main=$main" >>"${GITHUB_OUTPUT:?}"
echo "Checking $(git rev-parse HEAD), which contains main $main."
