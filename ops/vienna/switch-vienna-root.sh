#!/usr/bin/env bash
# Switch orphaned old GAME runner -> separate REINA RTS CI runner on Vienna.
# Does not touch the still-running old game server or its data.
set -Eeuo pipefail
umask 077
[[ $(id -u) -eq 0 ]] || { echo "Run via sudo"; exit 1; }
STAGE="${1:?Usage: switch-vienna-root.sh /tmp/reina-rts-switch-XXXX}"
[[ "$STAGE" == /tmp/reina-rts-switch-* && -d "$STAGE" ]] || { echo "Invalid staging path"; exit 1; }
[[ "$(hostname -s)" == "shy-ivory" ]] || { echo "Unexpected host; abort"; exit 1; }
[[ "$(uname -m)" == "x86_64" ]] || { echo "Unexpected architecture; abort"; exit 1; }
OLD_SERVICE="actions.runner.Ncorror-reina-dead-signal.reina-game-ci-01.service"
NEW_DIR="/opt/reina-rts/runner"
SERVER_SERVICE="reina-rts-bootstrap.service"
TOKEN_FILE="$STAGE/registration.token"
cleanup() { rm -rf -- "$STAGE"; }
trap cleanup EXIT

[[ -s "$TOKEN_FILE" ]] || { echo "Missing private registration token"; exit 1; }
[[ -s "$STAGE/ops/vienna/install-runner.sh" ]]
[[ -s "$STAGE/ops/vienna/install-server.sh" ]]
[[ -s "$STAGE/server/control_api.py" ]]
[[ -s "$STAGE/server/test_control_api.py" ]]
python3 -m py_compile "$STAGE/server/control_api.py" "$STAGE/server/test_control_api.py"
PYTHONPATH="$STAGE/server" python3 -m unittest discover -s "$STAGE/server" -p 'test_*.py' -v

# Legacy game has been purged. Do not touch Reina Core or shared toolchains.
echo "LEGACY_GAME_SERVER: $(systemctl is-active reina-dead-signal.service 2>/dev/null || true) (already purged)"
echo "LEGACY_GAME_RUNNER: $(systemctl is-active "$OLD_SERVICE" 2>/dev/null || true) (already purged)"
echo "CAPACITY: $(free -h | awk '/^Mem:/ {print "RAM available " $7}')"
echo "FREE_DISK: $(df -h / | awk 'NR==2 {print $4}')"

# Fail closed on unexpected services / partially staged installations.
if [[ -f "/etc/systemd/system/$SERVER_SERVICE" ]] && ! systemctl is-active --quiet "$SERVER_SERVICE"; then
  echo "Existing RTS server unit not running; inspect before any changes."
  exit 1
fi
if [[ -e "$NEW_DIR/.runner" ]]; then
  echo "RTS runner already registered: skipping runner installation."
else
  echo "INSTALLING_NEW_RTS_RUNNER..."
  REINA_RTS_REGISTRATION_TOKEN_FILE="$TOKEN_FILE" bash "$STAGE/ops/vienna/install-runner.sh"
fi
[[ -f "$NEW_DIR/.service" ]] || { echo "New RTS runner registration not complete"; exit 1; }
NEW_SERVICE="$(cat "$NEW_DIR/.service")"
[[ "$NEW_SERVICE" == actions.runner.Ncorror-reina-dead-signal-rts.*.service ]] || {
  echo "Invalid RTS service name; abort"; exit 1;
}
systemctl is-active --quiet "$NEW_SERVICE" || { echo "New RTS runner is not active"; exit 1; }
echo "RTS_RUNNER_ACTIVE=$NEW_SERVICE"

if [[ ! -f "/etc/systemd/system/$SERVER_SERVICE" ]]; then
  echo "INSTALLING_RTS_LOCAL_CONTROL_SERVER..."
  bash "$STAGE/ops/vienna/install-server.sh"
fi
systemctl is-active --quiet "$SERVER_SERVICE"
HEALTH_OK=0
for attempt in $(seq 1 25); do
  if curl -fsS --max-time 3 http://127.0.0.1:18777/healthz 2>/dev/null |
      python3 -c 'import json,sys; x=json.load(sys.stdin); assert x["healthy"] and x["match_server"] is False and x["online_gameplay"] is False' 2>/dev/null; then
    HEALTH_OK=1
    break
  fi
  sleep 1
done
if (( ! HEALTH_OK )); then
  systemctl --no-pager --full status "$SERVER_SERVICE" || true
  journalctl -u "$SERVER_SERVICE" -n 70 --no-pager || true
  echo "RTS_CONTROL_SERVER_HEALTH_FAILED"
  exit 1
fi
echo "RTS_CONTROL_SERVER_HEALTH_PASS (local bootstrap, NOT multiplayer)"

# Repo already deleted: GitHub cannot issue old repo removal token.
# Stop+disable ONLY the exact old runner unit. Do not touch files or game server.
if systemctl cat "$OLD_SERVICE" >/dev/null 2>&1; then
  if pgrep -u reina-game-ci -f 'Runner.Worker' >/dev/null 2>&1; then
    echo "OLD_RUNNER_BUSY: left intact to avoid killing an active build; RTS still ready"
  else
    systemctl stop "$OLD_SERVICE"
    systemctl disable "$OLD_SERVICE" >/dev/null
    echo "OLD_RUNNER_STOPPED_DISABLED=$OLD_SERVICE"
  fi
else
  echo "OLD_RUNNER_UNIT_ABSENT: nothing to stop"
fi
echo "OLD_GAME_SERVER_STATUS=$(systemctl is-active reina-dead-signal.service 2>/dev/null || true)"
echo "RTS_VIENNA_SWITCH_COMPLETE"
