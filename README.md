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