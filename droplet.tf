# Fetch the Debian 13 image to use as the droplet OS
data "digitalocean_image" "debian" {
  slug = "debian-13-x64"
}

# Minimal droplet used as a SOCKS5 proxy — no provisioning needed
resource "digitalocean_droplet" "proxy" {
  image    = data.digitalocean_image.debian.id
  name     = "proxy-droplet"
  region   = var.region
  size     = "s-1vcpu-512mb-10gb"
  ssh_keys = [data.digitalocean_ssh_key.terraform.id]

  # sshd uses the first value it reads and sshd_config includes sshd_config.d/*.conf
  # at the top, so a 00- drop-in takes precedence over both the main file and cloud-init's
  user_data = <<-EOF
    #!/bin/bash
    cat > /etc/ssh/sshd_config.d/00-hardening.conf <<'CONF'
    PermitRootLogin prohibit-password
    PasswordAuthentication no
    KbdInteractiveAuthentication no
    PermitEmptyPasswords no
    X11Forwarding no
    MaxAuthTries 3
    AllowTcpForwarding yes
    CONF
    sshd -t && systemctl restart ssh
  EOF
}

# Expose the droplet's public IP for use in the SSH tunnel command
output "ipv4_address" {
  value = digitalocean_droplet.proxy.ipv4_address
}
