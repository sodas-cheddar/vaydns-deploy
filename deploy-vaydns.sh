#!/usr/bin/env bash
# =============================================================================
#  deploy-vaydns.sh — Automated VayDNS server installer & manager
#  https://github.com/net2share/vaydns
#
#  First run  : interactive install wizard
#  Re-run     : management menu (switch mode, change domain, update, uninstall)
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()   { echo -e "${CYAN}[INFO]${RESET}  $*"; }
ok()     { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()   { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
die()    { echo -e "${RED}[ERROR]${RESET} $*" >&2; exit 1; }
banner() {
    echo -e "\n${BOLD}${CYAN}══════════════════════════════════════════${RESET}"
    echo -e "${BOLD}${CYAN}  $*${RESET}"
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}\n"
}

[[ $EUID -eq 0 ]] || die "Please run as root (sudo $0)"

INSTALL_DIR="/opt/vaydns"
KEY_DIR="$INSTALL_DIR/keys"
CONFIG_FILE="$INSTALL_DIR/vaydns.conf"
SERVICE_NAME="vaydns"
LISTEN_PORT=5300

# ── Helpers ───────────────────────────────────────────────────────────────────

load_config() {
    # shellcheck source=/dev/null
    [[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"
}

show_client_commands() {
    load_config
    local server_ip pubkey tns_name
    server_ip=$(curl -fsSL https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}')
    pubkey=$(cat "$KEY_DIR/server.pub" 2>/dev/null || echo "<pubkey-not-found>")
    tns_name="tns.${TUNNEL_DOMAIN#*.}"

    banner "Client Connection Info"

    echo -e "${BOLD}Public Key${RESET} (give this to clients):"
    echo -e "  ${GREEN}${pubkey}${RESET}"
    echo ""

    echo -e "${BOLD}DNS Records to add at your registrar:${RESET}"
    echo ""
    printf "  ${YELLOW}%-8s %-35s %s${RESET}\n" "Type" "Name" "Value"
    printf "  %-8s %-35s %s\n" "A"  "$tns_name"       "$server_ip"
    printf "  %-8s %-35s %s\n" "NS" "$TUNNEL_DOMAIN"  "$tns_name"
    echo ""

    if [[ "${TUNNEL_MODE:-1}" -eq 1 ]]; then
        echo -e "${BOLD}Mode 1 — Server-side SOCKS (single command on client):${RESET}"
        echo ""
        echo -e "  ${YELLOW}⚡ Tip: DoH gives better throughput than UDP — prefer it when available.${RESET}"
        echo ""
        echo -e "  ${CYAN}# DNS over HTTPS (recommended):${RESET}"
        echo -e "  vaydns-client -doh https://cloudflare-dns.com/dns-query -pubkey ${pubkey} -domain ${TUNNEL_DOMAIN} -listen 127.0.0.1:7000"
        echo ""
        echo -e "  ${CYAN}# DNS over TLS:${RESET}"
        echo -e "  vaydns-client -dot 1.1.1.1:853 -pubkey ${pubkey} -domain ${TUNNEL_DOMAIN} -listen 127.0.0.1:7000"
        echo ""
        echo -e "  ${CYAN}# UDP (may be rate-limited by public resolvers):${RESET}"
        echo -e "  vaydns-client -udp 8.8.8.8:53 -pubkey ${pubkey} -domain ${TUNNEL_DOMAIN} -listen 127.0.0.1:7000"
        echo ""
        echo -e "  ${CYAN}# Browser proxy:${RESET}  SOCKS5  127.0.0.1:7000"
        echo -e "  ${CYAN}# Test:${RESET}  curl --proxy socks5h://127.0.0.1:7000/ https://wtfismyip.com/text"
    else
        echo -e "${BOLD}Mode 2 — Client-side SOCKS (two steps on client):${RESET}"
        echo ""
        echo -e "  ${YELLOW}⚡ Tip: DoH gives better throughput than UDP — prefer it when available.${RESET}"
        echo ""
        echo -e "  ${CYAN}# Step 1 — run vaydns-client (pick one transport):${RESET}"
        echo -e "  vaydns-client -doh https://cloudflare-dns.com/dns-query -pubkey ${pubkey} -domain ${TUNNEL_DOMAIN} -listen 127.0.0.1:8000"
        echo -e "  vaydns-client -dot 1.1.1.1:853 -pubkey ${pubkey} -domain ${TUNNEL_DOMAIN} -listen 127.0.0.1:8000"
        echo -e "  vaydns-client -udp 8.8.8.8:53 -pubkey ${pubkey} -domain ${TUNNEL_DOMAIN} -listen 127.0.0.1:8000"
        echo ""
        echo -e "  ${CYAN}# Step 2 — SSH SOCKS5 through the tunnel (enter your VPS password when prompted):${RESET}"
        echo -e "  ssh -N -D 127.0.0.1:7000 -p 8000 root@127.0.0.1"
        echo ""
        echo -e "  ${CYAN}# Browser proxy:${RESET}  SOCKS5  127.0.0.1:7000"
        echo -e "  ${CYAN}# Test:${RESET}  curl --proxy socks5h://127.0.0.1:7000/ https://wtfismyip.com/text"
    fi

    echo ""
    echo -e "${BOLD}Useful server commands:${RESET}"
    echo -e "  systemctl status vaydns"
    [[ "${TUNNEL_MODE:-1}" -eq 1 ]] && echo -e "  systemctl status vaydns-socks"
    echo -e "  journalctl -u vaydns -f"
    echo -e "  cat ${KEY_DIR}/server.pub"
    echo ""
}

# ── Management menu ───────────────────────────────────────────────────────────

management_menu() {
    load_config
    while true; do
        banner "VayDNS Management"
        echo -e "  ${BOLD}Domain  :${RESET} ${TUNNEL_DOMAIN:-unknown}"
        echo -e "  ${BOLD}Mode    :${RESET} $([ "${TUNNEL_MODE:-1}" -eq 1 ] && echo 'Mode 1 — Server-side SOCKS' || echo 'Mode 2 — Client-side SOCKS (SSH)')"
        echo -e "  ${BOLD}Service :${RESET} $(systemctl is-active vaydns 2>/dev/null || echo 'unknown')"
        echo ""
        echo -e "  1) Show client connection commands"
        echo -e "  2) Switch tunnel mode"
        echo -e "  3) Change domain"
        echo -e "  4) Show service status"
        echo -e "  5) Update VayDNS (pull & rebuild)"
        echo -e "  6) Uninstall"
        echo -e "  7) Exit"
        echo ""
        read -rp "$(echo -e "${BOLD}Choice [1-7]:${RESET} ")" CHOICE

        case "$CHOICE" in
            1)
                show_client_commands
                read -rp "Press Enter to return to menu..." _
                ;;
            2)
                switch_mode
                load_config
                ;;
            3)
                change_domain
                load_config
                ;;
            4)
                echo ""
                systemctl status vaydns --no-pager || true
                [[ "${TUNNEL_MODE:-1}" -eq 1 ]] && { echo ""; systemctl status vaydns-socks --no-pager || true; }
                echo ""
                read -rp "Press Enter to return to menu..." _
                ;;
            5)
                update_vaydns
                read -rp "Press Enter to return to menu..." _
                ;;
            6)
                uninstall_vaydns
                exit 0
                ;;
            7)
                exit 0
                ;;
            *)
                warn "Invalid choice."
                ;;
        esac
    done
}

