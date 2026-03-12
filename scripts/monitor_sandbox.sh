#!/bin/bash
# monitor_sandbox.sh - OpenClaw Health Monitor
# Runs in background to check sandbox health

LOG_FILE="${OPENCLAW_WORKSPACE:-/data/openclaw-workspace}/monitor.log"
RECOVERY_SCRIPT="${OPENCLAW_WORKSPACE:-/data/openclaw-workspace}/recover_sandbox.sh"

mkdir -p "$(dirname "$LOG_FILE")"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log "🛡️  Health Monitor Started"

while true; do
  # Run every 5 minutes
  sleep 300
  
  log "🔍 Performing health check..."
  
  # Run recovery script as the "check and fix" mechanism
  if [ -f "$RECOVERY_SCRIPT" ]; then
    bash "$RECOVERY_SCRIPT" >> "$LOG_FILE" 2>&1
  else
    log "❌ Recovery script not found at $RECOVERY_SCRIPT"
  fi
done
