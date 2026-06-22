#!/usr/bin/env bash
# Runner for cloud-agent reel generation.
# Runs inside the signal-studio checkout on a GitHub Actions ubuntu-latest runner.
# Called by generate.yml with CHANNEL and CONTENT_ID env vars already set.
# CWD is the signal-studio checkout (working-directory: content); this script
# lives at reel-pipeline/scripts/runner.sh, so the reel-pipeline root is "..".

set -euo pipefail

CHANNEL="${CHANNEL:-wild-eye}"
CONTENT_ID="${CONTENT_ID:-}"

# ── Higgsfield auth smoke check ───────────────────────────────────────────────
# Fail fast if the Higgsfield CLI token is missing/expired, BEFORE spending any
# Claude tokens. higgsfield-credit-guard re-checks the balance later; this only
# proves the credentials restored from HIGGSFIELD_AUTH_TOKEN actually work.
echo "=== Higgsfield auth smoke check ==="
if ! higgsfield account balance; then
  echo "ERROR: Higgsfield CLI auth failed — check the HIGGSFIELD_AUTH_TOKEN secret / ~/.higgsfield/credentials." >&2
  exit 1
fi
echo ""

if [ -n "$CONTENT_ID" ]; then
  PROMPT="Run the ${CHANNEL}-reel skill for content_items.id=${CONTENT_ID}."
else
  PROMPT="Run the ${CHANNEL}-reel skill for the oldest status='brief' row in channel ${CHANNEL}."
fi

echo "=== Signal Studio Cloud Agent ==="
echo "Channel : $CHANNEL"
echo "Content : ${CONTENT_ID:-<oldest brief>}"
echo "Prompt  : $PROMPT"
echo ""

# --mcp-config: the cloud run needs ONLY the Supabase MCP server. The repo's own
#   .mcp.json also declares github/filesystem/etc. servers that point at a local
#   docker socket and a developer home path — neither exists on the runner — so we
#   pass a minimal cloud-only config instead. Higgsfield uses its CLI, not MCP.
# --dangerously-skip-permissions: headless, non-interactive run — no human is
#   present to approve tool/MCP calls.
claude --print \
  --mcp-config ../mcp.cloud.json \
  --dangerously-skip-permissions \
  "$PROMPT"
