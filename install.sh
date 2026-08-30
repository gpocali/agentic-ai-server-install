#!/bin/bash
# Agentic AI Server Installer
# Designed for curl/wget | bash execution

set -e

APP_DIR="/opt/antigravity-server"
ENV_FILE="$APP_DIR/.env"

# Determine the actual user running the script, avoiding root ownership inside /opt/ if run via sudo
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

# 2. Set up application structure
sudo mkdir -p "$APP_DIR/workspace"
sudo chown -R "$ACTUAL_USER":"$ACTUAL_USER" "$APP_DIR"
cd "$APP_DIR"

# 3. Handle Configuration Persistence
echo "⚙️ Checking runtime configuration..."
sudo -u "$ACTUAL_USER" touch "$ENV_FILE"

# Extract existing key to check if configuration is already complete
if grep -q "^GEMINI_API_KEY=" "$ENV_FILE"; then
    EXISTING_KEY=$(grep "^GEMINI_API_KEY=" "$ENV_FILE" | cut -d '=' -f2- | tr -d '"')
else
    EXISTING_KEY=""
fi

if [ -z "$EXISTING_KEY" ]; then
    # When piped via wget | bash, stdin is the script itself. 
    # We must explicitly read from /dev/tty to capture user input.
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
sudo -u "$ACTUAL_USER" cat << 'EOF' > server.py
import asyncio
import os
import sys
from dotenv import load_dotenv
from google.antigravity import Agent, LocalAgentConfig, CapabilitiesConfig
from google.antigravity.mcp import McpStdioServer

load_dotenv()

async def main():
    print("Initializing Google Antigravity Server with MCP Extensions...")
    workspace_dir = "/opt/antigravity-server/workspace"
    
    fs_mcp_server = McpStdioServer(
        command="npx",
        args=["-y", "@modelcontextprotocol/server-filesystem", workspace_dir]
    )
    
    config = LocalAgentConfig(
        system_instructions="You are an autonomous server agent running on Ubuntu 26.04 LTS. Await remote tasks and execute them efficiently.",
        capabilities=CapabilitiesConfig(),
        mcp_servers=[fs_mcp_server]
    )
    
    async with Agent(config) as agent:
        print("Agent is online. Awaiting remote invocation...\n")

if __name__ == "__main__":
    asyncio.run(main())
EOF

echo "✅ Installation complete! Run 'cd $APP_DIR && source venv/bin/activate && python3 server.py' to start the server."