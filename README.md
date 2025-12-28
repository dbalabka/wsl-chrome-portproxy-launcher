# Chrome Start From WSL Helper for MCP

A lightweight shell script that **automates Chrome DevTools MCP setup** from **WSL** by launching **Windows Chrome** with remote debugging enabled and transparently proxying traffic from WSL using `socat`.

No Linux Chrome, no gWSL, no manual Windows networking setup.

## What It Does

* 🤖 Automatically bridges **WSL → Windows Chrome DevTools (9222)** using `socat`
* ✅ Validates required **Windows portproxy and firewall rules**
* 🚀 Launches **existing Windows Chrome** with remote debugging and a temporary profile
* 🧹 Cleans up easily with a stop command and leaves no permanent system changes

## Key Features

* **Fully automated**: one command to get Chrome DevTools MCP working from WSL
* **Lightweight**: simple, readable shell script
* **Uses your existing Windows Chrome** — no Linux Chrome or gWSL required
* **Clean & reversible**: minimal system changes, easy to uninstall

## Prerequisites

* Windows Chrome already installed
* WSL environment
* The script will install one small dependency (`socat`) automatically for port proxying


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

> ℹ️️ Note: Must be run from WSL. Docker is supported only for proxying (no Chrome launch).

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

## Docker

`chrome-wsl` can also take care of starting a proxy inside the Docker container and allow to access the MCP server from localhost. It helps to use the same Chrome DevTools MCP configuration for agents running inside the docker container as well as outside.
```shell
npx @dbalabka/chrome-wsl --container=<name>
npx @dbalabka/chrome-wsl --stop --container=<name>
npx @dbalabka/chrome-wsl --uninstall --container=<name>
```

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

To run Codex inside the container and use the same MCP configuration and authorisation token, mount the Codex configuration folder inside the docker container using the following docker composer settings:
```shell
services:
    app:
        volumes:
            - ~/.codex:/home/vscode/.codex
```

## License
MIT License. See `LICENSE` for details.