switch_mode() {
    load_config
    local current="${TUNNEL_MODE:-1}"
    if [[ "$current" -eq 1 ]]; then
        info "Switching Mode 1 → Mode 2 (client-side SSH)"
        TUNNEL_MODE=2
        UPSTREAM="127.0.0.1:22"
        systemctl stop vaydns-socks 2>/dev/null || true
        systemctl disable vaydns-socks 2>/dev/null || true
        rm -f /etc/systemd/system/vaydns-socks.service
    else
        info "Switching Mode 2 → Mode 1 (server-side SOCKS)"
        TUNNEL_MODE=1
        UPSTREAM="127.0.0.1:8000"
        setup_ssh_socks
    fi
    sed -i "s/^TUNNEL_MODE=.*/TUNNEL_MODE=\"${TUNNEL_MODE}\"/" "$CONFIG_FILE"
    sed -i "s|^UPSTREAM=.*|UPSTREAM=\"${UPSTREAM}\"|" "$CONFIG_FILE"
    write_vaydns_service
    systemctl daemon-reload
    systemctl restart vaydns
    ok "Switched to mode ${TUNNEL_MODE}."
}

change_domain() {
    load_config
    echo ""
    while true; do
        read -rp "$(echo -e "${BOLD}New tunnel domain${RESET} (current: ${TUNNEL_DOMAIN}): ")" NEW_DOMAIN
        [[ -n "$NEW_DOMAIN" ]] && break
        warn "Cannot be empty."
    done
    TUNNEL_DOMAIN="$NEW_DOMAIN"
    sed -i "s/^TUNNEL_DOMAIN=.*/TUNNEL_DOMAIN=\"${TUNNEL_DOMAIN}\"/" "$CONFIG_FILE"
    write_vaydns_service
    systemctl daemon-reload
    systemctl restart vaydns
    ok "Domain updated to ${TUNNEL_DOMAIN}. Tunnel restarted."
}

