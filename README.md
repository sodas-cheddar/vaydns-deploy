<div align="center">

# 🚀 VayDNS Easy Deploy
[![Shell Script](https://img.shields.io/badge/shell-bash-89e051?style=flat-square&logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/platform-Ubuntu%20%2F%20Debian-E95420?style=flat-square&logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)

<br/>

> **This script automates the deployment of [VayDNS](https://github.com/net2share/vaydns)** — a DNS tunnel server written by [net2share](https://github.com/net2share), itself based on [dnstt](https://www.bamsoftware.com/software/dnstt/) by David Fifield.  
> This repo contains only the installer script. VayDNS is either downloaded as a prebuilt binary or cloned and compiled from the original repository at install time.

</div>

---

## ✨ What This Script Does

Instead of manually installing Go, building binaries, configuring iptables, and writing systemd unit files — you answer a few prompts and everything is configured end-to-end.

| Step | What happens |
|------|-------------|
| 📦 | Downloads a prebuilt binary **or** installs Go and builds from source (your choice) |
| 🔑 | Generates a Noise protocol keypair |
| 🔀 | Configures `iptables` to redirect UDP port `53 → 5300` (no root daemon needed) |
| 💾 | Persists iptables rules across reboots via `netfilter-persistent` |
| ⚙️ | Creates and enables `systemd` services that start on boot |
| 🚀 | Starts everything immediately and confirms it's running |

---

## 🛜 Tunnel Modes

During setup you choose how the SOCKS5 proxy is served:

---

### Mode 1 — Server-side SOCKS *(SSH-based)*

The server runs `ssh -N -D` as its own systemd service. The VayDNS tunnel points directly at that SOCKS5 listener. The client only needs a single command — no SSH step required.

```bash
vaydns-client -udp 8.8.8.8:53 -pubkey <server-pubkey> -domain t.example.com -listen 127.0.0.1:7000 -max-qname-len 253
```

Point your browser at `SOCKS5  127.0.0.1:7000`.

> ⚠️ **Anyone who has your public key can use the proxy in this mode.** Keep the key private.

---

### Mode 2 — Client-side SOCKS *(private, requires SSH credentials)*

The tunnel forwards directly to SSH on port 22. Each client establishes their own private SOCKS5 proxy using `ssh -D`.

```bash
# Step 1 — start the tunnel
vaydns-client -udp 8.8.8.8:53 -pubkey <server-pubkey> -domain t.example.com -listen 127.0.0.1:8000 -max-qname-len 253

# Step 2 — open a private SOCKS5 proxy through the tunnel
ssh -N -D 127.0.0.1:7000 -p 8000 root@127.0.0.1
```

Point your browser at `SOCKS5  127.0.0.1:7000`.

---

### Mode 3 — microsocks *(recommended, especially for Iran and restricted networks)*

A minimal, lightweight SOCKS5 proxy ([microsocks](https://github.com/rofl0r/microsocks)) runs on the server as its own systemd service. The VayDNS tunnel points directly at it. The client only needs a single command.

```bash
# Client — one command, proxy ready on :7000
vaydns-client -udp 8.8.8.8:53 -pubkey <server-pubkey> -domain t.example.com -listen 127.0.0.1:7000 -max-qname-len 253
```

Point your browser at `SOCKS5  127.0.0.1:7000` and you're done.

> `-max-qname-len 253` is critical on public DNS resolvers — without it you will get MTU errors.

> ⚠️ **Anyone who has your public key can use the proxy.** Keep the key private and only share it with trusted clients.

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
- Tunnel mode (`3` = microsocks (default), `1` = server-side SOCKS, `2` = client-side SOCKS)
- Installation method (`1` = prebuilt binary (default), `2` = build from source)
- Network interface (auto-detected from default route)
- Response MTU (default `500` — conservative for ISP compatibility; raise to `1232` on unrestricted networks)

At the end it prints your **public key**, the exact **DNS records** to add, and ready-to-paste **client commands**.

---

## 🖥️ Client Setup

Download the prebuilt client binary for your platform below. All links point to the **latest release** automatically.

#### 🐧 Linux

| Architecture | Download |
|---|---|
| x86_64 (64-bit PC) | [vaydns-client-linux-amd64](https://github.com/net2share/vaydns/releases/latest/download/vaydns-client-linux-amd64) |
| ARM 64-bit (e.g. Raspberry Pi 4, Apple Silicon VM) | [vaydns-client-linux-arm64](https://github.com/net2share/vaydns/releases/latest/download/vaydns-client-linux-arm64) |
| ARM 32-bit (e.g. Raspberry Pi 2/3) | [vaydns-client-linux-armv6](https://github.com/net2share/vaydns/releases/latest/download/vaydns-client-linux-armv6) |
| x86 32-bit | [vaydns-client-linux-386](https://github.com/net2share/vaydns/releases/latest/download/vaydns-client-linux-386) |

#### 🪟 Windows

| Architecture | Download |
|---|---|
| x86_64 (64-bit, most PCs) | [vaydns-client-windows-amd64.exe](https://github.com/net2share/vaydns/releases/latest/download/vaydns-client-windows-amd64.exe) |
| ARM 64-bit | [vaydns-client-windows-arm64.exe](https://github.com/net2share/vaydns/releases/latest/download/vaydns-client-windows-arm64.exe) |
| x86 32-bit | [vaydns-client-windows-386.exe](https://github.com/net2share/vaydns/releases/latest/download/vaydns-client-windows-386.exe) |

#### 🍎 macOS

| Architecture | Download |
|---|---|
| Apple Silicon (M1/M2/M3) | [vaydns-client-darwin-arm64](https://github.com/net2share/vaydns/releases/latest/download/vaydns-client-darwin-arm64) |
| Intel Mac | [vaydns-client-darwin-amd64](https://github.com/net2share/vaydns/releases/latest/download/vaydns-client-darwin-amd64) |

> Not sure which to pick? On Windows open **Settings → System → About** and check "System type". On Linux run `uname -m` in a terminal. On Mac: Apple Silicon = ARM64, Intel = AMD64.

Alternatively, build from source:

```bash
git clone https://github.com/net2share/vaydns.git
cd vaydns
go build -o vaydns-client ./vaydns-client
```

### Transport Options

| Flag | Transport | Covertness |
|------|-----------|------------|
| `-udp 8.8.8.8:53` | Plaintext UDP DNS | ✅ Works even when DoH/DoT are blocked |
| `-doh https://cloudflare-dns.com/dns-query` | DNS over HTTPS | ✅ Looks like normal HTTPS |
| `-dot 1.1.1.1:853` | DNS over TLS | ✅ Looks like normal TLS |

> 🇮🇷 **If you are in Iran or a similarly restricted network:** use `-udp` — DoH and DoT ports are commonly blocked. Always include `-max-qname-len 253` to avoid MTU errors on public resolvers.

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

Re-running the script on an already-installed server opens an interactive management menu:

```
══════════════════════════════════════════
  VayDNS Management
══════════════════════════════════════════

  Domain  : t.example.com
  Mode    : Mode 3 — microsocks (lightweight, recommended for Iran)
  Binary  : Prebuilt release
  Service : active

  1) Show client connection commands
  2) Switch tunnel mode
  3) Change domain
  4) Show service status
  5) Update VayDNS
  6) Uninstall
  7) Exit
```

| Option | Description |
|--------|-------------|
| **Show client commands** | Reprints public key, DNS records, and all client commands |
| **Switch tunnel mode** | Switch between Mode 1, 2, and 3 — restarts everything cleanly |
| **Change domain** | Updates the tunnel domain and restarts the service |
| **Show service status** | Runs `systemctl status` for vaydns and any mode-specific service |
| **Update VayDNS** | Re-downloads the latest prebuilt binary, or pulls and rebuilds from source — whichever method was used at install time |
| **Uninstall** | Stops all services, removes iptables rules, deletes all files |

### Manual commands

```bash
systemctl status vaydns               # tunnel status
systemctl status vaydns-microsocks    # microsocks status (mode 3)
systemctl status vaydns-socks         # SSH SOCKS5 status (mode 1)
systemctl restart vaydns              # restart tunnel
journalctl -u vaydns -f               # live logs
cat /opt/vaydns/keys/server.pub       # show public key
```

Configuration is stored at `/opt/vaydns/vaydns.conf`.

---

## 🏗️ How It Works

```
Client                    DNS Resolver              VPS
──────                    ────────────              ───────────────────────
Browser
  │ SOCKS5 :7000
  ▼
vaydns-client ──── UDP / DoH / DoT ─────── UDP ──► vaydns-server :5300
  -max-qname-len 253                                      │
                                                   iptables (53 → 5300)
                                                          │
                                            ┌─────────────▼────────────┐
                                            │  Mode 3: microsocks      │
                                            │  (lightweight, :1080)    │
                                            ├──────────────────────────┤
                                            │  Mode 1: SSH -D :8000    │
                                            │  (SOCKS5 via SSH)        │
                                            ├──────────────────────────┤
                                            │  Mode 2: sshd :22        │
                                            │  (SSH login required)    │
                                            └──────────────────────────┘
```

The tunnel uses the [Noise protocol](https://noiseprotocol.org/noise.html) (`Noise_NK_25519_ChaChaPoly_BLAKE2s`) for end-to-end encryption between client and server, independent of whatever DNS transport is used.

### MTU Notes

The server default MTU is **500**, which is conservative and compatible with most ISPs and public resolvers. If you are on an unrestricted network you can raise it to `1232` (safe for most EDNS(0) resolvers) or up to `1452`. The client flag `-max-qname-len 253` must always be used alongside UDP on public resolvers to avoid MTU-related errors.

---

## 🔒 Security Notes

- **Private key** lives at `/opt/vaydns/keys/server.key` — back it up and never share it
- **Public key** is safe to share with clients — it authenticates the server, not the client
- **Mode 3 and Mode 1** are open: any client with the pubkey can proxy through your server
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

VayDNS itself is not included — it is either downloaded as a prebuilt binary from the [releases page](https://github.com/net2share/vaydns/releases) or cloned and compiled from [net2share/vaydns](https://github.com/net2share/vaydns) at install time.

---

## 🙏 Attribution

This project would not exist without:

- **[VayDNS](https://github.com/net2share/vaydns)** by [net2share](https://github.com/net2share) and contributors — the DNS tunnel server this script deploys. Released under CC0 (public domain).
- **[dnstt](https://www.bamsoftware.com/software/dnstt/)** by [David Fifield](https://www.bamsoftware.com/) — the upstream project VayDNS is based on. Also public domain.
- **[microsocks](https://github.com/rofl0r/microsocks)** by [rofl0r](https://github.com/rofl0r) — the lightweight SOCKS5 proxy used in Mode 3.

The `deploy-vaydns.sh` script in this repository is original work released under the [MIT License](LICENSE).
