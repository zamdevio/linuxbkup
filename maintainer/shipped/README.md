# Shipped

What has actually landed (not aspirational). Binary: **`linuxbkup`**. Env: **`LINUXBKUP_*`**.

| When | What |
|------|------|
| Phase 0 | Dispatcher, `lib/core`, stub commands, smoke |
| Phase 1 | Real `inspect` (`lib/env`, `lib/fs`, classify, dest preview) |
| UX | `lib/core/terminal/` style + OSC 8 links |
| UX | `lib/constraints/` + include/exclude + list policy |
| UX | `deps status \| install \| howto` + `guides/tools/*.guide` |
| UX | Styled `--help` / `help <cmd>` / `version` |
| Phase 2 | `backup`: staging → APT manuals → allowlisted home/config rsync → `tar.zst` + checksums |
| Phase 2 | `verify` on `*.tar.zst` (extract + `checksums.sha256`) |
| Phase 2 | INDEX write survives `pipefail`; staging kept on pack failure (`32b5b11`) |
| Phase 00 | Identity `linuxbkup` + `LINUXBKUP_*`; `lib/core/platform/`; native dest `~/Backups/linuxbkup/` |
| UX | Portable backup/important lists; filter stack for `du` + rsync |
| Phase 01 | `verify` accepts staging dirs or `*.tar.zst`; fixture + smoke |
| Phase 02 | Full-home shallow scan + classify; unexpected auto-include (`--yes`/non-TTY) |
| UX | `plan` + `plan --json`; `-v`/`-d`; soft-skip permissions; fzf guide |
| Phase 08 | Terminal progress + notify; flag tips; live stage size; lists large→small |
| UX | Default-skip `~/go`; `/tmp` off default size scan; `--max-size` |
| Phase 03 | `--profile` / `--ask`>`--yes` / Bash+fzf ask UI / `--keep-stage` / `--stage-dir` |
| Phase 04 | `--reclaim` / `--reclaim-all` / `--mark-secret`; age encrypt secrets |
| Phase 08.8–08.9 | Shared `lib/env/snapshot.sh`; backup prints capability snapshot before stage |
| UX | Short aliases; help one flag per row |
| UX | Honor per-dir `.gitignore`; `--no-gitignore`; expanded regenerable strip |
| Phase 09.1–09.3/09.6 | Fail-fast secrets preflight; byte-accurate estimates; stage-vs-est warn |
| Phase 05.1–05.2 | Space floor + estimate+10% gate |
| UX | Regenerables: Python/JS/wrangler/PM/IDE caches + `*.pyc` |
| Phase 05.3–05.4 | `schema.json` + `decisions.tsv`; verify soft-checks |
| Phase 10 | Standing PM/tools path research (open until done) |
| UX | Strip `.tmp` / mise installs|downloads; keep mise state/config |
| UX | `-w/--workers` parallel checksums/du/verify + zstd -T + ETA |
| UX | Lean op compat probes (`lib/tools/compat.sh`) after presence checks |
| UX | Central interrupt API; rsync rc=20; Ctrl+Z process-group suspend |
| UX | Interrupt harden: `without_monitor` for rsync/pack; SIGINT smoke proof |
| UX | Phase 09.4–09.5: preflight banner + `ui_step` backup pipeline labels |
| UX | Regenerables: asdf/nvm/fnm/sdkman/rbenv install trees stripped |
| UX | Phase 08.10: structured step events + `metadata/events.jsonl` |
| Phase 04.5 | `restore` decrypts `secrets.tar.age` |
| Restore files | `restore` rsyncs `home/` + `secrets/` → `$HOME`; `config/etc` → `/etc`; `-f` to overwrite |
| Node reinstalls | Manifest on backup; restore peeks tsv; Linux-native PMs; regenerates `node_modules` |
| Phase 11 restore UX | Reinstall batch interrupt parity (r/s/c/q soft-quit) + Ctrl+Z + picker v2 + failure-first re-run |
| Phase 12 reinstall hardening | Prefix-tolerant extract; pnpm allow-all-builds; workspace-root-only reinstalls; interrupt boundary per project |
| Phase 13 A | Shared stage/extract path helper (`compat_stage_path`); `backup -k` / `restore -k` / `verify` always print path; restore logs extract for the run |
| Phase 13 B | Ctrl+Z parity restore **and** backup — children STOP then process group; CONT re-asserts `set -m`; extract/rsync/reinstall covered |
| Phase 13 C | Compat layer `lib/core/compat/compat.sh` — tar GNU/BusyBox flags; sha256sum\|shasum\|openssl; rsync metadata mode on non-Linux mounts; numfmt fallback; pack/extract/verify/checksum/restore wired through wrappers |
| Phase 13 D | Atomic archives (tmp → verify → mv); `deps` one-command bootstrap (apk/apt/pacman/pkg/dnf/yum/brew); schema/tool version soft-gate; zero hardcoded `/usr/bin` tool paths in `lib/` |

## Not shipped yet

See [`../phases/roadmap.md`](../phases/roadmap.md).

**Next:** docs site 06–07; real iSH/Termux/Kali soak (`maintainer/temp/13-soak-checklist.md`); PM research 10 (standing); refactor R-SMOKE/R2+.

Shipped phase docs are folded/deleted; outcomes live above.

Umbrella: [`../phases/redesign.md`](../phases/redesign.md). When a phase lands, add a row here and update the matching `systems/` doc in the same change.
