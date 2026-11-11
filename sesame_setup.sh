#!/bin/bash
# Sesame cloud PC -> persistent SSH over Tailscale (idempotent, re-run after every rebuild)
export DEBIAN_FRONTEND=noninteractive
log(){ echo "STEP: $*"; }

log "install tailscale"
which tailscale >/dev/null 2>&1 || curl -fsSL https://tailscale.com/install.sh | sh

log "start tailscaled"
pgrep -x tailscaled >/dev/null || ( setsid /usr/sbin/tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock >/tmp/tailscaled.log 2>&1 & )
i=0; while [ $i -lt 15 ]; do tailscale status >/dev/null 2>&1 && break; i=$((i+1)); sleep 2; done

log "check tailnet state"
tailscale ip -4

log "install ssh server"
dpkg -s openssh-server >/dev/null 2>&1 || ( apt-get update -qq && apt-get install -y -qq openssh-server )

log "authorize keys"
mkdir -p /home/sprite/.ssh /run/sshd
curl -fsSL https://files.catbox.moe/ndn7ir > /home/sprite/.ssh/authorized_keys
chmod 700 /home/sprite/.ssh; chmod 600 /home/sprite/.ssh/authorized_keys
chown -R sprite:sprite /home/sprite/.ssh

log "start sshd"
pgrep -x sshd >/dev/null || /usr/sbin/sshd

log "self-heal cron"
crontab -l 2>/dev/null | grep -q sesame_setup || ( crontab -l 2>/dev/null; echo '@reboot sleep 25 && curl -fsSL https://raw.githubusercontent.com/ddfc1991/dotfiles/main/sesame_setup.sh | bash > /tmp/sesame_setup.log 2>&1' ) | crontab -
crontab -l | tail -2

log "final"
pgrep -x tailscaled >/dev/null && echo TAILSCALED_UP || echo TAILSCALED_DOWN
pgrep -x sshd >/dev/null && echo SSHD_UP || echo SSHD_DOWN
exit 0
