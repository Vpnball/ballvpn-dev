#!/usr/bin/env bash

PASSWORD="ballvpn"
read -sp "Enter password: " input
echo ""
if [ "$input" != "$PASSWORD" ]; then
  echo -e "\e[91m❌ Incorrect password! Access denied.\e[0m"
  exit 1
fi

echo -e "\e[92m✅ Access granted. Running setup...\e[0m"
sleep 1
clear
# ballvpn_nat.sh - BallVPN / Looktow VPN NAT setup (idempotent)
# Features:
#  - Keep only one REDIRECT: UDP 53 -> 5300
#  - Remove any DNAT 6000:19999 -> 5667
#  - Ensure a single DNAT 22000:28000 -> :5667 (no IP specified)
#  - Ensure single SNAT 10.8.0.0/16 -> internal IF IP (fallback to public if needed)
#  - Save to /etc/iptables/rules.v4
set -e

log(){ echo -e "$1"; }

# ==== Detect default interface and IP ====
IF=$(ip -o -4 route show to default | awk '{print $5}' | head -n1)
IFIP=$(ip -4 addr show "$IF" 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1 | head -n1)

[ -z "$IF" ] && { log "!! ไม่พบ default interface"; exit 1; }
[ -z "$IFIP" ] && IFIP="127.0.0.1"

# Determine public IP (fallback)
PUBIP="$IFIP"
if [[ "$IFIP" =~ ^10\.|^192\.168\.|^172\.(1[6-9]|2[0-9]|3[0-1])\. ]]; then
  EXT=$({ command -v curl >/dev/null && curl -s --max-time 4 ipv4.icanhazip.com; } || { command -v wget >/dev/null && wget -qO- --timeout=4 ipv4.icanhazip.com; } || echo "")
  [ -n "$EXT" ] && PUBIP="$EXT"
fi

log ">> IF=$IF"
log ">> IFIP=$IFIP (ใช้กับ SNAT ก่อน)"
log ">> PUBIP=$PUBIP (สำรอง)"

# ==== 1) Keep single REDIRECT UDP 53 -> 5300 ====
mapfile -t R53 < <(iptables -t nat -S PREROUTING | awk '/^-A PREROUTING/ && /-p udp/ && /--dport 53/ && /-j REDIRECT/ && /--to-ports 5300/')
for r in "${R53[@]}"; do iptables -t nat -D PREROUTING ${r#-A PREROUTING } 2>/dev/null || true; done
iptables -t nat -A PREROUTING -i "$IF" -p udp --dport 53 -j REDIRECT --to-ports 5300
log "++ ensure: REDIRECT udp 53 -> 5300"

# ==== 2) Remove all DNAT 6000:19999 -> 5667 (any IP) ====
mapfile -t OLD6000 < <(iptables -t nat -S PREROUTING | awk '/^-A PREROUTING/ && /-p udp/ && /--dport 6000:19999/ && /-j DNAT/ && /:5667/')
for r in "${OLD6000[@]}"; do iptables -t nat -D PREROUTING ${r#-A PREROUTING } 2>/dev/null || true; done
log "++ cleared: DNAT udp 6000:19999 -> 5667 (all)"

# ==== 3) Ensure single DNAT 22000:28000 -> :5667 ====
mapfile -t D22 < <(iptables -t nat -S PREROUTING | awk '/^-A PREROUTING/ && /-p udp/ && /--dport 22000:28000/ && /-j DNAT/ && /:5667/')
for r in "${D22[@]}"; do iptables -t nat -D PREROUTING ${r#-A PREROUTING } 2>/dev/null || true; done
iptables -t nat -A PREROUTING -i "$IF" -p udp --dport 22000:28000 -j DNAT --to-destination :5667
log "++ ensure: DNAT udp 22000:28000 -> :5667"

# ==== 4) Ensure single SNAT 10.8.0.0/16 -> internal IF IP (fallback to public) ====
SNAT_IP="$IFIP"
if [[ "$IFIP" =~ ^127\. ]]; then SNAT_IP="$PUBIP"; fi

mapfile -t S108 < <(iptables -t nat -S POSTROUTING | awk '/^-A POSTROUTING/ && /-s 10\.8\.0\.0\/16/ && /-j SNAT/')
for r in "${S108[@]}"; do iptables -t nat -D POSTROUTING ${r#-A POSTROUTING } 2>/dev/null || true; done
iptables -t nat -A POSTROUTING -s 10.8.0.0/16 -j SNAT --to-source "$SNAT_IP"
log "++ ensure: SNAT 10.8.0.0/16 -> $SNAT_IP"

# ==== 5) Save rules ====
iptables-save > /etc/iptables/rules.v4
log "✅ DONE: 53->5300 / DNAT 22000:28000->:5667 / SNAT 10.8.0.0/16->$SNAT_IP"
