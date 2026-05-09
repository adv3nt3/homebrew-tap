class AppleDocsMcp < Formula
  desc "MCP server for Apple Developer Documentation, framework APIs, and WWDC videos"
  homepage "https://github.com/adv3nt3/apple-docs-mcp"
  url "https://github.com/adv3nt3/apple-docs-mcp/archive/refs/tags/v1.2.0.tar.gz"
  sha256 "df38c33f54a4ae988882b735bea4787c9efa12626ac89e522026c88c5d11fb00"
  license "MIT"
  head "https://github.com/adv3nt3/apple-docs-mcp.git", branch: "main"

  depends_on "node"
  depends_on "pnpm" => :build

  def install
    # Install all deps (build needs typescript, jest types, etc.) and compile.
    system "pnpm", "install", "--frozen-lockfile"
    system "pnpm", "run", "build"

    # Re-install with --prod so node_modules is the runtime tree only.
    rm_rf "node_modules"
    system "pnpm", "install", "--frozen-lockfile", "--prod", "--ignore-scripts"

    # Ship the compiled JS + bundled WWDC corpus + production node_modules.
    libexec.install Dir["dist/*"]
    libexec.install "node_modules"

    # Wrapper shim points at the compiled entry; node from this formula is on PATH.
    (bin/"apple-docs-mcp").write_env_script libexec/"index.js",
                                            PATH: "#{Formula["node"].opt_bin}:$PATH"
  end

  test do
    # Server is stdio MCP — sending an `initialize` JSON-RPC request and
    # checking for a well-formed response covers boot + transport + tool registry.
    request = <<~JSON
      {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"brew-test","version":"0"}}}
    JSON
    output = pipe_output("#{bin}/apple-docs-mcp", request, 0)
    assert_match(/"result"/, output)
    assert_match(/"serverInfo"/, output)
  end
end