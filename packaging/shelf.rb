# Homebrew cask for Shelf. Lives in a personal tap:
#   github.com/ssamsenpai/homebrew-tap  ->  Casks/shelf.rb
# Then:  brew install ssamsenpai/tap/shelf
# Update version and sha256 on each release:
#   shasum -a 256 Shelf-x.y.z.dmg
cask "shelf" do
  version "1.0.0"
  sha256 "4ebfeb27d4ec0e0b3359ba07171fd2bcc9772c8ac1760ea0e9efb38cb5c78009"

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