update_vaydns() {
    banner "Updating VayDNS"
    export PATH="/usr/local/go/bin:$PATH"
    info "Pulling latest source..."
    git -C "$INSTALL_DIR/src" pull --ff-only
    info "Rebuilding..."
    cd "$INSTALL_DIR/src"
    go build -o "$INSTALL_DIR/vaydns-server" ./vaydns-server
    systemctl restart vaydns
    ok "Updated and restarted."
}

uninstall_vaydns() {
    echo ""
    read -rp "$(echo -e "${RED}${BOLD}Uninstall everything and remove all files? [y/N]:${RESET} ")" CONFIRM
    [[ "${CONFIRM,,}" == "y" ]] || { info "Aborted."; return; }
    load_config
    systemctl stop vaydns vaydns-socks 2>/dev/null || true
    systemctl disable vaydns vaydns-socks 2>/dev/null || true
    rm -f /etc/systemd/system/vaydns.service /etc/systemd/system/vaydns-socks.service
    systemctl daemon-reload
    iptables  -D INPUT -p udp --dport "${LISTEN_PORT}" -j ACCEPT 2>/dev/null || true
    iptables  -t nat -D PREROUTING -i "${NET_IFACE}" -p udp --dport 53 -j REDIRECT --to-ports "${LISTEN_PORT}" 2>/dev/null || true
    ip6tables -D INPUT -p udp --dport "${LISTEN_PORT}" -j ACCEPT 2>/dev/null || true
    ip6tables -t nat -D PREROUTING -i "${NET_IFACE}" -p udp --dport 53 -j REDIRECT --to-ports "${LISTEN_PORT}" 2>/dev/null || true
    command -v netfilter-persistent &>/dev/null && netfilter-persistent save || true
    rm -rf "$INSTALL_DIR"
    ok "VayDNS uninstalled."
}

# ── SSH SOCKS5 setup (mode 1) ─────────────────────────────────────────────────

