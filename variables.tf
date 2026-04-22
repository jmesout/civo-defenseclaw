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
  description = "Civo instance size. LON1 currently serves the g4s.* family; g3.* may return size_not_selectable. g4s.medium (2c/4GB) is comfortable for Node + Go gateway; downgrade to g4s.small (1c/2GB) for lighter use."
  type        = string
  default     = "g4s.medium"
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

variable "ssh_allowed_cidr" {
  description = <<-EOT
    List of CIDRs permitted to SSH into the instance.
    Default is "0.0.0.0/0" (open to the internet) — this relies solely on your
    SSH public key for authentication. For production, lock this to your source
    IP, e.g. ["203.0.113.5/32"].
  EOT
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "relax_api_key" {
  description = "Relax.ai API key used as the OpenClaw model backend"
  type        = string
  sensitive   = true
}

variable "relax_model" {
  description = "Relax.ai model id used as OpenClaw's primary model (e.g. \"Kimi-K25\"). Rendered into openclaw.json as \"relax/<relax_model>\"."
  type        = string
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
