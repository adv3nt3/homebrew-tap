class Cupertino < Formula
  desc "Apple developer documentation MCP server with offline search"
  homepage "https://github.com/adv3nt3/cupertino"
  url "https://github.com/adv3nt3/cupertino/releases/download/v1.1.0-adv3nt3.1/cupertino-v1.1.0-adv3nt3.1-macos-universal.tar.gz"
  version "1.1.0-adv3nt3.1"
  sha256 "c451d20cbd6009cf60ffe3a97065ac106d8d83e5ded0f0a37e008101b40bf66a"
  license "MIT"

  head do
    url "https://github.com/adv3nt3/cupertino.git", branch: "main"
    depends_on xcode: ["16.0", :build]
  end

  depends_on macos: :sequoia

  def install
    if build.head?
      # Source build from main: useful for testing pre-release commits.
      # Catalogs are still embedded — no resource bundle to install.
      cd "Packages" do
        system "swift", "build", "--disable-sandbox", "-c", "release", "--product", "cupertino"
        bin.install ".build/release/cupertino"
      end
    else
      # Bottle: signed + notarized universal binary.
      # Catalogs are compiled in as Swift literals (#161 upstream) — no
      # bundle to copy, no post_install symlink to create.
      bin.install "cupertino"
    end
  end

  test do
    # cupertino serve doesn't exit on stdin EOF (pipe_output would hang),
    # so we settle for verifying the binary runs and reports the expected
    # version. A stronger MCP-protocol smoke test will land once the
    # server exits cleanly on transport close.
    assert_match version.to_s, shell_output("#{bin}/cupertino --version")
  end
end
