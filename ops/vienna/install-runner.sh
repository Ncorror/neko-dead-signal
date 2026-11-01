#!/usr/bin/env bash
# Standalone GitHub Actions runner scoped only to REINA RTS (no Docker/sudo).
set -Eeuo pipefail
umask 077
[[ $(id -u) -eq 0 ]] || { echo "Run using sudo bash install-runner.sh"; exit 1; }
REPO_URL="https://github.com/Ncorror/reina-dead-signal-rts"
DIR="/opt/reina-rts/runner"
USER="reina-rts-ci"
NAME="reina-rts-vienna-01"
VERSION="2.338.2"
SHA256="baebf204307bac6193480852732f0aba2ae97b6c5597c244f4d5558390147c40"
ARCHIVE="actions-runner-linux-x64-${VERSION}.tar.gz"
URL="https://github.com/actions/runner/releases/download/v${VERSION}/${ARCHIVE}"

[[ $(uname -m) == x86_64 ]] || { echo "Only x86_64 is supported here"; exit 1; }
[[ ! -e "$DIR/.runner" ]] || { echo "Already registered at $DIR; no changes"; exit 1; }
if systemctl --no-pager --type=service --state=running 'actions.runner.*' | grep -q 'Ncorror-reina-dead-signal.*reina-game-ci'; then
  echo "WARNING: old game runner appears active; audit it before switching to RTS."
fi
if [[ -d "$DIR" && -n $(ls -A "$DIR" 2>/dev/null) ]]; then
  echo "ABORT: runner directory not empty. Inspect manually."
  exit 1
fi
MEM_KIB=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)
DISK_KIB=$(df -Pk /opt | awk 'NR==2 {print $4}')
(( MEM_KIB >= 786432 && DISK_KIB >= 3145728 )) || { echo "ABORT: low memory or disk"; exit 1; }

command -v godot >/dev/null || { echo "Missing godot in PATH. Check existing game toolchain"; exit 1; }
GVER="$(godot --version)"
[[ "$GVER" == 4.7.2* ]] || { echo "Expected Godot 4.7.2; found $GVER"; exit 1; }
test -x /opt/android-sdk/build-tools/36.1.0/apksigner || { echo "Missing Android SDK apksigner"; exit 1; }
test -d /opt/android-sdk/platforms/android-36 || { echo "Missing Android SDK platform android-36"; exit 1; }

TEMPLATE_SOURCE=""
for candidate in /home/gameadmin/.local/share/godot/export_templates/4.7.2.stable/android_debug.apk /home/reinaadmin/.local/share/godot/export_templates/4.7.2.stable/android_debug.apk; do
  if [[ -s "$candidate" ]]; then TEMPLATE_SOURCE="$candidate"; break; fi
done
[[ -n "$TEMPLATE_SOURCE" ]] || { echo "No Godot 4.7.2 export template found; stop, install templates manually"; exit 1; }

getent passwd "$USER" >/dev/null || useradd --system --create-home --home-dir /var/lib/reina-rts-ci --shell /bin/bash "$USER"
if id -nG "$USER" | grep -Eq '(^| )(sudo|docker)( |$)'; then
  echo "ABORT: runner account has sudo/docker privileges!"
  exit 1
fi
install -d -m 0750 -o "$USER" -g "$USER" "$DIR"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl --fail --location --retry 3 --silent --show-error "$URL" --output "$tmp/$ARCHIVE"
echo "$SHA256  $tmp/$ARCHIVE" | sha256sum --check -
tar -xzf "$tmp/$ARCHIVE" -C "$DIR"
chown -R "$USER:$USER" "$DIR"
TEMPLATE_TARGET="/var/lib/reina-rts-ci/.local/share/godot/export_templates/4.7.2.stable"
install -d -m 0750 -o "$USER" -g "$USER" "$TEMPLATE_TARGET"
install -m 0644 -o "$USER" -g "$USER" "$TEMPLATE_SOURCE" "$TEMPLATE_TARGET/android_debug.apk"

echo "Get the one-hour token in Termux (separate session):"
echo "gh api --method POST repos/Ncorror/reina-dead-signal-rts/actions/runners/registration-token --jq .token"
echo "Never paste the token into ChatGPT."
if [[ -n "${REINA_RTS_REGISTRATION_TOKEN_FILE:-}" ]]; then
  [[ -r "$REINA_RTS_REGISTRATION_TOKEN_FILE" ]] || { echo "Registration-token file unreadable"; exit 1; }
  TOKEN="$(cat "$REINA_RTS_REGISTRATION_TOKEN_FILE")"
else
  read -r -s -p "Paste one-time registration token: " TOKEN
  echo
fi
[[ -n "$TOKEN" ]] || { echo "Empty registration token"; exit 1; }
# Standard GitHub registration. One-time token remains in memory only.
cd "$DIR"
runuser -u "$USER" -- ./config.sh --unattended --url "$REPO_URL" --token "$TOKEN" --name "$NAME" --labels reina-rts-ci --work _work
unset TOKEN
./svc.sh install "$USER"
# Add resource limits to this runner's systemd service without touching other runners.
SERVICE_NAME="$(cat .service)"
mkdir -p "/etc/systemd/system/${SERVICE_NAME}.d"
cat >"/etc/systemd/system/${SERVICE_NAME}.d/limits.conf" <<'EOF'
[Service]
MemoryHigh=1300M
MemoryMax=2100M
CPUQuota=125%
Nice=10
TasksMax=256
EOF
systemctl daemon-reload
./svc.sh start
./svc.sh status
echo "RTS_RUNNER_SERVICE=$SERVICE_NAME"
echo "RTS_RUNNER_REGISTERED_CHECK_GITHUB_ACTIONS"
