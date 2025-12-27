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
./chrome-wsl.sh
```
- If portproxy/firewall entries are missing, run the printed admin PowerShell commands on Windows, then rerun the script.
- The script logs `socat` output to `/tmp/socat-9222.log`.
- To stop the `socat` forwarder:
```sh
./chrome-wsl.sh --stop
```

## Installation (one-liner)
```sh
sudo install -m 755 chrome-wsl.sh /usr/local/bin/start-chrome-wsl
```
- Uses the local script (no curl/wget download needed). If you cloned the repo elsewhere, run from that path.
- Adjust `WINDOWS_CHROME_PATH` or `PORT` inside the script if needed.
- If `apt` is blocked, preinstall `socat` via your allowed package source.

## Installation via npx
```sh
npx --yes @dbalabka/chrome-wsl start-chrome-wsl
```
- Runs directly via npm without cloning; explicitly invokes the `start-chrome-wsl` binary from the scoped package.
- Use `npm install -g start-chrome-wsl` to keep it available without npx.

## Installation via pipx
```sh
pipx install start-chrome-wsl
```
- Installs the wrapper that invokes the same `start_chrome_wsl.sh` script.
- Alternatively, run without installing globally:
```sh
pipx run start-chrome-wsl --stop
```

## Notes
- Portproxy check expects forwarding from the detected Windows host IP to `127.0.0.1:9222`.
- Chrome launch is skipped when port 9222 already listens on Windows (assumed active remote-debug session).
- For a different remote debugging port or Chrome path, edit `PORT` or `WINDOWS_CHROME_PATH` in `start_chrome_wsl.sh`.

## License
MIT License. See `LICENSE` for details.
