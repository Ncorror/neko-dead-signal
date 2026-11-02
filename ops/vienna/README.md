# Vienna RTS infrastructure — actual state, 2026-11-01

**Audit findings:** old GitHub repo `Ncorror/reina-dead-signal` was deleted, while its systemd runner `actions.runner.Ncorror-reina-dead-signal.reina-game-ci-01.service` and the separately running beta game server `reina-dead-signal.service` (UDP 27960) still exist on `shy-ivory`. Available RAM ~3.2 GiB and disk ~46 GiB during audit. No Docker services were found on this VPS.

## One-shot deployment from Termux

```bash
gh api "repos/Ncorror/reina-dead-signal-rts/contents/ops/vienna/deploy-one-shot-termux.sh?ref=infra/vienna-runner-server" --jq '.content' | base64 -d > "$HOME/deploy-reina-rts-vienna.sh"
bash "$HOME/deploy-reina-rts-vienna.sh"
```

GitHub authorization, SSH alias `reina`, and sudo on Vienna are needed; do not paste credentials in chat. The launcher downloads pinned deployment scripts from this private repo, obtains a short-lived registration token, sends the bundle to Vienna, and calls sudo with an interactive terminal.

It first installs the isolated `reina-rts-vienna-01` Actions runner and localhost-only RTS health service. Once both are healthy, it stops and disables **only** the old game runner, unless that runner still has a live Worker. It does **not** stop `reina-dead-signal.service`, change firewall ports, delete the old runner's files, or destroy beta APKs.

The old repository no longer exists, so ordinary GitHub runner deregistration via an old repository token cannot be performed. Its exact orphaned systemd service is disabled instead, with files preserved.

If the new installation fails, the old runner and game server are not deliberately stopped. Partial new files are preserved for troubleshooting. Do not force-delete them.

## Reality check

The `reina-rts-bootstrap.service` on `127.0.0.1:18777` is only a health stub. It responds `/healthz=200` and `/readyz=503`. It is **not** an authoritative online match server. Actual multiplayer simulation, synchronization, and persistent world come in later milestones.

The separate Android workflow is `.github/workflows/vienna-rts-android.yml`, with required runner label `reina-rts-ci`. No APK is considered valid until workflow results and device tests confirm it.
