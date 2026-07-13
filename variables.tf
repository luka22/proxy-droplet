variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "ssh_key_name" {
  description = "Name of the SSH key stored in your DigitalOcean account (Settings > Security > SSH Keys)"
  type        = string
}

variable "region" {
  description = "DigitalOcean region slug"
  type        = string
  default     = "sfo3"
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to SSH into the droplet"
  type        = string
  default     = "0.0.0.0/0"
}
