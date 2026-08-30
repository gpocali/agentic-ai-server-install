#!/bin/bash
# Agentic AI Server Installer
# Designed for curl/wget | bash execution

set -e

APP_DIR="/opt/antigravity-server"
STORAGE_DIR="/storage/antigravity-server"
ENV_FILE="$APP_DIR/.env"
SERVICE_NAME="antigravity-agent.service"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME"

# Determine the actual user running the script
ACTUAL_USER="${SUDO_USER:-$USER}"

echo "🚀 Starting Agentic AI Server Setup/Update..."

# 1. Update system packages
echo "📦 Updating system packages..."
sudo apt-get update -qq
sudo apt-get install -y -qq python3 python3-pip python3-venv build-essential curl git jq > /dev/null

if ! command -v node >/dev/null 2>&1; then
    echo "🛠️ Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - > /dev/null
    sudo apt-get install -y -qq nodejs > /dev/null
fi

# 2. Set up application and storage structure
echo "📁 Provisioning directories..."
sudo mkdir -p "$APP_DIR"
# Create dedicated storage subfolders for this application
sudo mkdir -p "$STORAGE_DIR/workspace"
sudo mkdir -p "$STORAGE_DIR/models"

sudo chown -R "$ACTUAL_USER":"$ACTUAL_USER" "$APP_DIR"
sudo chown -R "$ACTUAL_USER":"$ACTUAL_USER" "$STORAGE_DIR"
cd "$APP_DIR"

# 3. Handle Configuration Persistence
echo "⚙️ Checking runtime configuration..."
sudo -u "$ACTUAL_USER" touch "$ENV_FILE"

if grep -q "^GEMINI_API_KEY=" "$ENV_FILE"; then
    EXISTING_KEY=$(grep "^GEMINI_API_KEY=" "$ENV_FILE" | cut -d '=' -f2- | tr -d '"')
else
    EXISTING_KEY=""
fi

if [ -z "$EXISTING_KEY" ]; then
    echo "🔑 No API key found in configuration."
    printf "Please enter your Gemini API Key: "
    read -r USER_API_KEY < /dev/tty
    
    echo "GEMINI_API_KEY=\"$USER_API_KEY\"" | sudo -u "$ACTUAL_USER" tee -a "$ENV_FILE" > /dev/null
    echo "✅ Configuration saved securely to $ENV_FILE."
else
    echo "✅ Existing configuration loaded. Skipping setup prompts."
fi

# 4. Initialize or update Python Virtual Environment
echo "🐍 Syncing Python environment & SDK dependencies..."
sudo -u "$ACTUAL_USER" python3 -m venv venv
sudo -u "$ACTUAL_USER" ./venv/bin/pip install --upgrade pip -q
sudo -u "$ACTUAL_USER" ./venv/bin/pip install google-antigravity asyncio python-dotenv -q

# 5. Write the latest server script
echo "📝 Writing latest server.py execution script..."
sudo -u "$ACTUAL_USER" cat << EOF_PYTHON > server.py
import asyncio
import os
import sys
from dotenv import load_dotenv
from google.antigravity import Agent, LocalAgentConfig, CapabilitiesConfig
from google.antigravity.mcp import McpStdioServer

load_dotenv()

async def main():
    print("Initializing Google Antigravity Server with MCP Extensions...", flush=True)
    
    # Pointing to the external storage drive paths
    workspace_dir = "$STORAGE_DIR/workspace"
    models_dir = "$STORAGE_DIR/models"
    
    # Grant the filesystem MCP server access to both the workspace and models directories
    fs_mcp_server = McpStdioServer(
        command="npx",
        args=["-y", "@modelcontextprotocol/server-filesystem", workspace_dir, models_dir]
    )
    
    config = LocalAgentConfig(
        system_instructions="You are an autonomous server agent running on Ubuntu 26.04 LTS. Await remote tasks and execute them efficiently.",
        capabilities=CapabilitiesConfig(),
        mcp_servers=[fs_mcp_server]
    )
    
    async with Agent(config) as agent:
        print("Agent is online. Awaiting remote invocation...\n", flush=True)
        while True:
            await asyncio.sleep(3600)

if __name__ == "__main__":
    asyncio.run(main())
EOF_PYTHON

# 6. Configure and start systemd service
echo "⚙️ Creating and enabling systemd service..."
cat << EOF | sudo tee "$SERVICE_FILE" > /dev/null
[Unit]
Description=Google Antigravity Agent Server
After=network.target

[Service]
Type=simple
User=$ACTUAL_USER
WorkingDirectory=$APP_DIR
EnvironmentFile=$ENV_FILE
ExecStart=$APP_DIR/venv/bin/python3 $APP_DIR/server.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME" --quiet
sudo systemctl restart "$SERVICE_NAME"

echo "✅ Installation complete and service is running in the background!"
echo "📁 Storage directories initialized at: $STORAGE_DIR"
echo "🔍 View live logs with: sudo journalctl -fu $SERVICE_NAME"