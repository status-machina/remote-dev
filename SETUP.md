# Remote Dev Container Setup

## 1. Build & Push the Image

```bash
docker build -t remote-dev .
```

Or let Coolify build from your Git repo directly.

## 2. Environment Variables (Coolify)

| Variable | Required | Example |
|----------|----------|---------|
| `ANTHROPIC_API_KEY` | Yes | `sk-ant-...` |
| `SSH_PUBLIC_KEY` | Yes | Contents of your public key (see step 3) |
| `GIT_USER_NAME` | Yes | `Dallas Hall` |
| `GIT_USER_EMAIL` | Yes | `dallas.hall@gmail.com` |
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | No | `1` |

## 3. Local SSH Key Setup

Generate a dedicated key for the dev box:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_devbox -C "devbox"
```

Copy the public key content — this goes into the `SSH_PUBLIC_KEY` env var in Coolify:

```bash
cat ~/.ssh/id_ed25519_devbox.pub
```

Add to your `~/.ssh/config`:

```
Host dev-box
    HostName <server-ip>
    User developer
    Port 4567
    IdentityFile ~/.ssh/id_ed25519_devbox
```

## 4. Volume Configuration (Coolify)

| Source (Host) | Destination (Container) | Purpose |
|---------------|------------------------|---------|
| Persistent volume | `/home/developer/projects` | Code, worktrees, deploy keys |
| Persistent volume | `/etc/ssh/host_keys` | SSH host keys (survive rebuilds) |

## 5. Port Mapping

| Host Port | Container Port | Protocol |
|-----------|---------------|----------|
| `4567` | `22` | TCP |

## 6. GitHub Deploy Key

On first boot, the container generates a deploy key. Find it in the container logs:

```
=============================================
  GitHub Deploy Key (add to GitHub):
=============================================
ssh-ed25519 AAAA... devbox-deploy-key
=============================================
```

Add this key to your GitHub repo(s):
1. Go to **Settings > Deploy keys > Add deploy key**
2. Paste the public key
3. Check **Allow write access** if you need to push

The key persists across container rebuilds via the projects volume.

## 7. Connect with Zed

1. Open Zed
2. `Cmd+Shift+P` -> **Remote Projects: Connect to SSH Host**
3. Select `dev-box` (from your SSH config)
4. Open `/home/developer/projects`

## 8. Using Worktrees

From inside any cloned repo:

```bash
cd /home/developer/projects/my-repo
wt-new feature-branch
# Creates: /home/developer/projects/my-repo--feature-branch
```

## Verification Checklist

- [ ] `ssh dev-box` connects without password prompt
- [ ] `ssh dev-box "claude --version"` returns a version string
- [ ] `ssh dev-box "git config user.name"` returns configured name
- [ ] Container logs show the GitHub deploy key public key
- [ ] `ssh dev-box "git clone git@github.com:<user>/<repo>.git /home/developer/projects/<repo>"` succeeds after adding deploy key
- [ ] `ssh dev-box "cd /home/developer/projects/<repo> && wt-new test-branch"` creates a worktree
- [ ] Zed connects and can open `/home/developer/projects`
- [ ] Running `claude` in Zed terminal starts Claude Code with API key
