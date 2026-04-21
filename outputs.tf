output "instance_public_ip" {
  description = "Public IPv4 of the Civo instance"
  value       = civo_instance.defenseclaw.public_ip
}

output "ssh_command" {
  description = "SSH into the instance as the openclaw user"
  value       = "ssh openclaw@${civo_instance.defenseclaw.public_ip}"
}

output "gateway_tunnel_command" {
  description = "Forward OpenClaw (18789) and DefenseClaw (8765) to localhost via SSH"
  value       = "ssh -L 18789:localhost:18789 -L 8765:localhost:8765 openclaw@${civo_instance.defenseclaw.public_ip}"
}

output "defenseclaw_status_command" {
  description = "Check DefenseClaw gateway + guardrail health"
  value       = "ssh openclaw@${civo_instance.defenseclaw.public_ip} 'defenseclaw status'"
}

output "openclaw_gateway_token" {
  description = "Auto-generated bearer token required on the OpenClaw gateway (port 18789). Retrieve with `terraform output -raw openclaw_gateway_token`."
  value       = random_id.openclaw_gateway_token.hex
  sensitive   = true
}
