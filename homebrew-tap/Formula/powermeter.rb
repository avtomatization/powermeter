# typed: false
# frozen_string_literal: true
# HEAD-only: brew install --HEAD powermeter (see README).

require "shellwords"

class Powermeter < Formula
  desc "macOS menu bar live power (SMC PSTR), battery fallback"
  homepage "https://github.com/avtomatization/powermeter"
  license :none
  head "https://github.com/avtomatization/powermeter.git", branch: "main"

  depends_on xcode: ["15.0", :build]

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/Powermeter"
    # SwiftPM embeds resources (Localizable.strings) in this bundle next to the executable.
    bin.install ".build/release/Powermeter_Powermeter.bundle"
  end

  def post_install
    exe = bin/"Powermeter"
    path = exe.realpath.to_s
    return unless File.executable?(path)

    ohai "Starting Powermeter in the menu bar…"
    # Release single-instance lock / old binary so the new build can run.
    quiet_system "/usr/bin/pkill", "-x", "Powermeter"
    sleep 0.5

    # MenuBarExtra needs WindowServer: `open`(1) starts the binary in the GUI login context.
    # Raw Process.spawn from brew often never shows in the menu bar.
    started = quiet_system("/usr/bin/open", path)
    unless started
      quiet_system("/bin/sh", "-c", "nohup #{Shellwords.escape(path)} >/dev/null 2>&1 &")
    end
  rescue StandardError => e
    opoo "Could not start Powermeter automatically: #{e}"
    opoo "Run `Powermeter` once from a terminal."
  end

  def post_uninstall
    plist = "#{Dir.home}/Library/LaunchAgents/com.powermeter.menu.plist"
    quiet_system "/bin/launchctl", "bootout", "gui/#{Process.uid}", plist if File.exist?(plist)
    FileUtils.rm_f(plist)
    quiet_system "/usr/bin/pkill", "-x", "Powermeter"
    log_dir = "#{Dir.home}/Library/Logs/Powermeter"
    FileUtils.rm_rf(log_dir)
    # Avoid a second copy taking precedence in PATH over the Homebrew shim.
    local = "#{Dir.home}/.local/bin"
    FileUtils.rm_f("#{local}/Powermeter")
    FileUtils.rm_rf("#{local}/Powermeter_Powermeter.bundle")
  end

  test do
    assert_predicate bin/"Powermeter", :executable?
    assert_predicate bin/"Powermeter_Powermeter.bundle", :directory?
  end

  def caveats
    <<~EOS
      Powermeter is a menu bar-only app (no Dock icon). `brew install` tries to start it via `open`(1).
      If the icon does not appear, run `Powermeter` once (check Privacy & Security if blocked).
      Autostart at login: menu bar item → Settings → Open at login.
      `brew uninstall powermeter` stops the app, removes the LaunchAgent plist, logs, and any copy in `~/.local/bin`.
    EOS
  end
end
