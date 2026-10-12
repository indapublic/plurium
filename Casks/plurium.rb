cask "plurium" do
  version "155.0.8059.40-3"
  sha256 "4efffbbab85669f4ae82fe554d4bcedd0d6120716513e6cfabbcbfbd470282b1"

  url "https://github.com/indapublic/plurium/releases/download/v#{version}/Plurium-#{version}-arm64.dmg"
  name "Plurium"
  desc "Chromium with the tabs of all profiles in one window"
  homepage "https://indapublic.github.io/plurium/"

  livecheck do
    url :url
    regex(/^v?(\d+(?:\.\d+)+(?:-\d+)?)$/i)
    strategy :github_latest
  end

  depends_on arch: :arm64
  depends_on macos: :ventura

  app "Plurium.app"

  uninstall quit: "com.indapublic.plurium"

  zap trash: [
    "~/Library/Application Support/Plurium",
    "~/Library/Caches/Plurium",
    "~/Library/Preferences/com.indapublic.plurium.plist",
    "~/Library/Preferences/com.indapublic.plurium.profile-tabs.plist",
    "~/Library/Saved Application State/com.indapublic.plurium.savedState",
  ]
end
