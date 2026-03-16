#!/usr/bin/env bash
set -e

# Enter the fullstack Nix environment to ensure we have uv, bun, and the Prisma engines
nix develop .#fullstack --command bash -c '

echo "📦 [post-create] Syncing Python dependencies (uv)"
uv sync

echo "🗄️ [post-create] Generating Prisma client"
just generate-prisma

echo "⚛️ [post-create] Installing UI dependencies (bun)"
just install-js

echo "✅ [post-create] Workspace Ready!"
'
