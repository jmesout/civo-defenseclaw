data "civo_disk_image" "ubuntu" {
  filter {
    key    = "name"
    values = [var.civo_disk_image]
  }
}

resource "civo_instance" "defenseclaw" {
  hostname    = var.hostname
  size        = var.civo_instance_size
  disk_image  = element(data.civo_disk_image.ubuntu.diskimages, 0).id
  network_id  = civo_network.defenseclaw.id
  firewall_id = civo_firewall.defenseclaw.id

  script = templatefile("${path.module}/templates/cloud-init.sh.tpl", {
    hostname               = var.hostname
    ssh_public_key         = var.ssh_public_key
    relax_api_key          = var.relax_api_key
    openclaw_gateway_token = var.openclaw_gateway_token
    slack_bot_token        = var.slack_bot_token
    slack_app_token        = var.slack_app_token
  })
}
