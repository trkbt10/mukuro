# mukuro Context Templates

This directory contains the default template files for mukuro's workspace context system, compatible with OpenClaw.

## Files

| File | Purpose |
|------|---------|
| `SOUL.md` | Agent personality, values, and boundaries |
| `IDENTITY.md` | Agent metadata (name, emoji, creature type) |
| `USER.md` | User profile (name, timezone, preferences) |
| `AGENTS.md` | Workspace guidelines and operational directives |
| `BOOTSTRAP.md` | First-run onboarding ritual (deleted after first session) |
| `TOOLS.md` | Local environment configuration and tool notes |
| `HEARTBEAT.md` | Periodic task checklist for background monitoring |

## Usage

### Onboarding

During onboarding, these templates are copied to the user's workspace directory at:
```
{data_dir}/workspace/
```

Where `{data_dir}` is resolved by `@config.data_dir()`:
- **Standard mode** (default): `~/Library/Application Support/mukuro/` (macOS)
- **Local mode** (`--local`): `.mukuro/` (relative to CWD)
- **Custom mode** (`--data-dir`): User-specified path

### Non-destructive Copy

Templates are only copied if the target file does not already exist. Existing user customizations are never overwritten.

### BOOTSTRAP.md Lifecycle

`BOOTSTRAP.md` is a special template:
1. Copied on first run (new workspace)
2. Injected into system prompt during onboarding session
3. Should be deleted by the agent after completing the onboarding ritual

## Customization

Users can customize these files in their workspace after initial setup. Changes persist across sessions as these files are read at session start and injected into the system prompt.

## OpenClaw Compatibility

These templates follow OpenClaw's conventions:
- Same file names and structure
- Same injection order into system prompt
- Compatible with OpenClaw's workspace migration tools

## Development

The embedded template strings in `api/v1/context/schemas.mbt` serve as runtime fallbacks when template files are not available (e.g., in pre-built binaries). Keep them in sync with the files in this directory.