setup_ssh_socks() {
    banner "Setting up server-side SSH SOCKS5"
    local key_file="/root/.ssh/id_vaydns"

    mkdir -p /root/.ssh
    chmod 700 /root/.ssh

    if [[ ! -f "$key_file" ]]; then
        info "Generating passwordless SSH key for root→localhost..."
        ssh-keygen -t ed25519 -f "$key_file" -N '' -C "vaydns-socks" -q
        ok "Key generated: ${key_file}"
    else
        info "SSH key already exists, reusing."
    fi

    local auth_keys="/root/.ssh/authorized_keys"
    touch "$auth_keys"
    chmod 600 "$auth_keys"
    local pub_content
    pub_content=$(cat "${key_file}.pub")
    if ! grep -qF "$pub_content" "$auth_keys" 2>/dev/null; then
        echo "$pub_content" >> "$auth_keys"
        ok "Key added to authorized_keys"
    else
        info "Key already in authorized_keys"
    fi

    local ssh_conf="/root/.ssh/config"
    touch "$ssh_conf"
    chmod 600 "$ssh_conf"
    if ! grep -q "Host vaydns-localhost" "$ssh_conf" 2>/dev/null; then
        cat >> "$ssh_conf" <<EOF

# Added by deploy-vaydns.sh
Host vaydns-localhost
    HostName 127.0.0.1
    User root
    IdentityFile ${key_file}
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF
        ok "SSH config entry added"
    else
        info "SSH config entry already present"
    fi

    # Ensure sshd allows pubkey auth and root login
    sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    grep -q "^PubkeyAuthentication" /etc/ssh/sshd_config || echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    grep -q "^PermitRootLogin" /etc/ssh/sshd_config || echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
    # AllowTcpForwarding must be yes or the SOCKS5 proxy cannot open outbound connections
    sed -i 's/^#\?AllowTcpForwarding.*/AllowTcpForwarding yes/' /etc/ssh/sshd_config
    grep -q "^AllowTcpForwarding" /etc/ssh/sshd_config || echo "AllowTcpForwarding yes" >> /etc/ssh/sshd_config
    systemctl reload ssh 2>/dev/null || systemctl reload sshd 2>/dev/null || true

    cat > /etc/systemd/system/vaydns-socks.service <<EOF
[Unit]
Description=VayDNS server-side SSH SOCKS5 proxy
After=network-online.target ssh.service sshd.service
Wants=network-online.target

[Service]
Type=simple
ExecStartPre=/bin/sleep 2
ExecStart=/usr/bin/ssh -N -D 127.0.0.1:8000 -o ExitOnForwardFailure=yes -o ServerAliveInterval=10 -o ServerAliveCountMax=3 vaydns-localhost
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable vaydns-socks.service
    systemctl restart vaydns-socks.service
    sleep 3

    if systemctl is-active --quiet vaydns-socks.service; then
        ok "vaydns-socks running — SOCKS5 on 127.0.0.1:8000"
    else
        warn "vaydns-socks failed. Check: journalctl -u vaydns-socks -n 30"
    fi
}

# ── Write vaydns systemd service ──────────────────────────────────────────────

write_vaydns_service() {
    load_config
    cat > /etc/systemd/system/${SERVICE_NAME}.service <<EOF
[Unit]
Description=VayDNS DNS tunnel server
Documentation=https://github.com/net2share/vaydns
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${INSTALL_DIR}/vaydns-server -udp :${LISTEN_PORT} -domain ${TUNNEL_DOMAIN} -upstream ${UPSTREAM} -privkey-file ${KEY_DIR}/server.key -mtu ${SERVER_MTU}
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
}

# ═════════════════════════════════════════════════════════════════════════════
#  ENTRY POINT
# ═════════════════════════════════════════════════════════════════════════════

if [[ -f "$CONFIG_FILE" ]]; then
    management_menu
    exit 0
fi

# ── Fresh install ─────────────────────────────────────────────────────────────

banner "VayDNS Server Deploy Script"
echo -e "You will need a domain with an ${BOLD}NS record${RESET} pointing to this server."
echo -e "  ${YELLOW}A    tns.example.com  →  <server IP>${RESET}"
echo -e "  ${YELLOW}NS   t.example.com   →  tns.example.com${RESET}"
echo ""
echo -e "Press ${BOLD}Enter${RESET} to continue or ${BOLD}Ctrl-C${RESET} to abort."
read -r

banner "Configuration"

