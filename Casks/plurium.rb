cask "plurium" do
  version "154.0.8037.98-6"
  sha256 "43e01454f16259f4a53b18b168f9baf5d28a8331b995cbe92c3afbbc871f827d"

  url "https://github.com/indapublic/plurium/releases/download/v#{version}/Plurium-#{version}-arm64.dmg"
  name "Plurium"
  desc "Chromium with the tabs of all profiles in one window"
  homepage "https://github.com/indapublic/plurium"

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
