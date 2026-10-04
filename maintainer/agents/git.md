# Git — linuxbkup

## 1. Never surprise the user

- **Do not commit** unless the user explicitly asks to commit.
- **Do not push** unless the user explicitly asks to push.
- **Do not** create tags, open PRs, or publish unless asked.

If unsure — **ask**.

## 2. Gates before commit

When the user asks to commit:

1. Inspect `git status` / `git diff` (staged + unstaged)
2. Exclude secrets, archives (`*.tar.zst`), and `maintainer/temp/`
3. Run `./tests/smoke.sh` and `bash -n` on touched shell files
4. One logical change set per commit

Before push (when asked): confirm branch/remote; never force-push `main`/`master` unless explicitly demanded; never skip hooks unless asked.

## 3. Conventional commits

```text
<type>(optional-scope): <short imperative summary>
```

Types: `feat`, `fix`, `refactor`, `docs`, `chore`, `test`, `build`.

Scopes: `cli`, `lib`, `modules`, `rules`, `inspect`, `backup`, `restore`, `secrets`, `docs`, `maintainer`.

Examples:

```text
feat(cli): add global flag parsing and command dispatch
feat(inspect): report du large items and package managers
docs(maintainer): lock Bash architecture after scaffold pivot
```

## 4. Group related files

Commit logically related files together. Split unrelated drive-bys.

## 5. Branches & tags

- Short-lived branches for multi-commit work
- Tags for releases only (`v0.1.0`)
- Amend only when asked, or when a hook rewrote your just-created **unpushed** commit

## 6. Secrets & temp

Keep out of git: `.env*`, `*.age`, backup archives, `maintainer/temp/**`, real SSH keys, tokens.
