#!/usr/bin/env bash
# AiSpace GitOps loader — the ONLY file published publicly (no secrets, no internal data).
# Run from the provider's web console (Sakura / Xserver) on iPhone. Requires root (sudo).
#
#   1) curl -fsSLo i.sh https://raw.githubusercontent.com/aispace-yamamoto/aispace-gitops-bootstrap/main/i.sh
#   2) sha256sum i.sh            -> compare with the value 山本 received in the Claude chat / GitHub release note
#   3) sudo bash i.sh check sakura-01     (READ-ONLY: shows current state and what install would change)
#   4) sudo bash i.sh install sakura-01   (asks for confirmation at every step)
#   later) sudo bash i.sh policy-update <host>  (shows the policy diff from Git, applies only after "yes")
#
# What install does (and nothing else):
#   - apt: git python3 openssh-client age qrencode (only if missing)
#   - /etc/aispace-gitops/deploy_key (new ed25519 key, read-only use) -> shows the public key as text AND QR code
#   - waits until that key can read the PRIVATE repo, clones it, shows the commit; you confirm the first 7 chars
#   - runs gitops/install.sh from that commit (agent + policy + one systemd unit), then enables the unit
# It does not touch SSH settings, ufw, users, existing services, backups or data.
# apt runs with needrestart suspended: no running service is restarted, no reboot.
set -euo pipefail
REPO_SSH="${AISPACE_REPO:-git@github.com:aispace-yamamoto/aispace-infra.git}"  # AISPACE_REPO: tests only
cmd="${1:-}"; host="${2:-}"
case "$host" in sakura-01|xserver-01) ;; *) echo "usage: sudo bash i.sh {check|install|policy-update} {sakura-01|xserver-01}"; exit 2;; esac
[ "$(id -u)" = 0 ] || { echo "root is required: run with sudo"; exit 2; }
# wrong-host guard: stop BEFORE anything is changed if this machine already belongs to another host name
if [ -f /etc/aispace-gitops/policy.json ]; then
  cur=$(python3 -c 'import json;print(json.load(open("/etc/aispace-gitops/policy.json"))["host"])' 2>/dev/null || true)
  [ -z "$cur" ] || [ "$cur" = "$host" ] || { echo "STOP: this machine is '$cur', not '$host' ($(hostname)). Nothing was changed."; exit 2; }
fi
say(){ printf '\n\033[1m== %s\033[0m\n' "$*"; }
ask(){ local a; read -r -p "$1 [type yes]: " a; [ "$a" = yes ] || { echo "stopped (nothing more changed)"; exit 1; }; }

check(){
  set +e   # read-only report: a missing tool must not abort it
  say "host"; hostname; . /etc/os-release; echo "$PRETTY_NAME"; uptime; df -h / | tail -1; free -h | sed -n 2p
  say "aispace services (state only)"; systemctl list-units --all --no-legend --plain 'aispace-*' | awk '{print $1, $3, $4}'
  say "aispace timers"; systemctl list-timers --all --no-legend 'aispace-*' | awk '{print $(NF-1), $NF, "next:", $1, $2, $3}'
  say "listening ports"; (ss -ltnH 2>/dev/null || echo "ss not available") | awk '{print $4}' | sort -u | tr '\n' ' '; echo
  say "firewall / ssh (summary)"; ufw status 2>/dev/null | head -5; sshd -T 2>/dev/null | grep -E '^(passwordauthentication|permitrootlogin|pubkeyauthentication) '
  say "newest files under /opt/aispace (backups received?)"; find /opt/aispace -maxdepth 4 -type f -mmin -1500 -printf '%TY-%Tm-%Td %TH:%TM %p\n' 2>/dev/null | sort | tail -5
  say "outbound to GitHub / GitLab (TCP 22, needed for the read-only deploy key)"
  for h in github.com gitlab.com; do timeout 5 bash -c "echo > /dev/tcp/$h/22" 2>/dev/null && echo "$h:22 ok" || echo "$h:22 NOT reachable"; done
  say "tools"; for c in git python3 ssh age qrencode; do printf '%s: ' "$c"; command -v "$c" || echo "MISSING (install would add)"; done
  say "already installed?"; ls -d /opt/aispace-gitops /etc/aispace-gitops /var/lib/aispace-gitops 2>/dev/null || echo "no (clean)"
  systemctl is-active aispace-gitops 2>/dev/null || true
  say "install WOULD create/change only"
  echo "  apt packages above marked MISSING"
  echo "  /opt/aispace-gitops  /etc/aispace-gitops  /var/lib/aispace-gitops  /opt/aispace-gitops-canary (empty)"
  echo "  /etc/systemd/system/aispace-gitops.service (+ .d/paths.conf)"
  echo "nothing changed by 'check'."
  set -e
}

