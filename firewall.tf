resource "digitalocean_firewall" "proxy" {
  name        = "proxy-ssh-only"
  droplet_ids = [digitalocean_droplet.proxy.id]

  # Only allow SSH inbound, from the caller's IP by default — all other ports/sources are blocked
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = [var.allowed_ssh_cidr]
  }

  # Allow all outbound so the proxy can reach the internet
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}
