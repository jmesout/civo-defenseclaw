output "instance_public_ip" {
  description = "Public IPv4 of the Civo instance"
  value       = civo_instance.defenseclaw.public_ip
}

output "ssh_user" {
  description = "SSH username (set by Civo's cloud image, typically 'civo')"
  value       = civo_instance.defenseclaw.initial_user
}

output "ssh_password" {
  description = "Auto-generated password for the SSH user (set by cloud-init via chpasswd). Retrieve with `terraform output -raw ssh_password`."
  value       = random_password.ssh_password.result
  sensitive   = true
}

output "ssh_command" {
  description = "SSH into the instance. You will be prompted for the password from `terraform output -raw ssh_password`."
  value       = "ssh ${civo_instance.defenseclaw.initial_user}@${civo_instance.defenseclaw.public_ip}"
}

output "gateway_tunnel_command" {
  description = "Forward OpenClaw (18789) and DefenseClaw (8765) to localhost via SSH"
  value       = "ssh -L 18789:localhost:18789 -L 8765:localhost:8765 ${civo_instance.defenseclaw.initial_user}@${civo_instance.defenseclaw.public_ip}"
}

output "defenseclaw_status_command" {
  description = "Check DefenseClaw gateway + guardrail health"
  value       = "ssh ${civo_instance.defenseclaw.initial_user}@${civo_instance.defenseclaw.public_ip} 'defenseclaw status'"
}

output "openclaw_gateway_token" {
  description = "Auto-generated bearer token required on the OpenClaw gateway (port 18789). Retrieve with `terraform output -raw openclaw_gateway_token`."
  value       = random_id.openclaw_gateway_token.hex
  sensitive   = true
}
