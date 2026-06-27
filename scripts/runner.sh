#!/usr/bin/env bash
# Runner for cloud-agent reel generation.
# Runs inside the signal-studio checkout on a GitHub Actions ubuntu-latest runner.
# Called by generate.yml with CHANNEL and CONTENT_ID env vars already set.
# CWD is the signal-studio checkout (working-directory: content); this script
# lives at reel-pipeline/scripts/runner.sh, so the reel-pipeline root is "..".

set -euo pipefail

CHANNEL="${CHANNEL:-wild-eye}"
CONTENT_ID="${CONTENT_ID:-}"

# ── Resolve channel slug → channel_key + skill name ───────────────────────────
# channel-slugs.js is the single source of truth. Inline the resolution here via
# Node so the bash script doesn't have to duplicate the map.
read -r CHANNEL_KEY SKILL_NAME <<< "$(node -e "
  import('file://$GITHUB_WORKSPACE/content/apps/video/src/config/channel-slugs.js').then(m => {
    const r = m.resolveChannelSlug('${CHANNEL}');
    process.stdout.write(r.channelKey + ' ' + r.skill + '\n');
  }).catch(e => { process.stderr.write(e.message + '\n'); process.exit(1); });
" 2>&1)" || {
  echo "ERROR: Unknown channel slug '${CHANNEL}'. Add it to apps/video/src/config/channel-slugs.js." >&2
  exit 1
}

echo "Channel slug : ${CHANNEL}"
echo "Channel key  : ${CHANNEL_KEY}"
echo "Skill        : ${SKILL_NAME}"
echo ""

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
  PROMPT="Run the ${SKILL_NAME} skill for content_items.id=${CONTENT_ID}."
else
  PROMPT="Run the ${SKILL_NAME} skill for the oldest status='brief' row with channel_key='${CHANNEL_KEY}'."
fi

echo "=== Signal Studio Cloud Agent ==="
echo "Channel : $CHANNEL"
echo "Content : ${CONTENT_ID:-<oldest brief>}"
echo "Prompt  : $PROMPT"
echo ""

# ── Trust the workspace so project skills + settings load ─────────────────────
# --dangerously-skip-permissions bypasses tool-approval prompts but does NOT mark
# the workspace trusted. Without trust, Claude Code ignores .claude/settings AND
# never loads the project skills — so `claude --print "Run wild-eye-reel..."` finds
# no such skill and silently no-ops (exactly what killed the #25 run). Pre-seed the
# per-project trust flag in ~/.claude.json (the path the CLI actually checks). CWD
# here is the signal-studio checkout, so $(pwd) is the project key the CLI uses.
PROJECT_DIR="$(pwd)"
node -e "
  const fs = require('fs'), os = require('os'), path = require('path');
  const file = path.join(os.homedir(), '.claude.json');
  let cfg = {};
  try { cfg = JSON.parse(fs.readFileSync(file, 'utf8')); } catch {}
  cfg.projects = cfg.projects || {};
  cfg.projects['$PROJECT_DIR'] = { ...(cfg.projects['$PROJECT_DIR'] || {}), hasTrustDialogAccepted: true };
  fs.writeFileSync(file, JSON.stringify(cfg, null, 2));
  process.stdout.write('Trusted workspace: $PROJECT_DIR\n');
"
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
