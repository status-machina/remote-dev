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

# --- GitHub Deploy Keys (persisted under projects volume) ---
DEPLOY_KEY_DIR="/home/developer/projects/.ssh-keys"
PERSONAL_KEY="$DEPLOY_KEY_DIR/github_personal"
WORK_KEY="$DEPLOY_KEY_DIR/github_work"

mkdir -p "$DEPLOY_KEY_DIR"

if [ ! -f "$PERSONAL_KEY" ]; then
    echo "Generating personal GitHub deploy key..."
    ssh-keygen -t ed25519 -f "$PERSONAL_KEY" -N "" -C "devbox-personal"
fi

if [ ! -f "$WORK_KEY" ]; then
    echo "Generating work GitHub deploy key..."
    ssh-keygen -t ed25519 -f "$WORK_KEY" -N "" -C "devbox-work"
fi

chown -R developer:developer "$DEPLOY_KEY_DIR"
chmod 600 "$PERSONAL_KEY" "$WORK_KEY"
chmod 644 "$PERSONAL_KEY.pub" "$WORK_KEY.pub"

# --- Git Identity & SSH Key Scoping ---
mkdir -p /home/developer/.config/git

# Global gitconfig: personal identity + personal SSH key as default
su - developer -c "git config --global user.name '${GIT_USER_NAME:-developer}'"
su - developer -c "git config --global user.email '${GIT_USER_EMAIL:-developer@devbox}'"
su - developer -c "git config --global core.sshCommand 'ssh -i $PERSONAL_KEY -o StrictHostKeyChecking=accept-new'"
echo "Git identity set: ${GIT_USER_NAME:-developer} <${GIT_USER_EMAIL:-developer@devbox}>"

# Work override scoped to ~/projects/work/
if [ -n "${GIT_WORK_EMAIL:-}" ]; then
    cat > /home/developer/.config/git/work <<EOF
[user]
    email = $GIT_WORK_EMAIL
[core]
    sshCommand = ssh -i $WORK_KEY -o StrictHostKeyChecking=accept-new
EOF
    su - developer -c "git config --global includeIf.gitdir:~/projects/work/.path /home/developer/.config/git/work"
    echo "Git work override: $GIT_WORK_EMAIL + work key (for ~/projects/work/)"
fi

chown -R developer:developer /home/developer/.config/git

echo ""
echo "============================================="
echo "  Personal GitHub Deploy Key:"
echo "============================================="
cat "$PERSONAL_KEY.pub"
echo ""
echo "============================================="
echo "  Work GitHub Deploy Key:"
echo "============================================="
cat "$WORK_KEY.pub"
echo "============================================="
echo ""

# --- Ensure sshd run directory exists ---
mkdir -p /var/run/sshd

# --- Start sshd ---
echo "Starting sshd..."
exec /usr/sbin/sshd -D
