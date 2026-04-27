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

  test do
    assert_predicate bin/"Powermeter", :executable?
    assert_predicate bin/"Powermeter_Powermeter.bundle", :directory?
  end

  def caveats
    <<~EOS
      Powermeter does not start by itself after install. It is a menu bar-only app (no Dock icon).
      Run once in Terminal:
        Powermeter
      Then look for the bolt and watt readout on the right of the menu bar.
      Autostart: menu bar item → Settings → Open at login.
    EOS
  end
end
