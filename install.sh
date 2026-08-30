#!/bin/bash
# Agentic AI Server Installer - Local GPU & Secure Network Edition
# Designed for curl/wget | bash execution

set -e

APP_DIR="/opt/antigravity-server"
STORAGE_DIR="/storage/antigravity-server"
ENV_FILE="$APP_DIR/.env"
SERVICE_NAME="antigravity-agent.service"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME"

ACTUAL_USER="${SUDO_USER:-$USER}"

echo "🚀 Starting Local Agentic AI Server Setup..."

# 1. Update & Install Core Dependencies
sudo apt-get update -qq
sudo apt-get install -y -qq python3 python3-pip python3-venv build-essential curl git jq ufw > /dev/null

if ! command -v node >/dev/null 2>&1; then
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - > /dev/null
    sudo apt-get install -y -qq nodejs > /dev/null
fi

# 2. Provision Storage
sudo mkdir -p "$APP_DIR"
sudo mkdir -p "$STORAGE_DIR/workspace"
sudo mkdir -p "/storage/lmstudio/models"

sudo chown -R "$ACTUAL_USER":"$ACTUAL_USER" "$APP_DIR"
sudo chown -R "$ACTUAL_USER":"$ACTUAL_USER" "$STORAGE_DIR"
cd "$APP_DIR"

# 3. Agent Configuration
echo "⚙️ Checking runtime configuration..."
sudo -u "$ACTUAL_USER" touch "$ENV_FILE"

if ! grep -q "^OAI_BASE_URL=" "$ENV_FILE"; then
    echo "🔌 Configuring local hardware inference."
    printf "Enter your Local API URL (default: http://127.0.0.1:1234/v1): "
    read -r LOCAL_URL < /dev/tty
    LOCAL_URL=${LOCAL_URL:-"http://127.0.0.1:1234/v1"}
    
    printf "Enter the model name (e.g., gemma-4-31b): "
    read -r MODEL_NAME < /dev/tty
    MODEL_NAME=${MODEL_NAME:-"gemma-4-31b"}
    
    echo "OAI_BASE_URL=\"$LOCAL_URL\"" | sudo -u "$ACTUAL_USER" tee -a "$ENV_FILE" > /dev/null
    echo "LOCAL_MODEL=\"$MODEL_NAME\"" | sudo -u "$ACTUAL_USER" tee -a "$ENV_FILE" > /dev/null
    echo "✅ Configuration saved to $ENV_FILE."
else
    # Load existing URL for firewall configuration
    LOCAL_URL=$(grep "^OAI_BASE_URL=" "$ENV_FILE" | cut -d '=' -f2- | tr -d '"')
fi

# 4. Network & Security Binding
# Extract the port from the provided URL (e.g., 1234 or 11434)
URL_WITHOUT_PROTO="${LOCAL_URL#*://}"
PORT_AND_PATH="${URL_WITHOUT_PROTO#*:}"
API_PORT="${PORT_AND_PATH%%/*}"

echo "🔒 Configuring UFW Firewall for API Port $API_PORT..."
printf "Enter trusted network for API access (e.g., tailscale0, a VLAN subnet like 10.0.10.0/24, or 'any') [default: tailscale0]: "
read -r TRUSTED_SRC < /dev/tty
TRUSTED_SRC=${TRUSTED_SRC:-"tailscale0"}

sudo ufw --force enable > /dev/null
if [ "$TRUSTED_SRC" = "any" ]; then
    sudo ufw allow "$API_PORT/tcp" > /dev/null
elif [[ "$TRUSTED_SRC" == *"/"* ]] || [[ "$TRUSTED_SRC" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    sudo ufw allow from "$TRUSTED_SRC" to any port "$API_PORT" proto tcp > /dev/null
else
    sudo ufw allow in on "$TRUSTED_SRC" to any port "$API_PORT" proto tcp > /dev/null
fi

# Attempt to auto-bind Ollama to 0.0.0.0 if it is installed as a systemd service
if systemctl list-unit-files | grep -q "^ollama.service"; then
    echo "⚙️ Ollama detected. Binding service to 0.0.0.0..."
    sudo mkdir -p /etc/systemd/system/ollama.service.d
    echo -e "[Service]\nEnvironment=\"OLLAMA_HOST=0.0.0.0\"" | sudo tee /etc/systemd/system/ollama.service.d/override.conf > /dev/null
    sudo systemctl daemon-reload
    sudo systemctl restart ollama
fi
# Note: LM Studio UI must still be bound to 0.0.0.0 manually in the desktop app if used instead of Ollama.

# 5. Initialize Python Environment
echo "🐍 Syncing Python environment..."
sudo -u "$ACTUAL_USER" python3 -m venv venv
sudo -u "$ACTUAL_USER" ./venv/bin/pip install --upgrade pip -q
sudo -u "$ACTUAL_USER" ./venv/bin/pip install google-antigravity asyncio python-dotenv -q

# 6. Write Server Script
sudo -u "$ACTUAL_USER" cat << EOF_PYTHON > server.py
import asyncio
import os
import sys
from dotenv import load_dotenv
from google.antigravity import Agent, LocalAgentConfig, CapabilitiesConfig
from google.antigravity.mcp import McpStdioServer

load_dotenv()

async def main():
    print(f"Initializing Google Antigravity Server on local GPU...", flush=True)
    
    workspace_dir = "$STORAGE_DIR/workspace"
    models_dir = "/storage/lmstudio/models"
    
    fs_mcp_server = McpStdioServer(
        command="npx",
        args=["-y", "@modelcontextprotocol/server-filesystem", workspace_dir, models_dir]
    )
    
    config = LocalAgentConfig(
        system_instructions="You are an autonomous server agent. Await remote tasks and execute them.",
        capabilities=CapabilitiesConfig(),
        mcp_servers=[fs_mcp_server],
        openai_base_url=os.getenv("OAI_BASE_URL"),
        model=os.getenv("LOCAL_MODEL")
    )
    
    async with Agent(config) as agent:
        print(f"Agent online. Awaiting invocation...\n", flush=True)
        while True:
            await asyncio.sleep(3600)

if __name__ == "__main__":
    asyncio.run(main())
EOF_PYTHON

# 7. Start Agent Service
echo "⚙️ Refreshing systemd service..."
cat << EOF | sudo tee "$SERVICE_FILE" > /dev/null
[Unit]
Description=Google Antigravity Local GPU Agent Server
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
echo "✅ Installation complete!"