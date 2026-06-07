# rcodex

Run Codex locally, execute shell commands on a remote machine.

`rcodex` is for remote development environments where the code, dependencies, or
GPUs live on an SSH host, but you want Codex authentication, sessions, and
conversation history to stay on your local machine.

It works by mounting one remote project directory locally with `sshfs`, then
launching the local `codex` CLI in that mounted directory. Shell commands started
by Codex are intercepted through a `bash`/`sh` shim and forwarded to the remote
host over SSH.

## Features

- Use your local Codex login.
- Keep Codex sessions and transcripts local.
- Read and edit remote files through `sshfs`.
- Execute Codex shell commands on the remote host.
- Support OpenSSH key authentication.
- Support `ProxyJump` and `ProxyCommand`.
- Support WSL setups where Windows can reach the target but WSL cannot, by using
  Windows `ssh.exe`.
- Keep separate Codex histories per local launch directory.
- Provide a `rcodex --doctor` diagnostic command.

## How It Works

`rcodex` has three layers:

1. Local Codex state:
   `rcodex` sets `CODEX_HOME` to `./.rcodex/codex-home` in the local directory
   where you start it.

2. Remote file view:
   `sshfs` mounts `REMOTE_HOST:REMOTE_DIR` at `LOCAL_MOUNT`.

3. Remote command execution:
   `rcodex` prepends a shim directory to `PATH`. When Codex runs `bash` or `sh`,
   the shim forwards the command to `REMOTE_HOST` and runs it inside
   `REMOTE_DIR`.

The result is:

- Codex auth, sessions, transcripts, and logs stay local.
- Project files live on the remote host.
- Build, test, and runtime logs produced by shell commands are produced on the
  remote host and streamed back to Codex.

## Directory Scope

One `rcodex` configuration mounts one remote directory:

```bash
REMOTE_DIR="/data/projects/foo"
LOCAL_MOUNT="$HOME/.rcodex/mnt/foo"
```

Codex starts in `LOCAL_MOUNT`, so it sees the contents of `REMOTE_DIR`.

This means:

- Subdirectories under `REMOTE_DIR` are part of the project.
- Paths outside `REMOTE_DIR` are not the intended workspace for that session.
- To work on another remote project, use another local launch directory and a
  different `./.rcodex/config.sh`.
- `sshfs -o follow_symlinks` can follow remote symlinks according to the remote
  account's filesystem permissions.

`rcodex` is not "SSH into a remote shell and run remote Codex". The correct
entry point is local:

```bash
rcodex
rcodex exec "fix the failing test"
```

`rcodex --shell` opens a raw remote shell for debugging. If you run `codex`
inside that shell, you are running the remote machine's Codex, not the local-auth
`rcodex` workflow.

## Sessions And Resume

`rcodex` stores Codex state under the local directory where it is launched:

```bash
CODEX_HOME="$PWD/.rcodex/codex-home"
```

For example:

- Launching from `~/work/foo` stores state in
  `~/work/foo/.rcodex/codex-home`.
- Launching from `~/work/bar` stores state in
  `~/work/bar/.rcodex/codex-home`.

Those histories are separate.

Resume from the same local launch directory:

```bash
rcodex resume
rcodex resume --last
rcodex exec resume --last "continue"
```

Do not use plain `codex resume` if you want rcodex sessions. Plain `codex
resume` usually reads the default `~/.codex`, while `rcodex resume` reads the
project-local `./.rcodex/codex-home`.

Diagnostic and transport commands do not create Codex sessions:

```bash
rcodex --doctor
rcodex --mount
rcodex --status
rcodex --shell
```

A resumable Codex session is created only when you run the Codex TUI or
`codex exec` through `rcodex`:

```bash
rcodex
rcodex exec "inspect this repository"
```

## Installation

Put `rcodex` and `remote-bash` in the same directory:

```bash
chmod +x rcodex remote-bash
ln -s "$PWD/rcodex" ~/.local/bin/rcodex
```

Required local tools:

```bash
ssh
sshfs
codex
base64
```

Check them with:

```bash
command -v ssh
command -v sshfs
command -v codex
command -v base64
```

Log in to Codex locally once:

```bash
codex login
```

If your Codex login uses an OS keyring and is not visible under the project
`CODEX_HOME`, run this once from the local project directory:

```bash
CODEX_HOME="$PWD/.rcodex/codex-home" codex login
```

## Configuration

Global config:

```bash
~/.rcodex/config.sh
```

Project config:

```bash
./.rcodex/config.sh
```

Project config wins when both exist.

Minimal example:

```bash
REMOTE_HOST="myserver"
REMOTE_DIR="/data/projects/foo"
LOCAL_MOUNT="$HOME/.rcodex/mnt/foo"

RCODEX_INIT=""
RCODEX_SSH_COMMAND="ssh"
RCODEX_SSH_CONTROLMASTER="auto"
RCODEX_SSH_PROXY_JUMP=""
RCODEX_SSH_PROXY_COMMAND=""
RCODEX_SSH_EXTRA=""
```

`RCODEX_INIT` is prepended to every remote shell command. Use it for environment
activation:

```bash
RCODEX_INIT="source .venv/bin/activate"
```

## SSH Authentication

`rcodex` does not implement its own password or key protocol. It reuses
OpenSSH. Configure key-based login first.

Example `~/.ssh/config`:

