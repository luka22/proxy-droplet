# Fetch the Debian 12 image to use as the droplet OS
data "digitalocean_image" "ubuntu" {
  slug = "debian-12-x64"
}

# Minimal droplet used as a SOCKS5 proxy — no provisioning needed
resource "digitalocean_droplet" "www-1" {
  image  = data.digitalocean_image.ubuntu.id
  name   = "sandbox"
  region = var.region
  size   = "s-1vcpu-512mb-10gb"
  ssh_keys = [
    data.digitalocean_ssh_key.terraform.id
  ]

  user_data = <<-EOF
    #!/bin/bash
    sed -i \
      -e 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' \
      -e 's/^#*PermitEmptyPasswords.*/PermitEmptyPasswords no/' \
      -e 's/^#*X11Forwarding.*/X11Forwarding no/' \
      -e 's/^#*MaxAuthTries.*/MaxAuthTries 3/' \
      /etc/ssh/sshd_config
    grep -q '^AllowTcpForwarding' /etc/ssh/sshd_config \
      || echo 'AllowTcpForwarding yes' >> /etc/ssh/sshd_config
    systemctl restart ssh
  EOF
}

# Expose the droplet's public IP for use in the SSH tunnel command
output "ipv4_address" {
  value = digitalocean_droplet.www-1.ipv4_address
}
