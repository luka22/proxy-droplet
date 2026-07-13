# proxy-droplet

[![CI](https://github.com/luka22/proxy-droplet/actions/workflows/ci.yml/badge.svg)](https://github.com/luka22/proxy-droplet/actions/workflows/ci.yml)

Spin up a disposable DigitalOcean SOCKS5 proxy in seconds. A single command provisions a minimal Debian droplet via Terraform, opens an SSH SOCKS5 tunnel on port 1337, and tears everything down automatically when you're done.

## How it works

1. `create-droplet.sh` prompts you to choose a region, then provisions a Debian 13 droplet with Terraform
2. An SSH SOCKS5 tunnel is opened on `localhost:1337`
3. Configure your browser or system to use `SOCKS5 localhost:1337`
4. Press `Ctrl+C` — the tunnel closes and the droplet is destroyed automatically

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) ≥ 1.0
- A [DigitalOcean](https://www.digitalocean.com/) account with:
  - A [Personal Access Token](https://docs.digitalocean.com/reference/api/create-personal-access-token/) with read/write scope — this is `DO_PAT`
  - An SSH key [uploaded to your account](https://docs.digitalocean.com/platform/teams/how-to/upload-ssh-keys/) — its **name** in DigitalOcean is `DO_SSH_KEY`
- The corresponding SSH **private key file** on your local machine — its **path** is `SSH_KEY_PATH`

> `DO_SSH_KEY` and `SSH_KEY_PATH` refer to the same key pair but aren't interchangeable: `DO_SSH_KEY` is the name shown in your DigitalOcean account, while `SSH_KEY_PATH` is the local file path to the matching private key (e.g. `~/.ssh/my-key`, not `~/.ssh/my-key.pub`). DigitalOcean's dashboard layout changes from time to time — if you can't find where to view tokens/keys, see [Troubleshooting](#troubleshooting) below for an API-based way to look them up.

## Setup

### 1. Initialize Terraform

```bash
terraform init
```

> The `.terraform.lock.hcl` file is committed to this repo — it pins the provider version so you get consistent behaviour without needing to re-resolve dependencies.

### 2. Set environment variables

```bash
export DO_PAT="your_digitalocean_api_token"
export DO_SSH_KEY="name-of-your-ssh-key-in-digitalocean"

# Optional — defaults to ~/.ssh/id_ed25519
export SSH_KEY_PATH="$HOME/.ssh/your_key"

# Optional — defaults to 1337
export SOCKS_PORT=1337
```

### 3. Start the proxy

```bash
./create-droplet.sh
```

Select a region when prompted. The script will provision the droplet, wait for SSH, and open the tunnel.

### 4. Configure your browser

Point your browser's SOCKS5 proxy to `localhost:1337` (or whichever port you set).

- **Firefox**: Settings → Network Settings → Manual proxy → SOCKS Host `127.0.0.1`, Port `1337`, SOCKS v5
- **Chrome/macOS**: System Preferences → Network → Proxies → SOCKS Proxy → `127.0.0.1:1337`

### 5. Stop

Press `Ctrl+C`. The tunnel closes and the droplet is destroyed automatically.

To destroy manually (e.g. after an unexpected exit):

```bash
./destroy-droplet.sh
```

## Configuration reference

| Variable       | Required | Default              | Description                                      |
|----------------|----------|----------------------|--------------------------------------------------|
| `DO_PAT`       | ✅       | —                    | DigitalOcean API token                           |
| `DO_SSH_KEY`   | ✅       | —                    | SSH key name in your DigitalOcean account        |
| `SSH_KEY_PATH` | —        | `~/.ssh/id_ed25519`  | Path to the local SSH private key file           |
| `SOCKS_PORT`   | —        | `1337`               | Local port to bind the SOCKS5 tunnel             |
| `SKIP_FORTUNE` | —        | `0`                  | Set to `1` to skip the fortune install (~30s)    |

## Available regions

| Slug    | Location      |
|---------|---------------|
| `sfo3`  | San Francisco |
| `nyc3`  | New York      |
| `ams3`  | Amsterdam     |
| `sgp1`  | Singapore     |
| `lon1`  | London        |
| `fra1`  | Frankfurt     |
| `tor1`  | Toronto       |
| `blr1`  | Bangalore     |

## Security notes

- The droplet allows **SSH inbound only** (firewall blocks all other ports), and by default only from your detected public IP (falls back to open if detection fails — see below)
- Password authentication and empty passwords are disabled via `cloud-init`
- The SSH host key is pinned on first connect to protect against MITM attacks
- The droplet is billed only for the time it exists (typically a few minutes per session)

### SSH firewall restriction

`create-droplet.sh` detects your public IP (via `api.ipify.org`, falling back to `ifconfig.me`) and restricts the firewall's SSH rule to that `/32`. If detection fails, it falls back to `0.0.0.0/0` (open) so the script still works.

Because the IP is captured once at `terraform apply` time, if your public IP changes mid-session (Wi-Fi drop, VPN toggle, carrier NAT reassignment) an already-open tunnel will likely keep working on its existing connection, but a fresh SSH connection would be blocked — you'd need to `destroy-droplet.sh` and re-run `create-droplet.sh` from the new IP.

## Cost

Uses the smallest DigitalOcean droplet (`s-1vcpu-512mb-10gb`, ~$4/month). Since it's destroyed after each session, a typical 1-hour session costs less than a cent.

## Troubleshooting

**`Error: DO_SSH_KEY environment variable is not set` (or `DO_PAT`), even though you set it before**

Environment variables only live in the shell session they were set in — they don't carry over to a new terminal window, tab, or app (e.g. switching from iTerm to another terminal). Re-export both in the new session, or persist them in your shell profile (e.g. `~/.zshrc`) if you don't want to repeat this — just don't commit your `DO_PAT` anywhere.

**Can't find where to view/create your API token or SSH keys in the DigitalOcean dashboard**

DigitalOcean reorganizes its control panel from time to time, so menu paths in this README (or in DigitalOcean's own docs) can go stale. The reliable fallback is to ask the API directly:

```bash
# List SSH key names already uploaded to your account — whichever matches
# your local key's name is your DO_SSH_KEY
curl -s -H "Authorization: Bearer $DO_PAT" "https://api.digitalocean.com/v2/account/keys" \
  | jq -r '.ssh_keys[].name'
```

See DigitalOcean's docs on [personal access tokens](https://docs.digitalocean.com/reference/api/create-personal-access-token/) and [SSH keys](https://docs.digitalocean.com/platform/teams/how-to/upload-ssh-keys/) for the current dashboard flow.

**`Error: image not found: GET .../images/debian-<version>-x64: 404`**

DigitalOcean retires an image slug shortly after that Debian release reaches end-of-life. Check which Debian slugs are currently supported, and if needed update the `slug` in `droplet.tf`'s `data "digitalocean_image" "debian"` block to match:

```bash
curl -s -H "Authorization: Bearer $DO_PAT" "https://api.digitalocean.com/v2/images?type=distribution&per_page=200" \
  | jq -r '.images[] | select(.distribution=="Debian") | .slug'
```
