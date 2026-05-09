class Cupertino < Formula
  desc "Apple developer documentation MCP server with offline search"
  homepage "https://github.com/adv3nt3/cupertino"
  url "https://github.com/adv3nt3/cupertino/archive/refs/tags/v0.11.1.tar.gz"
  sha256 "e237c7a9047ff05e85c3fcf02b885cf189fcf5adfee4b6e6f3e3a5ef0564e789"
  license "MIT"
  version "0.11.1"

  depends_on macos: :sequoia
  depends_on xcode: ["16.0", :build]

  def install
    cd "Packages" do
      system "swift", "build", "--disable-sandbox", "-c", "release", "--product", "cupertino"
      system "swift", "build", "--disable-sandbox", "-c", "release", "--product", "cupertino-tui"

      bin.install ".build/release/cupertino"
      bin.install ".build/release/cupertino-tui"

      # SwiftPM emits resource bundles under an arch-specific directory.
      arch_triple = Hardware::CPU.arm? ? "arm64-apple-macosx" : "x86_64-apple-macosx"
      bundle = Pathname.new(".build/#{arch_triple}/release/Cupertino_Resources.bundle")
      if bundle.directory?
        (bin/"Cupertino_Resources.bundle").install Dir["#{bundle}/*"]
      end
    end
  end

  def post_install
    # Homebrew symlinks files from bin/ but not directories.
    # Mirror the resource bundle as a symlink so Bundle.main.bundleURL
    # resolves the same way it does in the build tree.
    linked_bundle = HOMEBREW_PREFIX/"bin/Cupertino_Resources.bundle"
    linked_bundle.unlink if linked_bundle.symlink? || linked_bundle.exist?
    linked_bundle.make_symlink(bin/"Cupertino_Resources.bundle")
    ohai "Run 'cupertino setup' to download documentation databases (~230 MB)"
  end

  test do
    assert_match "0.11.1", shell_output("#{bin}/cupertino --version")
  end
end