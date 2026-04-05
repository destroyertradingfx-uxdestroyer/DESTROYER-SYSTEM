#!/bin/bash
# Memory backup to Supermemory — runs every 6 hours via cron
# Usage: ./memory-backup-supermemory.sh

API_KEY="sm_yMuPghBAf4Fpf5HM3G89k6_TrBOuNjopteFfOksodIlQhAkQVRFSgnZixAPdpgdOAbIjAlxgaOIYmeTiArMnVpJ"
MEMORY_DIR="/home/ubuntu/.openclaw/workspace/memory"
BACKUP_DIR="/home/ubuntu/.openclaw/workspace/memory/backups"
MEMORY_MD="/home/ubuntu/.openclaw/workspace/MEMORY.md"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Create backup archive
BACKUP_NAME="memory-backup-$(date -u +%Y%m%d-%H%M%S).tar.gz"
tar czf "$BACKUP_DIR/$BACKUP_NAME" \
  -C /home/ubuntu/.openclaw/workspace \
  MEMORY.md \
  $(find memory -name "*.md" -not -path "memory/backups/*" 2>/dev/null) \
  2>/dev/null

# Upload MEMORY.md to Supermemory
if [ -f "$MEMORY_MD" ]; then
  curl -s -X POST "https://api.supermemory.ai/api/v1/document" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -d "{
      \"content\": $(python3 -c "import json; print(json.dumps(open('$MEMORY_MD').read()))" 2>/dev/null),
      \"source\": \"openclaw-memory\",
      \"timestamp\": \"$TIMESTAMP\",
      \"type\": \"operational-memory\"
    }" > /dev/null 2>&1
fi

# Upload daily memory files
for f in "$MEMORY_DIR"/*.md; do
  [ -f "$f" ] && [ "$(basename "$f")" != "$(basename "$BACKUP_DIR")" ] && \
  curl -s -X POST "https://api.supermemory.ai/api/v1/document" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -d "{
      \"content\": $(python3 -c "import json; print(json.dumps(open('$f').read()))" 2>/dev/null),
      \"source\": \"openclaw-daily-memory\",
      \"filename\": \"$(basename "$f")\",
      \"timestamp\": \"$TIMESTAMP\",
      \"type\": \"daily-log\"
    }" > /dev/null 2>&1
done

echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) — Backup complete: $BACKUP_NAME"
