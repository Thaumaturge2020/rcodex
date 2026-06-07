# Copy to ~/.rcodex/config.sh and edit.

# SSH target. Use a Host alias from ~/.ssh/config (recommended) so key/port/user
# are handled there and SSH is passwordless — rcodex makes one SSH call per command.
REMOTE_HOST="myserver"

# Project directory on the remote.
REMOTE_DIR="/home/me/projects/foo"

# Local mountpoint (auto-created). Codex will run with this as its working dir.
LOCAL_MOUNT="$HOME/.rcodex/mnt/foo"

# Prepended to EVERY remote command. Each command is a fresh SSH session, so put
# environment activation here rather than relying on it persisting across calls.
RCODEX_INIT=""                 # e.g. "conda activate scbio"  or  "source .venv/bin/activate"

# Optional SSH transport override.
#
# WSL case: if Windows can reach the target but WSL cannot, use Windows OpenSSH:
# RCODEX_SSH_COMMAND="/mnt/c/Windows/System32/OpenSSH/ssh.exe"
# RCODEX_SSH_CONTROLMASTER="no"
#
# Real jump-host case:
# RCODEX_SSH_PROXY_JUMP="user@jump-host"
# Or, for custom stdio forwarding:
# RCODEX_SSH_PROXY_COMMAND="ssh user@jump-host -W %h:%p"
RCODEX_SSH_COMMAND="ssh"
RCODEX_SSH_CONTROLMASTER="auto"
RCODEX_SSH_PROXY_JUMP=""
RCODEX_SSH_PROXY_COMMAND=""

# Extra ssh/sshfs options if needed. Keep this simple; put complex settings
# (ProxyJump, quoted paths, multiple identities, etc.) in ~/.ssh/config.
RCODEX_SSH_EXTRA=""            # e.g. "-o IdentitiesOnly=yes"
