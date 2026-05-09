class AppleDocsMcp < Formula
  desc "MCP server for Apple Developer Documentation, framework APIs, and WWDC videos"
  homepage "https://github.com/adv3nt3/apple-docs-mcp"
  url "https://github.com/adv3nt3/apple-docs-mcp/archive/refs/tags/v1.2.0.tar.gz"
  sha256 "df38c33f54a4ae988882b735bea4787c9efa12626ac89e522026c88c5d11fb00"
  license "MIT"
  head "https://github.com/adv3nt3/apple-docs-mcp.git", branch: "main"

  depends_on "pnpm" => :build
  depends_on "node"

  def install
    # Install all deps (build needs typescript) and compile. --ignore-scripts
    # skips esbuild / unrs-resolver native-build steps that pnpm 10 otherwise
    # rejects in a non-interactive context — those are dev-only optimizations
    # (used by jest/ESLint) and aren't needed by `pnpm run build` (just tsc
    # + cp data).
    system "pnpm", "install", "--frozen-lockfile", "--ignore-scripts"
    system "pnpm", "run", "build"

    # Re-install with --prod so node_modules is the runtime tree only.
    rm_r "node_modules"
    system "pnpm", "install", "--frozen-lockfile", "--prod", "--ignore-scripts"

    # Ship the compiled JS + bundled WWDC corpus + production node_modules.
    libexec.install Dir["dist/*"]
    libexec.install "node_modules"

    # Wrapper shim explicitly invokes node on the compiled entry. Using a
    # custom shim instead of write_env_script because the entry .js file isn't
    # marked executable in the build output (shebang only), so a direct exec
    # would fail with EACCES.
    (bin/"apple-docs-mcp").write <<~SHIM
      #!/bin/bash
      exec "#{Formula["node"].opt_bin}/node" "#{libexec}/index.js" "$@"
    SHIM
    chmod 0755, bin/"apple-docs-mcp"
  end

  test do
    # Cheap check: the wrapper exists and is executable.
    assert_predicate bin/"apple-docs-mcp", :executable?

    # Construction smoke: import the compiled module under NODE_ENV=test so
    # the auto-`run()` block in src/index.ts is skipped, and the registerTool
    # wiring goes all the way through (Zod schema generation, tool registry).
    # If any imported handler throws at module load (broken require, missing
    # data file), this surfaces it. Doing this instead of a stdio init/EOF
    # round-trip because the server schedules a setInterval for cache refresh
    # and otherwise never exits — `pipe_output` would hang under brew test.
    ENV["NODE_ENV"] = "test"
    # Explicit process.exit(0) after construction: registerAllTools / McpServer
    # leaves something on the event loop that prevents natural exit, and we
    # don't want brew test to hit its 5-minute timeout on a green smoke.
    smoke = <<~JS
      import('#{libexec}/index.js')
        .then(m => { new m.default(); process.exit(0); })
        .catch(e => { console.error(e); process.exit(1); });
    JS
    system Formula["node"].opt_bin/"node", "--input-type=module", "-e", smoke
  end
end
