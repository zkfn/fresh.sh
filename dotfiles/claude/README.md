# claude

Portable parts of `~/.claude`, linked in by `setup/claude.sh`.

Synced: `settings.json`, `skills/`. The setup script also links `CLAUDE.md`,
`keybindings.json`, `agents/`, `commands/` and `output-styles/` if they show up
here later.

Deliberately not synced, because it is per-machine state rather than config:

- `.credentials.json` — auth token
- `settings.local.json` — the machine-local override layer
- `projects/` — session transcripts and per-project memory (~180M here)
- `history.jsonl`, `sessions/`, `shell-snapshots/`, `file-history/`
- `plugins/` — installed plugin checkouts and marketplace state; `settings.json`
  records which plugins are enabled, so a fresh machine re-adds the marketplace
  and pulls them down itself
- `backups/`, `cache/`, `paste-cache/`, `session-env/`, `ide/`, `daemon/`,
  `jobs/`, `debug/`, `downloads/`
