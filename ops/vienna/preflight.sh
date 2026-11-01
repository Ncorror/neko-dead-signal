#!/usr/bin/env bash
# Strictly read-only inspection of the Vienna VPS.
set -Eeuo pipefail
echo "== HOST =="
hostname
uname -srm
echo "== CPU & MEMORY =="
nproc
free -h
echo "== DISK =="
df -h / /opt /home
echo "== EXISTING SERVICES (read only) =="
systemctl --no-pager --plain --type=service --state=running | grep -E 'reina|actions.runner' || true
echo "== PORT 18777 =="
ss -H -ltn '( sport = :18777 )' || true
echo "== ANDROID TOOLCHAIN =="
command -v godot || true
godot --version 2>/dev/null || true
test -d /opt/android-sdk && echo "ANDROID_SDK_PRESENT" || echo "ANDROID_SDK_MISSING"
test -f /home/gameadmin/.local/share/godot/export_templates/4.7.2.stable/android_debug.apk && echo "GAMEADMIN_EXPORT_TEMPLATES_PRESENT" || true
echo "== SECURITY =="
id gameadmin 2>/dev/null || true
systemctl is-active reina-dev-runner.service || true
echo "PREFLIGHT_READ_ONLY_COMPLETE"
