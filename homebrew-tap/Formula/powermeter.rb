# typed: false
# frozen_string_literal: true
# HEAD-only: brew install --HEAD powermeter (see README).

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
    return unless exe.exist?

    ohai "Starting Powermeter in the menu bar…"
    Process.detach(Process.spawn(exe.to_s, in: File::NULL, out: File::NULL, err: File::NULL))
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
      Powermeter is a menu bar-only app (no Dock icon). It should start automatically after install.
      If you do not see the bolt + watts icon, run `Powermeter` once (check Privacy & Security if blocked).
      Autostart at login: menu bar item → Settings → Open at login.
      `brew uninstall powermeter` stops the app, removes the LaunchAgent plist, logs, and any copy in `~/.local/bin`.
    EOS
  end
end
