# typed: false
# frozen_string_literal: true
# HEAD-only: brew install --HEAD powermeter | brew reinstall powermeter (no --HEAD on reinstall; see README).
#
# Install layout is implemented in scripts/homebrew-install.sh (from the cloned source) so
# `brew tap avtomatization/tap` users get keg fixes after `brew update` without republishing
# homebrew-tap for every change — only when this `install` method changes.

class Powermeter < Formula
  desc "macOS menu bar live power (SMC PSTR), battery fallback"
  homepage "https://github.com/avtomatization/powermeter"
  license :none
  head "https://github.com/avtomatization/powermeter.git", branch: "main"

  depends_on xcode: ["15.0", :build]

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"

    install_script = buildpath/"scripts/homebrew-install.sh"
    odie "scripts/homebrew-install.sh missing in source checkout" unless install_script.file?

    system "bash", install_script.to_s, prefix.to_s, buildpath.to_s
  end

  def post_install
    unless (libexec/"Powermeter_Powermeter.bundle").directory? &&
           (share/"powermeter/Powermeter_Powermeter.bundle").directory?
      odie <<~ERR
        Resource bundle was not installed under:
          #{libexec}/Powermeter_Powermeter.bundle
          #{share}/powermeter/Powermeter_Powermeter.bundle
        Report this with `brew gist-logs powermeter`.
      ERR
    end

    wrapper = (libexec/"powermeter-brew-autostart-once.sh").realpath.to_s
    return unless File.executable?(wrapper)

    begin
      log_dir = File.join(Dir.home, "Library/Logs/Powermeter")
      FileUtils.mkdir_p(log_dir)
      out_log = File.join(log_dir, "brew-autostart-launchd-stdout.log")
      err_log = File.join(log_dir, "brew-autostart-launchd-stderr.log")
      plist_path = File.join(Dir.home, "Library/LaunchAgents/com.powermeter.brew-autostart-once.plist")

      plist_xml = <<~PLIST
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>Label</key>
          <string>com.powermeter.brew-autostart-once</string>
          <key>ProgramArguments</key>
          <array>
            <string>#{wrapper}</string>
          </array>
          <key>RunAtLoad</key>
          <true/>
          <key>KeepAlive</key>
          <false/>
          <key>StandardOutPath</key>
          <string>#{out_log}</string>
          <key>StandardErrorPath</key>
          <string>#{err_log}</string>
        </dict>
        </plist>
      PLIST

      ohai "Starting Powermeter via a one-time user LaunchAgent (GUI session)…"
      quiet_system "/bin/launchctl", "bootout", "gui/#{Process.uid}", plist_path if File.exist?(plist_path)
      FileUtils.mkdir_p(File.dirname(plist_path))
      File.write(plist_path, plist_xml)
      unless system("/bin/launchctl", "bootstrap", "gui/#{Process.uid}", plist_path)
        opoo "launchctl bootstrap failed; run `Powermeter` from Terminal."
      end
    rescue StandardError => e
      opoo "post_install: #{e}"
      opoo "Run `Powermeter` once from a terminal."
    end
  end

  def post_uninstall
    once = "#{Dir.home}/Library/LaunchAgents/com.powermeter.brew-autostart-once.plist"
    quiet_system "/bin/launchctl", "bootout", "gui/#{Process.uid}", once if File.exist?(once)
    FileUtils.rm_f(once)

    plist = "#{Dir.home}/Library/LaunchAgents/com.powermeter.menu.plist"
    quiet_system "/bin/launchctl", "bootout", "gui/#{Process.uid}", plist if File.exist?(plist)
    FileUtils.rm_f(plist)
    quiet_system "/usr/bin/pkill", "-x", "Powermeter"
    log_dir = "#{Dir.home}/Library/Logs/Powermeter"
    FileUtils.rm_rf(log_dir)
    local = "#{Dir.home}/.local/bin"
    FileUtils.rm_f("#{local}/Powermeter")
    FileUtils.rm_rf("#{local}/Powermeter_Powermeter.bundle")
  end

  test do
    assert_predicate bin/"Powermeter", :executable?
    assert_predicate libexec/"Powermeter_Powermeter.bundle", :directory?
    assert_predicate share/"powermeter/Powermeter_Powermeter.bundle", :directory?
    refute_predicate bin/"Powermeter_Powermeter.bundle", :exist?
  end

  def caveats
    <<~EOS
      Powermeter is a menu bar-only app (no Dock icon). After `brew install`/`reinstall`, a **one-time**
      LaunchAgent (`com.powermeter.brew-autostart-once`) runs `open -n` in your GUI session, then removes itself.
      Logs: `~/Library/Logs/Powermeter/brew-autostart-once.log` and `brew-autostart-launchd-*.log`.
      If the icon is still missing, run `Powermeter` manually (Privacy & Security).
      Autostart at login: menu bar → Settings → Open at login.
      `brew uninstall` removes that one-shot plist, the regular login plist, logs, and `~/.local/bin` copies.
      Reinstall: `brew reinstall powermeter` (no `--HEAD` on reinstall; `-v` for verbose).
    EOS
  end
end
