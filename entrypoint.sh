#!/bin/bash
set -euo pipefail

# --- SSH Host Keys (persisted via /etc/ssh/host_keys volume) ---
if [ ! -f /etc/ssh/host_keys/ssh_host_ed25519_key ]; then
    echo "Generating SSH host keys..."
    ssh-keygen -A
    mkdir -p /etc/ssh/host_keys
    cp /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub /etc/ssh/host_keys/
else
    echo "Restoring persisted SSH host keys..."
    cp /etc/ssh/host_keys/ssh_host_*_key /etc/ssh/
    cp /etc/ssh/host_keys/ssh_host_*_key.pub /etc/ssh/
    chmod 600 /etc/ssh/ssh_host_*_key
fi

# --- Authorized Keys ---
if [ -n "${SSH_PUBLIC_KEY:-}" ]; then
    mkdir -p /home/developer/.ssh
    echo "$SSH_PUBLIC_KEY" > /home/developer/.ssh/authorized_keys
    chmod 700 /home/developer/.ssh
    chmod 600 /home/developer/.ssh/authorized_keys
    chown -R developer:developer /home/developer/.ssh
    echo "SSH public key installed."
else
    echo "WARNING: SSH_PUBLIC_KEY not set. You won't be able to SSH in."
fi

# --- Git Identity ---
if [ -n "${GIT_USER_NAME:-}" ]; then
    su - developer -c "git config --global user.name '$GIT_USER_NAME'"
    echo "Git user.name set to: $GIT_USER_NAME"
fi
if [ -n "${GIT_USER_EMAIL:-}" ]; then
    su - developer -c "git config --global user.email '$GIT_USER_EMAIL'"
    echo "Git user.email set to: $GIT_USER_EMAIL"
fi

# --- GitHub Deploy Key (persisted under projects volume) ---
DEPLOY_KEY_DIR="/home/developer/projects/.ssh-keys"
DEPLOY_KEY="$DEPLOY_KEY_DIR/github_deploy_key"

if [ ! -f "$DEPLOY_KEY" ]; then
    echo "Generating GitHub deploy key..."
    mkdir -p "$DEPLOY_KEY_DIR"
    ssh-keygen -t ed25519 -f "$DEPLOY_KEY" -N "" -C "devbox-deploy-key"
    chown -R developer:developer "$DEPLOY_KEY_DIR"
fi

chmod 600 "$DEPLOY_KEY"
chmod 644 "$DEPLOY_KEY.pub"

# Configure SSH to use the deploy key for GitHub
mkdir -p /home/developer/.ssh
cat > /home/developer/.ssh/config <<EOF
Host github.com
    HostName github.com
    User git
    IdentityFile $DEPLOY_KEY
    StrictHostKeyChecking accept-new
EOF
chmod 600 /home/developer/.ssh/config
chown -R developer:developer /home/developer/.ssh

echo ""
echo "============================================="
echo "  GitHub Deploy Key (add to GitHub):"
echo "============================================="
cat "$DEPLOY_KEY.pub"
echo "============================================="
echo ""

# --- Ensure sshd run directory exists ---
mkdir -p /var/run/sshd

# --- Start sshd ---
echo "Starting sshd..."
exec /usr/sbin/sshd -D
