# proxy-droplet

Spin up a disposable DigitalOcean SOCKS5 proxy in seconds. A single command provisions a minimal Debian droplet via Terraform, opens an SSH SOCKS5 tunnel on port 1337, and tears everything down automatically when you're done.

## How it works

1. `create-droplet.sh` prompts you to choose a region, then provisions a Debian 12 droplet with Terraform
2. An SSH SOCKS5 tunnel is opened on `localhost:1337`
3. Configure your browser or system to use `SOCKS5 localhost:1337`
4. Press `Ctrl+C` — the tunnel closes and the droplet is destroyed automatically

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) ≥ 1.0
- A [DigitalOcean](https://www.digitalocean.com/) account with:
  - An API token (Personal Access Token with read/write scope)
  - An SSH key uploaded to your account (**Settings → Security → SSH Keys**)
- The corresponding SSH private key on your local machine

## Setup

### 1. Initialize Terraform

```bash
terraform init
```

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

- The droplet allows **SSH inbound only** (firewall blocks all other ports)
- Password authentication and empty passwords are disabled via `cloud-init`
- The SSH host key is pinned on first connect to protect against MITM attacks
- The droplet is billed only for the time it exists (typically a few minutes per session)

## Cost

Uses the smallest DigitalOcean droplet (`s-1vcpu-512mb-10gb`, ~$4/month). Since it's destroyed after each session, a typical 1-hour session costs less than a cent.