```sshconfig
Host myserver
  HostName 192.168.x.x
  User user
  IdentityFile ~/.ssh/id_ed25519
```

Verify passwordless SSH:

```bash
ssh myserver true
```

Then use the host alias:

```bash
REMOTE_HOST="myserver"
```

## SSH Transports

### Normal SSH

```bash
RCODEX_SSH_COMMAND="ssh"
RCODEX_SSH_CONTROLMASTER="auto"
RCODEX_SSH_PROXY_JUMP=""
RCODEX_SSH_PROXY_COMMAND=""
```

### ProxyJump

Use this when the target host is reachable through a jump host:

```bash
REMOTE_HOST="user@target.internal"
RCODEX_SSH_COMMAND="ssh"
RCODEX_SSH_CONTROLMASTER="auto"
RCODEX_SSH_PROXY_JUMP="user@jump-host"
```

Equivalent SSH command:

```bash
ssh -J user@jump-host user@target.internal
```

### ProxyCommand

Use this for custom stdio forwarding:

```bash
RCODEX_SSH_PROXY_COMMAND="ssh user@jump-host -W %h:%p"
```

Equivalent SSH command:

```bash
ssh -o 'ProxyCommand=ssh user@jump-host -W %h:%p' user@target.internal
```

### WSL With Windows `ssh.exe`

Use this when WSL cannot reach the target network, but Windows can:

```bash
REMOTE_HOST="user@192.168.x.x"
REMOTE_DIR="/data/projects/foo"
LOCAL_MOUNT="$HOME/.rcodex/mnt/foo"

RCODEX_SSH_COMMAND="/mnt/c/Windows/System32/OpenSSH/ssh.exe"
RCODEX_SSH_CONTROLMASTER="no"
RCODEX_SSH_PROXY_JUMP=""
RCODEX_SSH_PROXY_COMMAND=""
RCODEX_SSH_EXTRA=""
```

Verify from WSL:

```bash
/mnt/c/Windows/System32/OpenSSH/ssh.exe user@192.168.x.x 'hostname'
```

ControlMaster is disabled for Windows `ssh.exe` because WSL Unix socket
multiplexing is not reliable across the Windows process boundary.

`sshfs` uses the same transport through its `ssh_command` option.

## Usage

Run diagnostics:

```bash
rcodex --doctor
```

Mount the remote project:

```bash
rcodex --mount
```

Check status:

```bash
rcodex --status
```

Start the interactive Codex TUI:

```bash
rcodex
```

Run non-interactively:

```bash
rcodex exec "run the tests and fix the failure"
```

Resume:

```bash
rcodex resume
rcodex resume --last
rcodex exec resume --last "continue"
```

Open a raw remote shell for debugging:

```bash
rcodex --shell
```

Unmount and close the SSH master:

```bash
rcodex --umount
```

## Validate Remote Execution

Check the remote host and working directory:

```bash
rcodex --shell -lc 'hostname && pwd'
```

For GPU hosts:

```bash
rcodex exec "hostname && nvidia-smi -L"
```

The `pwd` printed by the remote shell should be `REMOTE_DIR`.

## Example: Compile And Run C++

```bash
rcodex --mount

cat > "$HOME/.rcodex/mnt/foo/hello.cpp" <<'CPP'
#include <iostream>

int main() {
  std::cout << "Hello from rcodex remote C++!" << std::endl;
  return 0;
}
CPP

rcodex --shell -lc 'g++ -std=c++17 hello.cpp -o hello && ./hello'
```

Expected output:

```text
Hello from rcodex remote C++!
```

## Security Notes

`rcodex` creates a project-local Codex home and configures:

```toml
sandbox_mode = "danger-full-access"
approval_policy = "never"
```

This is intentional: the local Codex sandbox would usually block SSH and sshfs
network access. In this workflow, the real boundary is the remote SSH account
and the mounted remote directory.

Use `rcodex` only with trusted repositories and trusted remote hosts.

Do not commit:

- `auth.json`
- SSH private keys
- `.rcodex/codex-home`
- real private hostnames or internal IPs
- sensitive paths in `config.sh`

## Troubleshooting

### `resume` does not show my session

Common causes:

1. You only ran `rcodex --doctor`, `rcodex --mount`, or `rcodex --shell`.
   These commands do not create Codex sessions.
2. You launched `rcodex` from a different local directory. Session history is
   stored under that directory's `./.rcodex/codex-home`.
3. You ran plain `codex resume` instead of `rcodex resume`.

### Commands run locally instead of remotely

Run:

```bash
rcodex exec "hostname && pwd"
```

If `hostname` prints your local machine, Codex may have spawned a command
without going through `bash` or `sh`. The current shim covers normal Codex shell
commands, which are issued through `bash -lc`.

### `ssh` works on Windows but times out in WSL

Use Windows OpenSSH from WSL:

```bash
RCODEX_SSH_COMMAND="/mnt/c/Windows/System32/OpenSSH/ssh.exe"
RCODEX_SSH_CONTROLMASTER="no"
```

### `rcodex --shell` works, but `codex` inside it uses remote auth

That is expected. `rcodex --shell` is a raw remote shell. Run `rcodex` from the
local terminal to use local Codex auth and local session storage.

## License

This project is licensed under the Apache License 2.0. See [LICENSE](LICENSE)
for details.
