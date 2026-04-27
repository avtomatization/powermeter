# Homebrew tap: avtomatization/tap

```bash
brew tap avtomatization/tap
brew install --HEAD powermeter
```

Reinstall / upgrade: **`brew reinstall powermeter`** (not `reinstall --HEAD`; verbose: **`-v`**). **`post_install`** loads a **one-time `launchd` user agent** that runs **`open -n`** in the GUI session (see **`~/Library/Logs/Powermeter/brew-autostart-once.log`**). **`brew uninstall`** removes that plist, login plist, logs, `~/.local/bin` copies, etc.

Formulas live under `Formula/`. Source: [Powermeter](https://github.com/avtomatization/powermeter).

This directory is a mirror of the tap layout kept in the main Powermeter repo. After editing the root `Formula/powermeter.rb`, run `bash scripts/prepare-homebrew-tap-repo.sh` to refresh `homebrew-tap/Formula/`.
