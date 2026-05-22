# Open in Codex for Finder

Finder Quick Action for macOS that opens a selected folder in the right Codex Desktop place:

- an existing chat for that exact folder, when one exists
- the saved Codex project for that folder, when it is already a project
- a prompt for new folders, so you can either open the folder as a Codex project or just open Codex

The action is folder-only. It appears in Finder under Quick Actions or Services as `Open in Codex`.

## Install

Requirements:

- macOS
- Codex Desktop installed at `/Applications/Codex.app`
- the `codex` CLI available somewhere on the normal shell path, Homebrew paths, or nvm Node paths
- Node.js 20 or newer for running the installer and tests

From this repository:

```bash
npm test
npm run install:quick-action
```

Then right-click a folder in Finder and choose `Quick Actions` or `Services` > `Open in Codex`.

## Install With Codex

Paste this prompt into Codex from a checkout of this repository:

```text
Install this macOS Finder Quick Action for me.

Repository goal:
- Install the helper from ./lib/codex-open-folder.mjs to ~/.codex/bin/codex-open-folder.mjs.
- Create or replace ~/Library/Services/Open in Codex.workflow.
- Register it as a Finder-only Quick Action named "Open in Codex".
- Restrict it to folders only with NSSendFileTypes = public.folder.
- Use Codex.app's bundled Node runtime when available, falling back to node on PATH.
- Refresh macOS Services after installation.

Before changing anything, inspect README.md, package.json, scripts/install.mjs, lib/codex-open-folder.mjs, and test/codex-open-folder.test.mjs.
Do not read, print, or summarize secrets or token-bearing config files.

Run:
- npm test
- npm run install:quick-action
- plutil -lint ~/Library/Services/Open\ in\ Codex.workflow/Contents/Info.plist
- plutil -lint ~/Library/Services/Open\ in\ Codex.workflow/Contents/document.wflow

After installing, verify:
- the Services registry contains "Open in Codex"
- the service is Finder-only
- the service accepts public.folder
- Finder shows "Open in Codex" in the Services or Quick Actions menu for a selected folder

Report the exact verification results.
```

## How It Chooses What To Open

The helper does not guess from file names, Git repos, or package manifests. It uses Codex Desktop's local state and exact folder paths.

1. It normalizes the selected Finder folder to an absolute path and also tries the folder's real path, so symlinked selections can still match.
2. It checks `~/.codex/state_5.sqlite` for the newest unarchived thread whose `cwd` exactly matches one of those folder paths.
3. If a matching thread exists, it opens `codex://threads/<thread-id>`.
4. If no exact thread exists, it checks `~/.codex/.codex-global-state.json` for `electron-saved-workspace-roots`.
5. If the folder is already saved as a Codex project, it runs `codex app "$folder"`.
6. If the folder is neither a known chat nor a saved project, it asks what to do.

For a new folder, the prompt has three outcomes:

- `Open Project`: runs `codex app "$folder"` so Codex opens that folder as a workspace.
- `Open Codex`: opens Codex Desktop without attaching the folder.
- `Cancel`: does nothing.

This exact-match behavior is intentional. It avoids opening a nearby, parent, child, or similarly named folder's chat by accident.

## Files

- `lib/codex-open-folder.mjs`: the Finder helper CLI
- `scripts/install.mjs`: installs the helper and Automator workflow
- `test/codex-open-folder.test.mjs`: behavior tests for the routing logic

## Development

Run the tests:

```bash
npm test
```

Dry-run the installer without writing files:

```bash
node scripts/install.mjs --dry-run
```

The installer creates:

- `~/.codex/bin/codex-open-folder.mjs`
- `~/Library/Services/Open in Codex.workflow`

It also copies the Codex app icon into the workflow when it can find one.

## Troubleshooting

If `Open in Codex` does not appear in Finder, run the installer again, then log out and back in if macOS still has an old Services cache.

If selecting a folder shows a missing CLI dialog, install or expose the Codex CLI so `codex app "$folder"` works from a normal shell.

If Codex changes its local state file names or schema, the helper will stop finding existing chats and will fall back to the saved-project or prompt behavior.
