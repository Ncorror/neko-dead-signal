#!/usr/bin/env bash
# Safe read-only discovery. Run on shy-ivory as reinaadmin.
set -Eeuo pipefail
echo '===== HOST / RESOURCES ====='
hostname
free -h
df -h / /opt
echo '===== RUNNER SYSTEMD SERVICES ====='
systemctl --no-pager --all --type=service 'actions.runner.*' || true
echo '===== RUNNER SERVICE DEFINITIONS (READ ONLY) ====='
systemctl list-unit-files --no-pager --no-legend 'actions.runner.*' || true
echo '===== RUNNER REGISTRATION FILE LOCATIONS (ONLY PATHS, NEVER TOKENS) ====='
for base in /home/gameadmin /home/reinaadmin /opt/reina /opt/reina-rts; do
  if [[ -d "$base" ]]; then
    sudo find "$base" -maxdepth 6 -type f -name .runner -print 2>/dev/null || true
  fi
done
echo '===== RUNNER PROCESS OWNERS ====='
ps -eo user,pid,pcpu,pmem,args --sort=user | grep -E '[R]unner.Listener|[R]unner.Worker|[r]unsvc.sh' || true
echo '===== EXISTING REINA SERVICES ====='
systemctl --no-pager --type=service --state=running | grep -Ei 'reina|actions.runner' || true
echo '===== PORT 18777 ====='
ss -ltn '( sport = :18777 )' || true
echo '===== TOOLCHAIN ====='
command -v godot || true
godot --version 2>/dev/null || true
test -d /opt/android-sdk && echo 'ANDROID_SDK_PRESENT' || true
echo 'AUDIT_COMPLETE_NO_CHANGES'
