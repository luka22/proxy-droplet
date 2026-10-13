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

# No default: callers must choose the CIDR explicitly so SSH is never opened to the internet by accident
variable "allowed_ssh_cidr" {
  description = "CIDR allowed to SSH into the droplet"
  type        = string

  validation {
    condition     = can(cidrhost(var.allowed_ssh_cidr, 0))
    error_message = "allowed_ssh_cidr must be a valid CIDR block, e.g. 203.0.113.7/32."
  }
}
