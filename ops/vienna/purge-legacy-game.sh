#!/usr/bin/env bash
# REINA DEAD SIGNAL legacy-only purge. IRREVERSIBLE. No backup.
# Do not touch new RTS, Reina core, system Godot/SDK, or SSH login gameadmin.
set -Eeuo pipefail
umask 077
OLD_RUNNER="actions.runner.Ncorror-reina-dead-signal.reina-game-ci-01.service"
OLD_GAME="reina-dead-signal.service"
die() { printf 'ABORT: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" == 0 ]] || die "sudo/root required"
[[ "$(hostname -s)" == "shy-ivory" ]] || die "unexpected host"
command -v python3 >/dev/null || die "python3 required"

runner_exists=0; game_exists=0
systemctl cat "$OLD_RUNNER" >/dev/null 2>&1 && runner_exists=1
systemctl cat "$OLD_GAME" >/dev/null 2>&1 && game_exists=1
if (( runner_exists )); then
  [[ "$(systemctl show -P User "$OLD_RUNNER")" == reina-game-ci ]] ||
    die "old runner user does not match expected account"
fi
if (( game_exists )); then
  [[ "$(systemctl show -P User "$OLD_GAME")" == reina-game-server ]] ||
    die "old game server user does not match expected account"
fi

runner_dir=""
if (( runner_exists )); then
  runner_dir="$(python3 - "$OLD_RUNNER" <<'PY'
import json,re,subprocess,sys
from pathlib import Path
s=subprocess.check_output(['systemctl','show','-P','ExecStart',sys.argv[1]],text=True)
m=re.search(r'path=([^ ;]+)',s)
if not m: sys.exit('no runner executable')
exe=Path(m.group(1))
if exe.name != 'runsvc.sh': sys.exit('unexpected runner executable')
root=exe.parent
meta=root/'.runner'
if not meta.is_file(): sys.exit('missing old runner identity')
j=json.loads(meta.read_text(encoding='utf-8-sig'))
if j.get('agentName')!='reina-game-ci-01': sys.exit('runner name mismatch')
url=str(j.get('gitHubUrl','')).rstrip('/').lower()
if url!='https://github.com/ncorror/reina-dead-signal': sys.exit('runner repo mismatch')
print(root)
PY
)" || die "cannot safely identify old runner directory"
fi

runner_home="$(getent passwd reina-game-ci | cut -d: -f6 || true)"
game_home="$(getent passwd reina-game-server | cut -d: -f6 || true)"
game_workdir=""
if (( game_exists )); then
  game_workdir="$(systemctl show -P WorkingDirectory "$OLD_GAME" || true)"
fi
LIST="$(mktemp)"
trap 'rm -f "$LIST"' EXIT

RUNNER_DIR="$runner_dir" RUNNER_HOME="$runner_home" GAME_HOME="$game_home" \
GAME_WORKDIR="$game_workdir" python3 - "$LIST" <<'PY'
import os,sys
from pathlib import Path
out=Path(sys.argv[1])
fixed=[
 '/opt/reina-dead-signal','/opt/reina-game-ci','/opt/reina-game-server',
 '/srv/reina-dead-signal','/srv/reina-game-server',
 '/var/lib/reina-dead-signal','/var/lib/reina-game-ci','/var/lib/reina-game-server',
 '/var/log/reina-dead-signal','/var/log/reina-game-ci','/var/log/reina-game-server',
 '/var/cache/reina-dead-signal','/etc/reina-dead-signal',
 '/home/gameadmin/reina-dead-signal','/home/gameadmin/builds/reina-dead-signal',
 '/home/gameadmin/builds/reina-dead-signal-native25d',
 '/tmp/reina-outpost25d','/tmp/reina-dead-signal'
]
runner=os.environ.get('RUNNER_DIR','')
rhome=os.environ.get('RUNNER_HOME','')
ghome=os.environ.get('GAME_HOME','')
work=os.environ.get('GAME_WORKDIR','')
candidates=list(fixed)
if runner: candidates.append(runner)
for h,valid in ((rhome,{'reina-game-ci','reina-dead-signal'}),
                (ghome,{'reina-game-server','reina-dead-signal'})):
    if h and Path(h).name in valid:
        candidates.append(h)
    elif h not in ('','/nonexistent','/'):
        print('SKIP unverified account home:',h,file=sys.stderr)
if work and Path(work).name in {'reina-dead-signal','reina-game-server','server-game','dead-signal'}:
    candidates.append(work)
elif work and work != '/':
    print('SKIP unverified game working directory:',work,file=sys.stderr)

for base in ('/opt','/srv','/var/lib','/tmp','/home/gameadmin','/home/gameadmin/builds'):
    root=Path(base)
    if not root.is_dir(): continue
    try:
        for p in root.iterdir():
            if p.name in ('reina-dead-signal','reina-game-server','reina-game-ci',
                          'reina-dead-signal-outpost','reina-outpost25d'):
                candidates.append(str(p))
            if base in ('/tmp','/home/gameadmin/builds') and (
                p.name.startswith('REINA_DEAD_SIGNAL-') or
                p.name.startswith('REINA_OUTPOST_')
            ) and p.name.endswith(('.apk','.apk.sha256','.zip')):
                candidates.append(str(p))
    except PermissionError: pass

