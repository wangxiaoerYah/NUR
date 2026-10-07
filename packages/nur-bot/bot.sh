#!/usr/bin/env bash
set -euo pipefail

: "${NUR_BOT_REPO:=wangxiaoerYah/NUR}"
: "${NUR_BOT_BASE:=main}"
: "${NUR_BOT_BRANCH:=bot/update-inputs}"

rm -rf /tmp/nur-bot
export HOME=/tmp/nur-bot/home
mkdir -p "$HOME" /tmp/nur-bot/repo

auth=""
if [ -n "${NUR_BOT_TOKEN:-}" ]; then
  auth="${NUR_BOT_TOKEN}@"
fi

git clone "https://${auth}github.com/${NUR_BOT_REPO}.git" /tmp/nur-bot/repo
cd /tmp/nur-bot/repo
git config user.name "nur-bot"
git config user.email "41898282+nur-bot@users.noreply.github.com"
git switch -C "$NUR_BOT_BRANCH" "origin/${NUR_BOT_BASE}"

nix flake update

if git diff --quiet -- flake.lock; then
  echo "flake.lock unchanged, nothing to do"
  exit 0
fi

git add flake.lock
git commit -m "flake.lock: update inputs"

if [ -z "${NUR_BOT_TOKEN:-}" ]; then
  echo "no NUR_BOT_TOKEN: dry run, stopping after commit"
  git --no-pager show --stat HEAD
  exit 0
fi

git push "https://${auth}github.com/${NUR_BOT_REPO}.git" "+HEAD:refs/heads/${NUR_BOT_BRANCH}"

body=$(
  jq -nc \
    --arg t "flake.lock: update inputs" \
    --arg h "$NUR_BOT_BRANCH" \
    --arg b "$NUR_BOT_BASE" \
    '{ title: $t, head: $h, base: $b }'
)
code=$(
  curl -sS -o /tmp/pr.json -w '%{http_code}' \
    -H "Authorization: Bearer ${NUR_BOT_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -d "$body" \
    "https://api.github.com/repos/${NUR_BOT_REPO}/pulls"
)
case "$code" in
201)
  jq -r '.html_url' /tmp/pr.json
  ;;
422)
  echo "pull request already open for ${NUR_BOT_BRANCH}"
  ;;
*)
  cat /tmp/pr.json >&2
  echo "pull request create failed: HTTP ${code}" >&2
  exit 1
  ;;
esac
