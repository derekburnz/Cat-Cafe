#!/usr/bin/env bash
# Waits while a publish or restart run of the OTHER lane, started before this run, is still in progress.
#
# Why (2026-11-13): publish.yml and restart-servers.yml shared one concurrency group, and GitHub keeps only one
# waiting run per group. Every finished main check starts a publish run, so a hand-started publish or restart
# that was still waiting got cancelled the moment any main check finished. Hand runs (workflow_dispatch) now have
# their own group, publish-hand, and automatic runs keep publish. The groups no longer keep the two lanes apart,
# so this step does: each run waits for the other lane's runs that started before it (oldest first, ties by run
# id), which is a total order, so two runs can never wait on each other.
#
# Usage: wait-publish-lane.sh <max minutes> <hand|auto>, this run's own lane. Needs GH_TOKEN (actions: read),
# GITHUB_REPOSITORY and GITHUB_RUN_ID. Another run's lane: a restart is hand; a publish is auto when started by a
# check (workflow_run) or with the automatic input (automerge.sh's label merges), else hand. After the limit it goes on with a warning rather than fail a restart players were told about.
set -euo pipefail

max_minutes="${1:-25}"
repo="$GITHUB_REPOSITORY"
me="$GITHUB_RUN_ID"

api() {
  curl -fsS --retry 3 --retry-all-errors -H "Authorization: Bearer $GH_TOKEN" \
    -H "Accept: application/vnd.github+json" "https://api.github.com/repos/$repo/$1"
}

my_lane="${2:?lane hand or auto}"
my_start=$(api "actions/runs/$me" | jq -r '.run_started_at')
deadline=$(($(date +%s) + max_minutes * 60))

while :; do
  ahead=""
  for wf in publish.yml restart-servers.yml; do
    found=$(api "actions/workflows/$wf/runs?status=in_progress&per_page=30" | jq -r \
      --arg me "$me" --arg lane "$my_lane" --arg start "$my_start" --arg wf "$wf" '
        .workflow_runs[]
        | select((.id | tostring) != $me)
        | select((if $wf == "restart-servers.yml" then "hand"
            elif .event != "workflow_dispatch" then "auto"
            elif ((.display_title // "") | test("automatic"; "i")) then "auto"
            else "hand" end) != $lane)
        | select(.run_started_at < $start or (.run_started_at == $start and (.id | tostring) < $me))
        | "\(.name) run \(.id) (\(.event), started \(.run_started_at))"')
    [ -n "$found" ] && ahead+="$found"$'\n'
  done
  if [ -z "$ahead" ]; then
    echo "No $( [ "$my_lane" = hand ] && echo automatic || echo hand-started ) publish or restart ahead of this run."
    exit 0
  fi
  if [ "$(date +%s)" -ge "$deadline" ]; then
    echo "::warning::Still running after ${max_minutes} minutes, going on anyway:"$'\n'"$ahead"
    exit 0
  fi
  echo "Waiting for:"$'\n'"$ahead"
  sleep 20
done
