#!/usr/bin/env bash
# Install isolated loopback-only RTS health stub, with no impact on Reina services.
set -Eeuo pipefail
umask 027
[[ $(id -u) -eq 0 ]] || { echo "Run using sudo bash install-server.sh"; exit 1; }
cd "$(dirname "$0")"
SOURCE="$(realpath ../../server/control_api.py 2>/dev/null || true)"
if [[ ! -f "$SOURCE" ]]; then
  SOURCE="$(realpath ./control_api.py 2>/dev/null || true)"
fi
[[ -f "$SOURCE" ]] || { echo "control_api.py is missing; copy it next to this script"; exit 1; }

UNIT=/etc/systemd/system/reina-rts-bootstrap.service
if [[ -e "$UNIT" ]]; then
  echo "ABORT: RTS systemd service already exists; inspect it before changing."
  exit 1
fi
if ss -H -ltn '( sport = :18777 )' | grep -q .; then
  echo "ABORT: TCP 18777 is in use. Nothing changed."
  exit 1
fi
AVAILABLE_KIB=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)
FREE_KIB=$(df -Pk /opt | awk 'NR==2 {print $4}')
if (( AVAILABLE_KIB < 524288 || FREE_KIB < 1048576 )); then
  echo "ABORT: insufficient free memory or disk. Nothing changed."
  exit 1
fi
getent passwd reina-rts-svc >/dev/null || useradd --system --home-dir /var/lib/reina-rts-svc --create-home --shell /usr/sbin/nologin reina-rts-svc
install -d -m 0755 -o root -g root /opt/reina-rts /opt/reina-rts/server
install -m 0644 -o root -g root "$SOURCE" /opt/reina-rts/server/control_api.py
cat >"$UNIT" <<'EOF'
[Unit]
Description=REINA DEAD SIGNAL RTS bootstrap health service (not live gameplay)
After=network.target

[Service]
Type=simple
User=reina-rts-svc
Group=reina-rts-svc
WorkingDirectory=/opt/reina-rts/server
Environment=REINA_RTS_PORT=18777
ExecStart=/usr/bin/python3 -B -u /opt/reina-rts/server/control_api.py
Restart=on-failure
RestartSec=5
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ProtectKernelTunables=yes
ProtectControlGroups=yes
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
CapabilityBoundingSet=
LockPersonality=yes
MemoryMax=384M
CPUQuota=35%
TasksMax=48

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now reina-rts-bootstrap.service
systemctl --no-pager --full status reina-rts-bootstrap.service || true
curl --fail --silent --show-error --max-time 4 http://127.0.0.1:18777/healthz
printf '\nRTS_BOOTSTRAP_RUNNING_LOCAL_ONLY\n'
echo "Do not expose this health stub to the Internet. Real multiplayer server not deployed."
