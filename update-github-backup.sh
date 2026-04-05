#!/bin/bash
# DESTROYER SYSTEM — Auto backup to GitHub every 2 hours
# Run via cron: 0 */2 * * *

set -e

BACKUP_DIR="/tmp/destroyer-system"
WORKSPACE="/home/ubuntu/.openclaw/workspace"
TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M UTC")

echo "[$TIMESTAMP] Starting DESTROYER backup..."

# Ensure backup dir exists
mkdir -p "$BACKUP_DIR/trading/webhook-server"
mkdir -p "$BACKUP_DIR/trading/chrome-extension/icons"
mkdir -p "$BACKUP_DIR/trading/signal-processor"
mkdir -p "$BACKUP_DIR/trading/bookmarklet"
mkdir -p "$BACKUP_DIR/trading/tv-mcp-server"

# Copy workspace files
cp "$WORKSPACE/SOUL.md" "$BACKUP_DIR/"
cp "$WORKSPACE/IDENTITY.md" "$BACKUP_DIR/"
cp "$WORKSPACE/USER.md" "$BACKUP_DIR/"
cp "$WORKSPACE/MEMORY.md" "$BACKUP_DIR/"
cp "$WORKSPACE/AGENTS.md" "$BACKUP_DIR/"
cp "$WORKSPACE/TOOLS.md" "$BACKUP_DIR/"
cp "$WORKSPACE/HEARTBEAT.md" "$BACKUP_DIR/"

# Copy memory files
mkdir -p "$BACKUP_DIR/memory"
cp "$WORKSPACE/memory"/*.md "$BACKUP_DIR/memory/" 2>/dev/null || true

# Copy trading code
cp "$WORKSPACE/trading/webhook-server/server.py" "$BACKUP_DIR/trading/webhook-server/" 2>/dev/null || true
cp "$WORKSPACE/trading/webhook-server/server.js" "$BACKUP_DIR/trading/webhook-server/" 2>/dev/null || true
cp "$WORKSPACE/trading/webhook-server/https-server.py" "$BACKUP_DIR/trading/webhook-server/" 2>/dev/null || true
cp "$WORKSPACE/trading/webhook-server/start-receiver.sh" "$BACKUP_DIR/trading/webhook-server/" 2>/dev/null || true
cp "$WORKSPACE/trading/chrome-extension/manifest.json" "$BACKUP_DIR/trading/chrome-extension/" 2>/dev/null || true
cp "$WORKSPACE/trading/chrome-extension/background.js" "$BACKUP_DIR/trading/chrome-extension/" 2>/dev/null || true
cp "$WORKSPACE/trading/chrome-extension/popup.html" "$BACKUP_DIR/trading/chrome-extension/" 2>/dev/null || true
cp "$WORKSPACE/trading/chrome-extension/popup.js" "$BACKUP_DIR/trading/chrome-extension/" 2>/dev/null || true
cp "$WORKSPACE/trading/chrome-extension/injector.js" "$BACKUP_DIR/trading/chrome-extension/" 2>/dev/null || true
cp "$WORKSPACE/trading/chrome-extension/icons/"*.png "$BACKUP_DIR/trading/chrome-extension/icons/" 2>/dev/null || true
cp "$WORKSPACE/trading/signal-processor/processor.py" "$BACKUP_DIR/trading/signal-processor/" 2>/dev/null || true
cp "$WORKSPACE/trading/bookmarklet/"*.js "$BACKUP_DIR/trading/bookmarklet/" 2>/dev/null || true
cp "$WORKSPACE/trading/tv-mcp-server/server.py" "$BACKUP_DIR/trading/tv-mcp-server/" 2>/dev/null || true
cp "$WORKSPACE/trading/TV_AUTOMATION_REFERENCE.md" "$BACKUP_DIR/" 2>/dev/null || true

# Copy scripts
cp "$WORKSPACE/scripts/"*.sh "$BACKUP_DIR/" 2>/dev/null || true

# Update README timestamp
sed -i "s/Last Updated: .*/Last Updated: $TIMESTAMP/" "$BACKUP_DIR/README.md" 2>/dev/null || true

# Strip any accidentally committed secrets
sed -i 's/gsk_[a-zA-Z0-9_]\{20,\}/YOUR_GROQ_KEY_HERE/g' "$BACKUP_DIR/CREDENTIALS.md" 2>/dev/null || true
sed -i 's/sm_[a-zA-Z0-9_]\{20,\}/YOUR_SUPERMEMORY_KEY_HERE/g' "$BACKUP_DIR/CREDENTIALS.md" 2>/dev/null || true
sed -i 's/z_[a-zA-Z0-9_]\{20,\}/YOUR_ZEP_KEY_HERE/g' "$BACKUP_DIR/CREDENTIALS.md" 2>/dev/null || true
sed -i 's/sk-or-v1-[a-zA-Z0-9_]\{20,\}/YOUR_OPENROUTER_KEY_HERE/g' "$BACKUP_DIR/CREDENTIALS.md" 2>/dev/null || true

# Git commit and push
cd "$BACKUP_DIR"
git add -A
git commit -m "Auto-backup: $TIMESTAMP" --allow-empty 2>/dev/null || true
git push origin master 2>/dev/null || (
    git remote remove origin 2>/dev/null || true
    git remote add origin git@github.com:destroyertradingfx-uxdestroyer/DESTROYER-SYSTEM.git || true
    git push origin master --force 2>/dev/null || echo "[$TIMESTAMP] PUSH FAILED"
)

echo "[$TIMESTAMP] Backup complete"
