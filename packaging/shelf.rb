# Homebrew cask for Shelf. Lives in a personal tap:
#   github.com/ssamsenpai/homebrew-tap  ->  Casks/shelf.rb
# Then:  brew install ssamsenpai/tap/shelf
# Update version and sha256 on each release:
#   shasum -a 256 Shelf-x.y.z.dmg
cask "shelf" do
  version "1.0.0"
  sha256 "239f9016c12e58a08edf2a3b9d650f709ca2b88421715b3cdf67605f9a6a9a59"

  url "https://github.com/ssamsenpai/shelf/releases/download/v#{version}/Shelf-#{version}.dmg"
  name "Shelf"
  desc "Local-first creative library for images, fonts, links, and palettes"
  homepage "https://github.com/ssamsenpai/shelf"

  depends_on macos: ">= :tahoe"

  app "Shelf.app"

  zap trash: [
    "~/Library/Containers/app.shelf.Shelf",
  ]
end
