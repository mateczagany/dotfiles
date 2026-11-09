# GitHub CLI, and git over HTTPS with the GH_TOKEN smv passes in. Runs at every Claude start.
if ! command -v gh >/dev/null; then
  sudo env DEBIAN_FRONTEND=noninteractive sh -c 'mkdir -p -m 755 /etc/apt/keyrings &&
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /etc/apt/keyrings/githubcli-archive-keyring.gpg &&
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg &&
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list &&
    apt-get update -qq && apt-get install -yqq gh >/dev/null'
fi
git config --global credential.https://github.com.helper '!gh auth git-credential'
git config --global --replace-all url.https://github.com/.insteadOf git@github.com: '^git@github\.com:$'
git config --global --replace-all url.https://github.com/.insteadOf ssh://git@github.com/ '^ssh://git@github\.com/$'
