# reel-pipeline

Public GitHub Actions host for Signal Studio cloud reel generation.

This repo holds **only** the workflow + runner. It checks out the private
`signal-studio` repo at runtime (read-only SSH deploy key) and runs the
channel generation skill there. All content logic, skills, knowledge, and
database code live in `signal-studio` — never here.

## Why a separate public repo

GitHub Actions minutes are free and unlimited on public repos. Keeping the
runner public and the content private gives free runner minutes without
exposing the content strategy, prompts, or credentials.

## Layout

```
.github/workflows/generate.yml   parameterised workflow (cron + workflow_dispatch)
scripts/runner.sh                thin wrapper: auth smoke check → claude --print
mcp.cloud.json                   minimal MCP config (Supabase only) for the headless run
```

## Required GitHub secrets

| Secret | Purpose |
|---|---|
| `SIGNAL_STUDIO_DEPLOY_KEY` | read-only SSH deploy key for the private signal-studio repo |
| `HIGGSFIELD_AUTH_TOKEN` | restored to `~/.higgsfield/credentials` for the Higgsfield CLI |
| `ANTHROPIC_API_KEY` | Claude Code CLI |
| `SUPABASE_MCP_TOKEN` | Supabase MCP server access token |

## Run

- **Scheduled:** cron entries in `generate.yml` map posting slots → `wild-eye`.
- **Manual:** `workflow_dispatch` with a `channel` slug (and optional `content_id`).

See `signal-studio/docs/cloud-automation-workflow.md` for the full architecture.
