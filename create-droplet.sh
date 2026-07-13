#! /bin/bash
# Creates a DigitalOcean droplet and opens a SOCKS5 proxy tunnel on port 1337.
# Automatically destroys the droplet when the tunnel is closed (Ctrl+C).
# The firewall is restricted to the machine's detected public IP; falls back
# to 0.0.0.0/0 if detection fails.
#
# Required environment variables:
#   DO_PAT         — DigitalOcean API token
#   DO_SSH_KEY     — Name of the SSH key in your DigitalOcean account (Settings > Security > SSH Keys)
#
# Optional environment variables:
#   SSH_KEY_PATH   — Path to the private key file (default: ~/.ssh/id_ed25519)
#   SOCKS_PORT     — Local port for the SOCKS5 tunnel (default: 1337)
set -e

SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/id_ed25519}"
SOCKS_PORT="${SOCKS_PORT:-1337}"

if [ -z "$DO_PAT" ]; then
  echo "Error: DO_PAT environment variable is not set."
  exit 1
fi

if [ -z "$DO_SSH_KEY" ]; then
  echo "Error: DO_SSH_KEY environment variable is not set."
  echo "Set it to the name of your SSH key in DigitalOcean (Settings > Security > SSH Keys)."
  exit 1
fi

if [ ! -f "$SSH_KEY_PATH" ]; then
  echo "Error: SSH private key not found at $SSH_KEY_PATH"
  echo "Set SSH_KEY_PATH to the correct path."
  exit 1
fi

# Pass credentials to Terraform via env vars to avoid exposing them in the process list
export TF_VAR_do_token="$DO_PAT"
export TF_VAR_ssh_key_name="$DO_SSH_KEY"

# Resolve script directory so destroy-droplet.sh can be called from anywhere
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Temp file to hold the pinned host key for this session
KNOWN_HOSTS_TMP=$(mktemp)

# Called on Ctrl+C or TERM signal — tears down the droplet automatically
cleanup() {
  echo ""
  echo "Tunnel closed. Destroying droplet..."
  rm -f "$KNOWN_HOSTS_TMP"
  "$SCRIPT_DIR/destroy-droplet.sh"
}

# Prompt user to select a DigitalOcean region
REGIONS=("sfo3 (San Francisco)" "nyc3 (New York)" "ams3 (Amsterdam)" "sgp1 (Singapore)" "lon1 (London)" "fra1 (Frankfurt)" "tor1 (Toronto)" "blr1 (Bangalore)")

echo "Select a region:"
select REGION_CHOICE in "${REGIONS[@]}"; do
  if [ -n "$REGION_CHOICE" ]; then
    REGION=$(echo "$REGION_CHOICE" | awk '{print $1}')
    echo "Using region: $REGION"
    break
  else
    echo "Invalid selection, please try again."
  fi
done

# Detect our own public IP so the firewall can restrict SSH to it instead of 0.0.0.0/0.
# Falls back to the Terraform default (open to all) if detection fails.
echo "Detecting your public IP..."
MY_IP=$(curl -fsS --max-time 5 https://api.ipify.org 2>/dev/null || curl -fsS --max-time 5 https://ifconfig.me 2>/dev/null || true)

if [[ "$MY_IP" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
  echo "Restricting SSH to $MY_IP/32"
  ALLOWED_SSH_CIDR="$MY_IP/32"
else
  echo "Warning: could not detect public IP. SSH will be open to 0.0.0.0/0."
  ALLOWED_SSH_CIDR="0.0.0.0/0"
fi

# Provision the droplet via Terraform
terraform apply -auto-approve -var "region=$REGION" -var "allowed_ssh_cidr=$ALLOWED_SSH_CIDR"

# Extract the droplet's public IP from Terraform output
IP=$(terraform output -raw ipv4_address)

if [ -n "$IP" ]; then
  echo ""
  echo "Droplet IP: $IP"
  echo "SSH: ssh -i $SSH_KEY_PATH root@$IP"
  echo ""

  # Wait for SSH to become available (droplet may not be ready immediately after provisioning)
  echo "Waiting for SSH to become available..."
  for i in $(seq 1 30); do
    if ssh -i "$SSH_KEY_PATH" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=5 \
        -o BatchMode=yes \
        root@"$IP" true 2>/dev/null; then
      echo "SSH is ready."
      break
    fi
    echo "  Attempt $i/30 failed, retrying in 5s..."
    sleep 5
    if [ "$i" -eq 30 ]; then
      echo "Error: SSH did not become available after 150s. Destroying droplet."
      rm -f "$KNOWN_HOSTS_TMP"
      "$SCRIPT_DIR/destroy-droplet.sh"
      exit 1
    fi
  done

  # Pin the host key now that SSH is confirmed up — protects against MITM on all subsequent connections
  echo "Pinning host key..."
  ssh-keyscan -H "$IP" >> "$KNOWN_HOSTS_TMP" 2>/dev/null

  # Install and run fortune on the remote droplet (set SKIP_FORTUNE=1 to skip)
  if [ "${SKIP_FORTUNE:-0}" != "1" ]; then
    echo "Fortune says:"
    ssh -i "$SSH_KEY_PATH" \
      -o StrictHostKeyChecking=yes \
      -o UserKnownHostsFile="$KNOWN_HOSTS_TMP" \
      -o LogLevel=ERROR \
      root@"$IP" "cloud-init status --wait > /dev/null 2>&1; DEBIAN_FRONTEND=noninteractive apt-get update -qq > /dev/null 2>&1 && apt-get install -yqq fortune-mod fortunes > /dev/null 2>&1 && /usr/games/fortune"
    echo ""
  fi

  echo ""
  cat << 'EOF'
  ██████╗ ██████╗  ██████╗ ██╗  ██╗██╗   ██╗
  ██╔══██╗██╔══██╗██╔═══██╗╚██╗██╔╝╚██╗ ██╔╝
  ██████╔╝██████╔╝██║   ██║ ╚███╔╝  ╚████╔╝
  ██╔═══╝ ██╔══██╗██║   ██║ ██╔██╗   ╚██╔╝
  ██║     ██║  ██║╚██████╔╝██╔╝ ██╗   ██║
  ╚═╝     ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝

  ┌─────────────────────────────────────────┐
  │   SOCKS5 TUNNEL ONLINE  :::  PORT 1337  │
  │          >> STAY ANONYMOUS <<           │
  └─────────────────────────────────────────┘
EOF
  echo ""

  echo "Starting SOCKS tunnel on port $SOCKS_PORT... (Ctrl+C to stop and destroy droplet)"
  # Destroy droplet on Ctrl+C or termination signal
  trap cleanup INT TERM
  # Open SOCKS5 tunnel: -D binds local port, -C enables compression, -N skips remote command
  ssh -i "$SSH_KEY_PATH" -D "$SOCKS_PORT" -C -N \
    -o StrictHostKeyChecking=yes \
    -o UserKnownHostsFile="$KNOWN_HOSTS_TMP" \
    -o ServerAliveInterval=60 \
    -o ServerAliveCountMax=3 \
    root@"$IP" || true
fi
