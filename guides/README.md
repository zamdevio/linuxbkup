# Guides

Install / How-To snippets consumed by `lib/tools/check.sh`.

## Tools

Each file: `guides/tools/<command>.guide`

```text
SUMMARY=One-line purpose
APT=package
DNF=package
…
HOW_APT=sudo apt install -y package
HOW_DNF=…
NOTE=Optional extra hint
```

The CLI detects apt/dnf/yum/pacman/apk/brew and prints the matching `HOW_*` line when a required tool is missing.
