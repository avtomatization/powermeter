# Homebrew tap: avtomatization/tap

```bash
brew tap avtomatization/tap
brew install --HEAD powermeter
Powermeter
```

**Run:** Homebrew does not auto-start the app. Run **`Powermeter`** once in Terminal (binary is in `$(brew --prefix)/bin/`). Look for the **bolt + watts** in the **menu bar** (no Dock icon). Autostart: tray menu → **Settings** → **Open at login**.

Formulas live under `Formula/`. Source: [Powermeter](https://github.com/avtomatization/powermeter).

This directory is a mirror of the tap layout kept in the main Powermeter repo. After editing the root `Formula/powermeter.rb`, run `bash scripts/prepare-homebrew-tap-repo.sh` to refresh `homebrew-tap/Formula/`.
