class AppleDocsMcp < Formula
  desc "MCP server for Apple Developer Documentation, framework APIs, and WWDC videos"
  homepage "https://github.com/adv3nt3/apple-docs-mcp"
  url "https://github.com/adv3nt3/apple-docs-mcp/releases/download/v1.3.0/apple-docs-mcp-1.3.0.tar.gz"
  sha256 "ad5f970e09434e25a7d72feb0a01444d315ffd676a73ecaad5296c057911549b"
  license "MIT"

  # Source-build path for contributors / TUI work / pre-release testing.
  # `pnpm` is only needed when building from source — keep it inside the
  # head block so stable installs don't pull a build-only dep.
  head do
    url "https://github.com/adv3nt3/apple-docs-mcp.git", branch: "main"
    depends_on "pnpm" => :build
  end

  depends_on "node"

  def install
    if build.head?
      # Source build: same flow the pre-bottle formula used.
      # --ignore-scripts skips esbuild / unrs-resolver native postinstalls
      # (devDep-only optimisations PNPM 10 otherwise rejects non-interactively).
      system "pnpm", "install", "--frozen-lockfile", "--ignore-scripts"
      system "pnpm", "run", "build"
      rm_r "node_modules"
      system "pnpm", "install", "--frozen-lockfile", "--prod", "--ignore-scripts"
      libexec.install Dir["dist/*"]
      libexec.install "node_modules"
    else
      # Bottle: tarball already contains compiled dist/* + production
      # node_modules at top level. Built by .github/workflows/release.yml
      # in the apple-docs-mcp repo (Package bottle tarball step).
      libexec.install Dir["*"]
    end

    # Custom shim — dist/index.js has a shebang but isn't chmod +x in the
    # build output, so a direct exec would EACCES. Avoiding write_env_script
    # for the same reason.
    (bin/"apple-docs-mcp").write <<~SHIM
      #!/bin/bash
      exec "#{Formula["node"].opt_bin}/node" "#{libexec}/index.js" "$@"
    SHIM
    chmod 0755, bin/"apple-docs-mcp"
  end

  test do
    # Cheap check: the wrapper exists and is executable.
    assert_predicate bin/"apple-docs-mcp", :executable?

    # Construction smoke under NODE_ENV=test (skips the auto-`run()` block in
    # src/index.ts). Explicit process.exit(0) — registerAllTools/McpServer
    # leaves something on the event loop that prevents natural exit; without
    # exit, brew test hangs to its 5-minute timeout.
    ENV["NODE_ENV"] = "test"
    smoke = <<~JS
      import('#{libexec}/index.js')
        .then(m => { new m.default(); process.exit(0); })
        .catch(e => { console.error(e); process.exit(1); });
    JS
    system Formula["node"].opt_bin/"node", "--input-type=module", "-e", smoke
  end
end
