#!/usr/bin/env bash
# Run ONCE in Termux: stages private repo scripts and ephemeral GitHub token to Vienna.
# No old game files are deleted. Old game UDP server remains running.
set -Eeuo pipefail
umask 077
REPO="Ncorror/reina-dead-signal-rts"
REF="infra/vienna-runner-server"
HOST="reina"
for command in gh ssh scp base64; do
  command -v "$command" >/dev/null || { echo "Missing $command"; exit 1; }
done
gh auth status >/dev/null 2>&1 || { echo "GitHub CLI not authorized"; exit 1; }
LOCAL="$(mktemp -d)"
SESSION="reina-rts-switch-$(date +%s)-$$-$RANDOM"
STAGE="$LOCAL/$SESSION"
mkdir -p "$STAGE/ops/vienna" "$STAGE/server"
finish() { rm -rf "$LOCAL"; }
trap finish EXIT

for path in ops/vienna/switch-vienna-root.sh ops/vienna/install-runner.sh ops/vienna/install-server.sh server/control_api.py server/test_control_api.py; do
  echo "FETCH: $path"
  gh api "repos/$REPO/contents/$path?ref=$REF" --jq '.content' |
    tr -d '\n' | base64 -d >"$STAGE/$path"
  [[ -s "$STAGE/$path" ]] || { echo "Download failed for $path"; exit 1; }
done
for path in "$STAGE"/ops/vienna/*.sh; do bash -n "$path"; done
python3 -m py_compile "$STAGE/server/control_api.py" "$STAGE/server/test_control_api.py"

echo "GET_RTS_RUNNER_REGISTRATION_TOKEN..."
gh api -X POST "repos/$REPO/actions/runners/registration-token" --jq '.token' >"$STAGE/registration.token"
chmod 600 "$STAGE/registration.token"
[[ -s "$STAGE/registration.token" ]] || { echo "No registration token"; exit 1; }

echo "UPLOAD_PRIVATE_STAGE: /tmp/$SESSION"
scp -qr "$STAGE" "$HOST:/tmp/"
echo "DEPLOY_VIENNA (sudo password requested interactively)..."
ssh -tt "$HOST" "sudo bash '/tmp/$SESSION/ops/vienna/switch-vienna-root.sh' '/tmp/$SESSION'; rc=\$?; rm -rf '/tmp/$SESSION'; exit \$rc"

echo "===== NEW REPOSITORY RUNNER ====="
gh api "repos/$REPO/actions/runners" --jq '.runners[] | [.name,.status,.busy,([.labels[].name] | join(","))] | @tsv'
echo "===== RECENT RTS ACTIONS ====="
gh run list -R "$REPO" --limit 4 || true
echo "ALL_DONE: Old game server untouched; RTS health service is local only."
