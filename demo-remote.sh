#!/usr/bin/env bash
# demo-remote.sh — uploads demo/ to the Civo instance and launches the demo
# inside an interactive SSH session so `read -r` pauses work correctly.
#
# Prerequisites on your laptop:  sshpass, terraform (state populated)
set -euo pipefail

cd "$(dirname "$0")"

command -v sshpass >/dev/null || { echo "sshpass not found — brew install sshpass"; exit 1; }
command -v terraform >/dev/null || { echo "terraform not found"; exit 1; }

IP=$(terraform output -raw instance_public_ip)
PW=$(terraform output -raw ssh_password)
USER=$(terraform output -raw ssh_user)

echo "→ Uploading demo/ to ${USER}@${IP}"
sshpass -p "$PW" scp -q \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -r demo "${USER}@${IP}:/home/${USER}/"

echo "→ Launching demo (interactive)"
exec sshpass -p "$PW" ssh -t \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  "${USER}@${IP}" \
  'cd demo && chmod +x run.sh acts/*.sh && ./run.sh'
