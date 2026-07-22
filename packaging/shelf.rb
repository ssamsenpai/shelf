# Homebrew cask for Shelf. Lives in a personal tap:
#   github.com/YOUR_HANDLE/homebrew-tap  ->  Casks/shelf.rb
# Then:  brew install YOUR_HANDLE/tap/shelf
# Update version and sha256 on each release:
#   shasum -a 256 Shelf-x.y.z.dmg
cask "shelf" do
  version "0.1.0"
  sha256 "REPLACE_WITH_DMG_SHA256"

  url "https://github.com/YOUR_HANDLE/shelf/releases/download/v#{version}/Shelf-#{version}.dmg"
  name "Shelf"
  desc "Local-first creative library for images, fonts, links, and palettes"
  homepage "https://github.com/YOUR_HANDLE/shelf"

  depends_on macos: ">= :tahoe"

  app "Shelf.app"

  zap trash: [
    "~/Library/Containers/app.shelf.Shelf",
  ]
end
