#!/usr/bin/env bash
# REINA Vienna full read-only audit. Never print .credentials/.env/tokens.
set -uo pipefail
export LC_ALL=C
section() { printf '\n===== %s =====\n' "$1"; }
run() { "$@" 2>&1 || true; }

section "HOST AND OS"
hostname -f 2>/dev/null || hostname
date -Is
uname -srm
if [ -r /etc/os-release ]; then grep -E '^(PRETTY_NAME|VERSION_ID)=' /etc/os-release; fi
uptime

section "CPU MEMORY AND DISK"
nproc
free -h
df -hT / /opt /home 2>/dev/null | awk '!seen[$1,$7]++' || true
printf 'Memory pressure: '
cat /proc/pressure/memory 2>/dev/null | head -n 2 || true
printf 'CPU pressure: '
cat /proc/pressure/cpu 2>/dev/null | head -n 2 || true
section "LARGEST PROCESSES (NAMES ONLY; NO COMMAND ARGUMENTS)"
ps -eo user:18,pid,%cpu,%mem,rss,etime,comm --sort=-rss 2>/dev/null | head -n 23 || true

section "RUNNING APPLICATION SERVICES"
systemctl list-units --type=service --state=running --no-pager --no-legend 2>/dev/null |
  grep -Ei 'reina|runner|docker|containerd|caddy|nginx|postgres|redis|fail2ban|ssh' || true

section "ALL ACTIONS RUNNER UNITS"
systemctl list-units --type=service --all --no-pager --no-legend 'actions.runner.*' 2>/dev/null || true
systemctl list-unit-files --no-pager --no-legend 'actions.runner.*' 2>/dev/null || true
section "RUNNER PROCESSES (NAMES ONLY)"
ps -eo user:18,pid,etime,comm | grep -Ei '(Runner.Listener|Runner.Worker|runsvc|RunnerService)' || true

section "RUNNER REGISTRATION LOCATIONS (SAFE METADATA ONLY)"
python3 - <<'PY'
import json, os
from pathlib import Path
roots = [Path('/home/gameadmin'), Path('/home/reinaadmin'), Path('/opt/reina'), Path('/opt/reina-rts')]
seen = set()
for root in roots:
    if not root.exists(): continue
    for directory, dirs, files in os.walk(root):
        depth = len(Path(directory).parts) - len(root.parts)
        if depth >= 7: dirs[:] = []
        dirs[:] = [x for x in dirs if x not in ('.git','node_modules','.cache','_work','build','dist','venv','.venv')]
        if '.runner' not in files: continue
        file = Path(directory) / '.runner'
        if str(file) in seen: continue
        seen.add(str(file))
        try:
            info = json.loads(file.read_text())
            name = info.get('agentName', 'unknown')
            url = info.get('gitHubUrl', 'unknown')
            service = (Path(directory) / '.service')
            unit = service.read_text().strip() if service.is_file() else 'not-installed'
            print(f'{directory} | agent={name} | repo={url} | systemd={unit}')
        except (OSError, ValueError) as e:
            print(f'{directory} | metadata unavailable: {type(e).__name__}')
PY

section "CONTAINERS (NAME IMAGE STATUS PORTS ONLY)"
if command -v docker >/dev/null 2>&1; then
  docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' 2>&1 || true
else
  echo "docker not installed/in PATH"
fi

section "LISTENING TCP/UDP PORTS"
ss -H -lntup 2>/dev/null | awk '{print $1,$5,$6}' | head -n 90 || true

section "GODOT AND ANDROID TOOLCHAIN"
if command -v godot >/dev/null 2>&1; then godot --version 2>&1; else echo 'godot NOT in PATH'; fi
for p in /opt/android-sdk /opt/android-sdk/platforms/android-36 /opt/android-sdk/build-tools/36.1.0/apksigner /usr/lib/jvm/java-17-openjdk-amd64; do
 if [ -e "$p" ]; then echo "PRESENT $p"; else echo "MISSING $p"; fi
done
for p in /home/gameadmin/.local/share/godot/export_templates/4.7.2.stable/android_debug.apk /home/reinaadmin/.local/share/godot/export_templates/4.7.2.stable/android_debug.apk; do
 if [ -s "$p" ]; then echo "PRESENT template at $p"; fi
done

section "DISK USAGE OF MAIN PROJECT DIRECTORIES"
for p in /opt/reina /opt/reina-rts /opt/android-sdk /home/gameadmin/builds; do
 [ -d "$p" ] && du -sh "$p" 2>/dev/null || true
done

section "RTS BOOTSTRAP HEALTH (LOCAL ONLY)"
if command -v curl >/dev/null 2>&1; then
 curl -sS --max-time 3 -o /dev/null -w '127.0.0.1:18777/healthz HTTP %{http_code}\n' http://127.0.0.1:18777/healthz 2>/dev/null || true
fi

section "FIREWALL AND BRUTE FORCE PROTECTION"
if command -v ufw >/dev/null 2>&1; then ufw status 2>&1 || true; fi
systemctl is-active fail2ban 2>/dev/null || true
systemctl is-active ssh 2>/dev/null || true

section "AUDIT FINISHED - READ ONLY; NO SERVICES CHANGED"
