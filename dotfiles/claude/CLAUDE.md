# Working with Zdeněk

## Environment

- Fedora Linux, zsh, kitty, tmux (prefix `C-\`), nvim, X11 under xmonad.
- Dotfiles live in `~/fresh.sh` and are symlinked into place by `setup/*.sh`.
  `~/.config/nvim`, `~/.config/tmux`, `~/.claude/*` and friends all point into
  that repo — editing them edits the repo, so check `git status` there.
- New config belongs in `~/fresh.sh/dotfiles/` and gets linked by a setup
  script. Never drop a config file straight into `~/.config` or `~/.claude`.
- Editors and languages in play: Haskell/cabal, typst, LaTeX, markdown, Lua,
  plus the LSPs enabled in `settings.json`.

## Verify, don't assert

- Prove the mechanism before naming a cause. Run the thing, capture the output,
  read the actual code — a plausible story is not a diagnosis.
- Never prescribe "restart it" or "try again" as a fix unless you have
  confirmed that state is the problem.
- If a hypothesis fails once, discard it. Do not re-litigate it with more
  confidence and no new evidence.
- When reading someone else's compiled or minified code, quote the exact lines
  you are relying on. Partial matches mislead — read the whole function.
- Say plainly which parts you tested and which you did not.

## Changing things

- Shell scripts: POSIX `sh`, tabs, idempotent, and defensive — back up to
  `.bak` rather than clobbering, and make re-runs a no-op.
- Test edge cases before claiming done: missing input, first run, re-run,
  and the "field not present yet" case.
- Don't widen scope. Fix what was asked, mention anything else you spotted.

## Colors and layout

- gruvbox-material is the palette everywhere (nvim, tmux, Claude Code).
  Look values up in the real palette instead of approximating them.
- For any visual choice, render the options in the terminal so they can be
  seen in the actual font, and offer a numbered list to pick from.
  Describing a color in words is useless.

## Git

- Commit and push when asked; one focused commit per change.
- Short imperative subject lines. No trailing period.
- Never commit machine-local state — e.g. the `model` key in
  `dotfiles/claude/settings.json` is deliberately left dirty.

## Communication

- Lead with the result or the answer. Keep it tight.
- Flag uncertainty as uncertainty rather than dressing it up.
- Corrections get one sentence, no ceremony.
