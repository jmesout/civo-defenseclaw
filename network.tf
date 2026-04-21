resource "civo_network" "defenseclaw" {
  label = "${var.hostname}-network"
}

resource "civo_firewall" "defenseclaw" {
  name                 = "${var.hostname}-firewall"
  network_id           = civo_network.defenseclaw.id
  create_default_rules = false

  ingress_rule {
    label      = "ssh-in"
    protocol   = "tcp"
    port_range = "22"
    cidr       = var.ssh_allowed_cidr
    action     = "allow"
  }

  egress_rule {
    label      = "https-out"
    protocol   = "tcp"
    port_range = "443"
    cidr       = ["0.0.0.0/0"]
    action     = "allow"
  }

  egress_rule {
    label      = "http-out"
    protocol   = "tcp"
    port_range = "80"
    cidr       = ["0.0.0.0/0"]
    action     = "allow"
  }

  egress_rule {
    label      = "dns-udp-out"
    protocol   = "udp"
    port_range = "53"
    cidr       = ["0.0.0.0/0"]
    action     = "allow"
  }

  egress_rule {
    label      = "dns-tcp-out"
    protocol   = "tcp"
    port_range = "53"
    cidr       = ["0.0.0.0/0"]
    action     = "allow"
  }
}
