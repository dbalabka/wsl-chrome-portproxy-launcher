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

## Usage
```sh
./start_chrome_wsl.sh
```
- If portproxy/firewall entries are missing, run the printed admin PowerShell commands on Windows, then rerun the script.
- The script logs `socat` output to `/tmp/socat-9222.log`.
- To stop the `socat` forwarder:
```sh
./start_chrome_wsl.sh --stop
```

## Notes
- Portproxy check expects forwarding from the detected Windows host IP to `127.0.0.1:9222`.
- Chrome launch is skipped when port 9222 already listens on Windows (assumed active remote-debug session).
- For a different remote debugging port or Chrome path, edit `PORT` or `WINDOWS_CHROME_PATH` in `start_chrome_wsl.sh`.
