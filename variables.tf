variable "do_token" {
  description = "DigitalOcean API token"
}

variable "ssh_key_name" {
  description = "Name of the SSH key stored in your DigitalOcean account (Settings > Security > SSH Keys)"
}

variable "region" {
  description = "DigitalOcean region slug"
  default     = "sfo3"
}
