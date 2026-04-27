# Powermeter

**Powermeter** is a tiny macOS menu bar app that shows live Mac power draw in watts.

It reads the same kind of fast SMC power sensor used by lightweight menu bar watt meters: **`PSTR` / System Total Power**. If that sensor is unavailable, Powermeter falls back to battery voltage × current (`U·I`) from IOKit / `AppleSmartBattery`.

## What You Get

- Live watts in the menu bar.
- Real refresh intervals: **1 s**, **2 s**, **5 s**, **10 s**.
- Language selector: English, Russian, Simplified Chinese, French, Spanish, German.
- Precision selector with optional smoothing.
- No root password, no privileged daemon, no network access.
- Simple install and uninstall scripts.

## Requirements

- macOS 13 Ventura or newer.
- Xcode Command Line Tools or Xcode, for Swift:

```bash
xcode-select --install
```

Check Swift:

```bash
swift --version
```

## Install

Clone the repo and run the installer:

```bash
git clone https://github.com/avtomatization/powermeter.git powermeter
cd powermeter
bash scripts/install.sh
```

The installer will:

1. Build the release binary.
2. Copy it to `~/.local/bin/Powermeter`.
3. Create a LaunchAgent at `~/Library/LaunchAgents/com.powermeter.menu.plist`.
4. Start Powermeter now and enable it at login.

If macOS blocks the first launch, open **System Settings → Privacy & Security** and allow Powermeter.

## Install with Homebrew (tap from this repo)

This repository includes a **Homebrew formula** at `Formula/powermeter.rb`. You do **not** need a separate `homebrew-*` repo: point `brew tap` at this URL once, then install.

```bash
brew tap avtomatization/powermeter https://github.com/avtomatization/powermeter.git
brew install powermeter
```

- Builds the latest `main` from source (Swift release build; formula is **HEAD-only**).
- The binary is installed as `$(brew --prefix)/bin/Powermeter`.

**Optional:** add the same LaunchAgent autostart as the shell installer (copy from `scripts/install.sh` or run that script after `brew install`).

**Uninstall:**

```bash
brew uninstall powermeter
brew untap avtomatization/powermeter
```

### Canonical tap (no URL)

Homebrew resolves `brew tap USER/TAP` to the GitHub repository **`USER/homebrew-TAP`**. So for a short command without a URL, publish a **separate** empty repo named **`homebrew-tap`** under the same account:

1. Create `https://github.com/avtomatization/homebrew-tap` (only `Formula/` and a short `README.md` is enough).
2. From this repo, generate that tree and push:

```bash
bash scripts/prepare-homebrew-tap-repo.sh
cd ../homebrew-tap
git init && git add . && git commit -m "Add powermeter formula"
git remote add origin git@github.com:avtomatization/homebrew-tap.git
git branch -M main && git push -u origin main
```

3. Users install with:

```bash
brew tap avtomatization/tap
brew install powermeter
```

Keep `Formula/powermeter.rb` in **either** the app repo (URL tap) **or** the tap repo in sync when you change the formula; the helper script only copies from this repo into `../homebrew-tap`.

## Update

From the repo folder:

```bash
git pull
bash scripts/install.sh
```

The script replaces the installed binary and restarts the menu bar item.

## Uninstall

```bash
bash scripts/uninstall.sh
```

This stops Powermeter, removes the LaunchAgent, and deletes `~/.local/bin/Powermeter`. UserDefaults preferences are left untouched.

## Run Without Installing

```bash
swift build -c release
.build/release/Powermeter
```

Stop it:

```bash
pkill -x Powermeter
```

## Settings

Open the menu bar item and go to **Settings**.

- **Language**: EN / RU / zh-Hans / FR / ES / DE.
- **Refresh interval**: 1, 2, 5, or 10 seconds.
- **Precision**:
  - Low: fewer decimals, more smoothing.
  - Medium: balanced.
  - High: no smoothing and more decimals.

Settings are stored in standard UserDefaults:

- `appLanguage`
- `refreshInterval`
- `measurementPrecision`

Older saved intervals like `0.25 s` or `0.5 s` are migrated to **1 s**, because the real SMC `PSTR` sensor updates around once per second.

## How The Reading Works

Powermeter first tries to read **SMC key `PSTR`**, which represents system total power in watts. This is the live source used by apps such as WattSec-style menu bar meters and changes much more often than battery-only estimates.

If `PSTR` cannot be read, Powermeter falls back to:

1. `AppleSmartBattery.BatteryData.SystemPower`
2. Battery voltage × current (`U·I`) from IOKit / IORegistry

The fallback exists so the app still shows something useful on machines where direct SMC power is unavailable.

## Accuracy Notes

Powermeter is intended for quick feedback while using your Mac. It is not a calibrated power meter.

- On MacBooks, SMC `PSTR` is usually the best live system-power estimate available without root.
- On desktop Macs or unusual hardware, fallback behavior may vary.
- `powermetrics` is not used because it requires superuser privileges.

## Logs And Diagnostics

Debug log:

```bash
/tmp/powermeter-debug.log
```

Restart from source during development:

```bash
bash scripts/run-powermeter.sh
```

Compare with another menu bar watt meter for 60 seconds:

```bash
bash scripts/test-tray-vs-reference.sh
```

Output goes to:

```bash
/tmp/powermeter-compare/run_<timestamp>/
```

It includes screenshots, the Powermeter log timeline, and a summary of sampled watt values.

Capture only screenshots:

```bash
bash scripts/capture-tray-series.sh 5 6 /tmp/powermeter-tray
```

## Development

```bash
swift build
swift build -c release
```

There is no XCTest target yet.

## Кратко По-Русски

Powermeter показывает текущую мощность Mac в ваттах в строке меню. Основной источник — быстрый SMC-сенсор **`PSTR`**, запасной — батарея (`SystemPower` / `U·I`).

Установка:

```bash
git clone https://github.com/avtomatization/powermeter.git powermeter
cd powermeter
bash scripts/install.sh
```

Через Homebrew (с URL к репозиторию приложения):

```bash
brew tap avtomatization/powermeter https://github.com/avtomatization/powermeter.git
brew install powermeter
```

Короткий вариант без URL — отдельный репозиторий **`avtomatization/homebrew-tap`** (см. раздел *Canonical tap* выше), затем:

```bash
brew tap avtomatization/tap
brew install powermeter
```

Удаление:

```bash
bash scripts/uninstall.sh
```

Удаление Homebrew-установки: `brew uninstall powermeter` и при желании `brew untap avtomatization/powermeter` или `brew untap avtomatization/tap`.

Реальные интервалы обновления в меню: **1 / 2 / 5 / 10 секунд**.

## License

No license file is included unless the repository owner adds one; treat usage terms as defined by the project owner.
