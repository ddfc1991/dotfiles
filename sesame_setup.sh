#!/bin/bash
# Sesame cloud PC -> persistent SSH over Tailscale
# Idempotent: safe to re-run after every VM rebuild.
set -x
export DEBIAN_FRONTEND=noninteractive

TSKEY=$(curl -fsSL --max-time 20 https://files.catbox.moe/4wqf9d.key)

# 1. install + start tailscale
which tailscale >/dev/null 2>&1 || curl -fsSL https://tailscale.com/install.sh | sh
pgrep -x tailscaled >/dev/null || ( /usr/sbin/tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock >/tmp/tailscaled.log 2>&1 & )
for i in $(seq 1 20); do tailscale status >/dev/null 2>&1 && break; sleep 2; done

# 2. join tailnet (only if not already authenticated)
if ! tailscale status 2>/dev/null | grep -q 100.; then
  tailscale up --authkey="$TSKEY" --hostname=sesame --ssh
fi

# 3. ssh server
dpkg -s openssh-server >/dev/null 2>&1 || ( apt-get update -qq && apt-get install -y -qq openssh-server )
mkdir -p /run/sshd /home/sprite/.ssh
chmod 700 /home/sprite/.ssh
grep -q sesamesandbox /home/sprite/.ssh/authorized_keys 2>/dev/null || \
  echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ8J6FzGvQOyXaMKrDwfRL2SgHnX0Mj5VhPqTrZKxYbW sesamesandbox' >> /home/sprite/.ssh/authorized_keys
chmod 600 /home/sprite/.ssh/authorized_keys
pgrep -x sshd >/dev/null || /usr/sbin/sshd

# 4. self-heal on every boot
crontab -l 2>/dev/null | grep -q sesame_setup || \
  ( crontab -l 2>/dev/null; echo '@reboot sleep 20 && curl -fsSL https://raw.githubusercontent.com/ddfc1991/dotfiles/main/sesame_setup.sh | bash > /tmp/sesame_setup.log 2>&1' ) | crontab -

sleep 5
echo "RESULT_IP=$(tailscale ip -4 2>/dev/null | head -1)"
pgrep -x tailscaled >/dev/null && echo TAILSCALED_UP || echo TAILSCALED_DOWN
pgrep -x sshd >/dev/null && echo SSHD_UP || echo SSHD_DOWN
exit 0
