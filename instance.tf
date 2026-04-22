data "civo_disk_image" "ubuntu" {
  filter {
    key    = "name"
    values = [var.civo_disk_image]
  }
}

resource "random_id" "openclaw_gateway_token" {
  byte_length = 32
}

resource "random_password" "ssh_password" {
  length  = 24
  special = false
}

resource "civo_instance" "defenseclaw" {
  hostname    = var.hostname
  size        = var.civo_instance_size
  disk_image  = element(data.civo_disk_image.ubuntu.diskimages, 0).id
  network_id  = civo_network.defenseclaw.id
  firewall_id = civo_firewall.defenseclaw.id

  script = templatefile("${path.module}/templates/cloud-init.sh.tpl", {
    hostname               = var.hostname
    ssh_password           = random_password.ssh_password.result
    relax_api_key          = var.relax_api_key
    relax_model            = var.relax_model
    openclaw_gateway_token = random_id.openclaw_gateway_token.hex
    slack_bot_token        = var.slack_bot_token
    slack_app_token        = var.slack_app_token
  })

  lifecycle {
    ignore_changes = [script]
  }
}