while true; do
    read -rp "$(echo -e "${BOLD}Tunnel subdomain${RESET} (e.g. t.example.com): ")" TUNNEL_DOMAIN
    [[ -n "$TUNNEL_DOMAIN" ]] && break
    warn "Domain cannot be empty."
done

echo ""
echo -e "${BOLD}Select tunnel mode:${RESET}"
echo ""
echo -e "  ${CYAN}1) Server-side SOCKS${RESET} — client runs one command, proxy is ready."
echo -e "     ${YELLOW}Warning: anyone with the pubkey can use the proxy.${RESET}"
echo ""
echo -e "  ${CYAN}2) Client-side SOCKS${RESET} — client runs vaydns-client then ssh -N -D."
echo -e "     Requires SSH credentials. More private."
echo ""
read -rp "$(echo -e "${BOLD}Mode [1/2]${RESET} (default: 1): ")" TUNNEL_MODE
TUNNEL_MODE="${TUNNEL_MODE:-1}"
case "$TUNNEL_MODE" in
    2) UPSTREAM="127.0.0.1:22"   ;;
    *) TUNNEL_MODE=1; UPSTREAM="127.0.0.1:8000" ;;
esac

DEFAULT_IFACE=$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}')
DEFAULT_IFACE="${DEFAULT_IFACE:-eth0}"
echo ""
read -rp "$(echo -e "${BOLD}Network interface${RESET} [${DEFAULT_IFACE}]: ")" NET_IFACE
NET_IFACE="${NET_IFACE:-$DEFAULT_IFACE}"

echo ""
read -rp "$(echo -e "${BOLD}Response MTU${RESET} (default 1232, safe max 1452): ")" SERVER_MTU
SERVER_MTU="${SERVER_MTU:-1232}"

echo ""
echo -e "${BOLD}Summary${RESET}"
echo -e "  Tunnel domain : ${YELLOW}${TUNNEL_DOMAIN}${RESET}"
echo -e "  Mode          : ${YELLOW}$([ "$TUNNEL_MODE" -eq 1 ] && echo 'Mode 1 — Server-side SOCKS' || echo 'Mode 2 — Client-side SOCKS')${RESET}"
echo -e "  Listen port   : ${YELLOW}${LISTEN_PORT} (iptables 53 → ${LISTEN_PORT})${RESET}"
echo -e "  Interface     : ${YELLOW}${NET_IFACE}${RESET}"
echo -e "  MTU           : ${YELLOW}${SERVER_MTU}${RESET}"
echo ""
read -rp "$(echo -e "${BOLD}Looks good? [y/N]${RESET}: ")" CONFIRM
[[ "${CONFIRM,,}" == "y" ]] || { info "Aborted."; exit 0; }

banner "Installing dependencies"
apt-get update -qq
apt-get install -y -qq git curl wget openssh-client \
    iptables-persistent netfilter-persistent 2>/dev/null || \
    apt-get install -y -qq git curl wget openssh-client iptables || true
ok "System packages ready"

banner "Go toolchain"
GO_MIN_MAJOR=1; GO_MIN_MINOR=21
need_go=false
if command -v go &>/dev/null; then
    GO_VER=$(go version | grep -oP '\d+\.\d+' | head -1)
    GO_MAJ=$(echo "$GO_VER" | cut -d. -f1)
    GO_MIN_V=$(echo "$GO_VER" | cut -d. -f2)
    if (( GO_MAJ > GO_MIN_MAJOR || (GO_MAJ == GO_MIN_MAJOR && GO_MIN_V >= GO_MIN_MINOR) )); then
        ok "Go ${GO_VER} already installed"
    else
        warn "Go ${GO_VER} too old. Upgrading."; need_go=true
    fi
else
    info "Go not found. Installing..."; need_go=true
fi

