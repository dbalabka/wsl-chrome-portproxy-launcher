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
PID_FILE="/tmp/start-chrome-wsl.pids"
OK_MARK="✅"
ERR_MARK="❌"

ok() {
  echo "${OK_MARK} $*"
}

err() {
  echo "${ERR_MARK} $*" >&2
}

set_pid() {
  # Stores or updates a PID value in the temp PID file.
  local key=$1
  local value=$2
  [[ -z "${value:-}" ]] && return
  touch "$PID_FILE"
  if grep -q "^${key}=" "$PID_FILE" 2>/dev/null; then
    sed -i.bak "s/^${key}=.*/${key}=${value}/" "$PID_FILE" && rm -f "${PID_FILE}.bak"
  else
    echo "${key}=${value}" >>"$PID_FILE"
  fi
}

get_pid() {
  local key=$1
  [[ -f "$PID_FILE" ]] || return 0
  sed -n "s/^${key}=//p" "$PID_FILE" | head -n1
}

clear_pid() {
  local key=$1
  [[ -f "$PID_FILE" ]] || return 0
  sed -i.bak "/^${key}=/d" "$PID_FILE"
  rm -f "${PID_FILE}.bak"
  if [[ ! -s "$PID_FILE" ]]; then
    rm -f "$PID_FILE"
  fi
}

stop_socat() {
  local pattern="socat TCP-LISTEN:${PORT},fork,reuseaddr"
  if pgrep -f "$pattern" >/dev/null 2>&1; then
    pkill -f "$pattern" || true
    ok "Stopped socat forwarding for port ${PORT}."
    clear_pid "SOCAT_PID"
  else
    ok "No socat forwarding for port ${PORT} is running."
  fi
}

run_powershell() {
  # Runs a PowerShell command from WSL.
  powershell.exe -NoLogo -NoProfile -NonInteractive -Command "$@"
}

chrome_running() {
  run_powershell "if (Get-Process -Name chrome -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }"
}

port_listening_by_chrome() {
  local attempts=5
  local delay=1
  local i
  for ((i=1; i<=attempts; i++)); do
    if run_powershell "if (Get-NetTCPConnection -LocalPort ${PORT} -ErrorAction SilentlyContinue | Where-Object { \$p = Get-Process -Id \$_.OwningProcess -ErrorAction SilentlyContinue; \$p -and \$p.Name -eq 'chrome' }) { exit 0 } else { exit 1 }"; then
      return 0
    fi
    sleep "$delay"
  done
  return 1
}

port_listening_info() {
  run_powershell "\$conns = Get-NetTCPConnection -LocalPort ${PORT} -ErrorAction SilentlyContinue | Select-Object -Property LocalAddress,LocalPort,RemoteAddress,RemotePort,State,OwningProcess; foreach (\$c in \$conns) { \$p = Get-Process -Id \$c.OwningProcess -ErrorAction SilentlyContinue; \$name = if (\$p) { \$p.Name } else { 'unknown' }; Write-Output (\"{0}:{1} owner={2} pid={3} state={4}\" -f \$c.LocalAddress, \$c.LocalPort, \$name, \$c.OwningProcess, \$c.State) }"
}

get_wsl_host_ip() {
  local host_ip
  host_ip=$(ip route | awk '/^default via / {print $3; exit}')
  if [[ -z "${host_ip:-}" ]]; then
    err "Could not determine Windows host IP from default route."
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
    ok "Portproxy ${host_ip}:${PORT} -> 127.0.0.1:${PORT} is configured."
    return 0
  fi

  cat <<EOF
${ERR_MARK} Portproxy on ${host_ip}:${PORT} is missing.
Run this in an **admin PowerShell** window:
netsh interface portproxy add v4tov4 listenaddress=${host_ip} listenport=${PORT} connectaddress=127.0.0.1 connectport=${PORT}
EOF
  return 1
}

