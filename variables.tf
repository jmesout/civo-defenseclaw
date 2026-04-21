variable "civo_api_token" {
  description = "Civo API token. Get one at https://dashboard.civo.com/security"
  type        = string
  sensitive   = true
}

variable "civo_region" {
  description = "Civo region to deploy in"
  type        = string
  default     = "LON1"
}

variable "civo_instance_size" {
  description = "Civo instance size (e.g. g3.small, g3.medium). g3.medium recommended when running both OpenClaw and the DefenseClaw gateway."
  type        = string
  default     = "g3.small"
}

variable "civo_disk_image" {
  description = "Civo disk image name filter (e.g. ubuntu-noble, debian-12)"
  type        = string
  default     = "ubuntu-noble"
}

variable "hostname" {
  description = "Hostname for the Civo instance"
  type        = string
  default     = "defenseclaw"
}

variable "ssh_public_key" {
  description = "SSH public key (contents of id_ed25519.pub / id_rsa.pub) authorised to log in as the openclaw user."
  type        = string
}

variable "ssh_allowed_cidr" {
  description = "List of CIDRs permitted to SSH into the instance, e.g. [\"203.0.113.5/32\"]. Lock this down to your source IP."
  type        = list(string)
}

variable "relax_api_key" {
  description = "Relax.ai API key used as the OpenClaw model backend"
  type        = string
  sensitive   = true
}

variable "openclaw_gateway_token" {
  description = "Bearer token required on the OpenClaw gateway (port 18789)"
  type        = string
  sensitive   = true
}

variable "slack_bot_token" {
  description = "Optional Slack bot token (xoxb-...). Leave empty to skip Slack setup."
  type        = string
  default     = ""
  sensitive   = true
}

variable "slack_app_token" {
  description = "Optional Slack app-level token (xapp-...). Required if slack_bot_token is set."
  type        = string
  default     = ""
  sensitive   = true
}