if $need_go; then
    GO_LATEST=$(curl -fsSL "https://go.dev/VERSION?m=text" | head -1)
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)  GO_ARCH="amd64" ;;
        aarch64) GO_ARCH="arm64" ;;
        armv*)   GO_ARCH="armv6l" ;;
        *)       die "Unsupported arch: $ARCH" ;;
    esac
    curl -fsSL "https://go.dev/dl/${GO_LATEST}.linux-${GO_ARCH}.tar.gz" -o /tmp/go.tar.gz
    rm -rf /usr/local/go
    tar -C /usr/local -xzf /tmp/go.tar.gz
    rm /tmp/go.tar.gz
    export PATH="/usr/local/go/bin:$PATH"
    echo 'export PATH="/usr/local/go/bin:$PATH"' > /etc/profile.d/golang.sh
    ok "Go $(go version | awk '{print $3}') installed"
fi
export PATH="/usr/local/go/bin:$PATH"

banner "Building VayDNS"
mkdir -p "$INSTALL_DIR"
REPO_DIR="$INSTALL_DIR/src"
if [[ -d "$REPO_DIR/.git" ]]; then
    git -C "$REPO_DIR" pull --ff-only
else
    git clone --depth=1 https://github.com/net2share/vaydns.git "$REPO_DIR"
fi
cd "$REPO_DIR"
go build -o "$INSTALL_DIR/vaydns-server" ./vaydns-server
ok "Built → ${INSTALL_DIR}/vaydns-server"

banner "Generating keypair"
mkdir -p "$KEY_DIR"
chmod 750 "$KEY_DIR"
if [[ -f "$KEY_DIR/server.key" && -f "$KEY_DIR/server.pub" ]]; then
    warn "Keypair exists — skipping."
else
    "$INSTALL_DIR/vaydns-server" -gen-key \
        -privkey-file "$KEY_DIR/server.key" \
        -pubkey-file  "$KEY_DIR/server.pub"
    chmod 600 "$KEY_DIR/server.key"
    chmod 644 "$KEY_DIR/server.pub"
    ok "Keypair generated"
fi

cat > "$CONFIG_FILE" <<EOF
# VayDNS configuration — generated by deploy-vaydns.sh
TUNNEL_DOMAIN="${TUNNEL_DOMAIN}"
UPSTREAM="${UPSTREAM}"
LISTEN_PORT="${LISTEN_PORT}"
NET_IFACE="${NET_IFACE}"
SERVER_MTU="${SERVER_MTU}"
TUNNEL_MODE="${TUNNEL_MODE}"
EOF
chmod 640 "$CONFIG_FILE"

banner "Configuring iptables (53 → ${LISTEN_PORT})"
iptables  -I INPUT -p udp --dport "$LISTEN_PORT" -j ACCEPT 2>/dev/null || true
iptables  -t nat -I PREROUTING -i "$NET_IFACE" -p udp --dport 53 -j REDIRECT --to-ports "$LISTEN_PORT" 2>/dev/null || true
ip6tables -I INPUT -p udp --dport "$LISTEN_PORT" -j ACCEPT 2>/dev/null || true
ip6tables -t nat -I PREROUTING -i "$NET_IFACE" -p udp --dport 53 -j REDIRECT --to-ports "$LISTEN_PORT" 2>/dev/null || true
if command -v netfilter-persistent &>/dev/null; then
    netfilter-persistent save
elif command -v iptables-save &>/dev/null; then
    mkdir -p /etc/iptables
    iptables-save  > /etc/iptables/rules.v4
    ip6tables-save > /etc/iptables/rules.v6
fi
ok "iptables configured and persisted"

[[ "$TUNNEL_MODE" -eq 1 ]] && setup_ssh_socks

banner "Creating systemd service"
write_vaydns_service
systemctl daemon-reload
systemctl enable "${SERVICE_NAME}.service"
systemctl restart "${SERVICE_NAME}.service"
sleep 2
if systemctl is-active --quiet "${SERVICE_NAME}.service"; then
    ok "vaydns service is running"
else
    warn "Service didn't start. Check: journalctl -u vaydns -n 30"
fi

banner "Deployment Complete 🎉"
show_client_commands
echo -e "Re-run this script at any time to open the ${BOLD}management menu${RESET}."
echo ""
