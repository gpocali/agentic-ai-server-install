# Agentic AI Server Installer

A streamlined, single-command deployment script to provision a Google Antigravity Agentic AI server on Ubuntu 26.04 LTS. This environment comes pre-configured with Model Context Protocol (MCP) support to easily extend your agent's capabilities.

## Features

* **Automated Provisioning:** Installs Python 3, Node.js, and core build tools without manual intervention.
* **Antigravity SDK:** Sets up an isolated Python virtual environment configured with the `google-antigravity` SDK.
* **MCP Extensibility:** Pre-wires the official `@modelcontextprotocol/server-filesystem` toolset via `npx`, granting the agent scoped read/write access to a local workspace.
* **Idempotent Updates:** Safe to run multiple times. Re-running the script updates dependencies and the core Python script without overwriting your saved `.env` configuration.

## Quick Install

Run the following command in your Ubuntu terminal. On the initial run, the script will pause to ask for your Gemini API key, which it will securely save to `/opt/antigravity-server/.env`.

```bash
wget -qO- [https://raw.githubusercontent.com/gpocali/agentic-ai-server-install/main/install.sh](https://raw.githubusercontent.com/gpocali/agentic-ai-server-install/main/install.sh) | bash

```

## Usage

The application and its virtual environment are installed to `/opt/antigravity-server`.

To start the agentic server, run:

```bash
cd /opt/antigravity-server
source venv/bin/activate
python3 server.py

```

### Workspace Directory

By default, the agent is granted filesystem manipulation capabilities restricted to `/opt/antigravity-server/workspace`. You can drop files in this directory for the agent to analyze, or instruct the agent to generate new files here.