protected={'/','/opt','/srv','/home','/home/gameadmin','/home/reinaadmin',
 '/opt/reina','/opt/reina-rts','/opt/android-sdk','/etc','/var',
 '/var/lib','/var/log','/tmp','/var/lib/reina-rts-ci','/var/lib/reina-rts-svc'}
prefixes=('/opt/reina-dead-signal','/opt/reina-game-',
 '/srv/reina-dead-signal','/srv/reina-game-server',
 '/var/lib/reina-dead-signal','/var/lib/reina-game-',
 '/var/log/reina-dead-signal','/var/log/reina-game-',
 '/var/cache/reina-dead-signal','/etc/reina-dead-signal',
 '/home/gameadmin/reina-dead-signal','/home/gameadmin/builds/reina-dead-signal',
 '/tmp/reina-outpost25d','/tmp/reina-dead-signal',
 '/home/reina-game-ci','/home/reina-game-server')
targets=[]
for name in sorted(set(candidates),key=lambda s:(s.count('/'),s)):
    p=Path(name)
    if not p.is_absolute() or str(p) in protected or len(p.parts)<3:
        sys.exit('ABORT protected or broad candidate '+str(p))
    if any(x in p.parts for x in ('reina-rts','reinaadmin','android-sdk','godot','postgres','docker')):
        sys.exit('ABORT shared or RTS candidate '+str(p))
    if any(parent.is_symlink() for parent in p.parents if parent!=Path('/')):
        sys.exit('ABORT symlink parent '+str(p))
    if not (p.exists() or p.is_symlink()): continue
    if p.is_mount(): sys.exit('ABORT mountpoint '+str(p))
    if any(p==t or t in p.parents for t in targets): continue
    identity=(runner and p==Path(runner))
    dedicated=(p in (Path(rhome),Path(ghome)) and p.name in
               ('reina-game-ci','reina-game-server','reina-dead-signal'))
    gamewd=(work and p==Path(work) and
            p.name in ('reina-dead-signal','reina-game-server','server-game','dead-signal'))
    named=str(p).startswith(prefixes)
    artifact=(p.parent in (Path('/tmp'),Path('/home/gameadmin/builds'))
              and p.name.startswith(('REINA_DEAD_SIGNAL-','REINA_OUTPOST_'))
              and p.name.endswith(('.apk','.apk.sha256','.zip')))
    if not any((identity,dedicated,gamewd,named,artifact)):
        sys.exit('ABORT unexpected candidate '+str(p))
    targets.append(p)
with out.open('wb') as f:
    for p in targets: f.write(os.fsencode(str(p))+b'\0')
print('DELETE_CANDIDATES=',len(targets))
for p in targets: print('WILL_REMOVE:',p)
PY

echo "STOPPING_ONLY_LEGACY_GAME_SERVICES..."
if (( game_exists )); then
  systemctl stop "$OLD_GAME"
  systemctl disable "$OLD_GAME" >/dev/null
fi
if (( runner_exists )); then
  systemctl stop "$OLD_RUNNER"
  systemctl disable "$OLD_RUNNER" >/dev/null
fi

# Remove exact unit files, never shared systemd directories.
for unit in "$OLD_GAME" "$OLD_RUNNER"; do
  if [[ -f "/etc/systemd/system/$unit" && ! -L "/etc/systemd/system/$unit" ]]; then
    rm -f -- "/etc/systemd/system/$unit"
  fi
  if [[ -d "/etc/systemd/system/$unit.d" ]]; then
    rm -rf -- "/etc/systemd/system/$unit.d"
  fi
done
systemctl daemon-reload
systemctl reset-failed "$OLD_GAME" "$OLD_RUNNER" >/dev/null 2>&1 || true

# Remove only previously verified files and dirs, never follow symlink trees.
while IFS= read -r -d '' p; do
  [[ -e "$p" || -L "$p" ]] || continue
  rm -rf --one-file-system -- "$p"
  printf 'REMOVED: %s\n' "$p"
done < "$LIST"

# Only dedicated old game accounts, not SSH login gameadmin.
for acc in reina-game-ci reina-game-server; do
  if getent passwd "$acc" >/dev/null; then
    if pgrep -u "$acc" >/dev/null 2>&1; then
      echo "ACCOUNT_LEFT_WITH_RUNNING_PROCESS=$acc"
    else
      userdel "$acc" || echo "ACCOUNT_REMOVAL_FAILED=$acc"
    fi
  fi
done

if command -v ufw >/dev/null &&
   ufw status | grep -Eq '27960/udp[[:space:]]+ALLOW'; then
  ufw --force delete allow 27960/udp ||
    echo "WARNING: manual firewall inspection required for 27960/udp"
fi

echo "===== FINAL SERVICE CHECK ====="
echo "OLD_GAME=$(systemctl is-active "$OLD_GAME" 2>/dev/null || true)"
echo "OLD_RUNNER=$(systemctl is-active "$OLD_RUNNER" 2>/dev/null || true)"
ss -H -lun '( sport = :27960 )' || true
ufw status 2>/dev/null | grep -E '27960|Status:' || true
echo "PRESERVED: new RTS, gameadmin SSH, Reina Core, Godot/Android SDK"
echo "LEGACY_PURGE_COMPLETE"
