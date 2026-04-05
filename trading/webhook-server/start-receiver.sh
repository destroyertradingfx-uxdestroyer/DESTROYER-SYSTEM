#!/bin/bash
# Start DESTROYER TradingView Webhook Receiver
# Run: ./start-receiver.sh

cd "$(dirname "$0")"
export TV_WEBHOOK_PORT=${TV_WEBHOOK_PORT:-8471}
export TV_WEBHOOK_TOKEN=${TV_WEBHOOK_TOKEN:-destroyer-signal-2026}

echo "Starting DESTROYER TV Webhook Receiver on port $TV_WEBHOOK_PORT..."
python3 server.py
