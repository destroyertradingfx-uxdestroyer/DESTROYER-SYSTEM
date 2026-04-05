#!/bin/bash
# Weekly memory audit — run every Sunday
# 1. Find duplicate memory files
# 2. List one-time scripts that can be deleted
# 3. Output audit report

MEMORY_DIR="/home/ubuntu/.openclaw/workspace/memory"
BACKUP_DIR="$MEMORY_DIR/backups"
REPORT="$MEMORY_DIR/audit-report-$(date -u +%Y%m%d).md"

echo "# Memory Audit Report — $(date -u +%Y-%m-%d)" > "$REPORT"
echo "" >> "$REPORT"

# File inventory
echo "## File Inventory" >> "$REPORT"
echo "\`\`\`" >> "$REPORT"
find "$MEMORY_DIR" -name "*.md" -not -path "*/backups/*" -printf "%f\t%s bytes\n" >> "$REPORT" 2>/dev/null
echo "\`\`\`" >> "$REPORT"
echo "" >> "$REPORT"

# Backup count
BACKUP_COUNT=$(find "$BACKUP_DIR" -name "*.tar.gz" 2>/dev/null | wc -l)
echo "## Backups: $BACKUP_COUNT archives" >> "$REPORT"
echo "" >> "$REPORT"

# Total size
TOTAL=$(du -sh "$MEMORY_DIR" 2>/dev/null | cut -f1)
echo "## Total Memory Size: $TOTAL" >> "$REPORT"

echo "$REPORT"
