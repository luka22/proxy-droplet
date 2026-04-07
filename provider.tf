terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

# Authenticate with DigitalOcean using the provided API token
provider "digitalocean" {
  token = var.do_token
}

# Look up the SSH key stored in DigitalOcean by name
data "digitalocean_ssh_key" "terraform" {
  name = var.ssh_key_name
}
