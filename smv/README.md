# smv: Claude Code in one smolvm machine per repo

Each git repo gets its own small Linux VM (a [smolvm](https://github.com/smol-machines/smolvm) machine named `cc-<repo>`), and Claude Code runs inside it with `--dangerously-skip-permissions`. The machine sees only its repo, a few shared folders and the internet. Your LAN, VPN and the Mac's own ports stay out of reach.

Repos and worktrees are mounted at the same path they have on the Mac, so every path Claude prints also opens on the Mac.

## Requirements

- An Apple Silicon Mac
- smolvm 1.34 or later: `brew install smol-machines/tap/smolvm`
- `brew install jq fzf bat`
- tmux, with `~/.local/bin` on the PATH tmux starts with
- A Claude Pro or Max plan, or an API key

## Install

```bash
bash ~/dev/repos/dotfiles/smv/install.sh
```

This links this folder to `~/.config/smv` and each script in `bin/` into `~/.local/bin`, and adds the memory guard hook (see [Claude memory](#claude-memory)) to `~/.claude/settings.json`. It prints a line for each thing it links, adds or skips. It is safe to run again, never replaces a real file, and copies `settings.json` to `settings.json.bak-smv-…` before changing it.

Then, once per Mac:

```bash
# Claude token (one year), stored in Keychain; smv passes it to the machines as CLAUDE_CODE_OAUTH_TOKEN
claude setup-token
security add-generic-password -U -a "$USER" -s claude-code-oauth -w

# Optional: a read-only, fine-grained GitHub token for gh and git fetch in the machines,
# passed as GH_TOKEN
# (Contents, Pull requests, Issues: Read; limited to the repos you need)
security add-generic-password -U -a "$USER" -s github-readonly -w

# ~/.claude/CLAUDE.md is just this import; your global instructions live in shared/
echo '@~/.config/smv/shared/CLAUDE.global.md' > ~/.claude/CLAUDE.md

# Ignore worktrees in every repo, on the Mac too
git config --global core.excludesFile '~/.config/smv/shared/gitignore'
```

Keep the `~/.config/smv` link for good. Existing machines store the full path of `~/.config/smv/shared` as a mount, and smolvm won't start a machine whose mount folder is gone.

## What's here

| Path | What it does |
| --- | --- |
| `install.sh` | Links this folder and `bin/` into place; adds the memory guard hook to `~/.claude/settings.json` |
| `bin/smv` | Creates, starts and enters machines; adds missing mounts; passes the tokens in |
| `Smolfile` | The machine definition: image, CPUs, memory, network, first-start setup |
| `ro-mounts` | Mac folders machines see read-only, one per line (`~/…` works); a `[PATH]` line limits the next ones to repos inside PATH (see [Mount lists](#mount-lists)) |
| `rw-mounts` | Same, read-write |
| `ro-mounts.local`, `rw-mounts.local` | Same as the two above, but git-ignored: for paths you'd rather not commit |
| `repos/cc-<repo>.init` | Extra first-start commands for one repo's machine, one per line, run as root |
| `shared/` | Mounted read-only at `/opt/smv` in every machine |
| `shared/claude-start` | Runs before every Claude start in a machine (see below) |
| `shared/CLAUDE.md` | Rules for Claude in the machines: environment, Docker |
| `shared/CLAUDE.global.md` | Your global instructions, used on the Mac and in every machine |
| `shared/gitignore` | Global git ignores: `.worktrees/` |
| `shared/setup.d/*.sh` | Your setup steps, run as `dev` at a machine's first start, then before every Claude start and every `smv sh` |
| `shared/shell-start` | What `smv sh` runs: `setup.d/`, then `shell-setup`, then zsh (bash if zsh isn't there) |
| `shared/shell-setup` | Installs zsh, oh-my-zsh and Neovim in a machine and links your `.zshrc` and `nvim/` from this repo |
| `shared/zshrc` | `~/.zshrc` in the machines: sources this repo's `.zshrc`, with stand-ins for the macOS commands it calls |
| `shared/bin/`, `shared/nvim-clipboard.lua` | `pbcopy` and `pbpaste` for the machines, and nvim's clipboard there (see below) |

Not in this folder, on purpose: Keychain items, each repo's `.git/info/exclude`, and anything inside the machines.

## Daily use

```bash
smv claude [DIR] [ARGS]   # Claude in this folder's machine (e.g. smv claude --continue)
smv sh [DIR]              # your zsh in the machine, as dev
smv root [DIR]            # root shell in the machine
smv up [DIR]              # create or start the machine, nothing else
smv state [DIR]           # running, stopped, or empty if there is none
smv stop [DIR]            # stop this repo's machine
smv rm [DIR]              # delete it, with its disk
smv ls                    # all machines
smv stop-all              # stop every cc-* machine
```

`DIR` defaults to the current folder and can be any worktree. The first `smv` call in a repo creates its machine; the first start installs everything and takes a few minutes.

The tmux bindings (in `~/.tmux.conf`, not here): `prefix C` Claude here, `prefix R` resume the last chat here, `prefix V` a machine shell. The fzf session switcher opens a `claude` window in every git repo's session. Inside tmux, `smv claude`, `smv sh` and `smv root` rename their window to the machine's name plus the command (`cc-api-claude`, `cc-api-sh`, `cc-api-root`) until Claude or the shell exits, then put the old name back.

## Worktrees

Put them inside the repo, under `.worktrees/`:

```bash
git worktree add .worktrees/fix-billing -b fix-billing
git worktree move ../api-fix-billing .worktrees/fix-billing   # an existing sibling worktree
```

A worktree's `.git` file points back to the main repo by absolute path, and only the main checkout is mounted. Sibling worktrees (`~/dev/repos/api-fix-billing`) are outside the machine, and `smv` refuses them.

## Mount lists

`ro-mounts`, `rw-mounts` and their `.local` versions name Mac folders to mount at the same path, one per line. A `[PATH]` line limits the lines after it, up to the next `[…]` line, to machines whose repo is inside PATH, and `[*]` goes back to every machine. With this in `ro-mounts.local`, each machine for a repo in `~/dev/work` sees the other repos there and a library they use, read-only, and other machines see neither:

```
[~/dev/work]
~/dev/work
~/dev/repos/some-library
```

A folder that holds the repo, like `~/dev/work` for `~/dev/work/api`, is mounted around it, and the repo stays read-write inside. smolvm mounts parent folders first when a machine starts, but attaching one to a running machine would cover the repo, so `smv` adds such a folder only while the machine is stopped and otherwise prints that you need to `smv stop` first. `smv` skips a line that is the repo or inside it, a folder that doesn't exist, and a folder inside another one listed with the same mode.

Keep other repos read-only. A machine that can write a repo's `.git/hooks` or `.git/config` can run commands on the Mac the next time you use git there.

A mount alone doesn't make Claude look there. Claude reads a `CLAUDE.md` in every parent folder of the one it starts in, so a `~/dev/work/CLAUDE.md` that says what the mounted repos are, and how to read the version this repo depends on, reaches every machine for a repo in `~/dev/work` and Claude on the Mac.

## Inside a machine

- User `dev` with your Mac's uid (501) and passwordless sudo. `/home/dev` lives on the machine's disk and survives stops; `/tmp` does not.
- Temurin 21, Maven, Python 3.14 with `uv`, `sqlite3`, `duckdb` (the latest CLI from GitHub, for Parquet), Docker (daemon inside the machine; `docker`, `docker compose` and Testcontainers work without sudo), `gh` from `setup.d/github.sh`.
- Network: the internet is open; LAN, VPN ranges and the Mac's own ports are closed (`block_private`).
- `CLAUDE_CODE_OAUTH_TOKEN` and `GH_TOKEN` hold the tokens from Keychain. `smv` reads both each time it starts Claude or a shell in a machine, so nothing in the machine stores them.
- Mounts: the repo at its Mac path, `shared/` at `/opt/smv`, `~/.claude/skills` at `/opt/claude-skills`, the repo's Claude memory folder read-write at its Mac path, plus the folders in `ro-mounts`, `rw-mounts` and their `.local` versions that apply to this repo, at their Mac paths.
- A SQLite database in WAL mode won't open from a read-only mount the usual way: SQLite needs to create its `-shm` file next to it. `sqlite3 'file:PATH?immutable=1'` works, and `shared/CLAUDE.md` tells Claude so. It reads only the main file, so writes a Mac program still holds in the `-wal` file don't show up until that program checkpoints or closes the database.
- `smv sh` opens zsh with this repo's `.zshrc` and nvim with its `nvim/` config, both read from the `~/dev/repos/dotfiles` mount, so an edit on the Mac shows up at the next shell or nvim start. A machine's first start runs `shell-setup`, which installs oh-my-zsh with the theme and plugins the `.zshrc` loads, Neovim from GitHub (the config needs 0.12, Ubuntu has 0.11), and nvim's plugins and treesitter parsers. Every `smv sh` runs it again, so whatever failed at the first start gets installed then.
- The prompt uses `.p10k.zsh` from this repo if there is one, and p10k's defaults otherwise. Either way it starts with the machine's name (`cc-<repo>`) in yellow, set in `shared/zshrc`, so a machine shell doesn't look like the Mac's.
- There is no system clipboard. `pbcopy`, `pbpaste` and nvim's `+` register share `~/.cache/smv-clipboard`, so the vi-mode `y` and `p` in zsh and yanks in nvim work together inside one machine. Each copy is also sent as OSC 52, which reaches the Mac clipboard only if `~/.tmux.conf` has `set -g set-clipboard on`.

`claude-start` runs before each Claude start and:

1. marks the worktree and its main checkout as trusted, and skips onboarding
2. sets the dark theme and the classic (non-fullscreen) UI unless you chose others, and turns off the bypass-mode confirmation
3. links your Mac's skills into `~/.claude/skills`, keeping links a skill's own installer made
4. imports `CLAUDE.global.md` and `CLAUDE.md` from `/opt/smv`
5. runs every `setup.d/*.sh`; a failing one prints a line and Claude starts anyway. `home-links.sh` links each folder mounted from your Mac home at the same place under `/home/dev`, so `~/…` paths mean the same thing on both sides, and `memory.sh` points Claude's memory folder at the Mac's
6. starts Claude on Opus at `xhigh` effort; `/model` and `/effort` change one session only

## Claude memory

Claude keeps a repo's auto memory in `~/.claude/projects/<key>/memory`, where `<key>` is the main checkout's path with every character other than letters and digits turned into `-` (`-Users-you-dev-repos-api`). Worktrees use the main checkout's folder. `smv` creates that folder on the Mac and mounts it read-write into the repo's machine at the same path, and `setup.d/memory.sh` links the machine's `~/.claude/projects/<key>/memory` to it. Claude in the machine and Claude on the Mac read and write one set of memories, and they survive `smv rm`. Each session reads `MEMORY.md` when it starts, so what one session writes reaches the others at their next start.

A machine sees only its own repo's memory folder: not the Mac's transcripts, and not other repos' memory.

Machines made before this had their own memory folder. At the first Claude start after `smv` adds the mount, `memory.sh` moves those memories into the Mac's folder, appends the machine's `MEMORY.md` lines the Mac's lacks, and replaces the folder with the link. It never overwrites a Mac file: when both sides have a file with the same name, it names the file and leaves the machine's folder alone until you merge it.

Claude adds a hash to keys over 200 characters, which `smv` doesn't compute, so a repo with a path that long keeps its memory in the machine.

What a machine can do with the folder: write memories that Claude on the Mac reads at its next start in that repo, delete them, or plant a symlink. Claude follows symlinks, so a `MEMORY.md` linked to `~/.ssh/id_ed25519` would load the key into a Mac session. The memory guard, a `SessionStart` hook that `install.sh` adds to `~/.claude/settings.json` on the Mac, deletes symlinks and other non-regular files from every memory folder before Claude reads them, and shows a warning naming what it deleted. It runs only when a session starts, so a link planted during a Mac session can still reach a topic file that session reads later. Write access to the repo already gives a machine as much: a symlinked `CLAUDE.local.md` loads the same way, and `.git/config` and `.git/hooks` can run commands on the Mac at your next `git status` or commit there.

## Changing things

| You edit | Takes effect |
| --- | --- |
| `shared/` (CLAUDE files, `claude-start`, `setup.d/`) | Next Claude start, in every machine |
| `shared/` shell files, this repo's `.zshrc` and `nvim/` | Next `smv sh` (or nvim start), in every machine. To update Neovim in one: `rm -rf ~/.local/nvim` in it, then `smv sh` |
| `ro-mounts`, `rw-mounts` and their `.local` versions | Next time `smv` opens a machine: attached right away if it's running, added for good at its next start from stopped. A folder that holds the repo or another mount is added only from stopped: `smv stop`, then open it |
| `bin/` | Immediately |
| A token in Keychain | Next `smv claude`, `smv sh` or `smv root`; a Claude that is already running keeps the old one |
| `Smolfile`, `repos/*.init` | New machines only. To rebuild one: `smv rm && smv up`, which loses its Claude history, caches and Docker images (its memory is on the Mac and stays) |
| The memory guard in `install.sh` | Run `install.sh` again: it replaces the hook it added before |
| CPUs or memory of one machine | `smv stop`, then `smolvm machine update --name cc-<repo> --cpus 8 --mem 16384` |

Claude working in this repo's own machine (`cc-dotfiles`) edits the live files every machine runs, and changes apply before you commit. Check `git diff` after such a session.

## Security notes

- The Claude and GitHub tokens are in the environment of Claude and of every shell `smv` opens in a machine. The agent can read them and send them anywhere on the internet. Keep the GitHub token read-only and limited to the repos it needs.
- The machines have no SSH keys; you push from the Mac.
- Credentials for private Maven or Gradle repositories, if needed, live inside the machine where the agent can read them.
- Each machine can write its repo's Claude memory folder on the Mac, which Claude on the Mac reads. See [Claude memory](#claude-memory) for what the memory guard catches and what it doesn't.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| Start fails with "agent did not become ready" | A mount folder is gone (a repo renamed, the `~/.config/smv` link removed). Restore it, or `smolvm machine delete --name cc-<old> --force` |
| `smv`: "is outside … so the machine can't see it" | Move the worktree under `.worktrees/` |
| Claude asks to log in, or 401 | The token expired: `claude setup-token`, store it again with `security add-generic-password -U …`, then start Claude again |
| A skill or `~/…` import is missing in a machine | Add its folder to `ro-mounts`; check with `ls -l ~/dev/…` in `smv sh` after a Claude start |
| `sqlite3`: "unable to open database file" for a database in a read-only mount | It's in WAL mode; open it as `sqlite3 'file:PATH?immutable=1'` (see [Inside a machine](#inside-a-machine)) |
| `smv: adding mount …` on every open | smolvm changed its `machine ls -v` output, which `smv` reads |
| `smv`: "gave up waiting for …lock" | A killed `smv` left its lock: `rmdir "$TMPDIR"/smv-cc-*.lock` |
| `docker` can't connect | `sudo tail /var/log/dockerd.log` in the machine |
| `smv sh` opens bash, not zsh | `shell-setup` failed; its error is printed above the prompt. Run `sh /opt/smv/shell-setup` in that bash to retry |
| Writes to the repo fail with "Operation not permitted" | The uid in the Smolfile isn't `id -u` on the Mac |
| `memory.sh: both this machine and the Mac have …` | Merge the files it names from the machine's folder into the Mac's, delete the machine's folder (both paths are in the message), then start Claude again |
| A Mac Claude session warns "smv memory guard: deleted …" | A machine put a symlink or special file in that memory folder. The path names the repo; check what that repo's machine was doing |
| `install.sh`: "skip … memory guard hook not added" | The reason is on the same line. Fix it and run `install.sh` again |
