#!/usr/bin/env bash
set -Eeuo pipefail

action="${1:-apply}"
case "${action}" in apply|remove) ;; *) echo "usage: $0 <apply|remove>" >&2; exit 64 ;; esac

if [[ "${action}" == "apply" ]] && ! ip link show tailscale0 >/dev/null 2>&1; then
  echo "[isaac-firewall] tailscale0 is unavailable" >&2
  exit 69
fi

manage_rule() {
  local family_command="$1"
  local rule_action="$2"
  shift 2

  if ! command -v "${family_command}" >/dev/null 2>&1; then
    return 0
  fi
  if ! "${family_command}" -w -L INPUT >/dev/null 2>&1; then
    return 0
  fi

  if [[ "${rule_action}" == "apply" ]]; then
    if ! "${family_command}" -w -C INPUT "$@" 2>/dev/null; then
      "${family_command}" -w -I INPUT 1 "$@"
    fi
  else
    while "${family_command}" -w -C INPUT "$@" 2>/dev/null; do
      "${family_command}" -w -D INPUT "$@"
    done
  fi
}

for family_command in iptables ip6tables; do
  for protocol_port in tcp:49100 udp:47998; do
    protocol="${protocol_port%%:*}"
    port="${protocol_port##*:}"
    comment_prefix="isaac-webrtc-${protocol}-${port}"

    if [[ "${action}" == "apply" ]]; then
      manage_rule "${family_command}" apply \
        -p "${protocol}" --dport "${port}" \
        -m comment --comment "${comment_prefix}-drop" -j DROP
      manage_rule "${family_command}" apply \
        -i tailscale0 -p "${protocol}" --dport "${port}" \
        -m comment --comment "${comment_prefix}-tailscale" -j ACCEPT
      manage_rule "${family_command}" apply \
        -i lo -p "${protocol}" --dport "${port}" \
        -m comment --comment "${comment_prefix}-loopback" -j ACCEPT
    else
      manage_rule "${family_command}" remove \
        -i lo -p "${protocol}" --dport "${port}" \
        -m comment --comment "${comment_prefix}-loopback" -j ACCEPT
      manage_rule "${family_command}" remove \
        -i tailscale0 -p "${protocol}" --dport "${port}" \
        -m comment --comment "${comment_prefix}-tailscale" -j ACCEPT
      manage_rule "${family_command}" remove \
        -p "${protocol}" --dport "${port}" \
        -m comment --comment "${comment_prefix}-drop" -j DROP
    fi
  done
done

echo "[isaac-firewall] ${action}: WebRTC is allowed only on tailscale0 and lo"
