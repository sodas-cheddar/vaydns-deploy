<div align="center">

# 🚀 VayDNS Easy Deploy
[![Shell Script](https://img.shields.io/badge/shell-bash-89e051?style=flat-square&logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/platform-Ubuntu%20%2F%20Debian-E95420?style=flat-square&logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)

<br/>

> **This script automates the deployment of [VayDNS](https://github.com/net2share/vaydns)** — a DNS tunnel server written by [net2share](https://github.com/net2share), itself based on [dnstt](https://www.bamsoftware.com/software/dnstt/) by David Fifield.  
> This repo contains only the installer script. VayDNS source code is cloned and compiled from the original repository at install time.

</div>

---

## ✨ What This Script Does

Instead of manually installing Go, building binaries, configuring iptables, and writing systemd unit files — you answer a few prompts and everything is configured end-to-end.

| Step | What happens |
|------|-------------|
| 📦 | Installs Go automatically (detects architecture: amd64 / arm64 / armv6) |
| 🔨 | Clones [net2share/vaydns](https://github.com/net2share/vaydns) and builds `vaydns-server` from source |
| 🔑 | Generates a Noise protocol keypair |
| 🔀 | Configures `iptables` to redirect UDP port `53 → 5300` (no root daemon needed) |
| 💾 | Persists iptables rules across reboots via `netfilter-persistent` or a restore service |
| ⚙️ | Creates and enables a `systemd` service that starts on boot |
| 🚀 | Starts everything immediately and confirms it's running |

---

## 🛜 Tunnel Modes

During setup you choose how the SOCKS5 proxy is served:

### Mode 1 — Server-side SOCKS *(easiest for browser proxying)*

The server runs `ssh -N -D` as its own systemd service. The VayDNS tunnel points directly at that SOCKS5 listener. The client only needs a single command — no SSH step required.

```bash
# Client — one command, proxy ready on :7000
vaydns-client -udp 8.8.8.8:53 -pubkey <server-pubkey> -domain t.example.com -listen 127.0.0.1:7000
```

Point your browser at `SOCKS5  127.0.0.1:7000` and you're done.

> ⚠️ **Anyone who has your public key can use the proxy in this mode.** Keep the key private and only share it with trusted clients.

---

### Mode 2 — Client-side SOCKS *(private, requires SSH credentials)*

The tunnel forwards directly to SSH on port 22. Each client establishes their own private SOCKS5 proxy using `ssh -D`.

```bash
# Step 1 — start the tunnel
vaydns-client -udp 8.8.8.8:53 -pubkey <server-pubkey> -domain t.example.com -listen 127.0.0.1:8000

# Step 2 — open a private SOCKS5 proxy through the tunnel
ssh -N -D 127.0.0.1:7000 -p 8000 root@127.0.0.1
```

Point your browser at `SOCKS5  127.0.0.1:7000`.

---

## 📋 Prerequisites

### Server
- Ubuntu or Debian VPS (tested on Debian 12)
- Root access
- A domain you control with the ability to add DNS records

### DNS Setup

Add these two records at your domain registrar **before** running the script:

| Type | Name | Value |
|------|------|-------|
| `A` | `tns.example.com` | `<your VPS IP>` |
| `NS` | `t.example.com` | `tns.example.com` |

- `t` is the tunnel subdomain — **keep it short (max 2 characters)** to maximise payload per DNS query


---

## ⚡ Quick Start

```bash
bash <(curl -Ls https://raw.githubusercontent.com/sodas-cheddar/vaydns-deploy/main/deploy-vaydns.sh)
```

The script will prompt you for:

- Tunnel subdomain (e.g. `t.example.com`)
- Network interface (auto-detected from default route)
- Response MTU (default `1232`, safe max `1452`)
- Tunnel mode (`1` = server-side SOCKS, `2` = client-side SOCKS)

At the end it prints your **public key**, the exact **DNS records** to add, and ready-to-paste **client commands**.

---

## 🖥️ Client Setup

Download a pre-built client binary from the [VayDNS releases page](https://github.com/net2share/vaydns/releases), or build it from source:

```bash
git clone https://github.com/net2share/vaydns.git
cd vaydns
go build -o vaydns-client ./vaydns-client
```

### Transport Options

| Flag | Transport | Covertness |
|------|-----------|------------|
| `-udp 8.8.8.8:53` | Plaintext UDP DNS | ❌ Visible on network |
| `-doh https://cloudflare-dns.com/dns-query` | DNS over HTTPS | ✅ Looks like normal HTTPS |
| `-dot 1.1.1.1:853` | DNS over TLS | ✅ Looks like normal TLS |

### Browser Proxy Configuration

**Firefox** *(recommended — has its own independent proxy stack)*

`Settings → search "proxy" → Manual proxy configuration`
- SOCKS Host: `127.0.0.1`  Port: `7000`
- Select **SOCKS v5**
- ✅ Check **"Proxy DNS when using SOCKS v5"** — this prevents DNS leaks

**Chrome / Edge**

Install [Proxy SwitchyOmega](https://chrome.google.com/webstore/detail/proxy-switchyomega/padekgcemlokbadohgkifijomclgjgif) and create a SOCKS5 profile pointing to `127.0.0.1:7000`. Chrome does not have per-browser proxy settings, so an extension is required.

### Test It

```bash
curl --proxy socks5h://127.0.0.1:7000/ https://wtfismyip.com/text
# Should print your VPS IP address, not your real one
```

---

## 🔧 Server Management

```bash
# Tunnel status
systemctl status vaydns

# SSH SOCKS5 status (mode 1 only)
systemctl status vaydns-socks

# Restart
systemctl restart vaydns

# Live logs
journalctl -u vaydns -f

# Show public key
cat /opt/vaydns/keys/server.pub
```

Configuration is stored at `/opt/vaydns/vaydns.conf`. Re-running the script is safe — it skips steps that are already done (existing keypair, existing repo clone).

---

## 🏗️ How It Works

```
Client                    DNS Resolver              VPS
──────                    ────────────              ───────────────────────
Browser
  │ SOCKS5 :7000
  ▼
vaydns-client ─── DoH / DoT / UDP ──────── UDP ──► vaydns-server :5300
                                                          │
                                                   iptables (53 → 5300)
                                                          │
                                            ┌─────────────▼────────────┐
                                            │  Mode 1: SSH -D :8000    │
                                            │  (SOCKS5, open access)   │
                                            ├──────────────────────────┤
                                            │  Mode 2: sshd :22        │
                                            │  (SSH login required)    │
                                            └──────────────────────────┘
```

The tunnel uses the [Noise protocol](https://noiseprotocol.org/noise.html) (`Noise_NK_25519_ChaChaPoly_BLAKE2s`) for end-to-end encryption between client and server, independent of whatever DNS transport is used. DoH/DoT additionally hides the tunnel traffic from local network observers.

---

## 🔒 Security Notes

- **Private key** lives at `/opt/vaydns/keys/server.key` — back it up and never share it
- **Public key** is safe to share with clients — it authenticates the server, not the client
- **Mode 1** is convenient but open: any client with the pubkey can proxy through your server
- **Mode 2** requires SSH credentials, giving you full access control and auth logging via `sshd`
- The tunnel encrypts content end-to-end — the DNS resolver can see query destinations but not the data

---

## 📁 Repo Structure

```
vaydns-deploy/
├── deploy-vaydns.sh    ← automated install script
├── README.md           ← this file
└── LICENSE             ← MIT
```

VayDNS itself is not included — it is cloned from [net2share/vaydns](https://github.com/net2share/vaydns) at install time.

---

## 🙏 Attribution

This project would not exist without:

- **[VayDNS](https://github.com/net2share/vaydns)** by [net2share](https://github.com/net2share) and contributors — the DNS tunnel server this script deploys. Released under CC0 (public domain).
- **[dnstt](https://www.bamsoftware.com/software/dnstt/)** by [David Fifield](https://www.bamsoftware.com/) — the upstream project VayDNS is based on. Also public domain.

The `deploy-vaydns.sh` script in this repository is original work released under the [MIT License](LICENSE).

