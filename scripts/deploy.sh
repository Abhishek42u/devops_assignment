#!/bin/bash
# This script runs ON the EC2 instance via SSM send-command during CI/CD deployment.
set -e

echo "[deploy] Pulling latest code from GitHub..."
cd /opt/app
git fetch origin main
git reset --hard origin/main

echo "[deploy] Installing dependencies..."
pip3 install -r app/requirements.txt -q

echo "[deploy] Restarting Flask service..."
systemctl restart flask-app

echo "[deploy] Done. Service status:"
systemctl status flask-app --no-pager