check_firewall_rule() {
  if run_powershell "\$rule='${FIREWALL_RULE_NAME}'; if (Get-NetFirewallRule -DisplayName \$rule -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }"; then
    ok "Firewall rule \"${FIREWALL_RULE_NAME}\" exists."
    return 0
  fi

  cat <<EOF
${ERR_MARK} Firewall rule "${FIREWALL_RULE_NAME}" is missing.
Run this in an **admin PowerShell** window:
New-NetFirewallRule -DisplayName "${FIREWALL_RULE_NAME}" -Direction Inbound -LocalPort ${PORT} -Protocol TCP -Action Allow
EOF
  return 1
}

ensure_socat() {
  if command -v socat >/dev/null 2>&1; then
    ok "socat is already installed."
    return 0
  fi

  err "socat not found. Installing via apt..."
  sudo apt-get update
  sudo apt-get install -y socat
}

start_socat() {
  local host_ip=$1
  if pgrep -f "socat TCP-LISTEN:${PORT},fork,reuseaddr TCP:${host_ip}:${PORT}" >/dev/null 2>&1; then
    ok "socat forwarding for port ${PORT} already running."
    return 0
  fi

  nohup socat "TCP-LISTEN:${PORT},fork,reuseaddr" "TCP:${host_ip}:${PORT}" >/tmp/socat-9222.log 2>&1 &
  set_pid "SOCAT_PID" "$!"
  ok "Started socat (logging to /tmp/socat-9222.log)."
}

stop_chrome() {
  local chrome_pid
  chrome_pid=$(get_pid "CHROME_PID")
  if [[ -z "${chrome_pid:-}" ]]; then
    ok "No tracked Chrome PID found; skipping Chrome stop."
    return 0
  fi

  if run_powershell "if (Get-Process -Id ${chrome_pid} -ErrorAction SilentlyContinue) { Stop-Process -Id ${chrome_pid} -Force; exit 0 } else { exit 1 }"; then
    ok "Stopped tracked Chrome process (pid ${chrome_pid})."
  else
    ok "Tracked Chrome PID ${chrome_pid} is not running."
  fi
  clear_pid "CHROME_PID"
}

start_chrome() {
  local chrome_cmd
  chrome_cmd="\$args = @(\"--remote-debugging-port=${PORT}\", \"--no-first-run\", \"--no-default-browser-check\", \"--user-data-dir=\$env:TEMP\\chrome-profile-stable\"); \$p = Start-Process -FilePath \"${WINDOWS_CHROME_PATH}\" -ArgumentList \$args -PassThru; Write-Output \$p.Id"

  if [[ -n "$(get_pid "CHROME_PID")" ]]; then
    if port_listening_by_chrome; then
      ok "Port ${PORT} already listening on Windows (owned by chrome); assuming ready. Skipping launch (tracked pid $(get_pid "CHROME_PID"))."
      return 0
    fi

    if chrome_running; then
      err "Chrome is running (tracked pid $(get_pid "CHROME_PID")), but port ${PORT} is not listening. You may need to start Chrome with --remote-debugging-port=${PORT}."
    fi
  fi

  local chrome_pid
  chrome_pid=$(run_powershell "$chrome_cmd" | tr -d '\r' | head -n 1)
  if [[ -n "${chrome_pid:-}" ]]; then
    set_pid "CHROME_PID" "$chrome_pid"
    ok "Launched Chrome (pid ${chrome_pid}) with remote debugging."
  else
    err "Launched Chrome but could not determine PID."
  fi

  if port_listening_by_chrome; then
    ok "Chrome is listening on port ${PORT}."
  else
    err "Chrome launch did not open port ${PORT}; verify remote-debugging flag or check for conflicts."
    port_listening_info
  fi
}

main() {
  if [[ "${1-}" == "--stop" ]]; then
    stop_chrome
    stop_socat
    exit 0
  fi

  local host_ip
  host_ip=$(get_wsl_host_ip)
  ok "Detected Windows host IP: ${host_ip}"

  check_portproxy "$host_ip" || exit 1
  check_firewall_rule || exit 1
  ensure_socat
  start_socat "$host_ip"
  start_chrome
}

main "$@"
