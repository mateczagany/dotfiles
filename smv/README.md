# smv: Claude Code in one smolvm machine per repo

Each git repo gets its own small Linux VM (a [smolvm](https://github.com/smol-machines/smolvm) machine named `cc-<repo>`), and Claude Code runs inside it with `--dangerously-skip-permissions`. The machine sees only its repo, a few shared folders and the internet. Your LAN, VPN and the Mac's own ports stay out of reach. Everything a machine sends goes through a proxy on the Mac that logs each request and refuses the ones that carry your personal information.

Repos and worktrees are mounted at the same path they have on the Mac, so every path Claude prints also opens on the Mac.

## Requirements

- An Apple Silicon Mac
- smolvm 1.34 or later: `brew install smol-machines/tap/smolvm`
- `brew install jq fzf bat mitmproxy`
- tmux, with `~/.local/bin` on the PATH tmux starts with
- A Claude Pro or Max plan, or an API key

## Install

```bash
bash ~/dev/repos/dotfiles/smv/install.sh
```

This links this folder to `~/.config/smv` and each script in `bin/` into `~/.local/bin`, and adds the memory guard hook (see [Claude memory](#claude-memory)) to `~/.claude/settings.json`. It prints a line for each thing it links, adds or skips. It is safe to run again, never replaces a real file, and copies `settings.json` to `settings.json.bak-smv-…` before changing it.

Then, once per Mac:

```bash
# Claude token (one year), stored in Keychain; the egress proxy adds it to requests to Anthropic
claude setup-token
security add-generic-password -U -a "$USER" -s claude-code-oauth -w

# Optional: a read-only, fine-grained GitHub token for gh and git fetch in the machines,
# also added by the egress proxy
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
| `bin/smv` | Creates, starts and enters machines; adds missing mounts; starts the egress proxy |
| `egress.py` | The egress proxy: a mitmproxy addon that is also smolvm's egress decider |
| `Smolfile` | The machine definition: image, CPUs, memory, network, first-start setup |
| `ro-mounts` | Mac folders every machine sees read-only, one per line (`~/…` works) |
| `rw-mounts` | Same, read-write |
| `repos/cc-<repo>.init` | Extra first-start commands for one repo's machine, one per line, run as root |
| `shared/` | Mounted read-only at `/opt/smv` in every machine |
| `shared/claude-start` | Runs before every Claude start in a machine (see below) |
| `shared/CLAUDE.md` | Rules for Claude in the machines: environment, Docker |
| `shared/CLAUDE.global.md` | Your global instructions, used on the Mac and in every machine |
| `shared/gitignore` | Global git ignores: `.worktrees/` |
| `shared/docker-runc` | Docker's runc in the machines: gives each container the egress proxy's CA |
| `shared/setup.d/*.sh` | Your setup steps, run as `dev` at a machine's first start, then before every Claude start and every `smv sh` |
| `shared/shell-start` | What `smv sh` runs: `setup.d/`, then `shell-setup`, then zsh (bash if zsh isn't there) |
| `shared/shell-setup` | Installs zsh, oh-my-zsh and Neovim in a machine and links your `.zshrc` and `nvim/` from this repo |
| `shared/zshrc` | `~/.zshrc` in the machines: sources this repo's `.zshrc`, with stand-ins for the macOS commands it calls |
| `shared/bin/`, `shared/nvim-clipboard.lua` | `pbcopy` and `pbpaste` for the machines, and nvim's clipboard there (see below) |

Not in this folder, on purpose: Keychain items, the egress proxy's files in `~/.local/state/smv`, each repo's `.git/info/exclude`, and anything inside the machines.

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
smv log [N]               # follow what the machines send, starting N lines back
smv proxy                 # restart the egress proxy
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

## Inside a machine

- User `dev` with your Mac's uid (501) and passwordless sudo. `/home/dev` lives on the machine's disk and survives stops; `/tmp` does not.
- Temurin 21, Maven, Python 3.14 with `uv`, Docker (daemon inside the machine; `docker`, `docker compose` and Testcontainers work without sudo), `gh` from `setup.d/github.sh`.
- Network: HTTP and HTTPS to the internet, through the egress proxy; LAN, VPN ranges and the Mac's own ports closed (`block_private`). Other TCP (SSH, databases on the internet) and UDP other than DNS are blocked.
- `CLAUDE_CODE_OAUTH_TOKEN` and `GH_TOKEN` hold placeholders, not the tokens.
- Mounts: the repo at its Mac path, `shared/` at `/opt/smv`, `~/.claude/skills` at `/opt/claude-skills`, the repo's Claude memory folder read-write at its Mac path, plus `ro-mounts` and `rw-mounts` at their Mac paths.
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

## Egress proxy

`smv` starts every machine with smolvm's [mediated egress](https://github.com/smol-machines/smolvm/blob/main/docs/mediated-egress.md): smolvm hands each outbound TCP connection to `egress.py`, which runs in `mitmdump` on the Mac (smolvm talks to it on 127.0.0.1:47130, mitmproxy listens on 47131). Opening a machine starts the proxy in the background if it isn't running, and `smv proxy` restarts it. While it's down, every connection from the machines is refused.

The proxy decrypts HTTPS with its own CA. Machines that `smv` creates trust it: `--trust-host-certs` points `SSL_CERT_FILE`, `NODE_EXTRA_CA_CERTS` and the like at it, and the first start adds it to the system store and Java's keystore. For each request the proxy:

- writes a line to `~/.local/state/smv/egress.log` with the time, machine, method, URL, status, bytes sent and, for a refused one, the reason. Bodies aren't logged. `smv log` follows the file.
- answers 403 itself, without sending anything, if the URL, a header or the body contains a line of `~/.local/state/smv/personal`. Requests to Anthropic (`anthropic.com`, `claude.ai`, `claude.com` and their subdomains) skip this check: they carry the whole conversation, which holds your name and email as soon as Claude reads a `git log`, and blocking them would end the session.
- puts the real Claude or GitHub token, read from Keychain when the proxy starts, in place of the placeholder the machine sent. That happens only in the `Authorization` header, and only on connections where mitmproxy verified the server's certificate for an Anthropic or GitHub host name.

Connections that aren't HTTP (SSH, a database protocol) are closed before a byte crosses in either direction, and logged as `not HTTP`.

The first start creates `personal` from your global git `user.email` and `user.name`. Add anything else you want kept in, one per line: phone numbers, your address, other email addresses. Matching ignores case and also looks in URL-encoded, JSON-escaped and base64 text. A space in a line matches any run of spaces, `+`, `_`, `.` or `-`, so `Jane Doe` also catches `jane.doe`. A line starting with `re:` is a regular expression. The proxy re-reads the file when it changes.

What it doesn't stop:

- A model trying to leak on purpose: the email spelled backwards, split across two requests, or encoded some other way. The check catches your email pasted into a curl, a WebFetch or a GitHub comment.
- DNS: lookups go through smolvm's resolver, not the proxy, so a name like `<data>.example.com` hands the data to that domain's name server.
- Claude's server-side tools, such as web search, which run at Anthropic after the request has left.

Docker containers have their own trust stores, so `shared/docker-runc` adds the CA to each one. The Smolfile links it to `/usr/local/sbin/runc`, ahead of the real runc on dockerd's `PATH`, and dockerd uses it for `docker run`, compose, Testcontainers and `docker build` steps. Before a container starts, it:

- mounts the machine's CA bundle at `/dev/smv-egress-ca.pem` and points `SSL_CERT_FILE`, `REQUESTS_CA_BUNDLE`, `CURL_CA_BUNDLE`, `NODE_EXTRA_CA_CERTS`, `PIP_CERT`, `GIT_SSL_CAINFO` and three more at it, in the container and in `docker exec`. If the image pointed one of them at its own bundle, that bundle is added to the container's copy. Nothing lands in a built image: `/dev` is a fresh tmpfs in every container, and the variables aren't saved in the image config.
- mounts the machine's Java keystore, read-only, over the image's, when the image sets `JAVA_HOME`. It follows symlinks inside the image, so Corretto's and UBI's keystores under `/etc/pki` work too.

That covers curl, apk, pip, Python, Node and Java 8 to 21 in containers. What still fails:

- A `keytool -importcert` in a container or a `RUN` step: "Read-only file system". On RHEL-family images `update-ca-trust` prints "couldn't complete writing file" for the keystore but exits 0.
- Programs that ignore those variables and read the image's own CA file, such as apt over HTTPS. Debian and Ubuntu images use HTTP mirrors by default.
- `sudo` inside a container, which clears the variables.

Keep `~/.local/state/smv` out of `ro-mounts` and `rw-mounts`: it holds the CA's private key and the token smolvm presents to the proxy. If you delete its `mitmproxy/` folder, the proxy makes a new CA and every machine needs a rebuild.

## Changing things

| You edit | Takes effect |
| --- | --- |
| `shared/` (CLAUDE files, `claude-start`, `setup.d/`) | Next Claude start, in every machine |
| `shared/` shell files, this repo's `.zshrc` and `nvim/` | Next `smv sh` (or nvim start), in every machine. To update Neovim in one: `rm -rf ~/.local/nvim` in it, then `smv sh` |
| `ro-mounts`, `rw-mounts` | Next time `smv` opens a machine: attached right away if it's running, added for good at its next start from stopped |
| `bin/` | Immediately |
| `egress.py`, `~/.local/state/smv/personal` | Immediately: the proxy reloads both when they change |
| `shared/docker-runc` | The next container started, in machines made since it was added |
| A token in Keychain | `smv proxy` |
| `Smolfile`, `repos/*.init` | New machines only. To rebuild one: `smv rm && smv up`, which loses its Claude history, caches and Docker images (its memory is on the Mac and stays) |
| The memory guard in `install.sh` | Run `install.sh` again: it replaces the hook it added before |
| CPUs or memory of one machine | `smv stop`, then `smolvm machine update --name cc-<repo> --cpus 8 --mem 16384` |

Claude working in this repo's own machine (`cc-dotfiles`) edits the live files every machine runs, and changes apply before you commit. That includes `egress.py`, so it can turn off its own filter. Check `git diff` after such a session.

## Security notes

- The Claude and GitHub tokens stay on the Mac. Machines hold placeholders, and the egress proxy puts the tokens in on verified connections to Anthropic and GitHub, so the agent can use them there but can't read them. Keep the GitHub token read-only and limited to the repos it needs.
- The machines have no SSH keys; you push from the Mac.
- Credentials for private Maven or Gradle repositories, if needed, live inside the machine where the agent can read them.
- Each machine can write its repo's Claude memory folder on the Mac, which Claude on the Mac reads. See [Claude memory](#claude-memory) for what the memory guard catches and what it doesn't.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| Start fails with "agent did not become ready" | A mount folder is gone (a repo renamed, the `~/.config/smv` link removed). Restore it, or `smolvm machine delete --name cc-<old> --force` |
| `smv`: "is outside … so the machine can't see it" | Move the worktree under `.worktrees/` |
| Claude asks to log in, or 401 | The token expired: `claude setup-token`, store it again with `security add-generic-password -U …`, then `smv proxy` |
| `smv`: "… predates the egress proxy" | The machine was made before the proxy and doesn't trust its CA: `smv rm && smv up`, which loses its Claude history, caches and Docker images |
| `smv`: "the egress proxy did not start" | `tail ~/.local/state/smv/proxy.out`. If another program holds port 47130 or 47131, pick other ports with `SMV_EGRESS_PORT`, after `smv stop-all` |
| Every request from the machines fails | The proxy stopped: `smv proxy`. `smv log` shows whether requests reach it |
| A 403 "Blocked by the smv egress proxy" | `smv log` names the line of `~/.local/state/smv/personal` that matched |
| A skill or `~/…` import is missing in a machine | Add its folder to `ro-mounts`; check with `ls -l ~/dev/…` in `smv sh` after a Claude start |
| `smv: adding mount …` on every open | smolvm changed its `machine ls -v` output, which `smv` reads |
| `smv`: "gave up waiting for …lock" | A killed `smv` left its lock: `rmdir "$TMPDIR"/smv-cc-*.lock` |
| `docker` can't connect | `sudo tail /var/log/dockerd.log` in the machine |
| `smv sh` opens bash, not zsh | `shell-setup` failed; its error is printed above the prompt. Run `sh /opt/smv/shell-setup` in that bash to retry |
| Writes to the repo fail with "Operation not permitted" | The uid in the Smolfile isn't `id -u` on the Mac |
| `memory.sh: both this machine and the Mac have …` | Merge the files it names from the machine's folder into the Mac's, delete the machine's folder (both paths are in the message), then start Claude again |
| A Mac Claude session warns "smv memory guard: deleted …" | A machine put a symlink or special file in that memory folder. The path names the repo; check what that repo's machine was doing |
| `install.sh`: "skip … memory guard hook not added" | The reason is on the same line. Fix it and run `install.sh` again |
