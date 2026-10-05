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
| Phase 00 | Identity `linuxbkup` + `LINUXBKUP_*`; `lib/core/platform/` (detect, paths, windows, fs_space); native dest `~/Backups/linuxbkup/`; smoke identity gate |
| UX | Portable backup/important lists (no host-shaped dirnames); filter stack for `du` + rsync; broader inspect capability probes |
| Phase 01 | `verify` accepts staging dirs or `*.tar.zst`; fixture + smoke |
| Phase 02 | Full-home shallow scan + classify; unexpected auto-include (`--yes`/non-TTY) |
| UX | `plan` + `plan --json`; drop `--print-plan`; `-v`/`-d`; soft-skip permissions; `fzf` guide + `systems/guides.md` |
| Phase 08 | Terminal progress + notify; flag tips; live stage size; lists large→small |
| UX | Default-skip `~/go`; `/tmp` off default size scan; `--max-size` (staged bytes) |
| Phase 03 | `--profile` / `--ask`>`--yes` / Bash+fzf ask UI / `--keep-stage` / `--stage-dir` |
| Phase 04 | `--reclaim` / `--reclaim-all` / `--mark-secret`; age encrypt secrets → `secrets.tar.age` |
| Phase 08.8–08.9 | Shared `lib/env/snapshot.sh`; backup prints capability snapshot before stage |
| UX | Short aliases (`-k`/`-S`/`-i`/`-e`/`-a`/`-p`/`-m`/`-j`/`-f`/…); help one flag per row |
| UX | Honor per-dir `.gitignore` (rsync); `--no-gitignore`; expanded regenerable strip |
| Phase 09.1–09.3/09.6 | Fail-fast secrets preflight before copy; byte-accurate estimates; stage-vs-est warn |
| Phase 05.1–05.2 | Space floor + estimate+10% gate (`lib/backup/preflight.sh`) |
| UX | Regenerables: Python/JS/wrangler/PM/IDE caches + `*.pyc`; smoke on `~/Bots` |
| Phase 05.3–05.4 | `schema.json` + `decisions.tsv`; verify soft-checks |
| Phase 10 | Standing PM/tools path research (mise installs strip; open forever until done) |
| UX | Strip `.tmp` / mise `installs|downloads`; keep mise state/config |
| UX | `-w/--workers` (default 4) parallel checksums/du/verify + zstd -T + ETA |
| UX | Lean op compat probes (`lib/tools/compat.sh`) after presence checks |
| UX | Central interrupt API (`lib/core/interrupt.sh`): Ctrl+C menu + `interrupt_resolve`; rsync rc=20; live stderr progress park/redraw; Ctrl+Z process-group suspend (`set -m`); `tput cnorm` on EXIT |
| UX | Interrupt harden: `without_monitor` for rsync/pack so tty ^C hits the menu; disarm/arm resume; whole-backup step coverage; SIGINT smoke proof |
| UX | Phase 09.4–09.5: preflight banner (profile/gitignore/max-size/secrets) + `ui_step` backup pipeline labels |
| UX | Regenerables: asdf/nvm/fnm/sdkman/rbenv install trees stripped (with mise/site-packages/.tmp) |
| UX | Phase 08.10: structured step events (`events.sh`) + `metadata/events.jsonl` in stage/archive |
| Phase 04.5 | `restore` decrypts `secrets.tar.age` (passphrase env/TTY) |
| Restore files | `restore` rsyncs `home/` + `secrets/` → `$HOME` and `config/etc` → `/etc`; `-f` for overwrite |
| Node reinstalls | `packages/reinstalls.json` on backup; restore peeks tsv, lists PMs with **resolved Linux paths** (interop shims ignored), top-10 list policy, regenerates `node_modules` (`-y` all / `--skip-reinstall` / TTY+fzf pick / `--ask`) |
| Phase 11 restore UX | Reinstall batch **interrupt parity** (Ctrl+C menu r/s/c/q; `q` = soft-quit, partial summary, no exit 130) + Ctrl+Z suspend + **picker v2** (exclude/include/PM/grep/fzf/undo) + failure-first re-run. Layout: `lib/backup/reinstall.sh` barrel → `lib/backup/reinstall/*.sh` (R1) |
| Phase 12 reinstall hardening | Prefix-tolerant archive extract; picker counts fix; pnpm allow-all-builds non-interactive; workspace-root-only reinstalls (nested members collapsed); interrupt boundary per project; progress `[i/N]` |

## Not shipped yet (redesign track)

| Item | Phase doc |
|------|-----------|
| Profiles / ask UI / stage flags (richer) | [03](../phases/03-profiles-ask-flags.md) |
| Reclaim + secrets/`age` | [04](../phases/04-reclaim-secrets.md) |
| Space preflight + `schema.json` | [05](../phases/05-space-schema.md) |
| `docs/*` rewrite | [06](../phases/06-docs-content.md) |
| VitePress → https://linuxbkup.pages.dev | [07](../phases/07-vitepress.md) |

Umbrella: [`../phases/redesign.md`](../phases/redesign.md). When a phase lands, add a row here and update the matching `systems/` doc in the same change.
