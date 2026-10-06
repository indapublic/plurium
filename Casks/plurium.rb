cask "plurium" do
  version "154.0.8037.98-8"
  sha256 "6d38b493db9838a4ce1fa77a10dc4da616e6d234ab87db47324fdca594d1f654"

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
