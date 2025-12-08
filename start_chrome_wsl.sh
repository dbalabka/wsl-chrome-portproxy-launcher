#!/usr/bin/env bash
# Compatible with bash and zsh.
set -e
set -u
if command -v setopt >/dev/null 2>&1; then
  setopt pipefail
else
  set -o pipefail 2>/dev/null || true
fi

PORT=9222
WINDOWS_CHROME_PATH='C:\Program Files\Google\Chrome\Application\chrome.exe'
FIREWALL_RULE_NAME='Chrome Remote Debug'

stop_socat() {
  local pattern="socat TCP-LISTEN:${PORT},fork,reuseaddr"
  if pgrep -f "$pattern" >/dev/null 2>&1; then
    pkill -f "$pattern" || true
    echo "Stopped socat forwarding for port ${PORT}."
  else
    echo "No socat forwarding for port ${PORT} is running."
  fi
}

run_powershell() {
  # Runs a PowerShell command from WSL.
  powershell.exe -NoLogo -NoProfile -NonInteractive -Command "$@"
}

chrome_running() {
  run_powershell "if (Get-Process -Name chrome -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }"
}

port_listening() {
  run_powershell "if (Get-NetTCPConnection -LocalPort ${PORT} -ErrorAction SilentlyContinue | Where-Object { \$_.State -eq 'Listen' }) { exit 0 } else { exit 1 }"
}

get_wsl_host_ip() {
  local host_ip
  host_ip=$(ip route | awk '/^default via / {print $3; exit}')
  if [[ -z "${host_ip:-}" ]]; then
    echo "Could not determine Windows host IP from default route." >&2
    return 1
  fi
  printf '%s' "$host_ip"
}

check_portproxy() {
  local host_ip=$1
  local output regex
  output=$(run_powershell "netsh interface portproxy show all" | tr -d '\r')
  regex="${host_ip//./\\.}[[:space:]]+${PORT}[[:space:]]+127\\.0\\.0\\.1[[:space:]]+${PORT}"
  if echo "$output" | grep -Eq "$regex"; then
    echo "Portproxy ${host_ip}:${PORT} -> 127.0.0.1:${PORT} is configured."
    return 0
  fi

  cat <<EOF
Portproxy on ${host_ip}:${PORT} is missing.
Run this in an **admin PowerShell** window:
netsh interface portproxy add v4tov4 listenaddress=${host_ip} listenport=${PORT} connectaddress=127.0.0.1 connectport=${PORT}
EOF
  return 1
}

check_firewall_rule() {
  if run_powershell "\$rule='${FIREWALL_RULE_NAME}'; if (Get-NetFirewallRule -DisplayName \$rule -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }"; then
    echo "Firewall rule \"${FIREWALL_RULE_NAME}\" exists."
    return 0
  fi

  cat <<EOF
Firewall rule "${FIREWALL_RULE_NAME}" is missing.
Run this in an **admin PowerShell** window:
New-NetFirewallRule -DisplayName "${FIREWALL_RULE_NAME}" -Direction Inbound -LocalPort ${PORT} -Protocol TCP -Action Allow
EOF
  return 1
}

ensure_socat() {
  if command -v socat >/dev/null 2>&1; then
    echo "socat is already installed."
    return 0
  fi

  echo "socat not found. Installing via apt..."
  sudo apt-get update
  sudo apt-get install -y socat
}

start_socat() {
  local host_ip=$1
  if pgrep -f "socat TCP-LISTEN:${PORT},fork,reuseaddr TCP:${host_ip}:${PORT}" >/dev/null 2>&1; then
    echo "socat forwarding for port ${PORT} already running."
    return 0
  fi

  nohup socat "TCP-LISTEN:${PORT},fork,reuseaddr" "TCP:${host_ip}:${PORT}" >/tmp/socat-9222.log 2>&1 &
  echo "Started socat (logging to /tmp/socat-9222.log)."
}

start_chrome() {
  local chrome_cmd
  chrome_cmd="& \"${WINDOWS_CHROME_PATH}\" --remote-debugging-port=${PORT} --no-first-run --no-default-browser-check --user-data-dir=\"\$env:TEMP\\chrome-profile-stable\""

  if port_listening; then
    echo "Port ${PORT} already listening on Windows; assuming Chrome is ready. Skipping launch."
    return 0
  fi

  if chrome_running; then
    echo "Chrome is running, but port ${PORT} is not listening. You may need to start Chrome with --remote-debugging-port=${PORT}."
  fi

  run_powershell "$chrome_cmd"
}

main() {
  if [[ "${1-}" == "--stop" ]]; then
    stop_socat
    exit 0
  fi

  local host_ip
  host_ip=$(get_wsl_host_ip)
  echo "Detected Windows host IP: ${host_ip}"

  check_portproxy "$host_ip" || exit 1
  check_firewall_rule || exit 1
  ensure_socat
  start_socat "$host_ip"
  start_chrome
}

main "$@"
