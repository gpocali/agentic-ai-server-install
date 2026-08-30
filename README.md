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
wget -qO- https://raw.githubusercontent.com/gpocali/agentic-ai-server-install/main/install.sh | bash

```

## Directory Structure & Storage

To prevent large AI model files from filling up your root OS drive, the installation separates the application environment from the data payload:

* **Application & Environment (`/opt/antigravity-server`):** 
  Contains the Python virtual environment, the core execution script (`server.py`), and your `.env` configuration file.
* **Data Storage (`/storage/antigravity-server`):** 
  Contains the `workspace/` and `models/` subdirectories. The agent is explicitly granted read/write access to these segregated paths via the filesystem MCP server.

### Mounting an External Drive or Partition

Because AI models and agent workspaces can consume significant disk space, the `/storage` directory is designed to be mapped to a separate partition, external NVMe drive, or storage pool. 

If you are attaching a new drive, mount it persistently to `/storage` before running the installer:

1. **Identify the drive:**
   ```bash
   sudo lsblk

```

*(For this example, assume your new drive is `/dev/nvme0n1`).*

2. **Format the drive (if it is unformatted):**
```bash
sudo mkfs.ext4 /dev/nvme0n1

```


3. **Create the base mount point:**
```bash
sudo mkdir -p /storage

```


4. **Retrieve the drive's UUID:**
```bash
sudo blkid /dev/nvme0n1

```


5. **Configure persistent mounting:**
Open `/etc/fstab` with your preferred text editor (e.g., `sudo nano /etc/fstab`) and add the following line, replacing `your-uuid-here` with the output from the previous step:
```text
UUID=your-uuid-here  /storage  ext4  defaults  0  2

```


6. **Mount the drive:**
```bash
sudo mount -a

```


Once the drive is mounted to `/storage`, you can run the installation script. The installer will automatically generate the `antigravity-server` subdirectories on the new drive and apply the correct user permissions without modifying the root ownership of the `/storage` mount itself.


## Managing the Background Service

The installation script automatically registers and starts the agent as a background `systemd` service (`antigravity-agent.service`). It is configured to launch automatically whenever the server boots.

You can manage the daemon and monitor its activity using standard systemctl commands:

**View live logs (Recommended)**
Watch the agent's real-time output, including MCP tool execution and remote task processing:
```bash
sudo journalctl -fu antigravity-agent.service

```

*(Press `Ctrl+C` to exit the log stream)*

**Check current status**
Verify the service is running and see recent state changes:

```bash
sudo systemctl status antigravity-agent.service

```

**Restart the agent**
Required if you manually edit `/opt/antigravity-server/server.py` or your `.env` configuration file:

```bash
sudo systemctl restart antigravity-agent.service

```

**Stop the agent**
Halt the service manually:

```bash
sudo systemctl stop antigravity-agent.service

```

**Start the agent**
Start the service if it was previously stopped:

```bash
sudo systemctl start antigravity-agent.service

```

## Connecting Remote Antigravity Clients

To offload processing and allow Antigravity instances on other machines (like your laptop or workstation) to utilize this server's GPU, you need to point them to the host's inference API. 

### 1. Verify Inference Engine Network Binding
For the server to accept connections from other machines, your local inference engine must be bound to `0.0.0.0` (all interfaces) rather than `localhost`.
* **Ollama:** The install script automatically configures and restarts the Ollama service to listen on all interfaces.
* **LM Studio:** Open the desktop application, go to the **Local Server** tab, change the network binding to `0.0.0.0` (or check "Listen on all network interfaces"), and click **Start Server**.

### 2. Identify the Server's IP Address
Determine the IP address of your Ubuntu server on the trusted network you configured during installation. If you restricted access to Tailscale, use the server's Tailscale IP (`100.x.y.z`). If you used a local VLAN, use the standard LAN IP (`192.168.x.y` or `10.0.x.y`).

### 3. Register the Server in the Antigravity IDE
On the client machine (the remote computer you want to work from):
1. Open the Antigravity application.
2. Navigate to **Settings** > **Models** > **Add Custom** (or equivalent endpoint configuration).
3. Set the **API URL** to your server's IP and port, appending the API path. 
   * *Example:* `http://100.x.y.z:1234/v1` (for LM Studio) or `http://100.x.y.z:11434/v1` (for Ollama).
4. **Select the Model:** The Antigravity IDE will ping the endpoint. Select the active model you configured during the server installation (e.g., `gemma-4-31b`).
5. Save your settings. 

When you issue prompts in the client IDE, the context and reasoning tasks will now route over the network to execute on your Ubuntu server's hardware.