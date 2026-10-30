#!/bin/bash
# Builds ninetail-mcp at session start so the project MCP server in .mcp.json
# (node ninetail-mcp/dist/index.js) can launch in Claude Code cloud sessions.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-.}/ninetail-mcp"
hook=../.claude/hooks/session-start.sh

# stdout from a SessionStart hook lands in Claude's context, so npm output goes to stderr.

# Install only if this script or the manifests changed since the last successful install
deps_hashes=node_modules/.session-start.sha256
if ! sha256sum --check --status "$deps_hashes" 2>/dev/null; then
  # Delete the old hashes first, so a failed install runs again next time
  rm -f "$deps_hashes"
  npm install --no-audit --no-fund >&2
  sha256sum "$hook" package.json package-lock.json > "$deps_hashes" 2>/dev/null || rm -f "$deps_hashes"
fi

# Build only if the sources, compiler config, dependencies or the output changed since the last successful build
build_hashes=dist/.session-start.sha256
if ! sha256sum --check --status "$build_hashes" 2>/dev/null; then
  rm -f "$build_hashes"
  npm run build >&2
  find src -type f | sort | xargs sha256sum "$hook" tsconfig.json package.json package-lock.json dist/index.js \
    > "$build_hashes" 2>/dev/null || rm -f "$build_hashes"
fi
