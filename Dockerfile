FROM node:24-bookworm

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-server \
    git \
    ripgrep \
    fd-find \
    jq \
    curl \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Create developer user with sudo access
RUN useradd -m -s /bin/bash developer \
    && echo "developer ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/developer

# Configure sshd
RUN mkdir -p /var/run/sshd \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config \
    && sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# Remove SSH host keys (regenerated at runtime by entrypoint)
RUN rm -f /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub

# Install Claude Code using native installer
USER developer
RUN curl -fsSL https://claude.ai/install.sh | bash
USER root

# Ensure Claude Code is on PATH for all login shells
RUN echo 'export PATH="/home/developer/.local/bin:$PATH"' >> /home/developer/.bashrc

# Set up projects directory
RUN mkdir -p /home/developer/projects && chown developer:developer /home/developer/projects

# Copy helper scripts
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh
COPY --chmod=755 wt-new /usr/local/bin/wt-new

# Environment defaults
ENV GIT_EDITOR="zed --wait"

EXPOSE 22

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
