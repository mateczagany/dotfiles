# GitHub CLI, and git over HTTPS with the tokens smv passes in. /opt/smv/bin/gh picks the
# token by the repo's owner, for gh and for git. Runs at every Claude start.
if [ ! -x /usr/bin/gh ]; then
  sudo env DEBIAN_FRONTEND=noninteractive sh -c 'mkdir -p -m 755 /etc/apt/keyrings &&
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /etc/apt/keyrings/githubcli-archive-keyring.gpg &&
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg &&
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list &&
    apt-get update -qq && apt-get install -yqq gh >/dev/null'
fi
mkdir -p "$HOME/.local/bin"
ln -sfn /opt/smv/bin/gh "$HOME/.local/bin/gh"
git config --global credential.https://github.com.helper '!/opt/smv/bin/gh auth git-credential'
git config --global credential.https://github.com.useHttpPath true   # so the helper sees the owner
git config --global --replace-all url.https://github.com/.insteadOf git@github.com: '^git@github\.com:$'
git config --global --replace-all url.https://github.com/.insteadOf ssh://git@github.com/ '^ssh://git@github\.com/$'
