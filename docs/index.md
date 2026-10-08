---
layout: home

title: linuxbkup
description: Universal Linux backup — Bash + coreutils + small tools. Desktop, VPS, WSL; Alpine/iSH/Termux best-effort.

hero:
  name: linuxbkup
  text: Backup what can't be regenerated
  tagline: Portable Linux backup/restore — desktop, VPS, and WSL. Scan, decide, archive, restore with a real schema. No Node/Python runtime.
  image:
    src: /linuxbkup.svg
    alt: linuxbkup
  actions:
    - theme: brand
      text: Get started
      link: /install
    - theme: alt
      text: Guide
      link: /guide
    - theme: alt
      text: CLI
      link: /cli

features:
  - icon: 🐧
    title: Bash-first, no heavy runtime
    details: One script plus tools you already have — tar, zstd, rsync, du. No daemon, no node_modules, no compile step for the CLI.
  - icon: 🌍
    title: Same tool across hosts
    details: GNU Linux happy path; BusyBox/iSH/Termux via compat probes and deps bootstrap (apk, apt, pacman, pkg).
  - icon: 📦
    title: Atomic archives
    details: Pack to *.tar.zst.tmp, verify, then rename. Checksums + schema.json. Crash does not leave a half-written archive.
  - icon: 🧠
    title: Classify, don't dump
    details: Full-home scan with unexpected-path reporting. Regenerables (node_modules, venvs, caches) stripped by default.
  - icon: 🔐
    title: Secrets with age
    details: Encrypted subset when you mark paths. --yes never silently skips encryption of secret paths.
  - icon: 🛡️
    title: Safety by default
    details: Restore overwrite needs -f. Ctrl+C menu, Ctrl+Z suspend on backup and restore. Sudo targets SUDO_USER, not /root.
---

## Quick start

```bash
git clone https://github.com/zamdevio/linuxbkup.git && cd linuxbkup
./linuxbkup deps
./linuxbkup plan
./linuxbkup -y backup
./linuxbkup verify ~/Backups/linuxbkup/<archive>.tar.zst
./linuxbkup -k -f restore ~/Backups/linuxbkup/<archive>.tar.zst
```

## Documentation

| Topic | What you will learn |
|-------|---------------------|
| [Install](/install) | Clone, deps, PATH, first commands |
| [Concepts](/concepts) | What gets backed up, safety model, portability |
| [Guide](/guide) | inspect → plan → backup → verify → restore |
| [Platforms](/platforms) | Desktop, VPS, WSL, Alpine, Termux, external mounts |
| [Schema](/schema) | Archive layout, atomic pack, checksums |
| [Secrets](/secrets) | age encryption and --yes rules |
| [CLI](/cli) | Every command and global flag |
| [Troubleshooting](/troubleshooting) | When something fails |

Source: [github.com/zamdevio/linuxbkup](https://github.com/zamdevio/linuxbkup) · License: MIT
