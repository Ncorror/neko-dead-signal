#!/usr/bin/env bash
# One-shot sudo-side switch. Receives private, staged files; never echoes tokens.
set -Eeuo pipefail
umask 077
[[ $(id -u) -eq 0 ]] || { echo "ERROR: sudo/root required"; exit 1; }
STAGE="${1:?staging directory required}"
[[ "$STAGE" == /tmp/reina-rts-switch-* ]] || { echo "ERROR: staging directory must be dedicated"; exit 1; }
[[ -s "$STAGE/registration.token" ]] || { echo "ERROR: missing ephemeral registration token"; exit 1; }
trap 'rm -f "$STAGE/registration.token" "$STAGE/package.tgz"' EXIT

HOST="$(hostname -s)"
[[ "$HOST" == "shy-ivory" ]] || { echo "ERROR: unexpected host $HOST"; exit 1; }
[[ $(uname -m) == x86_64 ]] || { echo "ERROR: architecture unsupported"; exit 1; }

# Resolve exactly the old REINA GAME runner, not Reina core / other CI.
OLD_DIR="$(python3 - <<'PY'
from pathlib import Path
import json
found = []
for base in ('/home/gameadmin', '/home/reinaadmin', '/opt/reina', '/opt'):
    root = Path(base)
    if not root.exists():
        continue
    for f in root.glob('**/.runner'):
        if len(f.parts) > len(root.parts) + 7:
            continue
        try:
            j = json.loads(f.read_text())
        except (OSError, ValueError):
            continue
        if j.get('agentName') == 'reina-game-ci-01':
            found.append(str(f.parent))
found = sorted(set(found))
if len(found) != 1:
    raise SystemExit('ERROR: expected exactly one old game runner, found ' + str(len(found)) + ' — refusing to change services')
print(found[0])
PY
)"
OLD_SERVICE_FILE="$OLD_DIR/.service"
[[ -f "$OLD_SERVICE_FILE" ]] || { echo "ERROR: old game runner has no .service"; exit 1; }
OLD_SERVICE="$(cat "$OLD_SERVICE_FILE")"
[[ "$OLD_SERVICE" =~ ^actions\.runner\.[a-zA-Z0-9_.-]+\.service$ ]] || { echo "ERROR: invalid service name"; exit 1; }
[[ "$OLD_SERVICE" == *reina-dead-signal* && "$OLD_SERVICE" == *reina-game-ci-01* ]] || {
  echo "ERROR: runner service does not match old GAME repository"; exit 1;
}
systemctl cat "$OLD_SERVICE" >/dev/null || { echo "ERROR: game unit missing"; exit 1; }
if [[ -e /opt/reina-rts/runner/.runner ]]; then
  echo "ERROR: new RTS runner already registered. Refusing duplicate."; exit 1
fi

# Before changing anything, ensure tools and services are present.
command -v curl >/dev/null
command -v python3 >/dev/null
test -s "$STAGE/ops/vienna/install-runner.sh"
test -s "$STAGE/ops/vienna/install-server.sh"
test -s "$STAGE/server/control_api.py"
if ss -H -ltn '( sport = :18777 )' | grep -q .; then
    echo "ERROR: RTS port already allocated; refusing migration"; exit 1
fi
echo "OLD_GAME_RUNNER=$OLD_SERVICE"
echo "OLD_RUNNER_DIRECTORY_PRESERVED=$OLD_DIR"
echo "Stopping only the old game-runner systemd unit..."
systemctl stop "$OLD_SERVICE"
systemctl disable "$OLD_SERVICE"
SUCCESS=0
rollback() {
  if (( SUCCESS == 0 )); then
    echo "NEW RUNNER DEPLOY FAILED. Restoring old game runner service..."
    systemctl enable "$OLD_SERVICE" || true
    systemctl start "$OLD_SERVICE" || true
  fi
}
trap rollback EXIT
echo "Registering isolated new RTS runner..."
REINA_RTS_REGISTRATION_TOKEN_FILE="$STAGE/registration.token" bash "$STAGE/ops/vienna/install-runner.sh"
echo "Starting local-only RTS bootstrap server..."
bash "$STAGE/ops/vienna/install-server.sh"
systemctl is-active --quiet reina-rts-bootstrap.service
[[ "$(curl -fsS --max-time 3 http://127.0.0.1:18777/healthz | python3 -c 'import json,sys; print(json.load(sys.stdin)["match_server"])')" == "False" ]]
NEW_SERVICE="$(cat /opt/reina-rts/runner/.service)"
systemctl is-active --quiet "$NEW_SERVICE"
SUCCESS=1
trap - EXIT
echo "RTS_SERVICE_ACTIVE=reina-rts-bootstrap.service"
echo "RTS_RUNNER_SERVICE_ACTIVE=$NEW_SERVICE"
echo "OLD_GAME_SERVICE_STOPPED=$OLD_SERVICE"
echo "REINA_CORE_SERVICES_UNTOUCHED"
