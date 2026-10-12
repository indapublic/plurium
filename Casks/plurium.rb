cask "plurium" do
  version "155.0.8059.40-1"
  sha256 "4cda2c6b157b34ba854158cefff0fad373880a4bfa1fd7159c4d3e59aef25fce"

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
