# Network

The internet is reachable from this machine. The user's LAN, VPN and Mac are not.

There are no SSH keys here: use HTTPS git remotes, not SSH. `gh` and git reach GitHub with read-only tokens, so the user pushes from their Mac. There is one token per owner: `gh` here is a wrapper (`/opt/smv/bin/gh`) that picks the token of the owner named in its arguments, or else of this repo's remotes. If a private repo answers 404, run the command from that repo or name it as `OWNER/REPO`.

# Read-only folders

Folders mounted read-only from the user's Mac (`grep virtiofs /proc/mounts` marks them `ro`) reject every write, including the `-shm` file SQLite creates next to a database in WAL mode. So `sqlite3 DB`, `sqlite3 -readonly DB` and `?mode=ro` all fail there with "unable to open database file". Open such a database as `sqlite3 'file:/path/to/DB?immutable=1'`. That reads only the main file: while a program on the Mac has the database open, its newest writes can sit in the `-wal` file and won't show up. Say so when the answer depends on recent data.