do_install(){
  check </dev/null
  ask "Continue with install on $host?"
  need=(); for p in git python3 openssh-client age qrencode; do dpkg -s "$p" >/dev/null 2>&1 || need+=("$p"); done
  if [ ${#need[@]} -gt 0 ]; then say "apt install ${need[*]}"; DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 apt-get update -q && DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 apt-get install -y -q --no-install-recommends "${need[@]}"; fi   # never restart running services
  install -d -m 755 /etc/aispace-gitops; install -d -m 700 /var/lib/aispace-gitops
  [ -f /etc/aispace-gitops/deploy_key ] || ssh-keygen -q -t ed25519 -N '' -C "aispace-gitops@$host" -f /etc/aispace-gitops/deploy_key </dev/null
  chmod 600 /etc/aispace-gitops/deploy_key
  say "PUBLIC key of this host (safe to share). Scan the QR with the iPhone camera to copy it."
  cat /etc/aispace-gitops/deploy_key.pub
  qrencode -t ANSIUTF8 < /etc/aispace-gitops/deploy_key.pub
  echo "Register it: GitHub > aispace-infra > Settings > Deploy keys > Add (title $host, do NOT allow write)."
  echo "Also paste the same public key into the Claude chat (it is stored in the repo as hosts/$host/host_key.pub)."
  export GIT_SSH_COMMAND="ssh -i /etc/aispace-gitops/deploy_key -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/var/lib/aispace-gitops/known_hosts"
  say "waiting until the deploy key can read the repository (Ctrl-C to stop)"
  until git ls-remote "$REPO_SSH" refs/heads/main </dev/null >/dev/null 2>&1; do printf '.'; sleep 10; done; echo " ok"
  rm -rf /opt/aispace-gitops/src; install -d -m 755 /opt/aispace-gitops
  git clone -q --depth 1 "$REPO_SSH" /opt/aispace-gitops/src </dev/null
  short=$(git -C /opt/aispace-gitops/src rev-parse --short=7 HEAD)
  say "repository commit: $short  $(git -C /opt/aispace-gitops/src log -1 --format=%s | cut -c1-60)"
  local a; read -r -p "Type the 7 characters of the commit shown in the GitHub app / Claude chat: " a
  [ "$a" = "$short" ] || { echo "commit mismatch: stopped. Nothing installed except the key and packages."; exit 1; }
  bash /opt/aispace-gitops/src/gitops/install.sh "$host" "/opt/aispace-gitops/src/hosts/$host/policy.template.json" </dev/null
  ask "Start the agent now (it only reads the repo until a GO arrives)?"
  systemctl enable aispace-gitops >/dev/null 2>&1
  systemctl restart aispace-gitops   # restart (not just start): a re-install must load the new code/settings
  sleep 5; systemctl --no-pager --lines=8 status aispace-gitops || true
  say "done. Take a screenshot of this screen and send it to the Claude chat."
}

policy_update(){
  [ -f /etc/aispace-gitops/policy.json ] && [ -f /etc/aispace-gitops/deploy_key ] || { echo "not installed yet: run install first"; exit 1; }
  export GIT_SSH_COMMAND="ssh -i /etc/aispace-gitops/deploy_key -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/var/lib/aispace-gitops/known_hosts"
  rm -rf /opt/aispace-gitops/src; git clone -q --depth 1 "$REPO_SSH" /opt/aispace-gitops/src </dev/null
  short=$(git -C /opt/aispace-gitops/src rev-parse --short=7 HEAD)
  say "repository commit: $short  $(git -C /opt/aispace-gitops/src log -1 --format=%s | cut -c1-60)"
  local a; read -r -p "Type the 7 characters of the commit shown in the GitHub app / Claude chat: " a
  [ "$a" = "$short" ] || { echo "commit mismatch: stopped. Policy unchanged."; exit 1; }
  new="/opt/aispace-gitops/src/hosts/$host/policy.template.json"
  say "policy change (- current  + new)"
  diff -u /etc/aispace-gitops/policy.json "$new" && { echo "no difference: nothing to do"; exit 0; }
  ask "Apply this policy change on $host?"
  cp -a /etc/aispace-gitops/policy.json "/var/lib/aispace-gitops/policy.before-$(date +%Y%m%d%H%M%S).json"
  install -m 644 "$new" /etc/aispace-gitops/policy.json
  bash /opt/aispace-gitops/src/gitops/install.sh "$host" "$new" </dev/null
  systemctl restart aispace-gitops; sleep 3; systemctl --no-pager --lines=5 status aispace-gitops || true
  say "done. previous policy saved under /var/lib/aispace-gitops/policy.before-*.json"
}

case "$cmd" in check) check;; install) do_install;; policy-update) policy_update;; *) echo "usage: sudo bash i.sh {check|install|policy-update} <host>"; exit 2;; esac
