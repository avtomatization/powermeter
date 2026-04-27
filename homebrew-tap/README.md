# Homebrew tap: avtomatization/tap

```bash
brew tap avtomatization/tap
brew install --HEAD powermeter
```

Reinstall / upgrade: **`brew reinstall powermeter`** (not `reinstall --HEAD`; verbose: **`-v`**). **`post_install`** schedules **`open`** ~2s after Brew exits (`nohup`); log **`~/Library/Logs/Powermeter/brew-post-install-launch.log`**. **`brew uninstall`** removes logs, LaunchAgent, `~/.local/bin` copy, etc.

Formulas live under `Formula/`. Source: [Powermeter](https://github.com/avtomatization/powermeter).

This directory is a mirror of the tap layout kept in the main Powermeter repo. After editing the root `Formula/powermeter.rb`, run `bash scripts/prepare-homebrew-tap-repo.sh` to refresh `homebrew-tap/Formula/`.
