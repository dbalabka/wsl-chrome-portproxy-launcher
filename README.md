# Chrome Start From WSL Helper for MCP

A small WSL helper to open Google Chrome on Windows with remote debugging (port 9222) while bridging traffic from WSL via `socat`. It checks/prints the required Windows portproxy and firewall setup, ensures `socat` is installed, starts the tunnel, and launches Chrome with a temporary profile.

## Features
- Detects Windows host IP automatically from WSL.
- Verifies Windows portproxy forwarding (9222) and shows admin PowerShell commands if missing.
- Verifies the Windows firewall rule for port 9222 and shows the admin command if missing.
- Ensures `socat` is installed on WSL, installs via `apt` when needed.
- Starts a background `socat` bridge WSL→Windows (logs to `/tmp/socat-9222.log`).
- Launches Windows Chrome with `--remote-debugging-port=9222` and a temp profile.
- Skips launching if port 9222 is already listening on Windows; warns if Chrome is running without the debug port.
- Works under bash or zsh; includes `--stop` to kill the `socat` forwarder.

## Prerequisites
- WSL with `powershell.exe` available.
- Windows Chrome installed at `C:\Program Files\Google\Chrome\Application\chrome.exe` (adjust the path in the script if different).
- Network/apt access to install `socat` on first run (or preinstall manually).
- Run the script from inside WSL; non-WSL Linux is not supported (Docker has limited proxy-only support, see below).

## Usage

### with NPX
```sh
npx @dbalabka/chrome-wsl
```
- If portproxy/firewall entries are missing, run the printed admin PowerShell commands on Windows, then rerun the script.
- The script logs `socat` output to `/tmp/socat-9222.log`.
- To stop the `socat` forwarder:
```sh
 npx @dbalabka/chrome-wsl --stop
```
- To uninstall (prompts before removing the firewall rule and socat):
```sh
 npx @dbalabka/chrome-wsl --uninstall
```
- Runs directly via npm without cloning; default entrypoint is `chrome-wsl` (matching the package name).

#### Example
```sh
❯ npx @dbalabka/chrome-wsl
✅ Detected Windows host IP: 172.18.112.1
✅ Portproxy 172.18.112.1:9222 -> 127.0.0.1:9222 is configured.
✅ Firewall rule "Chrome Remote Debug" exists.
✅ socat is already installed.
✅ Started socat (logging to /tmp/socat-9222.log).
✅ Launched Chrome (pid 32408) with remote debugging.
✅ Chrome is listening on port 9222.
```
```sh
❯ npx @dbalabka/chrome-wsl --stop
✅ Stopped tracked Chrome process (pid 32408).
✅ Stopped socat forwarding for port 9222.
```

### with NPM
To install globally instead of npx:
  ```sh
  npm install -g @dbalabka/chrome-wsl
  ```
Then run:
  ```sh
  chrome-wsl
  chrome-wsl --stop
  chrome-wsl --uninstall
  ```

## Notes
- Portproxy check expects forwarding from the detected Windows host IP to `127.0.0.1:9222`.
- Chrome launch is skipped when port 9222 already listens on Windows (assumed active remote-debug session).
- For a different remote debugging port or Chrome path, edit `PORT` or `WINDOWS_CHROME_PATH` in `start_chrome_wsl.sh`.

## Chrome DevTools MCP configuration for agents

To use Windows Chrome with any agent running in WSL you have 
to cofigure the DevTools to connect to `--browser-url=http://127.0.0.1:9222`.

### Codex

```toml
[mcp_servers.chome-devtools]
command = "npx"
args = ["-y", "chrome-devtools-mcp@latest", "--browser-url=http://127.0.0.1:9222"]
startup_timeout_sec = 20.0
```

## License
MIT License. See `LICENSE` for details.

### Docker
- Targets `host.docker.internal:9222`.
- Supported inside Docker: start tunnel (`npx @dbalabka/chrome-wsl`) and uninstall proxy (`npx @dbalabka/chrome-wsl --uninstall`).
- Other flags (e.g., firewall/portproxy checks for Windows) are skipped; full start must happen from WSL.

## License
MIT License. See `LICENSE` for details.
