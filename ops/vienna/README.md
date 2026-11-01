# Vienna RTS Infrastructure

Separate VPS: `shy-ivory` (Ubuntu 24.04; existing Reina Gateway, web, bot and old game runner live here).
Do not remove or restart any other Reina service, and do not modify other projects.

## 1. Identify runner and capacity (read-only)

On the VPS, after cloning this repository:

```bash
bash ops/vienna/audit-old-runner.sh
bash ops/vienna/preflight.sh
```

On Termux, list only repository-scoped GitHub runners:

```bash
gh api repos/Ncorror/reina-dead-signal/actions/runners --jq '.runners[] | [.id,.name,.status,.busy,(.labels|map(.name)|join(","))] | @tsv'
gh api repos/Ncorror/reina-dead-signal-rts/actions/runners --jq '.runners[] | [.id,.name,.status,.busy,(.labels|map(.name)|join(","))] | @tsv'
```

**Do not print registration/removal tokens.** Confirm the old runner is an idle game runner scoped to `reina-dead-signal`; never delete Reina core's `reina-ci-01`.

## 2. Controlled old game runner retirement

Only after checking runner identity, path, service ownership, and that it is idle:
- stop the exact old game's `actions.runner.*` service with that runner's `svc.sh stop`;
- uninstall that service with `svc.sh uninstall`;
- unregister old runner with `config.sh remove --token <one-time removal token>`, run as the old runner user;
- keep the old runner directory and build logs as a dated restore point (do not use `rm -rf`);
- if GitHub deregistration fails, do not destroy the runner files.

Old game's workflows with label `reina-game-ci` will no longer execute unless another runner with that label is registered.

## 3. Install an isolated RTS runner

```bash
sudo bash ops/vienna/install-runner.sh
```

Run on VPS. It creates Linux user `reina-rts-ci` without sudo/docker access, registers runner label `reina-rts-ci`, and places resource limits. Registration token obtained privately from Termux when requested:

```bash
gh api --method POST repos/Ncorror/reina-dead-signal-rts/actions/runners/registration-token --jq .token
```

Use the token on the VPS terminal only; do not share it in chat. The installer checks the Godot 4.7.2/Android toolchain and copies the existing export template to the new isolated user's home.

## 4. Start local-only RTS control stub

```bash
sudo bash ops/vienna/install-server.sh
curl -fsS http://127.0.0.1:18777/healthz
```

Service: `reina-rts-bootstrap.service`. Its HTTP API binds to `127.0.0.1:18777`, with `CPUQuota=35%` and `MemoryMax=384M`. It is **only a health stub**, not online gameplay. `/readyz` intentionally returns HTTP 503.

Check `sudo systemctl status reina-rts-bootstrap.service`; no UFW/firewall modifications should be necessary.

## 5. Build verification

New workflow: `.github/workflows/vienna-rts-android.yml`. It queues only on self-hosted label `reina-rts-ci`, builds an Android debug APK and uploads GitHub artifacts. Do not claim a successful APK before an Actions run and Android installation test.

```bash
gh run list -R Ncorror/reina-dead-signal-rts --workflow vienna-rts-android.yml --limit 5
```
