cask "valentine" do
  version "1.0"
  sha256 "10fb7d4d4a8636c14405333647e10f2ba7a16665a92906528bd5c069c6212a46"

  url "https://github.com/JesusChapman/valentine/releases/download/#{version}/Valentine_v#{version}_Apple_Silicon.dmg"
  name "Valentine"
  desc "Elegant native music player and synchronized lyrics editor"
  homepage "https://github.com/JesusChapman/valentine"

  app "Valentine.app"

  zap trash: [
    "~/Library/Application Support/dev.jesuschapman.Valentine",
    "~/Library/Preferences/dev.jesuschapman.Valentine.plist",
    "~/Library/Saved Application State/dev.jesuschapman.Valentine.savedState",
  ]
end
