# Schema & archive layout

What a linuxbkup archive contains, how it is sealed, and how verify interprets it.

## Archive shape

A backup archive is a **single** `*.tar.zst` — zstd-compressed tar of a staging tree:

```text
<archive>.tar.zst
  metadata/
    backup.env          # version, created, user, home, hostname, profile
    distro.env          # pretty/id/version/arch/wsl fields
    schema.json         # restore contract + tool/schema versions
    decisions.tsv       # path, class, action, size, reason, decision
    events.jsonl        # step telemetry (excluded from hard checksums)
  packages/
    reinstalls.json     # Node workspace roots / lockfile dirs
    reinstalls.tsv
    apt.manual          # APT package list (manifest only)
  config/               # selected config trees (e.g. config/etc snippets)
  home/                 # classified home copy (regenerables stripped)
  secrets.tar.age       # optional age-encrypted secrets subset
  secrets.agekey.enc    # optional wrapped key material (when encrypting)
  checksums.sha256      # sha256 of payload files (relative paths)
  INDEX                 # human-oriented sample listing (first ~500 paths)
```

Staging directories on disk use the same layout (no `.tar.zst` wrapper). Verify accepts **either** an archive or a staging root.

## Atomic commit

Pack never writes the final name directly:

1. Write `<dest>.tar.zst.tmp.<pid>`
2. `zstd -t` + `tar -tf` integrity checks
3. `mv` to `<dest>` (final name)

A crash mid-pack leaves a `.tmp` you can delete — not a half-written production archive.

## Checksums

- File: `checksums.sha256` (sha256sum format: `<hash>  <relative-path>`)
- Computed over staged payload files
- `metadata/events.jsonl` is **excluded** from the hard path (telemetry may drift; payload must not)
- Verify compares payload entries and hard-fails on mismatch
- Provider may be `sha256sum`, `shasum -a 256`, or `openssl dgst`

## `schema.json`

Written at backup time. Fields include:

| Field | Meaning |
|-------|---------|
| `schema` | Identifier, e.g. `linuxbkup.schema/v1` |
| `schema_version` | Integer contract version |
| `tool_version` | CLI version that produced the archive |
| `created`, `profile`, `user`, `home` | Provenance |
| `host` | hostname / distro / arch / wsl |
| `features` | secrets_mode, gitignore, apt_manual, etc. |

**Verify / restore gate:** unknown `schema` ids or a newer `schema_version` than the running tool → **soft warning**, best-effort restore. Older archives without `schema.json` also soft-warn. Hard refusal only for true incompatibilities the tool cannot interpret at all.

## Stage / extract paths

| Command | Basename |
|---------|----------|
| `backup` | `linuxbkup.<pid>.<rand>` |
| `backup -k` | same — path printed |
| `restore` (archive) | `linuxbkup-restore-<ts>.<pid>` — path printed |
| `verify` (archive) | `linuxbkup-verify-<ts>.<pid>` — path printed |

Parent: `-S/--stage-dir` if set, else `${TMPDIR:-/tmp}`.

## Restore contract (practical)

1. Extract (or open a staging dir)
2. Soft-check schema / manifests
3. Decrypt `secrets.tar.age` when present
4. Rsync `home/` + `secrets/` → target home; `config/etc` → `/etc` when writable
5. Node reinstalls from `packages/reinstalls.json` (optional / skippable)

Next: [Secrets](./secrets.md) · [CLI](./cli.md)
