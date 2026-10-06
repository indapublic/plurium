cask "plurium" do
  version "154.0.8037.98-5"
  sha256 "c511c636fa6941f4605056ea89097013e5f35b55ab5f86d8e2c4e7edc0d63b7c"

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
