# typed: false
# frozen_string_literal: true
# HEAD-only: brew install --HEAD powermeter | brew reinstall powermeter (no --HEAD on reinstall; see README).

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
    path = (bin/"Powermeter").realpath.to_s
    return unless File.executable?(path)

    log = File.join(Dir.home, "Library/Logs/Powermeter", "brew-post-install-launch.log")
    FileUtils.mkdir_p(File.dirname(log))

    # Homebrew can tear down the install environment when `post_install` returns; starting
    # immediately often fails to attach MenuBarExtra to WindowServer. Defer with `nohup` so
    # pkill+`open`(1) run after Brew has fully exited.
    ohai "Scheduling Powermeter to start ~2s after Homebrew finishes (log: #{log})"
    path_q = Shellwords.escape(path)
    log_q = Shellwords.escape(log)
    log_dir_q = Shellwords.escape(File.dirname(log))
    inner = [
      "set -e",
      "mkdir -p #{log_dir_q}",
      "exec >>#{log_q} 2>&1",
      "echo \"=== $(/bin/date) brew post_install launcher ===\"",
      "sleep 2",
      "/usr/bin/pkill -x Powermeter 2>/dev/null || true",
      "sleep 0.6",
      "if /usr/bin/open #{path_q}; then echo \"$(/bin/date) open ok\"; else echo \"$(/bin/date) open failed, nohup fallback\"; /usr/bin/nohup #{path_q} </dev/null >/dev/null 2>&1 & fi",
      "sleep 0.5",
      "if /usr/bin/pgrep -xq Powermeter; then echo \"$(/bin/date) pgrep: Powermeter running\"; else echo \"$(/bin/date) pgrep: Powermeter not running\"; fi",
    ].join("; ")

    # Outer `nohup … &` returns immediately so Brew does not wait on the GUI process tree.
    unless system("/bin/bash", "-c", "nohup /bin/bash -c #{Shellwords.escape(inner)} </dev/null >/dev/null 2>&1 &")
      opoo "Could not schedule Powermeter auto-start; run `Powermeter` from a terminal."
    end
  rescue StandardError => e
    opoo "post_install: #{e}"
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
      Powermeter is a menu bar-only app (no Dock icon). After `brew install`/`reinstall`, start is
      scheduled ~2s later via `open`(1); see `~/Library/Logs/Powermeter/brew-post-install-launch.log` if the icon is missing.
      You can always run `Powermeter` manually (check Privacy & Security if blocked).
      Autostart at login: menu bar item → Settings → Open at login.
      `brew uninstall powermeter` stops the app, removes the LaunchAgent plist, logs, and any copy in `~/.local/bin`.
      Reinstall / rebuild: `brew reinstall powermeter` (do not pass `--HEAD` to `reinstall`; use `-v` for verbose).
    EOS
  end
end
